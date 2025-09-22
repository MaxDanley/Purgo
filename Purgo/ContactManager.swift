//
//  ContactManager.swift
//  Purgo
//
//  Created by Max Danley on 8/27/25.
//

import Foundation
import Contacts
import FirebaseFirestore

// MARK: - Contact Models
struct ContactMatch: Identifiable, Codable {
    let id: String
    let name: String
    let email: String?
    let phoneNumber: String?
    let profileImage: String?
    let mutualFriends: Int
    let isAlreadyFriend: Bool
    let isInvited: Bool
    let suggestedReason: String
}

struct ContactInfo: Codable {
    let name: String
    let email: String?
    let phoneNumber: String?
    let normalizedPhone: String?
    let normalizedEmail: String?
}

// MARK: - Contact Manager
@MainActor
class ContactManager: ObservableObject {
    @Published var contactsPermissionStatus: CNAuthorizationStatus = .notDetermined
    @Published var contactMatches: [ContactMatch] = []
    @Published var isLoadingContacts = false
    @Published var errorMessage: String?
    
    private let store = CNContactStore()
    private let db = Firestore.firestore()
    
    init() {
        contactsPermissionStatus = CNContactStore.authorizationStatus(for: .contacts)
    }
    
    // MARK: - Permission Management
    func requestContactsPermission() async {
        do {
            let granted = try await store.requestAccess(for: .contacts)
            contactsPermissionStatus = granted ? .authorized : .denied
            
            if granted {
                await loadAndMatchContacts()
            } else {
                errorMessage = "Contacts access denied. You can enable it in Settings > Privacy & Security > Contacts."
            }
        } catch {
            print("❌ Error requesting contacts permission: \(error)")
            errorMessage = "Failed to request contacts permission: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Contact Loading and Matching
    func loadAndMatchContacts() async {
        guard contactsPermissionStatus == .authorized else {
            errorMessage = "Contacts permission not granted"
            return
        }
        
        isLoadingContacts = true
        errorMessage = nil
        
        do {
            let contacts = try await fetchContacts()
            let contactInfos = contacts.map { contact in
                ContactInfo(
                    name: contact.name,
                    email: contact.email,
                    phoneNumber: contact.phoneNumber,
                    normalizedPhone: contact.normalizedPhone,
                    normalizedEmail: contact.normalizedEmail
                )
            }
            
            let matches = await findContactMatches(contactInfos)
            
            DispatchQueue.main.async {
                self.contactMatches = matches
                self.isLoadingContacts = false
            }
            
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to load contacts: \(error.localizedDescription)"
                self.isLoadingContacts = false
            }
        }
    }
    
    private func fetchContacts() async throws -> [ContactInfo] {
        let keys = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactEmailAddressesKey, CNContactPhoneNumbersKey] as [CNKeyDescriptor]
        let request = CNContactFetchRequest(keysToFetch: keys)
        
        var contacts: [ContactInfo] = []
        
        try store.enumerateContacts(with: request) { contact, _ in
            let name = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
            
            // Get first email
            let email = contact.emailAddresses.first?.value as String?
            
            // Get first phone number
            let phoneNumber = contact.phoneNumbers.first?.value.stringValue
            
            // Normalize phone number (remove non-digits)
            let normalizedPhone = phoneNumber?.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
            
            // Normalize email (lowercase)
            let normalizedEmail = email?.lowercased()
            
            // Only include contacts with at least a name and either email or phone
            if !name.isEmpty && (email != nil || phoneNumber != nil) {
                contacts.append(ContactInfo(
                    name: name,
                    email: email,
                    phoneNumber: phoneNumber,
                    normalizedPhone: normalizedPhone,
                    normalizedEmail: normalizedEmail
                ))
            }
        }
        
        return contacts
    }
    
    private func findContactMatches(_ contacts: [ContactInfo]) async -> [ContactMatch] {
        guard let currentUserId = FirebaseManager.shared.currentUser?.id else {
            return []
        }
        
        var matches: [ContactMatch] = []
        
        // Get all existing users
        let usersSnapshot = try? await db.collection("users").getDocuments()
        guard let users = usersSnapshot?.documents else { return [] }
        
        // Get current user's friends for mutual friend calculation
        let friendsSnapshot = try? await db.collection("friendships")
            .whereField("userId", isEqualTo: currentUserId)
            .whereField("status", isEqualTo: "accepted")
            .getDocuments()
        
        let friendIds = Set(friendsSnapshot?.documents.map { $0.data()["friendId"] as? String ?? "" } ?? [])
        
        // Get pending invitations
        let invitationsSnapshot = try? await db.collection("friendships")
            .whereField("userId", isEqualTo: currentUserId)
            .whereField("status", isEqualTo: "pending")
            .getDocuments()
        
        let invitedIds = Set(invitationsSnapshot?.documents.map { $0.data()["friendId"] as? String ?? "" } ?? [])
        
        for contact in contacts {
            for userDoc in users {
                let userData = userDoc.data()
                let userId = userDoc.documentID
                
                // Skip current user
                if userId == currentUserId { continue }
                
                // Check if already a friend
                if friendIds.contains(userId) { continue }
                
                // Check if already invited
                if invitedIds.contains(userId) { continue }
                
                var isMatch = false
                var matchReason = ""
                
                // Match by email
                if let contactEmail = contact.normalizedEmail,
                   let userEmail = userData["email"] as? String,
                   !userEmail.isEmpty,
                   contactEmail == userEmail.lowercased() {
                    isMatch = true
                    matchReason = "Email match"
                }
                
                // Match by phone number
                if !isMatch,
                   let contactPhone = contact.normalizedPhone,
                   let userPhone = userData["phoneNumber"] as? String,
                   !userPhone.isEmpty {
                    let normalizedUserPhone = userPhone.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
                    if contactPhone == normalizedUserPhone {
                        isMatch = true
                        matchReason = "Phone number match"
                    }
                }
                
                if isMatch {
                    // Calculate mutual friends
                    let mutualFriends = await calculateMutualFriends(userId: userId, currentUserFriends: friendIds)
                    
                    let match = ContactMatch(
                        id: userId,
                        name: userData["displayName"] as? String ?? userData["username"] as? String ?? "Unknown",
                        email: userData["email"] as? String,
                        phoneNumber: userData["phoneNumber"] as? String,
                        profileImage: userData["photoURL"] as? String,
                        mutualFriends: mutualFriends,
                        isAlreadyFriend: false,
                        isInvited: false,
                        suggestedReason: matchReason
                    )
                    
                    matches.append(match)
                }
            }
        }
        
        // Sort by mutual friends count (descending) and then by name
        return matches.sorted { first, second in
            if first.mutualFriends != second.mutualFriends {
                return first.mutualFriends > second.mutualFriends
            }
            return first.name < second.name
        }
    }
    
    private func calculateMutualFriends(userId: String, currentUserFriends: Set<String>) async -> Int {
        // Get the other user's friends
        let otherUserFriendsSnapshot = try? await db.collection("friendships")
            .whereField("userId", isEqualTo: userId)
            .whereField("status", isEqualTo: "accepted")
            .getDocuments()
        
        guard let otherUserFriends = otherUserFriendsSnapshot?.documents else { return 0 }
        
        let otherUserFriendIds = Set(otherUserFriends.map { $0.data()["friendId"] as? String ?? "" })
        
        // Calculate intersection
        return currentUserFriends.intersection(otherUserFriendIds).count
    }
    
    // MARK: - Invite Management
    func sendFriendRequest(to userId: String) async -> Bool {
        guard let currentUserId = FirebaseManager.shared.currentUser?.id else { return false }
        
        do {
            // Check if request already exists
            let existingRequest = try await db.collection("friendships")
                .whereField("userId", isEqualTo: currentUserId)
                .whereField("friendId", isEqualTo: userId)
                .getDocuments()
            
            if !existingRequest.isEmpty {
                errorMessage = "Friend request already sent"
                return false
            }
            
            // Create friend request
            let friendRequest: [String: Any] = [
                "userId": currentUserId,
                "friendId": userId,
                "status": "pending",
                "createdAt": Date(),
                "type": "friend_request"
            ]
            
            try await db.collection("friendships").addDocument(data: friendRequest)
            
            // Update the contact match to show as invited
            if let index = contactMatches.firstIndex(where: { $0.id == userId }) {
                contactMatches[index] = ContactMatch(
                    id: contactMatches[index].id,
                    name: contactMatches[index].name,
                    email: contactMatches[index].email,
                    phoneNumber: contactMatches[index].phoneNumber,
                    profileImage: contactMatches[index].profileImage,
                    mutualFriends: contactMatches[index].mutualFriends,
                    isAlreadyFriend: contactMatches[index].isAlreadyFriend,
                    isInvited: true,
                    suggestedReason: contactMatches[index].suggestedReason
                )
            }
            
            return true
            
        } catch {
            errorMessage = "Failed to send friend request: \(error.localizedDescription)"
            return false
        }
    }
    
    // MARK: - Utility Methods
    func refreshContactMatches() async {
        await loadAndMatchContacts()
    }
    
    func clearError() {
        errorMessage = nil
    }
}

// MARK: - Contact Info Extensions
extension ContactInfo {
    var displayName: String {
        return name.isEmpty ? "Unknown Contact" : name
    }
    
    var hasValidContactInfo: Bool {
        return !name.isEmpty && (email != nil || phoneNumber != nil)
    }
}
