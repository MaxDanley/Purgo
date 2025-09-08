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
    @Binding var selectedTab: FriendsTab
    @State private var selectedPeriod: LeaderboardPeriod = .weekly
    @State private var selectedScope: LeaderboardScope = .friends
    
    var body: some View {
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
    private var selectedTabContent: some View {
        switch selectedTab {
        case .friends:
            FriendsListView(firebaseManager: firebaseManager)
        case .leaderboard:
            FitnessStyleLeaderboardView(firebaseManager: firebaseManager, selectedPeriod: $selectedPeriod, selectedScope: $selectedScope)
        case .profile:
            ProfileView(firebaseManager: firebaseManager)
        }
    }
}

// MARK: - Friends List View
struct FriendsListView: View {
    @ObservedObject var firebaseManager: FirebaseManager
    @State private var searchText = ""
    @State private var searchResults: [PurgoUser] = []
    @State private var isSearching = false
    
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
                                        FriendRow(user: user)
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
    }
    
    private func searchBarBackground() -> some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.white.opacity(0.1))
    }
}

// MARK: - Profile View
struct ProfileView: View {
    @ObservedObject var firebaseManager: FirebaseManager
    @State private var showingUsernameEditor = false
    @State private var newUsername = ""
    @State private var isUpdatingUsername = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isUpdatingProfilePicture = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let user = firebaseManager.currentUser {
                    profileHeaderSection(user: user)
                    statsCardsSection(user: user)
                    recentSessionsSection(user: user)
                } else {
                    noUserView
                }
            }
            .padding(20)
        }
        .background(Color.black.ignoresSafeArea())
        .sheet(isPresented: $showingUsernameEditor) {
            UsernameEditorView(
                currentUsername: firebaseManager.currentUser?.username ?? "",
                newUsername: $newUsername,
                isUpdating: $isUpdatingUsername,
                onSave: {
                    Task {
                        await firebaseManager.updateUsername(newUsername)
                        showingUsernameEditor = false
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

            if user.recentSessions.isEmpty {
                Text("No recent sessions")
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 8) {
                    ForEach(user.recentSessions.prefix(5), id: \.timestamp) { session in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(session.type == "sauna" ? "Sauna Session" : "Cold Tub Session")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)

                                Text("\(session.duration) minutes")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }

                            Spacer()

                            Text(session.timestamp, style: .date)
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
                }
            }
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
                            FitnessStyleLeaderboardRow(entry: entry, rank: entry.rank)
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
                AsyncImage(url: URL(string: entry.photoURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    userImagePlaceholder()
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.displayName)
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
                    .padding(.horizontal, 12)
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
                    .padding(.horizontal, 12)
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
        NavigationView {
            VStack(spacing: 20) {
                Text("Change Username")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("New Username")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    TextField("Enter new username", text: $newUsername)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled(isUpdating)
                }
                
                Spacer()
                
                Button(action: onSave) {
                    if isUpdating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Save")
                            .fontWeight(.semibold)
                    }
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.white)
                .cornerRadius(25)
                .disabled(newUsername.isEmpty || newUsername == currentUsername || isUpdating)
                .opacity((newUsername.isEmpty || newUsername == currentUsername || isUpdating) ? 0.6 : 1.0)
            }
            .padding(20)
            .background(Color.black.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                    .disabled(isUpdating)
                }
            }
        }
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
