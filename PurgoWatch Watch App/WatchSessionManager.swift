//
//  WatchSessionManager.swift
//  PurgoWatch
//
//  Created by Max Danley on 8/27/25.
//

import Foundation
import SwiftUI
import WatchConnectivity

// MARK: - Watch Session Manager
class WatchSessionManager: NSObject, ObservableObject {
    @Published var isRunning = false
    @Published var isPaused = false
    @Published var sessionType: SessionType?
    @Published var sessionStartTime: Date?
    @Published var pausedDuration: TimeInterval = 0
    @Published var pauseStartTime: Date?
    @Published var selectedGoal: SessionGoal?
    @Published var showingSessionComplete = false
    @Published var pendingSessionType: SessionType?
    @Published var lastCompletedSession: CompletedSession?
    
    private var displayTimer: Timer?
    private var session: WCSession?
    
    override init() {
        super.init()
        setupWatchConnectivity()
    }
    
    // MARK: - Computed Properties
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
        return min(timeElapsed / goal.duration, 1.0)
    }
    
    // MARK: - Session Management
    func selectGoalAndStart(_ goal: SessionGoal, type: SessionType) {
        selectedGoal = goal
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
        
        // Send session start to iPhone
        sendSessionUpdateToPhone()
        
        // Start timer for UI updates
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
        
        // Send pause update to iPhone
        sendSessionUpdateToPhone()
    }
    
    func resumeSession() {
        guard isPaused, let pauseStart = pauseStartTime else { return }
        
        // Add pause duration to total paused time
        pausedDuration += Date().timeIntervalSince(pauseStart)
        
        isPaused = false
        isRunning = true
        pauseStartTime = nil
        
        // Restart timer
        displayTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
        
        if let timer = displayTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
        
        // Send resume update to iPhone
        sendSessionUpdateToPhone()
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
        
        lastCompletedSession = session
        
        // Send completed session to iPhone
        sendCompletedSessionToPhone(session)
        
        // Stop timer
        displayTimer?.invalidate()
        displayTimer = nil
        
        // Reset session state
        isRunning = false
        isPaused = false
        sessionType = nil
        sessionStartTime = nil
        pausedDuration = 0
        selectedGoal = nil
        pauseStartTime = nil
        
        // Show completion screen
        showingSessionComplete = true
    }
    
    // MARK: - Watch Connectivity
    private func setupWatchConnectivity() {
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }
    
    private func sendSessionUpdateToPhone() {
        guard let session = session, session.isReachable else { return }
        
        let message: [String: Any] = [
            "type": "sessionUpdate",
            "isRunning": isRunning,
            "isPaused": isPaused,
            "sessionType": sessionType?.rawValue ?? "",
            "sessionStartTime": sessionStartTime?.timeIntervalSince1970 ?? 0,
            "pausedDuration": pausedDuration,
            "selectedGoalDuration": selectedGoal?.duration ?? 0
        ]
        
        session.sendMessage(message, replyHandler: nil) { error in
            print("❌ Failed to send session update: \(error.localizedDescription)")
        }
    }
    
    private func sendCompletedSessionToPhone(_ completedSession: CompletedSession) {
        guard let session = session, session.isReachable else { return }
        
        let message: [String: Any] = [
            "type": "completedSession",
            "sessionType": completedSession.sessionType.rawValue,
            "startTime": completedSession.startTime.timeIntervalSince1970,
            "endTime": completedSession.endTime.timeIntervalSince1970,
            "goalDuration": completedSession.goalDuration,
            "actualDuration": completedSession.actualDuration,
            "wasGoalMet": completedSession.wasGoalMet
        ]
        
        session.sendMessage(message, replyHandler: nil) { error in
            print("❌ Failed to send completed session: \(error.localizedDescription)")
        }
    }
}

// MARK: - WCSessionDelegate
extension WatchSessionManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("❌ WCSession activation failed: \(error.localizedDescription)")
        } else {
            print("✅ WCSession activated successfully")
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            if let messageType = message["type"] as? String {
                switch messageType {
                case "sessionSync":
                    // Handle session sync from iPhone
                    self.handleSessionSync(message)
                default:
                    break
                }
            }
        }
    }
    
    private func handleSessionSync(_ message: [String: Any]) {
        // Handle session synchronization from iPhone
        // This could be used to sync session state when iPhone app is opened
        print("📱 Received session sync from iPhone")
    }
}
