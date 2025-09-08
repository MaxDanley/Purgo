//
//  SharedComponents.swift
//  Purgo
//
//  Created by Max Danley on 8/27/25.
//

import SwiftUI

// MARK: - App Tabs
enum AppTab: String, CaseIterable {
    case timer = "Timer"
    case friends = "Friends" 
    case achievements = "Achievements"
    
    var icon: String {
        switch self {
        case .timer: return "timer"
        case .friends: return "person.2.fill"
        case .achievements: return "trophy.fill"
        }
    }
}

enum FriendsTab: String, CaseIterable {
    case friends = "Friends"
    case leaderboard = "Leaderboard"
    case profile = "Profile"
}

// MARK: - Custom Tab Bar
struct CustomTabBar: View {
    @Binding var selectedTab: AppTab
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 20, weight: .medium))
                        Text(tab.rawValue)
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(selectedTab == tab ? .white : .gray)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 20)
        .background(
            Color.black.opacity(0.95)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}



// MARK: - Session History
struct SessionHistoryView: View {
    @ObservedObject var sessionManager: SessionManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Session history list
                LazyVStack(spacing: 12) {
                    ForEach(sessionManager.completedSessions) { session in
                        SessionHistoryRow(session: session)
                    }
                }
                
                if sessionManager.completedSessions.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("No sessions yet")
                            .font(.title2)
                            .foregroundColor(.gray)
                        Text("Complete your first session to see it here!")
                            .font(.subheadline)
                            .foregroundColor(.gray.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 50)
                }
                
                // Overall stats cards
                if !sessionManager.completedSessions.isEmpty {
                    VStack(spacing: 16) {
                        Text("Overall Stats")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                            StatCard(title: "Total Sessions", value: "\(sessionManager.completedSessions.count)", icon: "number.circle.fill")
                            StatCard(title: "Total Time", value: sessionManager.formatTime(sessionManager.totalSessionTime), icon: "clock.fill")
                            StatCard(title: "Average Duration", value: sessionManager.formatTime(Int(sessionManager.averageSessionDuration)), icon: "chart.bar.fill")
                            StatCard(title: "Goals Met", value: "\(sessionManager.goalsMetCount)/\(sessionManager.completedSessions.count)", icon: "target")
                        }
                    }
                    .padding(.top, 20)
                }
            }
            .padding(20)
        }
        .background(Color.black.ignoresSafeArea())
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.white)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(statCardBackground())
    }
    
    private func statCardBackground() -> some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.white.opacity(0.05))
            .stroke(Color.white.opacity(0.1), lineWidth: 1)
    }
}

struct SessionHistoryRow: View {
    let session: CompletedSession
    
    var body: some View {
        HStack(spacing: 12) {
            // Session type indicator
            ZStack {
                Circle()
                    .fill(sessionGradient(for: session.sessionType))
                    .frame(width: 40, height: 40)
                
                Image(systemName: session.sessionType == .sauna ? "flame.fill" : "snowflake")
                    .foregroundColor(.white)
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(session.sessionType.rawValue.capitalized)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    if session.goalMet {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
                
                HStack {
                    Text(session.durationString)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    Text("•")
                        .foregroundColor(.gray)
                    
                    Text(session.goalName)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Text(session.date, style: .date)
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.8))
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private func sessionGradient(for sessionType: SessionType) -> LinearGradient {
        switch sessionType {
        case .sauna:
            return LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .cold:
            return LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

// MARK: - Goal Selection View
struct GoalSelectionView: View {
    @ObservedObject var sessionManager: SessionManager
    @State private var selectedGoal: SessionGoal?
    @State private var sessionTypeToStart: SessionType = .sauna
    @State private var saunaTemperature: Double = 180 // Default 180°F
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                headerSection
                temperatureSliderSection
                goalsGridSection
                startButtonSection
                Spacer()
            }
            .padding()
            .background(Color.black.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        sessionManager.showingGoalSelection = false
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            sessionTypeToStart = sessionManager.pendingSessionType ?? .sauna
            selectedGoal = sessionManager.suggestedNextGoal(for: sessionTypeToStart)
            print("🎯 GoalSelectionView onAppear:")
            print("📝 Session type to start: \(sessionTypeToStart)")
            print("🎯 Selected goal: \(selectedGoal?.displayName ?? "nil")")
        }
    }
    
    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 10) {
            Image("InfinityIcon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
            
            Text("Choose Your Goal")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("How long would you like to session?")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
    }
    
    @ViewBuilder
    private var temperatureSliderSection: some View {
        if sessionTypeToStart == .sauna {
            VStack(spacing: 10) {
                Text("Sauna Temperature")
                    .font(.system(size: 14, weight: .light, design: .monospaced))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                HStack {
                    Text("160°F")
                        .font(.system(size: 12, weight: .light, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Slider(value: $saunaTemperature, in: 160...200, step: 5)
                        .accentColor(.orange)
                        .scaleEffect(0.9)
                    
                    Text("200°F")
                        .font(.system(size: 12, weight: .light, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Text("\(Int(saunaTemperature))°F")
                    .font(.system(size: 16, weight: .light, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
            }
            .padding(.horizontal, 20)
        }
    }
    
    @ViewBuilder
    private var goalsGridSection: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 15) {
            ForEach(SessionGoal.goals(for: sessionTypeToStart), id: \.duration) { goal in
                GoalButton(
                    goal: goal,
                    isSelected: selectedGoal?.duration == goal.duration,
                    isRecommended: goal.duration == sessionManager.suggestedNextGoal(for: sessionTypeToStart)?.duration,
                    sessionType: sessionTypeToStart,
                    saunaTemperature: saunaTemperature
                ) {
                    selectedGoal = goal
                }
            }
        }
    }
    
    @ViewBuilder
    private var startButtonSection: some View {
        if let selected = selectedGoal {
            Button("Start Session") {
                sessionManager.selectGoalAndStart(selected, type: sessionTypeToStart)
            }
            .font(.title2)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 40)
            .padding(.vertical, 16)
            .background(startButtonGradient())
            .cornerRadius(25)
        }
    }
    
    private func startButtonGradient() -> LinearGradient {
        LinearGradient(
            colors: sessionTypeToStart == .sauna ? [.orange, .red] : [.cyan, .blue],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

struct GoalButton: View {
    let goal: SessionGoal
    let isSelected: Bool
    let isRecommended: Bool
    let sessionType: SessionType
    let saunaTemperature: Double
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                recommendedBadge
                goalTitle
                goalDurationLabel
                calorieEstimate
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(goalButtonBackground())
        }
    }
    
    @ViewBuilder
    private var recommendedBadge: some View {
        if isRecommended {
            Text("RECOMMENDED")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.green)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.green.opacity(0.2))
                .cornerRadius(8)
        }
    }
    
    @ViewBuilder
    private var goalTitle: some View {
        Text(goal.displayName)
            .font(.title3)
            .fontWeight(.semibold)
            .foregroundColor(.white)
    }
    
    @ViewBuilder
    private var goalDurationLabel: some View {
        Text("Goal Duration")
            .font(.caption)
            .foregroundColor(.white.opacity(0.6))
    }
    
    @ViewBuilder
    private var calorieEstimate: some View {
        if sessionType == .sauna {
            let calories = calculateCaloriesBurned()
            Text("~\(Int(calories)) calories")
                .font(.system(size: 12, weight: .light, design: .monospaced))
                .foregroundColor(.white.opacity(0.8))
        }
    }
    
    private func goalButtonBackground() -> some View {
        RoundedRectangle(cornerRadius: 15)
            .fill(isSelected ? Color.white.opacity(0.2) : Color.white.opacity(0.05))
            .stroke(isSelected ? Color.white.opacity(0.6) : Color.clear, lineWidth: 2)
    }
    
    private func calculateCaloriesBurned() -> Double {
        let durationMinutes = goal.duration / 60
        
        switch sessionType {
        case .sauna:
            // Sauna calorie burn: Base rate of 1.5 cal/min at 160°F, increases with temperature
            // Temperature multiplier: 1.0 at 160°F, 1.5 at 200°F
            let baseRate = 1.5 // calories per minute at 160°F
            let temperatureMultiplier = 1.0 + ((saunaTemperature - 160) / 40) * 0.5
            return durationMinutes * baseRate * temperatureMultiplier
            
        case .cold:
            // Cold tub calorie burn: Higher rate due to thermogenesis
            // Cold water triggers brown fat activation and increased metabolic rate
            return durationMinutes * 2.5 // Higher burn rate for cold exposure
        }
    }
}

// MARK: - Session Stats View
struct SessionStatsView: View {
    @ObservedObject var sessionManager: SessionManager
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                sessionContentSection
                Spacer()
                continueButtonSection
            }
            .padding()
            .background(Color.black.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Session Complete")
        }
    }
    
    @ViewBuilder
    private var sessionContentSection: some View {
        if let session = sessionManager.lastCompletedSession {
            VStack(spacing: 20) {
                successIndicatorSection(session: session)
                sessionTitleSection(session: session)
                sessionDetailsSection(session: session)
                nextChallengeSection
            }
        }
    }
    
    @ViewBuilder
    private var continueButtonSection: some View {
        Button("Continue") {
            sessionManager.showingSessionStats = false
        }
        .font(.title2)
        .fontWeight(.semibold)
        .foregroundColor(.white)
        .padding(.horizontal, 40)
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.2))
        .cornerRadius(25)
    }
    
    @ViewBuilder
    private func successIndicatorSection(session: CompletedSession) -> some View {
        ZStack {
            Circle()
                .fill(session.wasGoalMet ? Color.green.opacity(0.2) : Color.white.opacity(0.2))
                .frame(width: 100, height: 100)
            
            Image("InfinityIcon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 60, height: 60)
        }
    }
    
    @ViewBuilder
    private func sessionTitleSection(session: CompletedSession) -> some View {
        VStack(spacing: 8) {
            Text(session.wasGoalMet ? "🎉 Goal Achieved!" : "💪 Great Session!")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("\(session.sessionType.displayName) Complete")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
        }
    }
    
    @ViewBuilder
    private func sessionDetailsSection(session: CompletedSession) -> some View {
        VStack(spacing: 15) {
            StatRow(title: "Duration", value: session.durationString)
            if session.goalDuration > 0 {
                StatRow(title: "Goal", value: session.goalString)
            }
            StatRow(title: "Session Type", value: session.sessionType.displayName)
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var nextChallengeSection: some View {
        if let suggested = sessionManager.suggestedNextGoal(for: .sauna) {
            VStack(spacing: 8) {
                Text("💡 Next Challenge")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("Try a \(suggested.displayName) session next time!")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(15)
        }
    }
}

struct StatRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.05))
        .cornerRadius(10)
    }
}
