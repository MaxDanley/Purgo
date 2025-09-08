//
//  FirebaseManager.swift
//  Purgo
//
//  Created by Max Danley on 8/27/25.
//

import Foundation
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import FirebaseMessaging
import GoogleSignIn
import Contacts
import UserNotifications
import AuthenticationServices
import CryptoKit

// MARK: - User Models
struct PurgoUser: Codable, Identifiable, Equatable {
    let id: String
    let email: String
    let displayName: String
    let username: String
    let photoURL: String?
    let location: UserLocation?
    let createdAt: Date
    let lastActiveAt: Date
    
    // Stats
    let totalSessions: Int
    let totalTimeSpent: TimeInterval
    let longestSession: TimeInterval
    let averageSessionDuration: TimeInterval
    let saunaSessionCount: Int
    let coldSessionCount: Int
    var fcmToken: String?
    
    init(id: String, email: String, displayName: String, username: String, photoURL: String? = nil, location: UserLocation? = nil) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.username = username
        self.photoURL = photoURL
        self.location = location
        self.createdAt = Date()
        self.lastActiveAt = Date()
        self.totalSessions = 0
        self.totalTimeSpent = 0
        self.longestSession = 0
        self.averageSessionDuration = 0
        self.saunaSessionCount = 0
        self.coldSessionCount = 0
    }
    
    // Computed properties for compatibility
    var totalMinutes: Int {
        return Int(totalTimeSpent / 60)
    }
    
    var currentStreak: Int {
        // This would need to be calculated based on session history
        // For now, return a placeholder value
        return 0
    }

    var longestStreak: Int {
        // Convert longestSession from TimeInterval to a streak representation
        // For now, return a placeholder value
        return 5 // placeholder
    }

    var recentSessions: [RecentSession] {
        // This would need to be populated with actual session data
        // For now, return an empty array
        return []
    }
}

struct RecentSession: Codable, Equatable {
    let type: String
    let duration: Int
    let timestamp: Date
}

struct UserLocation: Codable, Equatable {
    let city: String
    let state: String
    let country: String
    let latitude: Double?
    let longitude: Double?
}

struct Friendship: Codable, Identifiable {
    let id: String
    let userId: String
    let friendId: String
    let status: FriendshipStatus
    let createdAt: Date
    let mutualFollow: Bool
}

enum FriendshipStatus: String, Codable {
    case pending
    case accepted
    case blocked
}

struct LeaderboardEntry: Codable, Identifiable {
    let id: String
    let userId: String
    let username: String
    let displayName: String
    let photoURL: String?
    let totalTime: TimeInterval
    let sessionCount: Int
    let rank: Int
    let period: LeaderboardPeriod
    let scope: LeaderboardScope
    
    // Computed properties for compatibility
    var totalSessions: Int {
        return sessionCount
    }
    
    var totalMinutes: Int {
        return Int(totalTime / 60)
    }
    
    var score: Int {
        return totalMinutes // Cold sessions worth 2x points, sauna sessions worth 1x points
    }
}

enum LeaderboardPeriod: String, Codable, CaseIterable {
    case daily
    case weekly
    case monthly
    
    var displayName: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        }
    }
}

enum LeaderboardScope: String, Codable, CaseIterable {
    case friends
    case local
    case state
    case country
    
    var displayName: String {
        switch self {
        case .friends: return "Friends"
        case .local: return "Local"
        case .state: return "State"
        case .country: return "Country"
        }
    }
}

// MARK: - Firebase Manager (Singleton)
class FirebaseManager: ObservableObject {
    static let shared = FirebaseManager()
    @Published var currentUser: PurgoUser?
    @Published var isAuthenticated = false
    @Published var friends: [PurgoUser] = []
    @Published var friendRequests: [PurgoUser] = []
    @Published var leaderboardEntries: [LeaderboardEntry] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var sentFriendRequests: Set<String> = []
    @Published var receivedFriendRequests: Set<String> = []
    @Published var friendshipStatuses: [String: FriendshipStatus] = [:]
    
    // Apple Sign-In
    private var currentNonce: String?
    private var appleSignInCoordinator: AppleSignInCoordinator?
    
    private let db = Firestore.firestore()
    private let auth = Auth.auth()
    private let storage = Storage.storage(url: "gs://purgo-1374e.firebasestorage.app")
    
    private init() {
        print("🔥 Initializing FirebaseManager singleton")
        setupAuthStateListener()
        
        // Check if user is already signed in
        if let currentUser = auth.currentUser {
            print("✅ User already signed in: \(currentUser.email ?? "unknown")")
            Task {
                await loadCurrentUser(currentUser)
            }
        } else {
            print("👤 No user currently signed in")
        }
    }
    
    // MARK: - Authentication
    private func setupAuthStateListener() {
        auth.addStateDidChangeListener { [weak self] _, user in
            print("🔄 Auth state changed. User: \(user?.email ?? "nil")")
            if let user = user {
                print("✅ User is signed in, loading profile...")
                Task {
                    await self?.loadCurrentUser(user)
                }
            } else {
                print("👤 User signed out")
                DispatchQueue.main.async {
                    self?.currentUser = nil
                    self?.isAuthenticated = false
                    self?.friends = []
                    self?.friendRequests = []
                }
            }
        }
    }
    
    @MainActor
    func signInWithGoogle() async {
        print("🔐 Starting Google Sign-In...")
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let presentingViewController = windowScene.windows.first?.rootViewController else {
            print("❌ No root view controller found")
            errorMessage = "Unable to get root view controller"
            return
        }
        
        do {
            // Verify Firebase is configured
            guard let firebaseApp = FirebaseApp.app() else {
                print("❌ Firebase not configured")
                errorMessage = "Firebase not configured properly"
                return
            }
            
            guard let clientID = firebaseApp.options.clientID else {
                print("❌ No client ID in GoogleService-Info.plist")
                errorMessage = "No client ID found in GoogleService-Info.plist"
                return
            }
            
            print("✅ Firebase configured with client ID: \(String(clientID.prefix(10)))...")
            
            // Configure Google Sign-In
            let gidSignIn = GIDSignIn.sharedInstance
            gidSignIn.configuration = GIDConfiguration(clientID: clientID)
            
            print("🚀 Presenting Google Sign-In...")
            let result = try await gidSignIn.signIn(withPresenting: presentingViewController)
            
            print("✅ Google Sign-In successful")
            
            guard let idToken = result.user.idToken?.tokenString else {
                print("❌ Failed to get ID token")
                errorMessage = "Failed to get ID token"
                return
            }
            
            print("🔑 Got ID token, creating Firebase credential...")
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: result.user.accessToken.tokenString)
            
            print("🔥 Signing in to Firebase...")
            let authResult = try await auth.signIn(with: credential)
            
            print("✅ Firebase sign-in successful for user: \(authResult.user.email ?? "unknown")")
            await createOrUpdateUser(authResult.user)
            
        } catch {
            print("❌ Google Sign-In error: \(error)")
            DispatchQueue.main.async {
                self.errorMessage = "Sign-in failed: \(error.localizedDescription)"
            }
        }
    }
    
    func signOut() {
        do {
            try auth.signOut()
            GIDSignIn.sharedInstance.signOut()
            DispatchQueue.main.async {
                self.currentUser = nil
                self.isAuthenticated = false
                self.friends = []
                self.friendRequests = []
            }
            print("✅ Successfully signed out")
        } catch {
            print("❌ Sign out error: \(error)")
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Apple Sign-In
    @MainActor
    func signInWithApple() async {
        print("🍎 Starting Apple Sign-In process...")
        
        let nonce = randomNonceString()
        currentNonce = nonce
        
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        
        do {
            let result = try await withCheckedThrowingContinuation { continuation in
                let coordinator = AppleSignInCoordinator(continuation: continuation)
                self.appleSignInCoordinator = coordinator // Keep strong reference
                authorizationController.delegate = coordinator
                authorizationController.presentationContextProvider = coordinator
                authorizationController.performRequests()
            }
            
            // Clear the coordinator reference after completion
            self.appleSignInCoordinator = nil
            
            await handleAppleSignInResult(result)
            
        } catch {
            print("❌ Apple Sign-In failed: \(error)")
            // Clear the coordinator reference on error
            self.appleSignInCoordinator = nil
            DispatchQueue.main.async {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    private func handleAppleSignInResult(_ authorization: ASAuthorization) async {
        print("🔍 Processing Apple Sign-In result...")
        
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            print("❌ Invalid Apple ID credential")
            DispatchQueue.main.async {
                self.errorMessage = "Invalid Apple ID credential"
            }
            return
        }
        
        print("✅ Apple ID credential received")
        print("📧 Email: \(appleIDCredential.email ?? "Hidden/Not provided")")
        print("👤 Full name: \(appleIDCredential.fullName?.formatted() ?? "Not provided")")
        
        guard let nonce = currentNonce else {
            print("❌ Invalid state: A login callback was received, but no login request was sent.")
            DispatchQueue.main.async {
                self.errorMessage = "Invalid authentication state"
            }
            return
        }
        
        guard let appleIDToken = appleIDCredential.identityToken else {
            print("❌ Unable to fetch identity token")
            DispatchQueue.main.async {
                self.errorMessage = "Unable to fetch identity token"
            }
            return
        }
        
        guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            print("❌ Unable to serialize token string from data")
            DispatchQueue.main.async {
                self.errorMessage = "Unable to process authentication token"
            }
            return
        }
        
        print("🔥 Creating Firebase credential with Apple ID token...")
        let credential = OAuthProvider.appleCredential(withIDToken: idTokenString,
                                                      rawNonce: nonce,
                                                      fullName: appleIDCredential.fullName)
        
        do {
            print("🚀 Signing in to Firebase with Apple credential...")
            let authResult = try await auth.signIn(with: credential)
            print("🎉 Apple Sign-In to Firebase successful!")
            print("📧 Firebase user email: \(authResult.user.email ?? "Private")")
            print("👤 Firebase user display name: \(authResult.user.displayName ?? "Unknown")")
            print("🆔 Firebase user ID: \(authResult.user.uid)")
            
            print("📝 Creating or updating user profile...")
            await createOrUpdateUser(authResult.user)
            print("✅ Apple Sign-In flow completed successfully!")
            
        } catch {
            print("❌ Firebase sign-in with Apple failed: \(error)")
            print("🔍 Error details: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.errorMessage = "Sign-in failed: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Apple Sign-In Helper Functions
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }
        
        return String(nonce)
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
    
    private func loadCurrentUser(_ firebaseUser: User) async {
        print("📱 Loading user profile for: \(firebaseUser.email ?? "unknown")")
        do {
            let document = try await db.collection("users").document(firebaseUser.uid).getDocument()
            
            if document.exists {
                print("✅ Found existing user profile")
                let user = try document.data(as: PurgoUser.self)
                DispatchQueue.main.async {
                    self.currentUser = user
                    self.isAuthenticated = true
                    print("✅ Authentication state updated - user logged in")
                }
                
                // Load friends list and pending requests
                await loadFriends()
                await loadPendingRequests()
            } else {
                print("🆕 Creating new user profile")
                await createOrUpdateUser(firebaseUser)
            }
        } catch {
            print("❌ Error loading user: \(error)")
            DispatchQueue.main.async {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    private func createOrUpdateUser(_ firebaseUser: User) async {
        do {
            // Check if user already exists
            let document = try await db.collection("users").document(firebaseUser.uid).getDocument()
            
            if document.exists {
                print("✅ User already exists, updating profile info only")
                // User exists - only update basic profile info, preserve stats
                let updateData: [String: Any] = [
                    "email": firebaseUser.email ?? "",
                    "displayName": firebaseUser.displayName ?? "",
                    "photoURL": firebaseUser.photoURL?.absoluteString as Any,
                    "lastActiveAt": Date()
                ]
                
                try await db.collection("users").document(firebaseUser.uid).updateData(updateData)
                
                // Reload the user to get updated data
                let updatedDoc = try await db.collection("users").document(firebaseUser.uid).getDocument()
                if let updatedUser = try? updatedDoc.data(as: PurgoUser.self) {
                    DispatchQueue.main.async {
                        self.currentUser = updatedUser
                        self.isAuthenticated = true
                        print("✅ Existing user profile updated and authenticated")
                        print("📊 Preserved stats: \(updatedUser.totalSessions) sessions, \(Int(updatedUser.totalTimeSpent/60)) minutes")
                    }
                }
            } else {
                print("🆕 Creating new user profile")
                let username = await generateUniqueUsername(from: firebaseUser.displayName ?? firebaseUser.email ?? "user")
                
                let user = PurgoUser(
                    id: firebaseUser.uid,
                    email: firebaseUser.email ?? "",
                    displayName: firebaseUser.displayName ?? "",
                    username: username,
                    photoURL: firebaseUser.photoURL?.absoluteString
                )
                
                try await db.collection("users").document(firebaseUser.uid).setData(from: user)
                
                DispatchQueue.main.async {
                    self.currentUser = user
                    self.isAuthenticated = true
                    print("✅ New user created and authenticated")
                }
            }
            
            // Load friends list and pending requests
            await loadFriends()
            await loadPendingRequests()
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    private func generateUniqueUsername(from name: String) async -> String {
        let baseUsername = name.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined()
            .prefix(20)
        
        var username = String(baseUsername)
        var counter = 1
        
        while await isUsernameTaken(username) {
            username = "\(baseUsername)\(counter)"
            counter += 1
        }
        
        return username
    }
    
    private func isUsernameTaken(_ username: String) async -> Bool {
        do {
            let query = db.collection("users").whereField("username", isEqualTo: username)
            let snapshot = try await query.getDocuments()
            return !snapshot.documents.isEmpty
        } catch {
            return false
        }
    }
    
    // MARK: - Friends Management
    func searchUsers(by username: String) async -> [PurgoUser] {
        do {
            let query = db.collection("users")
                .whereField("username", isGreaterThanOrEqualTo: username.lowercased())
                .whereField("username", isLessThan: username.lowercased() + "z")
                .limit(to: 20)
            
            let snapshot = try await query.getDocuments()
            let users = snapshot.documents.compactMap { try? $0.data(as: PurgoUser.self) }
            
            // Filter out the current user's profile
            let filteredUsers = users.filter { user in
                user.id != currentUser?.id
            }
            
            // Load friendship statuses for these users
            let userIds = filteredUsers.map { $0.id }
            await loadFriendshipStatuses(for: userIds)
            
            return filteredUsers
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = error.localizedDescription
            }
            return []
        }
    }
    
    func sendFriendRequest(to userId: String) async {
        print("👥 Sending friend request to user: \(userId)")
        
        guard let currentUserId = currentUser?.id else {
            print("❌ No current user to send friend request")
            return
        }
        
        guard currentUserId != userId else {
            print("❌ Cannot send friend request to yourself")
            return
        }
        
        do {
            // Check if friendship already exists
            let existingFriendship = try await checkExistingFriendship(currentUserId: currentUserId, friendId: userId)
            
            if let existing = existingFriendship {
                print("❌ Friendship already exists with status: \(existing.status)")
                DispatchQueue.main.async {
                    switch existing.status {
                    case .pending:
                        self.errorMessage = "Friend request already sent"
                    case .accepted:
                        self.errorMessage = "You are already friends"
                    case .blocked:
                        self.errorMessage = "Cannot send friend request"
                    }
                }
                return
            }
            
            let friendship = Friendship(
                id: UUID().uuidString,
                userId: currentUserId,
                friendId: userId,
                status: .pending,
                createdAt: Date(),
                mutualFollow: false
            )
            
            print("📝 Creating friendship document...")
            try await db.collection("friendships").document(friendship.id).setData(from: friendship)
            
            print("✅ Friend request sent successfully")
            
            // Update local state
            DispatchQueue.main.async {
                self.sentFriendRequests.insert(userId)
                self.friendshipStatuses[userId] = .pending
                self.errorMessage = nil
            }
            
            // Send push notification to recipient
            await sendFriendRequestNotification(to: userId, from: currentUser?.displayName ?? "Someone")
            
        } catch {
            print("❌ Error sending friend request: \(error)")
            DispatchQueue.main.async {
                self.errorMessage = "Failed to send friend request: \(error.localizedDescription)"
            }
        }
    }
    
    func cancelFriendRequest(to userId: String) async {
        print("🚫 Canceling friend request to user: \(userId)")
        
        guard let currentUserId = currentUser?.id else {
            print("❌ No current user to cancel friend request")
            return
        }
        
        do {
            // Find the pending friendship document
            let query = db.collection("friendships")
                .whereField("userId", isEqualTo: currentUserId)
                .whereField("friendId", isEqualTo: userId)
                .whereField("status", isEqualTo: "pending")
            
            let snapshot = try await query.getDocuments()
            
            for document in snapshot.documents {
                try await document.reference.delete()
                print("✅ Friend request canceled successfully")
            }
            
            // Update local state
            DispatchQueue.main.async {
                self.sentFriendRequests.remove(userId)
                self.friendshipStatuses.removeValue(forKey: userId)
            }
            
        } catch {
            print("❌ Error canceling friend request: \(error)")
            DispatchQueue.main.async {
                self.errorMessage = "Unable to cancel friend request. Please try again."
            }
        }
    }
    
    func removeFriend(_ userId: String) async {
        print("👥 Removing friend: \(userId)")
        
        guard let currentUserId = currentUser?.id else {
            print("❌ No current user to remove friend")
            return
        }
        
        do {
            // Find and delete the friendship document
            let query1 = db.collection("friendships")
                .whereField("userId", isEqualTo: currentUserId)
                .whereField("friendId", isEqualTo: userId)
            
            let query2 = db.collection("friendships")
                .whereField("userId", isEqualTo: userId)
                .whereField("friendId", isEqualTo: currentUserId)
            
            let snapshot1 = try await query1.getDocuments()
            let snapshot2 = try await query2.getDocuments()
            
            // Delete all matching friendships
            for document in snapshot1.documents + snapshot2.documents {
                try await document.reference.delete()
            }
            
            print("✅ Friend removed successfully")
            
            // Update local state
            DispatchQueue.main.async {
                self.friends.removeAll { $0.id == userId }
                self.sentFriendRequests.remove(userId)
                self.receivedFriendRequests.remove(userId)
                self.friendshipStatuses[userId] = nil
            }
            
        } catch {
            print("❌ Error removing friend: \(error)")
            DispatchQueue.main.async {
                self.errorMessage = "Failed to remove friend: \(error.localizedDescription)"
            }
        }
    }
    
    private func checkExistingFriendship(currentUserId: String, friendId: String) async throws -> Friendship? {
        // Check both directions of the friendship
        let query1 = db.collection("friendships")
            .whereField("userId", isEqualTo: currentUserId)
            .whereField("friendId", isEqualTo: friendId)
        
        let query2 = db.collection("friendships")
            .whereField("userId", isEqualTo: friendId)
            .whereField("friendId", isEqualTo: currentUserId)
        
        let snapshot1 = try await query1.getDocuments()
        let snapshot2 = try await query2.getDocuments()
        
        // Return the first friendship found
        for document in snapshot1.documents + snapshot2.documents {
            if let friendship = try? document.data(as: Friendship.self) {
                return friendship
            }
        }
        
        return nil
    }
    
    func loadFriendshipStatuses(for userIds: [String]) async {
        print("🔍 Loading friendship statuses for \(userIds.count) users")
        
        guard let currentUserId = currentUser?.id else { return }
        
        var statuses: [String: FriendshipStatus] = [:]
        
        do {
            for userId in userIds {
                if let friendship = try await checkExistingFriendship(currentUserId: currentUserId, friendId: userId) {
                    statuses[userId] = friendship.status
                    print("📋 User \(userId): \(friendship.status)")
                } else {
                    // No friendship exists
                    statuses[userId] = nil
                    print("📋 User \(userId): no relationship")
                }
            }
            
            DispatchQueue.main.async {
                self.friendshipStatuses.merge(statuses) { _, new in new }
            }
            
        } catch {
            print("❌ Error loading friendship statuses: \(error)")
        }
    }
    
    func loadFriends() async {
        print("👥 Loading friends list...")
        
        guard let currentUserId = currentUser?.id else {
            print("❌ No current user to load friends")
            return
        }
        
        do {
            // Query friendships where current user is involved and status is accepted
            let query1 = db.collection("friendships")
                .whereField("userId", isEqualTo: currentUserId)
                .whereField("status", isEqualTo: "accepted")
            
            let query2 = db.collection("friendships")
                .whereField("friendId", isEqualTo: currentUserId)
                .whereField("status", isEqualTo: "accepted")
            
            let snapshot1 = try await query1.getDocuments()
            let snapshot2 = try await query2.getDocuments()
            
            var friendIds: Set<String> = []
            
            // Collect friend IDs from both directions
            for document in snapshot1.documents {
                if let friendship = try? document.data(as: Friendship.self) {
                    friendIds.insert(friendship.friendId)
                }
            }
            
            for document in snapshot2.documents {
                if let friendship = try? document.data(as: Friendship.self) {
                    friendIds.insert(friendship.userId)
                }
            }
            
            print("📋 Found \(friendIds.count) accepted friendships")
            
            // Load user data for all friends
            var friendUsers: [PurgoUser] = []
            
            for friendId in friendIds {
                do {
                    let userDoc = try await db.collection("users").document(friendId).getDocument()
                    if let user = try? userDoc.data(as: PurgoUser.self) {
                        friendUsers.append(user)
                    }
                } catch {
                    print("❌ Error loading friend \(friendId): \(error)")
                }
            }
            
            print("✅ Loaded \(friendUsers.count) friends")
            
            DispatchQueue.main.async {
                self.friends = friendUsers
                // Update friendship statuses
                for friend in friendUsers {
                    self.friendshipStatuses[friend.id] = .accepted
                }
            }
            
        } catch {
            print("❌ Error loading friends: \(error)")
            DispatchQueue.main.async {
                self.errorMessage = "Failed to load friends: \(error.localizedDescription)"
            }
        }
    }
    
    func loadPendingRequests() async {
        print("📬 Loading pending friend requests...")
        
        guard let currentUserId = currentUser?.id else {
            print("❌ No current user to load pending requests")
            return
        }
        
        do {
            // Query received friend requests (where current user is the friendId and status is pending)
            let receivedQuery = db.collection("friendships")
                .whereField("friendId", isEqualTo: currentUserId)
                .whereField("status", isEqualTo: "pending")
            
            let receivedSnapshot = try await receivedQuery.getDocuments()
            
            var pendingUsers: [PurgoUser] = []
            var receivedRequestIds: Set<String> = []
            
            for document in receivedSnapshot.documents {
                if let friendship = try? document.data(as: Friendship.self) {
                    // Load the user who sent the request
                    do {
                        let userDoc = try await db.collection("users").document(friendship.userId).getDocument()
                        if let user = try? userDoc.data(as: PurgoUser.self) {
                            pendingUsers.append(user)
                            receivedRequestIds.insert(user.id)
                        }
                    } catch {
                        print("❌ Error loading pending request user \(friendship.userId): \(error)")
                    }
                }
            }
            
            // Query sent friend requests (where current user is the userId and status is pending)
            let sentQuery = db.collection("friendships")
                .whereField("userId", isEqualTo: currentUserId)
                .whereField("status", isEqualTo: "pending")
            
            let sentSnapshot = try await sentQuery.getDocuments()
            
            var sentRequestIds: Set<String> = []
            
            for document in sentSnapshot.documents {
                if let friendship = try? document.data(as: Friendship.self) {
                    sentRequestIds.insert(friendship.friendId)
                }
            }
            
            print("✅ Loaded \(pendingUsers.count) received friend requests")
            print("✅ Loaded \(sentRequestIds.count) sent friend requests")
            
            DispatchQueue.main.async {
                self.friendRequests = pendingUsers
                self.receivedFriendRequests = receivedRequestIds
                self.sentFriendRequests = sentRequestIds
                
                // Update friendship statuses
                for userId in receivedRequestIds {
                    self.friendshipStatuses[userId] = .pending
                }
                for userId in sentRequestIds {
                    self.friendshipStatuses[userId] = .pending
                }
            }
            
        } catch {
            print("❌ Error loading pending requests: \(error)")
            DispatchQueue.main.async {
                self.errorMessage = "Failed to load pending requests: \(error.localizedDescription)"
            }
        }
    }
    
    func acceptFriendRequest(_ friendship: Friendship) async {
        do {
            var updatedFriendship = friendship
            updatedFriendship = Friendship(
                id: friendship.id,
                userId: friendship.userId,
                friendId: friendship.friendId,
                status: .accepted,
                createdAt: friendship.createdAt,
                mutualFollow: await checkMutualFollow(friendship.userId, friendship.friendId)
            )
            
            try await db.collection("friendships").document(friendship.id).setData(from: updatedFriendship)
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    func declineFriendRequest(_ friendship: Friendship) async {
        do {
            // Delete the friendship document
            try await db.collection("friendships").document(friendship.id).delete()
            
            print("✅ Friend request declined successfully")
            
            // Update local state
            DispatchQueue.main.async {
                self.friendRequests.removeAll { $0.id == friendship.userId }
                self.receivedFriendRequests.remove(friendship.userId)
                self.friendshipStatuses[friendship.userId] = nil
            }
            
        } catch {
            print("❌ Error declining friend request: \(error)")
            DispatchQueue.main.async {
                self.errorMessage = "Failed to decline friend request: \(error.localizedDescription)"
            }
        }
    }
    
    private func checkMutualFollow(_ userId1: String, _ userId2: String) async -> Bool {
        do {
            let query1 = db.collection("friendships")
                .whereField("userId", isEqualTo: userId1)
                .whereField("friendId", isEqualTo: userId2)
                .whereField("status", isEqualTo: "accepted")
            
            let query2 = db.collection("friendships")
                .whereField("userId", isEqualTo: userId2)
                .whereField("friendId", isEqualTo: userId1)
                .whereField("status", isEqualTo: "accepted")
            
            let snapshot1 = try await query1.getDocuments()
            let snapshot2 = try await query2.getDocuments()
            
            return !snapshot1.documents.isEmpty && !snapshot2.documents.isEmpty
        } catch {
            return false
        }
    }
    
    // MARK: - Session Tracking
    func updateUserStats(with session: CompletedSession) async {
        print("🔄 updateUserStats called for session: \(session.sessionType.rawValue)")
        
        guard let userId = currentUser?.id else { 
            print("❌ No current user ID available")
            return 
        }
        
        print("✅ Current user ID: \(userId)")
        
        do {
            let userRef = db.collection("users").document(userId)
            let sessionRef = db.collection("sessions").document()
            
            // Save session
            let sessionData: [String: Any] = [
                "userId": userId,
                "sessionType": session.sessionType.rawValue,
                "startTime": session.startTime,
                "endTime": session.endTime,
                "duration": session.actualDuration,
                "goalDuration": session.goalDuration,
                "wasGoalMet": session.wasGoalMet,
                "createdAt": Date()
            ]
            
            print("📝 Saving session data to Firestore...")
            try await sessionRef.setData(sessionData)
            print("✅ Session data saved successfully")
            
            // Update user stats
            let updateData: [String: Any] = [
                "totalSessions": FieldValue.increment(Int64(1)),
                "totalTimeSpent": FieldValue.increment(Int64(session.actualDuration)),
                "longestSession": max(currentUser?.longestSession ?? 0, session.actualDuration),
                "\(session.sessionType.rawValue)SessionCount": FieldValue.increment(Int64(1)),
                "lastActiveAt": Date()
            ]
            
            print("📊 Updating user stats: \(updateData)")
            try await userRef.updateData(updateData)
            print("✅ User stats updated in Firestore")
            
            // Refresh the user data to update the UI
            print("🔄 Fetching updated user data...")
            let updatedUserDoc = try await userRef.getDocument()
            
            if updatedUserDoc.exists {
                print("✅ User document exists, parsing data...")
                if let updatedUser = try? updatedUserDoc.data(as: PurgoUser.self) {
                    DispatchQueue.main.async {
                        self.currentUser = updatedUser
                        print("🎉 UI updated! New stats: \(updatedUser.totalSessions) sessions, \(Int(updatedUser.totalTimeSpent/60)) minutes")
                        print("🔍 Sauna: \(updatedUser.saunaSessionCount), Cold: \(updatedUser.coldSessionCount)")
                    }
                } else {
                    print("❌ Failed to parse updated user data")
                    // Try to get the raw data for debugging
                    if let rawData = updatedUserDoc.data() {
                        print("📋 Raw user data: \(rawData)")
                    }
                }
            } else {
                print("❌ User document doesn't exist after update")
            }
            
        } catch {
            print("❌ Error updating user stats: \(error)")
            print("🔍 Error details: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    // MARK: - Leaderboards
    func loadLeaderboard(period: LeaderboardPeriod, scope: LeaderboardScope) async {
        print("🏆 Loading leaderboard for \(period.displayName) \(scope.displayName)")
        DispatchQueue.main.async {
            self.isLoading = true
        }
        
        do {
            // Calculate date range based on period
            let calendar = Calendar.current
            let now = Date()
            let startDate: Date
            
            switch period {
            case .daily:
                startDate = calendar.startOfDay(for: now)
            case .weekly:
                startDate = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            case .monthly:
                startDate = calendar.dateInterval(of: .month, for: now)?.start ?? now
            }
            
            print("📅 Date range: \(startDate) to \(now)")
            
            // Determine which users to include based on scope
            var targetUserIds: Set<String> = []
            
            switch scope {
            case .friends:
                // Include current user and friends
                if let currentUserId = currentUser?.id {
                    targetUserIds.insert(currentUserId)
                }
                for friend in friends {
                    targetUserIds.insert(friend.id)
                }
                print("👥 Friends scope: Including \(targetUserIds.count) users")
            case .local, .state, .country:
                // For now, include all users (can be enhanced later with location filtering)
                targetUserIds = [] // Empty means include all
                print("🌍 Global scope: Including all users")
            }
            
            // Query sessions in the time period
            var query = db.collection("sessions")
                .whereField("createdAt", isGreaterThanOrEqualTo: startDate)
                .whereField("createdAt", isLessThanOrEqualTo: now)
            
            let snapshot = try await query.getDocuments()
            print("📊 Found \(snapshot.documents.count) sessions in time period")
            
            // Process leaderboard data
            var userStats: [String: (totalTime: TimeInterval, sessionCount: Int)] = [:]
            
            for document in snapshot.documents {
                let data = document.data()
                if let userId = data["userId"] as? String,
                   let duration = data["duration"] as? TimeInterval,
                   let sessionTypeString = data["sessionType"] as? String {
                    
                    // Filter by scope if needed
                    if !targetUserIds.isEmpty && !targetUserIds.contains(userId) {
                        continue
                    }
                    
                    if userStats[userId] == nil {
                        userStats[userId] = (0, 0)
                    }
                    
                    // Cold sessions are worth double points
                    let pointsMultiplier: Double = (sessionTypeString == "cold") ? 2.0 : 1.0
                    let pointsEarned = duration * pointsMultiplier
                    userStats[userId]?.totalTime += pointsEarned
                    userStats[userId]?.sessionCount += 1
                    
                    print("🏆 \(sessionTypeString.capitalized) session: \(Int(duration/60))min → \(Int(pointsEarned/60)) points (x\(pointsMultiplier))")
                }
            }
            
            print("📈 Processed stats for \(userStats.count) users")
            
            // Convert to leaderboard entries and sort
            var entries: [LeaderboardEntry] = []
            for (userId, stats) in userStats {
                // Fetch user data
                let userDoc = try await db.collection("users").document(userId).getDocument()
                if let user = try? userDoc.data(as: PurgoUser.self) {
                    let entry = LeaderboardEntry(
                        id: userId,
                        userId: userId,
                        username: user.username,
                        displayName: user.displayName,
                        photoURL: user.photoURL,
                        totalTime: stats.totalTime,
                        sessionCount: stats.sessionCount,
                        rank: 0, // Will be set after sorting
                        period: period,
                        scope: scope
                    )
                    entries.append(entry)
                }
            }
            
            // Sort by total time and assign ranks
            entries.sort { $0.totalTime > $1.totalTime }
            for i in 0..<entries.count {
                entries[i] = LeaderboardEntry(
                    id: entries[i].id,
                    userId: entries[i].userId,
                    username: entries[i].username,
                    displayName: entries[i].displayName,
                    photoURL: entries[i].photoURL,
                    totalTime: entries[i].totalTime,
                    sessionCount: entries[i].sessionCount,
                    rank: i + 1,
                    period: entries[i].period,
                    scope: entries[i].scope
                )
            }
            
            print("🏅 Final leaderboard: \(entries.count) entries")
            
            DispatchQueue.main.async {
                self.leaderboardEntries = entries
                self.isLoading = false
            }
            
        } catch {
            print("❌ Leaderboard loading error: \(error)")
            DispatchQueue.main.async {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
                self.leaderboardEntries = []
            }
        }
    }
    
    // MARK: - Debug & Testing
    func testGoogleSignInConfig() {
        print("🔍 Testing Google Sign-In Configuration:")
        print("Firebase App: \(FirebaseApp.app()?.name ?? "nil")")
        print("Client ID exists: \(FirebaseApp.app()?.options.clientID != nil)")
        print("GIDSignIn configured: \(GIDSignIn.sharedInstance.configuration != nil)")
        
        // Check if URL scheme is configured
        if let urlTypes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] {
            print("URL Types configured: \(urlTypes.count)")
            for urlType in urlTypes {
                if let schemes = urlType["CFBundleURLSchemes"] as? [String] {
                    print("URL Schemes: \(schemes)")
                }
            }
        } else {
            print("❌ No URL types configured!")
        }
        
        // Check GoogleService-Info.plist
        if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: path) {
            print("✅ GoogleService-Info.plist found")
            print("CLIENT_ID exists: \(plist["CLIENT_ID"] != nil)")
            print("REVERSED_CLIENT_ID exists: \(plist["REVERSED_CLIENT_ID"] != nil)")
        } else {
            print("❌ GoogleService-Info.plist not found in bundle!")
        }
    }
    
    // MARK: - Push Notifications
    func sendSessionNotification(to friendId: String, sessionType: SessionType) async {
        guard let currentUser = currentUser,
              await checkMutualFollow(currentUser.id, friendId) else { return }
        
        // Only send notification 30% of the time to avoid spam
        guard Double.random(in: 0...1) < 0.3 else { return }
        
        do {
            let notificationData: [String: Any] = [
                "fromUserId": currentUser.id,
                "fromUsername": currentUser.username,
                "fromDisplayName": currentUser.displayName,
                "toUserId": friendId,
                "sessionType": sessionType.rawValue,
                "message": "\(currentUser.displayName) just started a \(sessionType.displayName.lowercased())!",
                "createdAt": Date()
            ]
            
            try await db.collection("notifications").document().setData(notificationData)
        } catch {
            print("Failed to send notification: \(error)")
        }
    }
    
    func findPendingFriendship(userId: String) async -> Friendship? {
        guard let currentUserId = currentUser?.id else { return nil }
        
        do {
            let query = db.collection("friendships")
                .whereField("userId", isEqualTo: userId)
                .whereField("friendId", isEqualTo: currentUserId)
                .whereField("status", isEqualTo: "pending")
            
            let snapshot = try await query.getDocuments()
            
            for document in snapshot.documents {
                if let friendship = try? document.data(as: Friendship.self) {
                    return friendship
                }
            }
        } catch {
            print("❌ Error finding pending friendship: \(error)")
        }
        
        return nil
    }
    
    // MARK: - FCM Token Management
    func updateFCMToken(_ token: String) async {
        print("🔑 Updating FCM token for current user")
        
        // Retry mechanism - wait for user to be loaded
        var retryCount = 0
        let maxRetries = 10
        
        while currentUser == nil && retryCount < maxRetries {
            print("⏳ Waiting for user to load... (attempt \(retryCount + 1)/\(maxRetries))")
            try? await Task.sleep(nanoseconds: 1_000_000_000) // Wait 1 second
            retryCount += 1
        }
        
        guard let currentUserId = currentUser?.id else {
            print("❌ No current user to update FCM token after \(maxRetries) retries")
            return
        }
        
        do {
            try await db.collection("users").document(currentUserId).updateData([
                "fcmToken": token
            ])
            
            print("✅ FCM token updated successfully")
            
            // Update local user object
            DispatchQueue.main.async {
                if var updatedUser = self.currentUser {
                    updatedUser.fcmToken = token
                    self.currentUser = updatedUser
                }
            }
            
        } catch {
            print("❌ Error updating FCM token: \(error)")
        }
    }
    
    func sendFriendRequestNotification(to userId: String, from senderName: String) async {
        print("📱 Sending friend request notification to \(userId)")
        
        do {
            // Get the recipient's FCM token
            let userDoc = try await db.collection("users").document(userId).getDocument()
            
            if let userData = userDoc.data(),
               let fcmToken = userData["fcmToken"] as? String {
                
                // Create notification document for Cloud Function to process
                let notificationData: [String: Any] = [
                    "type": "friend_request",
                    "recipientId": userId,
                    "recipientToken": fcmToken,
                    "senderName": senderName,
                    "title": "New Friend Request",
                    "body": "\(senderName) wants to be friends with you!",
                    "data": [
                        "type": "friend_request",
                        "senderId": currentUser?.id ?? ""
                    ],
                    "createdAt": FieldValue.serverTimestamp()
                ]
                
                try await db.collection("notifications").addDocument(data: notificationData)
                print("✅ Friend request notification queued")
                
            } else {
                print("❌ No FCM token found for user \(userId)")
            }
            
        } catch {
            print("❌ Error sending friend request notification: \(error)")
        }
    }
}

// MARK: - Firebase App Initialization
extension FirebaseManager {
    static func configureFirebase() {
        guard FirebaseApp.app() == nil else { 
            print("✅ Firebase already configured")
            return 
        }
        print("🔥 Configuring Firebase...")
        FirebaseApp.configure()
        print("✅ Firebase configured successfully")
    }
    
    func checkAuthenticationState() {
        print("🔍 Checking current authentication state...")
        if let currentUser = auth.currentUser {
            print("✅ User is already authenticated: \(currentUser.email ?? "unknown")")
            Task {
                await loadCurrentUser(currentUser)
            }
        } else {
            print("👤 No authenticated user found")
            DispatchQueue.main.async {
                self.isAuthenticated = false
                self.currentUser = nil
            }
        }
    }
    
    // MARK: - Manual Profile Refresh
    func refreshUserProfile() async {
        print("🔄 Manual profile refresh requested")
        guard let userId = currentUser?.id else {
            print("❌ No current user to refresh")
            return
        }
        
        do {
            let userDoc = try await db.collection("users").document(userId).getDocument()
            if let updatedUser = try? userDoc.data(as: PurgoUser.self) {
                DispatchQueue.main.async {
                    self.currentUser = updatedUser
                    print("✅ Profile refreshed: \(updatedUser.totalSessions) sessions")
                }
            } else {
                print("❌ Failed to parse user data during refresh")
            }
        } catch {
            print("❌ Error refreshing profile: \(error)")
        }
    }
    
    // MARK: - Username Management
    func updateUsername(_ newUsername: String) async -> Bool {
        print("🔄 Updating username to: \(newUsername)")
        
        guard let userId = currentUser?.id else {
            print("❌ No current user to update username")
            DispatchQueue.main.async {
                self.errorMessage = "No user logged in"
            }
            return false
        }
        
        // Validate username
        let cleanUsername = newUsername.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        guard isValidUsername(cleanUsername) else {
            print("❌ Invalid username format")
            DispatchQueue.main.async {
                self.errorMessage = "Username must be 3-20 characters, letters, numbers, and underscores only"
            }
            return false
        }
        
        // Check if username is already taken
        let isAvailable = await isUsernameAvailable(cleanUsername)
        guard isAvailable else {
            print("❌ Username already taken")
            DispatchQueue.main.async {
                self.errorMessage = "Username '\(cleanUsername)' is already taken"
            }
            return false
        }
        
        do {
            // Update username in Firestore
            try await db.collection("users").document(userId).updateData([
                "username": cleanUsername
            ])
            
            // Refresh user data to get updated username
            await refreshUserProfile()
            print("✅ Username updated successfully to: \(cleanUsername)")
            
            return true
            
        } catch {
            print("❌ Error updating username: \(error)")
            DispatchQueue.main.async {
                self.errorMessage = "Failed to update username: \(error.localizedDescription)"
            }
            return false
        }
    }
    
    func isUsernameAvailable(_ username: String) async -> Bool {
        do {
            let query = db.collection("users").whereField("username", isEqualTo: username)
            let snapshot = try await query.getDocuments()
            
            // If we find any documents, username is taken
            // But allow current user to keep their existing username
            if snapshot.documents.isEmpty {
                return true
            } else if snapshot.documents.count == 1,
                      let currentUserId = currentUser?.id,
                      snapshot.documents.first?.documentID == currentUserId {
                // Current user is updating to their existing username
                return true
            } else {
                return false
            }
        } catch {
            print("❌ Error checking username availability: \(error)")
            return false
        }
    }
    
    private func isValidUsername(_ username: String) -> Bool {
        // Username must be 3-20 characters, alphanumeric + underscores only
        let usernameRegex = "^[a-z0-9_]{3,20}$"
        let usernamePredicate = NSPredicate(format: "SELF MATCHES %@", usernameRegex)
        return usernamePredicate.evaluate(with: username)
    }
    
    // MARK: - Profile Picture Management
    func updateProfilePicture(_ image: UIImage) async -> Bool {
        print("📸 Starting profile picture update...")
        
        guard let userId = currentUser?.id else {
            print("❌ No current user to update profile picture")
            DispatchQueue.main.async {
                self.errorMessage = "No user logged in"
            }
            return false
        }
        
        // Compress image
        guard let imageData = compressImage(image) else {
            print("❌ Failed to compress image")
            DispatchQueue.main.async {
                self.errorMessage = "Failed to process image"
            }
            return false
        }
        
        do {
            // Upload image to Firebase Storage
            let imageUrl = try await uploadImageToStorage(imageData, userId: userId)
            print("✅ Image uploaded to: \(imageUrl)")
            
            // Update user profile with new photo URL
            try await db.collection("users").document(userId).updateData([
                "photoURL": imageUrl
            ])
            
            print("✅ Profile picture updated in Firestore")
            
            // Refresh user profile to update UI
            await refreshUserProfile()
            
            return true
            
        } catch {
            print("❌ Error updating profile picture: \(error)")
            DispatchQueue.main.async {
                self.errorMessage = "Failed to update profile picture: \(error.localizedDescription)"
            }
            return false
        }
    }
    
    private func uploadImageToStorage(_ imageData: Data, userId: String) async throws -> String {
        let storageRef = storage.reference()
        let profileImagesRef = storageRef.child("profile_images/\(userId).jpg")
        
        print("📤 Uploading image to Firebase Storage...")
        print("🔗 Storage bucket: \(storageRef.bucket)")
        print("📁 Full path: \(profileImagesRef.fullPath)")
        print("📊 Image size: \(imageData.count) bytes")
        
        // Upload the image
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        let _ = try await profileImagesRef.putDataAsync(imageData, metadata: metadata)
        print("✅ Image uploaded successfully")
        
        // Get download URL
        let downloadURL = try await profileImagesRef.downloadURL()
        print("🔗 Download URL obtained: \(downloadURL.absoluteString)")
        
        return downloadURL.absoluteString
    }
    
    private func compressImage(_ image: UIImage) -> Data? {
        // Resize image to max 512x512 to save storage and bandwidth
        let maxSize: CGFloat = 512
        let size = image.size
        
        var newSize: CGSize
        if size.width > size.height {
            newSize = CGSize(width: maxSize, height: size.height * maxSize / size.width)
        } else {
            newSize = CGSize(width: size.width * maxSize / size.height, height: maxSize)
        }
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        // Compress to JPEG with 0.8 quality
        return resizedImage?.jpegData(compressionQuality: 0.8)
    }
}

// MARK: - Apple Sign-In Coordinator
class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private let continuation: CheckedContinuation<ASAuthorization, Error>
    
    init(continuation: CheckedContinuation<ASAuthorization, Error>) {
        self.continuation = continuation
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        continuation.resume(returning: authorization)
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation.resume(throwing: error)
    }
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            fatalError("No window available for Apple Sign-In")
        }
        return window
    }
}
