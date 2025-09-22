//
//  FriendsViews.swift
//  Purgo
//
//  Created by Max Danley on 8/27/25.
//

import SwiftUI
import PhotosUI
import FirebaseFirestore
import UIKit

// MARK: - Friends Page View
struct FriendsPageView: View {
    @ObservedObject var firebaseManager: FirebaseManager
    @ObservedObject var sessionManager: SessionManager
    @Binding var selectedTab: FriendsTab
    @State private var selectedPeriod: LeaderboardPeriod = .weekly
    @State private var selectedScope: LeaderboardScope = .friends
    
    var body: some View {
        VStack(spacing: 0) {
            if firebaseManager.isAuthenticated {
                // Authenticated user - show tabs and content
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 16) {
                        Text("Connect & Compete")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Tab selector
                        HStack(spacing: 0) {
                            ForEach(FriendsTab.allCases, id: \.self) { tab in
                                Button(action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selectedTab = tab
                                    }
                                }) {
                                    Text(tab.rawValue)
                                        .font(.system(size: 16, weight: .light, design: .monospaced))
                                        .fontWeight(.semibold)
                                        .foregroundColor(selectedTab == tab ? .black : .gray)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(tabButtonBackground(isSelected: selectedTab == tab))
                                }
                            }
                        }
                        .padding(4)
                        .background(tabSelectorBackground())
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    // Content based on selected tab
                    selectedTabContent
                }
            } else {
                // Not authenticated - show sign-in options
                signInView
            }
        }
        .background(Color.black.ignoresSafeArea())
        .alert("Error", isPresented: .constant(firebaseManager.errorMessage != nil)) {
            Button("OK") {
                firebaseManager.errorMessage = nil
            }
        } message: {
            Text(firebaseManager.errorMessage ?? "")
        }
    }
    
    private func tabButtonBackground(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(isSelected ? Color.white : Color.clear)
    }
    
    private func tabSelectorBackground() -> some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.white.opacity(0.1))
    }
    
    @ViewBuilder
    private var signInView: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Header
            VStack(spacing: 16) {
                Text("Connect & Compete")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("Sign in to connect with friends, track your progress, and compete on leaderboards")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 20)
            
            Spacer()
            
            // Sign-in buttons
            VStack(spacing: 16) {
                // Google Sign-In Button
                Button(action: {
                    Task {
                        await firebaseManager.signInWithGoogle()
                    }
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "globe")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text("Sign in with Google")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.red)
                            .stroke(Color.red.opacity(0.3), lineWidth: 1)
                    )
                }
                
                // Apple Sign-In Button
                Button(action: {
                    Task {
                        await firebaseManager.signInWithApple()
                    }
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "applelogo")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text("Sign in with Apple")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, 20)
            
            Spacer()
        }
    }
    
    @ViewBuilder
    private var selectedTabContent: some View {
        switch selectedTab {
        case .friends:
            FriendsListView(firebaseManager: firebaseManager)
        case .findFriends:
            FindFriendsView(firebaseManager: firebaseManager)
        case .leaderboard:
            FitnessStyleLeaderboardView(firebaseManager: firebaseManager, selectedPeriod: $selectedPeriod, selectedScope: $selectedScope)
        case .profile:
            ProfileView(firebaseManager: firebaseManager, sessionManager: sessionManager)
        }
    }
}

// MARK: - Friends List View
struct FriendsListView: View {
    @ObservedObject var firebaseManager: FirebaseManager
    @State private var searchText = ""
    @State private var searchResults: [PurgoUser] = []
    @State private var isSearching = false
    @State private var selectedFriend: PurgoUser?
    @State private var showingFriendProfile = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search users...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .foregroundColor(.white)
                    .onChange(of: searchText) { newValue in
                        if !newValue.isEmpty {
                            Task {
                                isSearching = true
                                searchResults = await firebaseManager.searchUsers(by: newValue)
                                isSearching = false
                            }
                        } else {
                            searchResults = []
                        }
                    }
                
                if !searchText.isEmpty {
                    Button("Clear") {
                        searchText = ""
                        searchResults = []
                    }
                    .foregroundColor(.white)
                }
            }
            .padding(12)
            .background(searchBarBackground())
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            ScrollView {
                VStack(spacing: 16) {
                    // Search results
                    if !searchText.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Search Results")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            if isSearching {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 20)
                            } else if searchResults.isEmpty {
                                Text("No users found")
                                    .foregroundColor(.gray)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 20)
                            } else {
                                LazyVStack(spacing: 8) {
                                    ForEach(searchResults) { user in
                                        UserSearchRow(user: user, firebaseManager: firebaseManager)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    } else {
                        // Received Friend requests section
                        if !firebaseManager.friendRequests.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Friend Requests")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                LazyVStack(spacing: 8) {
                                    ForEach(firebaseManager.friendRequests) { user in
                                        FriendRequestRow(user: user, firebaseManager: firebaseManager)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // Sent requests section
                        if !firebaseManager.sentFriendRequests.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Sent requests")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                LazyVStack(spacing: 8) {
                                    ForEach(Array(firebaseManager.sentFriendRequests), id: \.self) { userId in
                                        PendingSentRequestRow(userId: userId, firebaseManager: firebaseManager)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // Friends list
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Your Friends (\(firebaseManager.friends.count))")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            if firebaseManager.friends.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "person.2.fill")
                                        .font(.system(size: 48))
                                        .foregroundColor(.gray)
                                    Text("No friends yet")
                                        .font(.title2)
                                        .foregroundColor(.gray)
                                    Text("Search for users above to add friends!")
                                        .font(.subheadline)
                                        .foregroundColor(.gray.opacity(0.8))
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                            } else {
                                LazyVStack(spacing: 8) {
                                    ForEach(firebaseManager.friends) { user in
                                        FriendRow(user: user, firebaseManager: firebaseManager) {
                                            print("🟡 FriendsListView: FriendRow tapped for user: \(user.username)")
                                            print("🟡 FriendsListView: Setting selectedFriend to: \(user.username)")
                                            selectedFriend = user
                                            print("🟡 FriendsListView: Setting showingFriendProfile to true")
                                            showingFriendProfile = true
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.vertical, 20)
            }
        }
        .onAppear {
            Task {
                await firebaseManager.loadFriends()
                await firebaseManager.loadPendingRequests()
            }
        }
        .sheet(isPresented: $showingFriendProfile) {
            if let friend = selectedFriend {
                FriendProfileView(friend: friend, firebaseManager: firebaseManager)
                    .onAppear {
                        print("🟡 FriendsListView: Sheet presenting for friend: \(friend.username)")
                    }
            } else {
                Text("Error: No friend selected")
                    .foregroundColor(.white)
                    .background(Color.black)
                    .onAppear {
                        print("🔴 FriendsListView: Sheet presenting but selectedFriend is nil!")
                    }
            }
        }
        .onChange(of: showingFriendProfile) { isPresented in
            print("🟡 FriendsListView: showingFriendProfile changed to: \(isPresented)")
            if isPresented {
                print("🟡 FriendsListView: selectedFriend: \(selectedFriend?.username ?? "nil")")
            }
        }
    }
    
    private func searchBarBackground() -> some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.white.opacity(0.1))
    }
}

// MARK: - Profile View
struct ProfileView: View {
    @ObservedObject var firebaseManager: FirebaseManager
    @ObservedObject var sessionManager: SessionManager
    @State private var showingUsernameEditor = false
    @State private var newUsername = ""
    @State private var isUpdatingUsername = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isUpdatingProfilePicture = false
    @State private var showAllSessions = false
    @State private var showingDeleteAccountAlert = false
    @State private var isDeletingAccount = false
    @StateObject private var inviteManager = InviteManager()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let user = firebaseManager.currentUser {
                    profileHeaderSection(user: user)
                    statsCardsSection(user: user)
                    recentSessionsSection(user: user)
                    signOutSection()
                } else {
                    noUserView
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 100) // Extra padding for bottom tabs
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            // Refresh user profile data when view appears
            Task {
                await firebaseManager.refreshUserProfile()
            }
        }
        .sheet(isPresented: $showingUsernameEditor) {
            UsernameEditorView(
                currentUsername: firebaseManager.currentUser?.username ?? "",
                newUsername: $newUsername,
                isUpdating: $isUpdatingUsername,
                onSave: {
                    Task {
                        let success = await firebaseManager.updateUsername(newUsername)
                        if success {
                            showingUsernameEditor = false
                        }
                        // Error handling is done in FirebaseManager via errorMessage
                    }
                }
            )
        }
        .onChange(of: selectedPhotoItem) { newItem in
            Task {
                if let newItem = newItem,
                   let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    isUpdatingProfilePicture = true
                    let success = await firebaseManager.updateProfilePicture(image)
                    isUpdatingProfilePicture = false
                    if !success {
                        print("Failed to update profile picture")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func profileHeaderSection(user: PurgoUser) -> some View {
        VStack(spacing: 16) {
            ZStack {
                // Profile Image
                AsyncImage(url: URL(string: user.photoURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    profileImagePlaceholder()
                }
                .frame(width: 100, height: 100)
                .clipShape(Circle())

                // Camera button for photo editing
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    cameraButton()
                }
                .offset(x: 30, y: 30)
                .disabled(isUpdatingProfilePicture)
            }
            .overlay(profileUpdateOverlay())

            VStack(spacing: 8) {
                HStack {
                    Text(user.username)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Button(action: {
                        newUsername = user.username
                        showingUsernameEditor = true
                    }) {
                        Image(systemName: "pencil")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                }

                if !user.email.isEmpty {
                    Text(user.email)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                // Share button
                Button(action: {
                    Task {
                        await inviteManager.shareInviteLink()
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                        
                        Text("Share Profile")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.blue)
                    )
                }
                .padding(.top, 8)
            }
        }
    }

    @ViewBuilder
    private func statsCardsSection(user: PurgoUser) -> some View {
        // Stats Cards
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
            EnhancedStatCard(
                title: "Total Sessions",
                value: "\(user.totalSessions)",
                icon: "flame.fill",
                color: .white
            )

            EnhancedStatCard(
                title: "Total Time",
                value: formatDuration(user.totalMinutes * 60),
                icon: "clock.fill",
                color: .blue
            )

            EnhancedStatCard(
                title: "Current Streak",
                value: "\(user.currentStreak)",
                icon: "calendar.badge.checkmark",
                color: .green
            )

            EnhancedStatCard(
                title: "Best Streak",
                value: "\(user.longestStreak)",
                icon: "trophy.fill",
                color: .yellow
            )
        }
    }

    @ViewBuilder
    private func recentSessionsSection(user: PurgoUser) -> some View {
        // Recent Sessions
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Sessions")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            if sessionManager.completedSessions.isEmpty {
                Text("No recent sessions")
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 8) {
                    let sortedSessions = sessionManager.completedSessions.sorted { $0.endTime > $1.endTime }
                    let sessionsToShow = showAllSessions ? sortedSessions : Array(sortedSessions.prefix(3))
                    
                    ForEach(sessionsToShow, id: \.id) { session in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(session.sessionType == .sauna ? "Sauna Session" : "Cold Tub Session")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)

                                Text("\(Int(session.actualDuration / 60)) minutes")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }

                            Spacer()

                            Text(session.endTime, style: .date)
                                .font(.caption)
                                .foregroundColor(.gray.opacity(0.8))
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.05))
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                    }
                    
                    // Show All button if there are more than 3 sessions
                    if sessionManager.completedSessions.count > 3 {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showAllSessions.toggle()
                            }
                        }) {
                            Text(showAllSessions ? "Show Less" : "Show All (\(sessionManager.completedSessions.count))")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.white.opacity(0.1))
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        }
                        .padding(.top, 8)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func signOutSection() -> some View {
        VStack(spacing: 12) {
            Button(action: {
                firebaseManager.signOut()
            }) {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Text("Sign Out")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.red.opacity(0.1))
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
            }
            
            Button(action: {
                showingDeleteAccountAlert = true
            }) {
                HStack {
                    if isDeletingAccount {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .red))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "trash")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    
                    Text(isDeletingAccount ? "Deleting..." : "Delete Account")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.red.opacity(0.1))
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
            }
            .disabled(isDeletingAccount)
        }
        .alert("Delete Account", isPresented: $showingDeleteAccountAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await deleteAccount()
                }
            }
        } message: {
            Text("Are you sure you want to delete your account? This action cannot be undone and will permanently remove all your data, including sessions, friends, and achievements.")
        }
    }
    
    @ViewBuilder
    private var noUserView: some View {
        Text("Please sign in to view your profile")
            .font(.title2)
            .foregroundColor(.gray)
            .padding(.top, 50)
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func profileImagePlaceholder() -> some View {
        Circle()
            .fill(Color.gray.opacity(0.3))
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.gray)
            )
    }
    
    private func cameraButton() -> some View {
        Image(systemName: "camera.fill")
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.black)
            .frame(width: 28, height: 28)
            .background(Color.white)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
    }
    
    @ViewBuilder
    private func profileUpdateOverlay() -> some View {
        if isUpdatingProfilePicture {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)
        }
    }
    
    private func deleteAccount() async {
        isDeletingAccount = true
        
        let success = await firebaseManager.deleteAccount()
        
        isDeletingAccount = false
        
        if !success {
            // Show error message if deletion failed
            // The error message is already set in FirebaseManager
        }
    }
}

// MARK: - Leaderboard View
struct FitnessStyleLeaderboardView: View {
    @ObservedObject var firebaseManager: FirebaseManager
    @Binding var selectedPeriod: LeaderboardPeriod
    @Binding var selectedScope: LeaderboardScope
    
    var body: some View {
        VStack(spacing: 20) {
            // Period and scope selectors
            VStack(spacing: 16) {
                // Period selector (Daily, Weekly, Monthly)
                HStack(spacing: 0) {
                    ForEach(LeaderboardPeriod.allCases, id: \.self) { period in
                        Button(action: {
                            selectedPeriod = period
                            loadLeaderboard()
                        }) {
                            Text(period.displayName)
                                .font(.system(size: 14, weight: .light, design: .monospaced))
                                .fontWeight(.semibold)
                                .foregroundColor(selectedPeriod == period ? .black : .gray)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(selectedPeriod == period ? Color.white : Color.clear)
                                )
                        }
                    }
                }
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.1))
                )
                
                // Scope selector (Friends, Local, State, Country)
                HStack(spacing: 0) {
                    ForEach(LeaderboardScope.allCases, id: \.self) { scope in
                        Button(action: {
                            selectedScope = scope
                            loadLeaderboard()
                        }) {
                            Text(scope.displayName)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(selectedScope == scope ? .white : .gray)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(selectedScope == scope ? Color.blue : Color.clear)
                                )
                        }
                    }
                }
                .padding(3)
                .background(
                    RoundedRectangle(cornerRadius: 9)
                        .fill(Color.white.opacity(0.05))
                )
            }
            .padding(.top, 20)
            
            // Leaderboard list
            if firebaseManager.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                    .padding(.top, 50)
            } else if firebaseManager.leaderboardEntries.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "trophy")
                        .font(.system(size: 48))
                        .foregroundColor(.gray.opacity(0.5))
                    
                    Text("No leaderboard data yet")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(.gray)
                    
                    Text("Complete some sessions to see rankings!")
                        .font(.subheadline)
                        .foregroundColor(.gray.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 50)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(Array(firebaseManager.leaderboardEntries.enumerated()), id: \.element.id) { index, entry in
                            FitnessStyleLeaderboardRow(entry: entry, rank: entry.rank, firebaseManager: firebaseManager)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            
            Spacer()
        }
        .onAppear {
            loadLeaderboard()
        }
        .onChange(of: firebaseManager.currentUser) { _ in
            // Reload leaderboard when user data changes
            loadLeaderboard()
        }
    }
    
    private func loadLeaderboard() {
        Task {
            await firebaseManager.loadLeaderboard(period: selectedPeriod, scope: selectedScope)
        }
    }
}

// MARK: - Leaderboard Row
struct FitnessStyleLeaderboardRow: View {
    let entry: LeaderboardEntry
    let rank: Int
    @ObservedObject var firebaseManager: FirebaseManager
    
    private var profileImageURL: String {
        // If this is the current user, use their current profile picture from FirebaseManager
        if entry.userId == firebaseManager.currentUser?.id {
            return firebaseManager.currentUser?.photoURL ?? ""
        }
        // Otherwise use the entry's photoURL
        return entry.photoURL ?? ""
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Rank
            ZStack {
                Circle()
                    .fill(rankColor.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Text("\(rank)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(rankColor)
            }
            
            // User info
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: profileImageURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    userImagePlaceholder()
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.userId == firebaseManager.currentUser?.id ? "Me" : entry.displayName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text("\(entry.totalSessions) sessions • \(entry.totalMinutes) min")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Text("\(entry.score) pts")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(leaderboardRowBackground())
    }
    
    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return Color.brown
        default: return .white
        }
    }
    
    @ViewBuilder
    private func userImagePlaceholder() -> some View {
        Circle()
            .fill(Color.gray.opacity(0.3))
            .overlay(
                Image(systemName: "person.fill")
                    .font(.title3)
                    .foregroundColor(.gray)
            )
    }
    
    @ViewBuilder
    private func leaderboardRowBackground() -> some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.white.opacity(0.05))
            .stroke(Color.white.opacity(0.1), lineWidth: 1)
    }
}

// MARK: - Supporting Views
struct EnhancedStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 15)
                    .fill(color.opacity(0.2))
                    .frame(width: 60, height: 60)
                
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
            }
            
            VStack(spacing: 4) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

struct UserSearchRow: View {
    let user: PurgoUser
    @ObservedObject var firebaseManager: FirebaseManager
    
    private var friendshipButtonContent: some View {
        let status = firebaseManager.friendshipStatuses[user.id]
        let buttonText: String
        let buttonColor: Color
        let isDisabled: Bool
        
        switch status {
        case .pending:
            buttonText = "Pending"
            buttonColor = Color.gray
            isDisabled = true
        case .accepted:
            buttonText = "Friends"
            buttonColor = Color.green
            isDisabled = true
        case .blocked:
            buttonText = "Blocked"
            buttonColor = Color.red
            isDisabled = true
        case nil:
            buttonText = "Follow"
            buttonColor = Color.white
            isDisabled = false
        }
        
        return Text(buttonText)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(buttonColor == .white ? .black : .white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(buttonColor)
            .cornerRadius(20)
            .opacity(isDisabled ? 0.7 : 1.0)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: user.photoURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                    )
            }
            .frame(width: 50, height: 50)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(user.username)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                HStack {
                    Text("\(user.totalSessions) sessions")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text("•")
                        .foregroundColor(.gray)
                    
                    Text("\(user.totalMinutes)min total")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            // Dynamic button based on friendship status
            Button(action: {
                let status = firebaseManager.friendshipStatuses[user.id]
                if status == nil {
                    Task {
                        await firebaseManager.sendFriendRequest(to: user.id)
                    }
                }
            }) {
                friendshipButtonContent
            }
            .disabled(firebaseManager.friendshipStatuses[user.id] != nil)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.05))
        )
    }
}

struct FriendRow: View {
    let user: PurgoUser
    let firebaseManager: FirebaseManager
    let onTap: () -> Void
    
    var body: some View {
        Button(action: {
            print("🟡 FriendRow: Button tapped for user: \(user.username)")
            onTap()
        }) {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: user.photoURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                    )
            }
            .frame(width: 50, height: 50)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(user.username)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                HStack {
                    Text("\(user.totalSessions) sessions")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text("•")
                        .foregroundColor(.gray)
                    
                    Text("\(user.currentStreak) day streak")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            // Status indicator
            Circle()
                .fill(Color.green)
                .frame(width: 8, height: 8)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.05))
        )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct FriendRequestRow: View {
    let user: PurgoUser
    @ObservedObject var firebaseManager: FirebaseManager
    @State private var isProcessing = false
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: user.photoURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                    )
            }
            .frame(width: 50, height: 50)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(user.username)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text("wants to be friends")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            if isProcessing {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.8)
            } else {
                HStack(spacing: 8) {
                    Button("Accept") {
                        Task {
                            isProcessing = true
                            if let friendship = await findPendingFriendship(userId: user.id) {
                                await firebaseManager.acceptFriendRequest(friendship)
                                await firebaseManager.loadFriends()
                                await firebaseManager.loadPendingRequests()
                            }
                            isProcessing = false
                        }
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(width: 60) // Fixed width
                    .padding(.vertical, 6)
                    .background(Color.green)
                    .cornerRadius(15)
                    
                    Button("Decline") {
                        Task {
                            isProcessing = true
                            if let friendship = await findPendingFriendship(userId: user.id) {
                                await firebaseManager.declineFriendRequest(friendship)
                                await firebaseManager.loadPendingRequests()
                            }
                            isProcessing = false
                        }
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(width: 60) // Fixed width
                    .padding(.vertical, 6)
                    .background(Color.red)
                    .cornerRadius(15)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.05))
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func findPendingFriendship(userId: String) async -> Friendship? {
        return await firebaseManager.findPendingFriendship(userId: userId)
    }
}

struct UsernameEditorView: View {
    let currentUsername: String
    @Binding var newUsername: String
    @Binding var isUpdating: Bool
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with close button
            HStack {
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding()
                }
                .disabled(isUpdating)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            
            ScrollView {
                VStack(spacing: 32) {
                    // Header Section
                    VStack(spacing: 16) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.white)
                        
                        Text("Change Username")
                            .font(.system(size: 24, weight: .light, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Choose a unique username for your profile")
                            .font(.system(size: 16, weight: .light, design: .monospaced))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    // Current Username Display
                    VStack(spacing: 8) {
                        Text("Current Username")
                            .font(.system(size: 14, weight: .light, design: .monospaced))
                            .foregroundColor(.gray)
                        
                        Text(currentUsername)
                            .font(.system(size: 18, weight: .light, design: .monospaced))
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white.opacity(0.1))
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    }
                    
                    // New Username Input
                    VStack(alignment: .leading, spacing: 12) {
                        Text("New Username")
                            .font(.system(size: 16, weight: .light, design: .monospaced))
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        TextField("Enter new username", text: $newUsername)
                            .font(.system(size: 16, weight: .light, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.1))
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                            .disabled(isUpdating)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    
                    // Username Requirements
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Requirements")
                            .font(.system(size: 14, weight: .light, design: .monospaced))
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            requirementRow("3-20 characters", isValid: newUsername.count >= 3 && newUsername.count <= 20)
                            requirementRow("Letters, numbers, underscores only", isValid: isValidUsernameFormat(newUsername))
                            requirementRow("Must be unique", isValid: newUsername != currentUsername && !newUsername.isEmpty)
                        }
                    }
                    
                    Spacer(minLength: 20)
                    
                    // Save Button
                    Button(action: onSave) {
                        HStack {
                            if isUpdating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 16, weight: .semibold))
                                
                                Text("Save Username")
                                    .font(.system(size: 16, weight: .light, design: .monospaced))
                                    .fontWeight(.semibold)
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            LinearGradient(
                                colors: isButtonEnabled ? [.orange, .red] : [.gray.opacity(0.3), .gray.opacity(0.2)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(25)
                        .shadow(color: isButtonEnabled ? .orange.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
                    }
                    .disabled(!isButtonEnabled)
                    .opacity(isButtonEnabled ? 1.0 : 0.6)
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 20)
            }
        }
        .background(Color.black.ignoresSafeArea())
    }
    
    private var isButtonEnabled: Bool {
        return !newUsername.isEmpty && 
               newUsername != currentUsername && 
               !isUpdating &&
               newUsername.count >= 3 && 
               newUsername.count <= 20 &&
               isValidUsernameFormat(newUsername)
    }
    
    private func requirementRow(_ text: String, isValid: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: isValid ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 12))
                .foregroundColor(isValid ? .green : .gray)
            
            Text(text)
                .font(.system(size: 12, weight: .light, design: .monospaced))
                .foregroundColor(isValid ? .white : .gray)
        }
    }
    
    private func isValidUsernameFormat(_ username: String) -> Bool {
        let regex = "^[a-zA-Z0-9_]+$"
        return username.range(of: regex, options: .regularExpression) != nil
    }
}

struct PendingSentRequestRow: View {
    let userId: String
    @ObservedObject var firebaseManager: FirebaseManager
    @State private var user: PurgoUser?
    @State private var isLoading = true
    
    var body: some View {
        HStack(spacing: 12) {
            if let user = user {
                AsyncImage(url: URL(string: user.photoURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.gray)
                        )
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.username)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text("Request sent")
                        .font(.caption)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Button("Cancel") {
                    Task {
                        await firebaseManager.cancelFriendRequest(to: userId)
                    }
                }
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.gray)
                .cornerRadius(15)
            } else if isLoading {
                HStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                    
                    Text("Loading...")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.05))
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
        .task {
            await loadUser()
        }
    }
    
    private func loadUser() async {
        do {
            let userData = try await Firestore.firestore()
                .collection("users")
                .document(userId)
                .getDocument()
            
            if let data = userData.data() {
                let user = try Firestore.Decoder().decode(PurgoUser.self, from: data)
                await MainActor.run {
                    self.user = user
                    self.isLoading = false
                }
            }
        } catch {
            print("❌ Error loading user: \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}

// MARK: - Friend Profile View
struct FriendProfileView: View {
    let friend: PurgoUser
    @ObservedObject var firebaseManager: FirebaseManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingRemoveConfirmation = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with close button
            HStack {
                Spacer()
                Button(action: { 
                    print("🔴 FriendProfileView: Close button tapped")
                    dismiss() 
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding()
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Header
                    profileHeaderSection
                        .onAppear {
                            print("🟢 FriendProfileView: Profile header appeared")
                        }
                    
                    // Stats Cards
                    statsCardsSection
                        .onAppear {
                            print("🟢 FriendProfileView: Stats cards appeared")
                        }
                    
                    // Remove Friend Button
                    removeFriendSection
                        .onAppear {
                            print("🟢 FriendProfileView: Remove friend button appeared")
                        }
                    
                    // Recent Sessions
                    recentSessionsSection
                        .onAppear {
                            print("🟢 FriendProfileView: Recent sessions section appeared")
                        }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 100)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            print("🟢 FriendProfileView: View appeared for friend: \(friend.username)")
            print("🟢 FriendProfileView: Friend data - ID: \(friend.id), Email: \(friend.email)")
            print("🟢 FriendProfileView: Friend stats - Sessions: \(friend.totalSessions), Time: \(friend.totalMinutes), Streak: \(friend.currentStreak)")
            print("🟢 FriendProfileView: FirebaseManager current user: \(firebaseManager.currentUser?.username ?? "nil")")
        }
        .onDisappear {
            print("🔴 FriendProfileView: View disappeared for friend: \(friend.username)")
        }
        .alert("Remove Friend", isPresented: $showingRemoveConfirmation) {
            Button("Cancel", role: .cancel) { 
                print("🔴 FriendProfileView: Remove friend cancelled")
            }
            Button("Remove", role: .destructive) {
                print("🔴 FriendProfileView: Remove friend confirmed")
                Task {
                    await firebaseManager.removeFriend(friend.id)
                    dismiss()
                }
            }
        } message: {
            Text("Are you sure you want to remove \(friend.username) from your friends list?")
        }
    }
    
    @ViewBuilder
    private var profileHeaderSection: some View {
        VStack(spacing: 16) {
            // Profile Image
            AsyncImage(url: URL(string: friend.photoURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                    )
            }
            .frame(width: 100, height: 100)
            .clipShape(Circle())
            
            VStack(spacing: 4) {
                Text(friend.username)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
        }
    }
    
    @ViewBuilder
    private var statsCardsSection: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
            EnhancedStatCard(
                title: "Total Sessions",
                value: "\(friend.totalSessions)",
                icon: "flame.fill",
                color: .white
            )
            
            EnhancedStatCard(
                title: "Total Time",
                value: formatDuration(friend.totalMinutes * 60),
                icon: "clock.fill",
                color: .blue
            )
            
            EnhancedStatCard(
                title: "Current Streak",
                value: "\(friend.currentStreak)",
                icon: "calendar.badge.checkmark",
                color: .green
            )
            
            EnhancedStatCard(
                title: "Best Streak",
                value: "\(friend.longestStreak)",
                icon: "trophy.fill",
                color: .yellow
            )
        }
    }
    
    @ViewBuilder
    private var removeFriendSection: some View {
        Button(action: {
            showingRemoveConfirmation = true
        }) {
            HStack {
                Image(systemName: "person.badge.minus")
                    .font(.system(size: 16, weight: .semibold))
                
                Text("Remove Friend")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.red)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.red.opacity(0.1))
                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
            )
        }
    }
    
    @ViewBuilder
    private var recentSessionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Sessions")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("Session history not available")
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
        }
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Find Friends View
struct FindFriendsView: View {
    @ObservedObject var firebaseManager: FirebaseManager
    @StateObject private var contactManager = ContactManager()
    @StateObject private var friendSuggestionManager = FriendSuggestionManager()
    @StateObject private var inviteManager = InviteManager()
    @State private var selectedSection: FindFriendsSection = .suggestions
    
    enum FindFriendsSection: String, CaseIterable {
        case suggestions = "Suggested"
        case contacts = "Contacts"
        case invite = "Invite"
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Section selector
                HStack(spacing: 0) {
                    ForEach(FindFriendsSection.allCases, id: \.self) { section in
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedSection = section
                            }
                        }) {
                            Text(section.rawValue)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(selectedSection == section ? .black : .gray)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(sectionButtonBackground(isSelected: selectedSection == section))
                        }
                    }
                }
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.1))
                )
                
                // Content based on selected section
                selectedSectionContent
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            Task {
                await friendSuggestionManager.loadFriendSuggestions()
            }
        }
        .alert("Error", isPresented: .constant(contactManager.errorMessage != nil || friendSuggestionManager.errorMessage != nil || inviteManager.errorMessage != nil)) {
            Button("OK") {
                contactManager.clearError()
                friendSuggestionManager.clearError()
                inviteManager.clearError()
            }
        } message: {
            Text(contactManager.errorMessage ?? friendSuggestionManager.errorMessage ?? inviteManager.errorMessage ?? "")
        }
    }
    
    private func sectionButtonBackground(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(isSelected ? Color.white : Color.clear)
    }
    
    @ViewBuilder
    private var selectedSectionContent: some View {
        switch selectedSection {
        case .suggestions:
            SuggestionsSectionView(friendSuggestionManager: friendSuggestionManager)
        case .contacts:
            ContactsSectionView(contactManager: contactManager)
        case .invite:
            InviteSectionView(inviteManager: inviteManager)
        }
    }
}

// MARK: - Suggestions Section
struct SuggestionsSectionView: View {
    @ObservedObject var friendSuggestionManager: FriendSuggestionManager
    @State private var showingMutualFriends = false
    @State private var selectedSuggestion: FriendSuggestion?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("People You May Know")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("Based on mutual friends and connections")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            if friendSuggestionManager.isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(.white)
                    
                    Text("Finding suggestions...")
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else if friendSuggestionManager.suggestions.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    
                    Text("No suggestions available")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("Connect with more people to see suggestions")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(friendSuggestionManager.suggestions) { suggestion in
                        SuggestionCardView(
                            suggestion: suggestion,
                            onSendRequest: {
                                Task {
                                    await friendSuggestionManager.sendFriendRequest(to: suggestion.id)
                                }
                            },
                            onShowMutualFriends: {
                                selectedSuggestion = suggestion
                                showingMutualFriends = true
                            }
                        )
                    }
                }
            }
        }
        .sheet(isPresented: $showingMutualFriends) {
            if let suggestion = selectedSuggestion {
                MutualFriendsView(suggestion: suggestion)
            }
        }
    }
}

// MARK: - Contacts Section
struct ContactsSectionView: View {
    @ObservedObject var contactManager: ContactManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Find Friends from Contacts")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("Connect with people you know from your contacts")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            if contactManager.contactsPermissionStatus == .notDetermined {
                VStack(spacing: 16) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                    
                    Text("Access Your Contacts")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("We'll help you find friends who are already using Purgo")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                    
                    Button(action: {
                        Task {
                            await contactManager.requestContactsPermission()
                        }
                    }) {
                        Text("Allow Access")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.blue)
                            )
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else if contactManager.contactsPermissionStatus == .denied {
                VStack(spacing: 16) {
                    Image(systemName: "person.crop.circle.badge.exclamationmark")
                        .font(.system(size: 48))
                        .foregroundColor(.red)
                    
                    Text("Contacts Access Denied")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("Enable contacts access in Settings to find friends")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                    
                    Button(action: {
                        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(settingsUrl)
                        }
                    }) {
                        Text("Open Settings")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.red)
                            )
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else if contactManager.isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(.white)
                    
                    Text("Scanning contacts...")
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else if contactManager.contactMatches.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "person.2.slash")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    
                    Text("No matches found")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("None of your contacts are using Purgo yet")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(contactManager.contactMatches) { match in
                        ContactMatchCardView(
                            match: match,
                            onSendRequest: {
                                Task {
                                    await contactManager.sendFriendRequest(to: match.id)
                                }
                            }
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Invite Section
struct InviteSectionView: View {
    @ObservedObject var inviteManager: InviteManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Invite Friends")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("Share Purgo with your friends and family")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            VStack(spacing: 20) {
                // Invite link display
                VStack(spacing: 12) {
                    Text("Your Invite Link")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if let inviteLink = inviteManager.currentInviteLink {
                        HStack {
                            Text(inviteLink)
                                .font(.system(size: 14, family: .monospaced))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.white.opacity(0.1))
                                )
                            
                            Button(action: {
                                UIPasteboard.general.string = inviteLink
                            }) {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.blue)
                            }
                        }
                    } else {
                        Button(action: {
                            Task {
                                await inviteManager.generateInviteLink()
                            }
                        }) {
                            HStack {
                                if inviteManager.isLoading {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .tint(.white)
                                } else {
                                    Image(systemName: "link")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                
                                Text(inviteManager.isLoading ? "Generating..." : "Generate Invite Link")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.blue)
                            )
                        }
                    }
                }
                
                // Share button
                Button(action: {
                    Task {
                        await inviteManager.shareInviteLink()
                    }
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 18, weight: .semibold))
                        
                        Text("Share Invite Link")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.green)
                    )
                }
                .disabled(inviteManager.currentInviteLink == nil)
                
                // Benefits section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Why invite friends?")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        BenefitRow(icon: "trophy.fill", text: "Compete on leaderboards together")
                        BenefitRow(icon: "chart.line.uptrend.xyaxis", text: "Track progress and motivate each other")
                        BenefitRow(icon: "person.2.fill", text: "Build a community of wellness enthusiasts")
                        BenefitRow(icon: "gift.fill", text: "Unlock special achievements and rewards")
                    }
                }
                .padding(.top, 20)
            }
        }
    }
}

// MARK: - Supporting Views
struct SuggestionCardView: View {
    let suggestion: FriendSuggestion
    let onSendRequest: () -> Void
    let onShowMutualFriends: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile image
            AsyncImage(url: URL(string: suggestion.profileImage ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                    )
            }
            .frame(width: 50, height: 50)
            .clipShape(Circle())
            
            // User info
            VStack(alignment: .leading, spacing: 4) {
                Text(suggestion.name)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("@\(suggestion.username)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                Text(suggestion.suggestedReason)
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            
            Spacer()
            
            // Action buttons
            VStack(spacing: 8) {
                Button(action: onSendRequest) {
                    Text(suggestion.isInvited ? "Invited" : "Add")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(suggestion.isInvited ? .gray : .white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(suggestion.isInvited ? Color.gray.opacity(0.3) : Color.blue)
                        )
                }
                .disabled(suggestion.isInvited)
                
                if suggestion.mutualFriendsCount > 0 {
                    Button(action: onShowMutualFriends) {
                        Text("\(suggestion.mutualFriendsCount) mutual")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

struct ContactMatchCardView: View {
    let match: ContactMatch
    let onSendRequest: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile image
            AsyncImage(url: URL(string: match.profileImage ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                    )
            }
            .frame(width: 50, height: 50)
            .clipShape(Circle())
            
            // User info
            VStack(alignment: .leading, spacing: 4) {
                Text(match.name)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(match.suggestedReason)
                    .font(.subheadline)
                    .foregroundColor(.blue)
                
                if match.mutualFriends > 0 {
                    Text("\(match.mutualFriends) mutual friend\(match.mutualFriends == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            // Action button
            Button(action: onSendRequest) {
                Text(match.isInvited ? "Invited" : "Add")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(match.isInvited ? .gray : .white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(match.isInvited ? Color.gray.opacity(0.3) : Color.blue)
                    )
            }
            .disabled(match.isInvited)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

struct MutualFriendsView: View {
    let suggestion: FriendSuggestion
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(suggestion.mutualFriends) { friend in
                    HStack(spacing: 12) {
                        AsyncImage(url: URL(string: friend.profileImage ?? "")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .foregroundColor(.gray)
                                )
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(friend.name)
                                .font(.headline)
                            
                            Text("@\(friend.username)")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Mutual Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct BenefitRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.green)
                .frame(width: 20)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.white)
        }
    }
}
