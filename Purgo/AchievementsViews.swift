//
//  AchievementsViews.swift
//  Purgo
//
//  Created by Max Danley on 8/27/25.
//

import SwiftUI

// MARK: - Achievements Tab
enum AchievementsTab: String, CaseIterable {
    case badges = "Badges"
    case stats = "Stats"
}

// MARK: - Achievements Page View
struct AchievementsPageView: View {
    @ObservedObject var sessionManager: SessionManager
    @ObservedObject var firebaseManager: FirebaseManager
    @State private var selectedAchievementsTab: AchievementsTab = .badges
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 16) {
                Text("Your Journey")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Tab selector
                HStack(spacing: 0) {
                    ForEach(AchievementsTab.allCases, id: \.self) { tab in
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedAchievementsTab = tab
                            }
                        }) {
                            Text(tab.rawValue)
                                .font(.system(size: 16, weight: .light, design: .monospaced))
                                .fontWeight(.semibold)
                                .foregroundColor(selectedAchievementsTab == tab ? .black : .gray)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(selectedAchievementsTab == tab ? Color.white : Color.clear)
                                )
                        }
                    }
                }
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.1))
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            // Content based on selected tab
            switch selectedAchievementsTab {
            case .badges:
                BadgesView(sessionManager: sessionManager, firebaseManager: firebaseManager)
            case .stats:
                StatsView(sessionManager: sessionManager, firebaseManager: firebaseManager)
            }
        }
        .background(Color.black.ignoresSafeArea())
    }
}

// MARK: - All Badges View
struct AllBadgesView: View {
    @ObservedObject var sessionManager: SessionManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                    ForEach(Badge.allBadges, id: \.id) { badge in
                        BadgeGridItem(badge: badge)
                    }
                }
                .padding(20)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("All Badges")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}

// MARK: - Badges View
struct BadgesView: View {
    @ObservedObject var sessionManager: SessionManager
    @ObservedObject var firebaseManager: FirebaseManager
    @State private var showingAllBadges = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Badges unlocked count
                VStack(spacing: 8) {
                    Text("\(unlockedBadgesCount)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Badges Unlocked")
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    Text("out of \(Badge.allBadges.count)")
                        .font(.subheadline)
                        .foregroundColor(.gray.opacity(0.8))
                }
                .padding(.top, 20)
                
                // Progress to next badge
                if let nextBadge = nextBadgeToUnlock {
                    NextBadgeCard(badge: nextBadge, progress: progressToNextBadge(nextBadge))
                }
                
                // Recently unlocked badges
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Recent Achievements")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Button("See All") {
                            showingAllBadges = true
                        }
                        .font(.subheadline)
                        .foregroundColor(.white)
                    }
                    
                    if recentlyUnlockedBadges.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                            Text("No badges unlocked yet")
                                .font(.headline)
                                .foregroundColor(.gray)
                            Text("Complete sessions to start earning badges!")
                                .font(.subheadline)
                                .foregroundColor(.gray.opacity(0.8))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                    } else {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 20) {
                            ForEach(recentlyUnlockedBadges.prefix(6), id: \.id) { badge in
                                BadgeGridItem(badge: badge)
                            }
                        }
                    }
                }
                
                // Badge categories
                VStack(alignment: .leading, spacing: 16) {
                    Text("Categories")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(spacing: 12) {
                        BadgeCategoryRow(title: "Session Count", badges: Badge.allBadges.filter { $0.requirement.type == .sessionCount }, unlockedCount: unlockedBadgesInCategory(.sessionCount))
                        BadgeCategoryRow(title: "Time Spent", badges: Badge.allBadges.filter { $0.requirement.type == .totalMinutes }, unlockedCount: unlockedBadgesInCategory(.totalMinutes))
                        BadgeCategoryRow(title: "Streaks", badges: Badge.allBadges.filter { $0.requirement.type == .streak }, unlockedCount: unlockedBadgesInCategory(.streak))
                        BadgeCategoryRow(title: "Goals", badges: Badge.allBadges.filter { $0.requirement.type == .goalsMet }, unlockedCount: unlockedBadgesInCategory(.goalsMet))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 120) // Much more padding for tab bar
        }
        .sheet(isPresented: $showingAllBadges) {
            AllBadgesView(sessionManager: sessionManager)
        }
    }
    
    private var unlockedBadgesCount: Int {
        Badge.allBadges.filter { isBadgeUnlocked($0) }.count
    }
    
    private var recentlyUnlockedBadges: [Badge] {
        Badge.allBadges.filter { isBadgeUnlocked($0) }
    }
    
    private var nextBadgeToUnlock: Badge? {
        Badge.allBadges.first { !isBadgeUnlocked($0) }
    }
    
    private func isBadgeUnlocked(_ badge: Badge) -> Bool {
        switch badge.requirement.type {
        case .sessionCount:
            return sessionManager.completedSessions.count >= badge.requirement.value
        case .totalMinutes:
            return sessionManager.totalSessionTime >= badge.requirement.value * 60
        case .streak:
            return sessionManager.currentStreak >= badge.requirement.value
        case .goalsMet:
            return sessionManager.goalsMetCount >= badge.requirement.value
        }
    }
    
    private func progressToNextBadge(_ badge: Badge) -> Double {
        let currentValue: Int
        switch badge.requirement.type {
        case .sessionCount:
            currentValue = sessionManager.completedSessions.count
        case .totalMinutes:
            currentValue = sessionManager.totalSessionTime / 60
        case .streak:
            currentValue = sessionManager.currentStreak
        case .goalsMet:
            currentValue = sessionManager.goalsMetCount
        }
        return Double(currentValue) / Double(badge.requirement.value)
    }
    
    private func unlockedBadgesInCategory(_ type: BadgeRequirement.BadgeType) -> Int {
        Badge.allBadges.filter { $0.requirement.type == type && isBadgeUnlocked($0) }.count
    }
}

// MARK: - Next Badge Card
struct NextBadgeCard: View {
    let badge: Badge
    let progress: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: badge.icon)
                    .font(.title2)
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Next Badge")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text(badge.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                
                Spacer()
            }
            
            Text(badge.description)
                .font(.subheadline)
                .foregroundColor(.gray)
            
            ProgressView(value: min(progress, 1.0))
                .progressViewStyle(LinearProgressViewStyle(tint: .white))
                .scaleEffect(y: 2)
            
            HStack {
                Text("\(Int(progress * 100))% Complete")
                    .font(.caption)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(badge.requirement.displayText)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Badge Grid Item
struct BadgeGridItem: View {
    let badge: Badge
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                // Badge background with consistent size
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                // Badge icon
                Image(systemName: badge.icon)
                    .font(.title)
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 4) {
                Text(badge.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                Text(badge.description)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
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

// MARK: - Stats View
struct StatsView: View {
    @ObservedObject var sessionManager: SessionManager
    @ObservedObject var firebaseManager: FirebaseManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Overall Stats
                VStack(alignment: .leading, spacing: 16) {
                    Text("Overall Statistics")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                        StatCard(title: "Total Sessions", value: "\(sessionManager.completedSessions.count)", icon: "flame.fill")
                        StatCard(title: "Total Time", value: formatTime(sessionManager.totalSessionTime), icon: "clock.fill")
                        StatCard(title: "Current Streak", value: "\(sessionManager.currentStreak) days", icon: "calendar.badge.checkmark")
                        StatCard(title: "Longest Streak", value: "\(sessionManager.longestStreak) days", icon: "trophy.fill")
                        StatCard(title: "Goals Met", value: "\(sessionManager.goalsMetCount)", icon: "target")
                        StatCard(title: "Average Duration", value: formatTime(Int(sessionManager.averageSessionDuration)), icon: "chart.bar.fill")
                    }
                }
                
                // Session Type Breakdown
                VStack(alignment: .leading, spacing: 16) {
                    Text("Session Breakdown")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    HStack(spacing: 16) {
                        // Sauna stats
                        VStack(spacing: 8) {
                            Image(systemName: "flame.fill")
                                .font(.title)
                                .foregroundColor(.white)
                            
                            Text("\(saunaSessions)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("Sauna Sessions")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                            
                            Text(formatTime(saunaTime))
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.orange.opacity(0.1))
                                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                        )
                        
                        // Cold stats
                        VStack(spacing: 8) {
                            Image(systemName: "snowflake")
                                .font(.title)
                                .foregroundColor(.cyan)
                            
                            Text("\(coldSessions)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("Cold Sessions")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                            
                            Text(formatTime(coldTime))
                                .font(.caption)
                                .foregroundColor(.cyan)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.cyan.opacity(0.1))
                                .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                        )
                    }
                }
                
                // Recent Sessions
                if !sessionManager.completedSessions.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Recent Sessions")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        LazyVStack(spacing: 8) {
                            ForEach(sessionManager.completedSessions.prefix(5)) { session in
                                SessionHistoryRow(session: session)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 40)
        }
    }
    
    private var saunaSessions: Int {
        sessionManager.completedSessions.filter { $0.sessionType == .sauna }.count
    }
    
    private var coldSessions: Int {
        sessionManager.completedSessions.filter { $0.sessionType == .cold }.count
    }
    
    private var saunaTime: Int {
        sessionManager.completedSessions
            .filter { $0.sessionType == .sauna }
            .reduce(0) { $0 + Int($1.actualDuration) }
    }
    
    private var coldTime: Int {
        sessionManager.completedSessions
            .filter { $0.sessionType == .cold }
            .reduce(0) { $0 + Int($1.actualDuration) }
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Supporting Views
struct BadgeCategoryRow: View {
    let title: String
    let badges: [Badge]
    let unlockedCount: Int
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text("\(unlockedCount) of \(badges.count) unlocked")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            ProgressView(value: Double(unlockedCount), total: Double(badges.count))
                .progressViewStyle(LinearProgressViewStyle(tint: .white))
                .frame(width: 60)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.05))
        )
    }
}

struct BadgeCard: View {
    let badge: Badge
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                // Badge background with hexagonal shape
                RoundedRectangle(cornerRadius: 15)
                    .fill(
                        LinearGradient(
                            colors: [Color.orange.opacity(0.3), Color.red.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                
                // Badge icon
                Image(systemName: badge.icon)
                    .font(.title)
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 6) {
                Text(badge.name)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                Text(badge.description)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 140) // Larger height
        .padding(20) // More padding
        .background(
            RoundedRectangle(cornerRadius: 16) // More rounded
                .fill(Color.white.opacity(0.05))
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}
