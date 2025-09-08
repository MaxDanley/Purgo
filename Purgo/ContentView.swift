//
//  ContentView.swift
//  Purgo
//
//  Created by Max Danley on 8/27/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var sessionManager = SessionManager()
    @StateObject private var liveActivityManager = LiveActivityManager()
    @ObservedObject private var firebaseManager = FirebaseManager.shared
    @State private var animateSauna = false
    @State private var animateCold = false
    @State private var selectedTab: AppTab = .timer
    @State private var friendsSelectedTab: FriendsTab = .friends
    @State private var showingEncouragementPopup = false
    @State private var currentEncouragementMessage = ""
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Timer Tab - Restored Original Design
            TimerPageView(
                sessionManager: sessionManager,
                liveActivityManager: liveActivityManager,
                firebaseManager: firebaseManager,
                animateSauna: $animateSauna,
                animateCold: $animateCold,
                showingEncouragementPopup: $showingEncouragementPopup,
                currentEncouragementMessage: $currentEncouragementMessage
            )
            .tag(AppTab.timer)
            
            // Friends Tab
            FriendsPageView(firebaseManager: firebaseManager, selectedTab: $friendsSelectedTab)
            .tag(AppTab.friends)
            
            // Sessions/Achievements Tab  
            AchievementsPageView(sessionManager: sessionManager, firebaseManager: firebaseManager)
            .tag(AppTab.achievements)
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        .background(Color.black.ignoresSafeArea())
        .overlay(
            // Custom tab bar at bottom
            CustomTabBar(selectedTab: $selectedTab)
            , alignment: .bottom
        )
        .sheet(isPresented: $sessionManager.showingGoalSelection) {
            GoalSelectionView(sessionManager: sessionManager)
        }
        .sheet(isPresented: $sessionManager.showingSessionStats) {
            SessionStatsView(sessionManager: sessionManager)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToFriends"))) { _ in
            selectedTab = .friends
            friendsSelectedTab = .friends
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToLeaderboard"))) { _ in
            selectedTab = .friends
            friendsSelectedTab = .leaderboard
        }
        .onAppear {
            sessionManager.setFirebaseManager(firebaseManager)
            firebaseManager.checkAuthenticationState()
        }
    }
    
    // MARK: - Encouragement Logic
    private func checkForEncouragementTriggers() {
        guard sessionManager.isRunning && !sessionManager.isPaused && !showingEncouragementPopup else { return }
        
        let minutes = Int(sessionManager.elapsedTime) / 60
        let seconds = Int(sessionManager.elapsedTime) % 60
        
        guard seconds == 0 else { return }
        
        let sessionType = sessionManager.sessionType ?? .sauna
        var message: String?
        
        switch minutes {
        case 5:
            message = sessionType == .sauna ? "🌡️ Great start! You've already boosted circulation and lowered stress hormones!" : "🧊 Incredible willpower! You've triggered norepinephrine release and boosted mental resilience!"
        case 10:
            message = sessionType == .sauna ? "🔥 Nice work! You've burned about 30 calories and improved circulation!" : "❄️ Outstanding! You've activated brown fat burning and improved cold tolerance!"
        case 15:
            message = sessionType == .sauna ? "💪 Excellent! Heart rate is up, sweating is at its peak!" : "🌊 Phenomenal! You're maximizing dopamine release and building serious mental toughness!"
        case 20:
            message = sessionType == .sauna ? "🏆 Amazing! You've activated heat shock proteins for cellular repair!" : "⚡ Legendary! You've achieved peak cold adaptation benefits!"
        default:
            break
        }
        
        if let encouragementMessage = message {
            showEncouragementPopup(message: encouragementMessage)
        }
    }
    
    private func showEncouragementPopup(message: String) {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            currentEncouragementMessage = message
            showingEncouragementPopup = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            withAnimation(.easeOut(duration: 0.5)) {
                showingEncouragementPopup = false
            }
        }
    }
}

#Preview {
    ContentView()
}
