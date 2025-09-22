//
//  SessionManager.swift
//  Purgo
//
//  Created by Max Danley on 8/27/25.
//

import Foundation
import SwiftUI

// MARK: - Session Models
enum SessionType: String, CaseIterable, Codable {
    case sauna = "sauna"
    case cold = "cold"
    
    var displayName: String {
        switch self {
        case .sauna:
            return "Sauna Session"
        case .cold:
            return "Cold Tub Session"
        }
    }
}

// MARK: - Badge System
struct BadgeRequirement {
    enum BadgeType {
        case sessionCount
        case totalMinutes
        case streak
        case goalsMet
    }
    
    let type: BadgeType
    let value: Int
    
    var displayText: String {
        switch type {
        case .sessionCount:
            return "\(value) sessions"
        case .totalMinutes:
            return "\(value) minutes"
        case .streak:
            return "\(value) day streak"
        case .goalsMet:
            return "\(value) goals met"
        }
    }
}

struct Badge: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let icon: String
    let requirement: BadgeRequirement
    
    static let allBadges: [Badge] = [
        // Session Count Badges
        Badge(name: "First Step", description: "Complete your first session", icon: "star.fill", requirement: BadgeRequirement(type: .sessionCount, value: 1)),
        Badge(name: "Getting Started", description: "Complete 5 sessions", icon: "flame.fill", requirement: BadgeRequirement(type: .sessionCount, value: 5)),
        Badge(name: "Committed", description: "Complete 10 sessions", icon: "target", requirement: BadgeRequirement(type: .sessionCount, value: 10)),
        Badge(name: "Dedicated", description: "Complete 25 sessions", icon: "medal.fill", requirement: BadgeRequirement(type: .sessionCount, value: 25)),
        Badge(name: "Veteran", description: "Complete 50 sessions", icon: "crown.fill", requirement: BadgeRequirement(type: .sessionCount, value: 50)),
        Badge(name: "Master", description: "Complete 100 sessions", icon: "trophy.fill", requirement: BadgeRequirement(type: .sessionCount, value: 100)),
        
        // Time Spent Badges
        Badge(name: "Time Keeper", description: "Spend 30 minutes total", icon: "clock.fill", requirement: BadgeRequirement(type: .totalMinutes, value: 30)),
        Badge(name: "Hour Master", description: "Spend 60 minutes total", icon: "clock.badge.checkmark", requirement: BadgeRequirement(type: .totalMinutes, value: 60)),
        Badge(name: "Time Warrior", description: "Spend 3 hours total", icon: "timer", requirement: BadgeRequirement(type: .totalMinutes, value: 180)),
        Badge(name: "Endurance", description: "Spend 10 hours total", icon: "stopwatch.fill", requirement: BadgeRequirement(type: .totalMinutes, value: 600)),
        Badge(name: "Marathon", description: "Spend 24 hours total", icon: "gauge.high", requirement: BadgeRequirement(type: .totalMinutes, value: 1440)),
        
        // Streak Badges
        Badge(name: "Consistent", description: "3 day streak", icon: "calendar.badge.checkmark", requirement: BadgeRequirement(type: .streak, value: 3)),
        Badge(name: "Weekly Habit", description: "7 day streak", icon: "calendar.badge.plus", requirement: BadgeRequirement(type: .streak, value: 7)),
        Badge(name: "Unstoppable", description: "14 day streak", icon: "bolt.fill", requirement: BadgeRequirement(type: .streak, value: 14)),
        Badge(name: "Legend", description: "30 day streak", icon: "star.circle.fill", requirement: BadgeRequirement(type: .streak, value: 30)),
        
        // Goals Met Badges
        Badge(name: "Goal Getter", description: "Meet your first goal", icon: "checkmark.circle.fill", requirement: BadgeRequirement(type: .goalsMet, value: 1)),
        Badge(name: "Achiever", description: "Meet 5 goals", icon: "checkmark.shield.fill", requirement: BadgeRequirement(type: .goalsMet, value: 5)),
        Badge(name: "Perfectionist", description: "Meet 10 goals", icon: "rosette", requirement: BadgeRequirement(type: .goalsMet, value: 10)),
        Badge(name: "Goal Master", description: "Meet 25 goals", icon: "diamond.fill", requirement: BadgeRequirement(type: .goalsMet, value: 25))
    ]
}
struct SessionGoal: Identifiable {
    let id = UUID()
    let duration: TimeInterval // in seconds
    let displayName: String
    
    static let saunaGoals: [SessionGoal] = [
        SessionGoal(duration: 5 * 60, displayName: "5 min"),
        SessionGoal(duration: 10 * 60, displayName: "10 min"),
        SessionGoal(duration: 15 * 60, displayName: "15 min"),
        SessionGoal(duration: 20 * 60, displayName: "20 min"), // Default for sauna
        SessionGoal(duration: 25 * 60, displayName: "25 min"),
        SessionGoal(duration: 30 * 60, displayName: "30 min")
    ]
    
    static let coldGoals: [SessionGoal] = [
        SessionGoal(duration: 1 * 60, displayName: "1 min"),
        SessionGoal(duration: 2 * 60, displayName: "2 min"),
        SessionGoal(duration: 3 * 60, displayName: "3 min"),
        SessionGoal(duration: 5 * 60, displayName: "5 min"), // Default for cold
        SessionGoal(duration: 10 * 60, displayName: "10 min")
    ]
    
    static func goals(for sessionType: SessionType) -> [SessionGoal] {
        switch sessionType {
        case .sauna:
            return saunaGoals
        case .cold:
            return coldGoals
        }
    }
    
    static func defaultGoal(for sessionType: SessionType) -> SessionGoal {
        let goal: SessionGoal
        switch sessionType {
        case .sauna:
            goal = saunaGoals[3] // 20 min
        case .cold:
            goal = coldGoals[3] // 5 min
        }
        print("🎯 defaultGoal for \(sessionType): \(goal.displayName) (\(goal.duration)s)")
        return goal
    }
}

struct CompletedSession: Codable, Identifiable {
    let id: UUID
    let sessionType: SessionType
    let startTime: Date
    let endTime: Date
    let goalDuration: TimeInterval
    let actualDuration: TimeInterval
    let wasGoalMet: Bool
    
    init(sessionType: SessionType, startTime: Date, endTime: Date, goalDuration: TimeInterval, actualDuration: TimeInterval, wasGoalMet: Bool) {
        self.id = UUID()
        self.sessionType = sessionType
        self.startTime = startTime
        self.endTime = endTime
        self.goalDuration = goalDuration
        self.actualDuration = actualDuration
        self.wasGoalMet = wasGoalMet
    }
    
    var goalName: String {
        return "\(Int(goalDuration / 60)) min"
    }
    
    var duration: TimeInterval {
        return actualDuration
    }
    
    var goalMet: Bool {
        return wasGoalMet
    }
    
    var date: Date {
        return startTime
    }
    
    var durationString: String {
        let minutes = Int(actualDuration) / 60
        let seconds = Int(actualDuration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var goalString: String {
        let minutes = Int(goalDuration) / 60
        return "\(minutes) min"
    }
}

// MARK: - Session Manager
class SessionManager: ObservableObject {
    @Published var isRunning = false
    @Published var isPaused = false
    @Published var sessionType: SessionType?
    @Published var sessionStartTime: Date?
    @Published var pausedDuration: TimeInterval = 0
    @Published var pauseStartTime: Date?
    @Published var selectedGoal: SessionGoal?
    @Published var currentGoal: SessionGoal?
    @Published var showingGoalSelection = false
    @Published var showingSessionStats = false
    @Published var lastCompletedSession: CompletedSession?
    @Published var pendingSessionType: SessionType?
    
    @Published var completedSessions: [CompletedSession] = []
    
    private var displayTimer: Timer?
    private var liveActivityManager: LiveActivityManager?
    var firebaseManager: FirebaseManager?
    private var watchConnectivityManager: WatchConnectivityManager?
    
    init() {
        loadSessions()
    }
    
    // Computed property that calculates elapsed time based on start time
    var timeElapsed: TimeInterval {
        guard let startTime = sessionStartTime, isRunning || isPaused else { return 0 }
        let rawElapsed = Date().timeIntervalSince(startTime)
        return max(0, rawElapsed - pausedDuration)
    }
    
    var timeString: String {
        let elapsed = timeElapsed
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var timeRemaining: TimeInterval? {
        guard let goal = selectedGoal else { return nil }
        return max(0, goal.duration - timeElapsed)
    }
    
    var timeRemainingString: String {
        guard let remaining = timeRemaining else { return "" }
        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var isGoalMet: Bool {
        guard let goal = selectedGoal else { return false }
        return timeElapsed >= goal.duration
    }
    
    
    func setLiveActivityManager(_ manager: LiveActivityManager) {
        self.liveActivityManager = manager
    }
    
    func setFirebaseManager(_ manager: FirebaseManager) {
        self.firebaseManager = manager
    }
    
    func setWatchConnectivityManager(_ manager: WatchConnectivityManager) {
        self.watchConnectivityManager = manager
    }
    
    func selectGoalAndStart(_ goal: SessionGoal, type: SessionType) {
        selectedGoal = goal
        showingGoalSelection = false
        startSession(type)
    }
    
    func startSession(_ type: SessionType) {
        if isRunning {
            endSession()
        }
        
        sessionType = type
        sessionStartTime = Date()
        pausedDuration = 0
        isRunning = true
        isPaused = false
        
        // Start Live Activity
        liveActivityManager?.startLiveActivity(for: type)
        
        // Send session update to watch
        watchConnectivityManager?.sendSessionUpdateToWatch()
        
        // Notify mutual friends (creates notifications collection automatically)
        Task {
            if let currentUserId = firebaseManager?.currentUser?.id {
                // This will create the notifications collection on first use
                for friend in firebaseManager?.friends ?? [] {
                    await firebaseManager?.sendSessionNotification(to: friend.id, sessionType: type)
                }
            }
        }
        
        // Timer only for UI updates in the main app
        displayTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            DispatchQueue.main.async {
                self.objectWillChange.send()
                
                // Check if goal is met
                if self.isGoalMet && self.selectedGoal != nil {
                    // Auto-complete session when goal is reached
                    // User can still continue or manually end
                }
            }
        }
        
        // Add to common run loop to survive scrolling
        if let timer = displayTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    func pauseSession() {
        guard isRunning && !isPaused else { return }
        
        isPaused = true
        isRunning = false
        pauseStartTime = Date()
        
        displayTimer?.invalidate()
        displayTimer = nil
        
        // Pause Live Activity
        liveActivityManager?.endLiveActivity()
        
        // Send session update to watch
        watchConnectivityManager?.sendSessionUpdateToWatch()
    }
    
    func resumeSession() {
        guard isPaused, let pauseStart = pauseStartTime else { return }
        
        // Add pause duration to total paused time
        pausedDuration += Date().timeIntervalSince(pauseStart)
        
        isPaused = false
        isRunning = true
        pauseStartTime = nil
        
        // Restart timer and Live Activity
        if let sessionType = sessionType {
            liveActivityManager?.startLiveActivity(for: sessionType)
        }
        
        displayTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
        
        if let timer = displayTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
        
        // Send session update to watch
        watchConnectivityManager?.sendSessionUpdateToWatch()
    }
    
    func endSession() {
        guard let startTime = sessionStartTime, let type = sessionType else { return }
        
        let endTime = Date()
        let actualDuration = timeElapsed
        let goalDuration = selectedGoal?.duration ?? 0
        let wasGoalMet = selectedGoal != nil ? actualDuration >= goalDuration : true
        
        let session = CompletedSession(
            sessionType: type,
            startTime: startTime,
            endTime: endTime,
            goalDuration: goalDuration,
            actualDuration: actualDuration,
            wasGoalMet: wasGoalMet
        )
        
        completedSessions.append(session)
        lastCompletedSession = session
        saveSessions()
        
        // Send completed session to watch
        watchConnectivityManager?.sendCompletedSessionToWatch(session)
        
        // Sync with Firebase (creates collections automatically)
        Task {
            print("🔄 Starting Firebase sync for session: \(session.sessionType.rawValue), duration: \(Int(session.actualDuration))s")
            if firebaseManager == nil {
                print("❌ FirebaseManager is nil - cannot sync session")
            } else if firebaseManager?.currentUser == nil {
                print("❌ No current user - cannot sync session")
            } else {
                print("✅ FirebaseManager and user available, syncing...")
                await firebaseManager?.updateUserStats(with: session)
            }
        }
        
        // Stop timer and Live Activity
        displayTimer?.invalidate()
        displayTimer = nil
        liveActivityManager?.endLiveActivity()
        
        // Reset session state
        isRunning = false
        isPaused = false
        sessionType = nil
        sessionStartTime = nil
        pausedDuration = 0
        selectedGoal = nil
        pauseStartTime = nil
        
        // Show stats
        showingSessionStats = true
    }
    
    // MARK: - Data Persistence
    func saveSessions() {
        if let data = try? JSONEncoder().encode(completedSessions) {
            UserDefaults.standard.set(data, forKey: "completedSessions")
        }
    }
    
    private func loadSessions() {
        if let data = UserDefaults.standard.data(forKey: "completedSessions"),
           let sessions = try? JSONDecoder().decode([CompletedSession].self, from: data) {
            completedSessions = sessions
        }
    }
    
    // MARK: - Statistics
    var totalSessions: Int {
        completedSessions.count
    }
    
    var totalTimeSpent: TimeInterval {
        completedSessions.reduce(0) { $0 + $1.actualDuration }
    }
    
    var totalSessionTime: Int {
        Int(totalTimeSpent)
    }
    
    var currentStreak: Int {
        guard !completedSessions.isEmpty else { return 0 }
        
        let sortedSessions = completedSessions.sorted { $0.startTime < $1.startTime }
        var streak = 0
        var lastDate: Date?
        
        // Work backwards from the most recent session
        for session in sortedSessions.reversed() {
            let sessionDate = Calendar.current.startOfDay(for: session.startTime)
            let today = Calendar.current.startOfDay(for: Date())
            
            if lastDate == nil {
                // First session (most recent)
                let daysSinceSession = Calendar.current.dateComponents([.day], from: sessionDate, to: today).day ?? 0
                if daysSinceSession <= 1 {
                    streak = 1
                    lastDate = sessionDate
                } else {
                    break // Streak is broken
                }
            } else {
                let daysBetween = Calendar.current.dateComponents([.day], from: sessionDate, to: lastDate!).day ?? 0
                if daysBetween == 1 {
                    streak += 1
                    lastDate = sessionDate
                } else if daysBetween == 0 {
                    // Same day, don't increment streak but continue
                    continue
                } else {
                    break // Streak is broken
                }
            }
        }
        
        return streak
    }
    
    var goalsMetCount: Int {
        completedSessions.filter { $0.wasGoalMet }.count
    }
    
    var elapsedTime: TimeInterval {
        guard let startTime = sessionStartTime else { return 0 }
        let currentTime = isPaused ? (pauseStartTime ?? Date()) : Date()
        return currentTime.timeIntervalSince(startTime) - pausedDuration
    }
    
    var formattedTime: String {
        formatTime(Int(elapsedTime))
    }
    
    var progressPercentage: Double {
        guard let goal = currentGoal else { return 0 }
        return min(elapsedTime / goal.duration, 1.0)
    }
    
    func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
    
    var averageSessionDuration: TimeInterval {
        guard !completedSessions.isEmpty else { return 0 }
        return totalTimeSpent / Double(completedSessions.count)
    }
    
    var longestSession: CompletedSession? {
        completedSessions.max { $0.actualDuration < $1.actualDuration }
    }
    
    func suggestedNextGoal(for sessionType: SessionType) -> SessionGoal? {
        let goals = SessionGoal.goals(for: sessionType)
        let sessionsOfType = completedSessions.filter { $0.sessionType == sessionType }
        
        print("🎯 suggestedNextGoal for \(sessionType)")
        print("📊 Total completed sessions: \(completedSessions.count)")
        print("📊 Sessions of type \(sessionType): \(sessionsOfType.count)")
        
        // Filter out very short sessions (less than 1 minute) as they're likely test sessions
        let validSessions = sessionsOfType.filter { $0.actualDuration >= 60 }
        print("📊 Valid sessions (>= 1 min): \(validSessions.count)")
        
        guard !validSessions.isEmpty else { 
            let defaultGoal = SessionGoal.defaultGoal(for: sessionType)
            print("✅ No valid previous sessions, returning default goal: \(defaultGoal.displayName)")
            return defaultGoal
        }
        
        // Use average of last 3 sessions for better recommendation
        let recentSessions = Array(validSessions.suffix(3))
        let averageDuration = recentSessions.map { $0.actualDuration }.reduce(0, +) / Double(recentSessions.count)
        print("📊 Recent sessions average: \(averageDuration)s")
        
        // If average is very short (< 3 minutes), suggest default goal
        if averageDuration < 180 {
            let defaultGoal = SessionGoal.defaultGoal(for: sessionType)
            print("⚡ Average too short, suggesting default goal: \(defaultGoal.displayName)")
            return defaultGoal
        }
        
        // Suggest next step up from their average
        let suggestedDuration = averageDuration * 1.2 // 20% longer than average
        print("⏱️ Suggesting 20% longer than average: \(suggestedDuration)s")
        
        // Find the closest goal that's longer than their average
        let suggestedGoal = goals.first { $0.duration >= suggestedDuration } ?? goals.last
        print("🎯 Suggested goal: \(suggestedGoal?.displayName ?? "nil")")
        return suggestedGoal
    }
    
    // MARK: - Badge System Statistics
    var saunaSessionCount: Int {
        completedSessions.filter { $0.sessionType == .sauna }.count
    }
    
    var coldSessionCount: Int {
        completedSessions.filter { $0.sessionType == .cold }.count
    }
    
    var totalGoalsMet: Int {
        completedSessions.filter { $0.wasGoalMet }.count
    }
    
    var averageGoalsPerSession: Double {
        guard !completedSessions.isEmpty else { return 0 }
        return Double(totalGoalsMet) / Double(totalSessions)
    }
    
    var longestStreak: Int {
        let sortedSessions = completedSessions.sorted { $0.startTime < $1.startTime }
        var maxStreak = 0
        var currentStreak = 0
        var lastDate: Date?
        
        for session in sortedSessions {
            let sessionDate = Calendar.current.startOfDay(for: session.startTime)
            
            if let last = lastDate {
                let daysBetween = Calendar.current.dateComponents([.day], from: last, to: sessionDate).day ?? 0
                if daysBetween == 1 {
                    currentStreak += 1
                } else if daysBetween == 0 {
                    // Same day, don't increment streak
                    continue
                } else {
                    maxStreak = max(maxStreak, currentStreak)
                    currentStreak = 1
                }
            } else {
                currentStreak = 1
            }
            
            lastDate = sessionDate
        }
        
        return max(maxStreak, currentStreak)
    }
} 
