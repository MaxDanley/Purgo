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
import GoogleSignIn
import Contacts
import UserNotifications

// MARK: - User Models
struct PurgoUser: Codable, Identifiable {
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
}

struct UserLocation: Codable {
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
    
    private let db = Firestore.firestore()
    private let auth = Auth.auth()
    
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
            return snapshot.documents.compactMap { try? $0.data(as: PurgoUser.self) }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = error.localizedDescription
            }
            return []
        }
    }
    
    func sendFriendRequest(to userId: String) async {
        guard let currentUserId = currentUser?.id else { return }
        
        do {
            let friendship = Friendship(
                id: UUID().uuidString,
                userId: currentUserId,
                friendId: userId,
                status: .pending,
                createdAt: Date(),
                mutualFollow: false
            )
            
            try await db.collection("friendships").document(friendship.id).setData(from: friendship)
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = error.localizedDescription
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
        guard let userId = currentUser?.id else { return }
        
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
            
            try await sessionRef.setData(sessionData)
            
            // Update user stats
            try await userRef.updateData([
                "totalSessions": FieldValue.increment(Int64(1)),
                "totalTimeSpent": FieldValue.increment(Int64(session.actualDuration)),
                "longestSession": max(currentUser?.longestSession ?? 0, session.actualDuration),
                "\(session.sessionType.rawValue)SessionCount": FieldValue.increment(Int64(1)),
                "lastActiveAt": Date()
            ])
            
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    // MARK: - Leaderboards
    func loadLeaderboard(period: LeaderboardPeriod, scope: LeaderboardScope) async {
        // Implementation for leaderboard loading
        isLoading = true
        
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
            
            // Query sessions in the time period
            let query = db.collection("sessions")
                .whereField("createdAt", isGreaterThanOrEqualTo: startDate)
                .whereField("createdAt", isLessThanOrEqualTo: now)
            
            let snapshot = try await query.getDocuments()
            
            // Process leaderboard data
            var userStats: [String: (totalTime: TimeInterval, sessionCount: Int)] = [:]
            
            for document in snapshot.documents {
                let data = document.data()
                if let userId = data["userId"] as? String,
                   let duration = data["duration"] as? TimeInterval {
                    
                    if userStats[userId] == nil {
                        userStats[userId] = (0, 0)
                    }
                    userStats[userId]?.totalTime += duration
                    userStats[userId]?.sessionCount += 1
                }
            }
            
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
            
            DispatchQueue.main.async {
                self.leaderboardEntries = entries
                self.isLoading = false
            }
            
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
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
} 
