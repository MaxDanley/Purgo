//
//  InviteManager.swift
//  Purgo
//
//  Created by Max Danley on 8/27/25.
//

import Foundation
import UIKit
import FirebaseFirestore

// MARK: - Invite Models
struct InviteLink: Codable {
    let id: String
    let userId: String
    let code: String
    let createdAt: Date
    let expiresAt: Date?
    let usageCount: Int
    let maxUsage: Int?
    let isActive: Bool
}

struct InviteData: Codable {
    let inviterId: String
    let inviterName: String
    let inviterUsername: String
    let inviterProfileImage: String?
    let appName: String
    let message: String
}

// MARK: - Invite Manager
@MainActor
class InviteManager: ObservableObject {
    @Published var currentInviteLink: String?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    
    // MARK: - Generate Invite Link
    func generateInviteLink() async -> String? {
        guard let currentUser = FirebaseManager.shared.currentUser else {
            errorMessage = "No current user"
            return nil
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Check if user already has an active invite link
            let existingLink = try await db.collection("inviteLinks")
                .whereField("userId", isEqualTo: currentUser.id)
                .whereField("isActive", isEqualTo: true)
                .getDocuments()
            
            if let existingDoc = existingLink.documents.first {
                let existingData = existingDoc.data()
                let code = existingData["code"] as? String ?? ""
                let inviteLink = createInviteURL(with: code)
                
                DispatchQueue.main.async {
                    self.currentInviteLink = inviteLink
                    self.isLoading = false
                }
                
                return inviteLink
            }
            
            // Generate new invite code
            let inviteCode = generateInviteCode()
            
            // Create invite link document
            let inviteLinkData: [String: Any] = [
                "userId": currentUser.id,
                "code": inviteCode,
                "createdAt": Date(),
                "expiresAt": Calendar.current.date(byAdding: .month, value: 3, to: Date()), // 3 months expiry
                "usageCount": 0,
                "maxUsage": 100, // Limit to 100 uses
                "isActive": true
            ]
            
            try await db.collection("inviteLinks").addDocument(data: inviteLinkData)
            
            let inviteLink = createInviteURL(with: inviteCode)
            
            DispatchQueue.main.async {
                self.currentInviteLink = inviteLink
                self.isLoading = false
            }
            
            return inviteLink
            
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to generate invite link: \(error.localizedDescription)"
                self.isLoading = false
            }
            return nil
        }
    }
    
    private func generateInviteCode() -> String {
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let codeLength = 8
        
        var code = ""
        for _ in 0..<codeLength {
            let randomIndex = Int.random(in: 0..<characters.count)
            let character = characters[characters.index(characters.startIndex, offsetBy: randomIndex)]
            code.append(character)
        }
        
        return code
    }
    
    private func createInviteURL(with code: String) -> String {
        // This would be your app's deep link URL
        // For now, using a placeholder that would work with your app
        return "https://purgo.app/invite/\(code)"
    }
    
    // MARK: - Share Invite Link
    func shareInviteLink() async {
        guard let inviteLink = currentInviteLink ?? await generateInviteLink() else {
            errorMessage = "Failed to generate invite link"
            return
        }
        
        guard let currentUser = FirebaseManager.shared.currentUser else {
            errorMessage = "No current user"
            return
        }
        
        let inviteData = InviteData(
            inviterId: currentUser.id,
            inviterName: currentUser.displayName.isEmpty ? currentUser.username : currentUser.displayName,
            inviterUsername: currentUser.username,
            inviterProfileImage: currentUser.photoURL,
            appName: "Purgo",
            message: "Join me on Purgo! Track your sauna and cold therapy sessions with friends. Download the app and use my invite code: \(extractCodeFromLink(inviteLink))"
        )
        
        await presentShareSheet(with: inviteData, inviteLink: inviteLink)
    }
    
    private func extractCodeFromLink(_ link: String) -> String {
        // Extract the invite code from the URL
        if let lastComponent = link.components(separatedBy: "/").last {
            return lastComponent
        }
        return "PURGO"
    }
    
    @MainActor
    private func presentShareSheet(with inviteData: InviteData, inviteLink: String) async {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            errorMessage = "Unable to present share sheet"
            return
        }
        
        let shareText = """
        \(inviteData.message)
        
        \(inviteLink)
        """
        
        let activityViewController = UIActivityViewController(
            activityItems: [shareText],
            applicationActivities: nil
        )
        
        // Configure for iPad
        if let popover = activityViewController.popoverPresentationController {
            popover.sourceView = window
            popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        rootViewController.present(activityViewController, animated: true)
    }
    
    // MARK: - Handle Incoming Invite
    func handleIncomingInvite(code: String) async -> Bool {
        do {
            // Find the invite link
            let inviteSnapshot = try await db.collection("inviteLinks")
                .whereField("code", isEqualTo: code)
                .whereField("isActive", isEqualTo: true)
                .getDocuments()
            
            guard let inviteDoc = inviteSnapshot.documents.first else {
                errorMessage = "Invalid invite code"
                return false
            }
            
            let inviteData = inviteDoc.data()
            let inviterId = inviteData["userId"] as? String ?? ""
            let usageCount = inviteData["usageCount"] as? Int ?? 0
            let maxUsage = inviteData["maxUsage"] as? Int ?? 100
            
            // Check if invite has reached max usage
            if usageCount >= maxUsage {
                errorMessage = "This invite link has reached its usage limit"
                return false
            }
            
            // Check if invite has expired
            if let expiresAt = inviteData["expiresAt"] as? Timestamp {
                if expiresAt.dateValue() < Date() {
                    errorMessage = "This invite link has expired"
                    return false
                }
            }
            
            // Get inviter information
            let inviterDoc = try await db.collection("users").document(inviterId).getDocument()
            guard let inviterData = inviterDoc.data() else {
                errorMessage = "Invalid inviter"
                return false
            }
            
            let inviterName = inviterData["displayName"] as? String ?? inviterData["username"] as? String ?? "Unknown"
            
            // Update usage count
            try await db.collection("inviteLinks").document(inviteDoc.documentID).updateData([
                "usageCount": usageCount + 1
            ])
            
            // Store invite data for later use (when user creates account)
            UserDefaults.standard.set(code, forKey: "pendingInviteCode")
            UserDefaults.standard.set(inviterId, forKey: "pendingInviterId")
            UserDefaults.standard.set(inviterName, forKey: "pendingInviterName")
            
            return true
            
        } catch {
            errorMessage = "Failed to process invite: \(error.localizedDescription)"
            return false
        }
    }
    
    // MARK: - Process Pending Invite
    func processPendingInvite() async -> Bool {
        guard let inviteCode = UserDefaults.standard.string(forKey: "pendingInviteCode"),
              let inviterId = UserDefaults.standard.string(forKey: "pendingInviterId"),
              let currentUserId = FirebaseManager.shared.currentUser?.id else {
            return false
        }
        
        do {
            // Send friend request to inviter
            let friendRequest: [String: Any] = [
                "userId": currentUserId,
                "friendId": inviterId,
                "status": "pending",
                "createdAt": Date(),
                "type": "friend_request",
                "source": "invite",
                "inviteCode": inviteCode
            ]
            
            try await db.collection("friendships").addDocument(data: friendRequest)
            
            // Clear pending invite data
            UserDefaults.standard.removeObject(forKey: "pendingInviteCode")
            UserDefaults.standard.removeObject(forKey: "pendingInviterId")
            UserDefaults.standard.removeObject(forKey: "pendingInviterName")
            
            return true
            
        } catch {
            print("❌ Error processing pending invite: \(error)")
            return false
        }
    }
    
    // MARK: - Utility Methods
    func clearError() {
        errorMessage = nil
    }
    
    func refreshInviteLink() async {
        currentInviteLink = await generateInviteLink()
    }
}
