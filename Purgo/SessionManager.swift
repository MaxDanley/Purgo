//
//  SessionManager.swift
//  Purgo
//
//  Created by Max Danley on 8/27/25.
//

import Foundation
import SwiftUI

// MARK: - Session Models
struct SessionGoal {
    let duration: TimeInterval // in seconds
    let displayName: String
    
    static let goals: [SessionGoal] = [
        SessionGoal(duration: 5 * 60, displayName: "5 min"),
        SessionGoal(duration: 10 * 60, displayName: "10 min"),
        SessionGoal(duration: 15 * 60, displayName: "15 min"),
        SessionGoal(duration: 20 * 60, displayName: "20 min"),
        SessionGoal(duration: 25 * 60, displayName: "25 min")
    ]
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
    @Published var selectedGoal: SessionGoal?
    @Published var showingGoalSelection = false
    @Published var showingSessionStats = false
    @Published var lastCompletedSession: CompletedSession?
    @Published var pendingSessionType: SessionType?
    
    @Published var completedSessions: [CompletedSession] = []
    
    private var displayTimer: Timer?
    private var liveActivityManager: LiveActivityManager?
    private var pauseStartTime: Date?
    private var firebaseManager: FirebaseManager?
    
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
    
    var progressPercentage: Double {
        guard let goal = selectedGoal else { return 0 }
        return min(1.0, timeElapsed / goal.duration)
    }
    
    func setLiveActivityManager(_ manager: LiveActivityManager) {
        self.liveActivityManager = manager
    }
    
    func setFirebaseManager(_ manager: FirebaseManager) {
        self.firebaseManager = manager
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
        
        // Sync with Firebase (creates collections automatically)
        Task {
            await firebaseManager?.updateUserStats(with: session)
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
    private func saveSessions() {
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
    
    var averageSessionDuration: TimeInterval {
        guard !completedSessions.isEmpty else { return 0 }
        return totalTimeSpent / Double(completedSessions.count)
    }
    
    var longestSession: CompletedSession? {
        completedSessions.max { $0.actualDuration < $1.actualDuration }
    }
    
    var suggestedNextGoal: SessionGoal? {
        guard let lastSession = completedSessions.last else { return SessionGoal.goals.first }
        
        // Suggest 30 seconds longer than last session
        let suggestedDuration = lastSession.actualDuration + 30
        
        // Find the closest goal that's longer than their last session
        return SessionGoal.goals.first { $0.duration >= suggestedDuration } ?? SessionGoal.goals.last
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