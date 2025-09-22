//
//  FriendSuggestionManager.swift
//  Purgo
//
//  Created by Max Danley on 8/27/25.
//

import Foundation
import FirebaseFirestore

// MARK: - Friend Suggestion Models
struct FriendSuggestion: Identifiable, Codable {
    let id: String
    let name: String
    let username: String
    let profileImage: String?
    let mutualFriends: [MutualFriend]
    let mutualFriendsCount: Int
    let suggestedReason: String
    let isAlreadyFriend: Bool
    let isInvited: Bool
    let location: UserLocation?
    let totalSessions: Int
    let lastActiveAt: Date
}

struct MutualFriend: Identifiable, Codable {
    let id: String
    let name: String
    let username: String
    let profileImage: String?
}

// MARK: - Friend Suggestion Manager
@MainActor
class FriendSuggestionManager: ObservableObject {
    @Published var suggestions: [FriendSuggestion] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    
    // MARK: - Load Friend Suggestions
    func loadFriendSuggestions() async {
        guard let currentUserId = FirebaseManager.shared.currentUser?.id else {
            errorMessage = "No current user"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Get current user's friends
            let friendsSnapshot = try await db.collection("friendships")
                .whereField("userId", isEqualTo: currentUserId)
                .whereField("status", isEqualTo: "accepted")
                .getDocuments()
            
            let friendIds = Set(friendsSnapshot.documents.map { $0.data()["friendId"] as? String ?? "" })
            
            // Get pending invitations to avoid suggesting already invited users
            let pendingSnapshot = try await db.collection("friendships")
                .whereField("userId", isEqualTo: currentUserId)
                .whereField("status", isEqualTo: "pending")
                .getDocuments()
            
            let pendingIds = Set(pendingSnapshot.documents.map { $0.data()["friendId"] as? String ?? "" })
            
            // Get all users except current user and existing friends
            let allUsersSnapshot = try await db.collection("users").getDocuments()
            
            var suggestions: [FriendSuggestion] = []
            
            for userDoc in allUsersSnapshot.documents {
                let userId = userDoc.documentID
                let userData = userDoc.data()
                
                // Skip current user and existing friends
                if userId == currentUserId || friendIds.contains(userId) || pendingIds.contains(userId) {
                    continue
                }
                
                // Calculate mutual friends
                let mutualFriends = await calculateMutualFriends(
                    userId: userId,
                    currentUserFriends: friendIds
                )
                
                // Only suggest users with at least 1 mutual friend
                if mutualFriends.count > 0 {
                    let suggestion = FriendSuggestion(
                        id: userId,
                        name: userData["displayName"] as? String ?? userData["username"] as? String ?? "Unknown",
                        username: userData["username"] as? String ?? "unknown",
                        profileImage: userData["photoURL"] as? String,
                        mutualFriends: mutualFriends,
                        mutualFriendsCount: mutualFriends.count,
                        suggestedReason: "\(mutualFriends.count) mutual friend\(mutualFriends.count == 1 ? "" : "s")",
                        isAlreadyFriend: false,
                        isInvited: false,
                        location: nil, // Will be populated if needed
                        totalSessions: userData["totalSessions"] as? Int ?? 0,
                        lastActiveAt: (userData["lastActiveAt"] as? Timestamp)?.dateValue() ?? Date()
                    )
                    
                    suggestions.append(suggestion)
                }
            }
            
            // Sort by mutual friends count (descending) and then by last active
            suggestions.sort { first, second in
                if first.mutualFriendsCount != second.mutualFriendsCount {
                    return first.mutualFriendsCount > second.mutualFriendsCount
                }
                return first.lastActiveAt > second.lastActiveAt
            }
            
            // Limit to top 20 suggestions
            self.suggestions = Array(suggestions.prefix(20))
            self.isLoading = false
            
        } catch {
            self.errorMessage = "Failed to load friend suggestions: \(error.localizedDescription)"
            self.isLoading = false
        }
    }
    
    private func calculateMutualFriends(userId: String, currentUserFriends: Set<String>) async -> [MutualFriend] {
        do {
            // Get the other user's friends
            let otherUserFriendsSnapshot = try await db.collection("friendships")
                .whereField("userId", isEqualTo: userId)
                .whereField("status", isEqualTo: "accepted")
                .getDocuments()
            
            let otherUserFriendIds = otherUserFriendsSnapshot.documents.map { $0.data()["friendId"] as? String ?? "" }
            
            // Find mutual friends
            let mutualFriendIds = currentUserFriends.intersection(Set(otherUserFriendIds))
            
            if mutualFriendIds.isEmpty {
                return []
            }
            
            // Get details of mutual friends
            var mutualFriends: [MutualFriend] = []
            
            for friendId in mutualFriendIds {
                let friendDoc = try await db.collection("users").document(friendId).getDocument()
                
                if let friendData = friendDoc.data() {
                    let mutualFriend = MutualFriend(
                        id: friendId,
                        name: friendData["displayName"] as? String ?? friendData["username"] as? String ?? "Unknown",
                        username: friendData["username"] as? String ?? "unknown",
                        profileImage: friendData["photoURL"] as? String
                    )
                    mutualFriends.append(mutualFriend)
                }
            }
            
            return mutualFriends
            
        } catch {
            print("❌ Error calculating mutual friends: \(error)")
            return []
        }
    }
    
    // MARK: - Send Friend Request
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
            
            // Update the suggestion to show as invited
            if let index = suggestions.firstIndex(where: { $0.id == userId }) {
                suggestions[index] = FriendSuggestion(
                    id: suggestions[index].id,
                    name: suggestions[index].name,
                    username: suggestions[index].username,
                    profileImage: suggestions[index].profileImage,
                    mutualFriends: suggestions[index].mutualFriends,
                    mutualFriendsCount: suggestions[index].mutualFriendsCount,
                    suggestedReason: suggestions[index].suggestedReason,
                    isAlreadyFriend: suggestions[index].isAlreadyFriend,
                    isInvited: true,
                    location: suggestions[index].location,
                    totalSessions: suggestions[index].totalSessions,
                    lastActiveAt: suggestions[index].lastActiveAt
                )
            }
            
            return true
            
        } catch {
            errorMessage = "Failed to send friend request: \(error.localizedDescription)"
            return false
        }
    }
    
    // MARK: - Utility Methods
    func refreshSuggestions() async {
        await loadFriendSuggestions()
    }
    
    func clearError() {
        errorMessage = nil
    }
}
