//
//  WatchConnectivityManager.swift
//  Purgo
//
//  Created by Max Danley on 8/27/25.
//

import Foundation
import WatchConnectivity

// MARK: - Watch Connectivity Manager
class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()
    
    private var session: WCSession?
    private var sessionManager: SessionManager?
    
    override init() {
        super.init()
        setupWatchConnectivity()
    }
    
    func setSessionManager(_ manager: SessionManager) {
        self.sessionManager = manager
    }
    
    private func setupWatchConnectivity() {
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }
    
    // MARK: - Send Data to Watch
    func sendSessionUpdateToWatch() {
        guard let session = session, session.isReachable,
              let sessionManager = sessionManager else { return }
        
        let message: [String: Any] = [
            "type": "sessionSync",
            "isRunning": sessionManager.isRunning,
            "isPaused": sessionManager.isPaused,
            "sessionType": sessionManager.sessionType?.rawValue ?? "",
            "sessionStartTime": sessionManager.sessionStartTime?.timeIntervalSince1970 ?? 0,
            "pausedDuration": sessionManager.pausedDuration,
            "selectedGoalDuration": sessionManager.selectedGoal?.duration ?? 0
        ]
        
        session.sendMessage(message, replyHandler: nil) { error in
            print("❌ Failed to send session update to watch: \(error.localizedDescription)")
        }
    }
    
    func sendCompletedSessionToWatch(_ completedSession: CompletedSession) {
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
            print("❌ Failed to send completed session to watch: \(error.localizedDescription)")
        }
    }
}

// MARK: - WCSessionDelegate
extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("❌ WCSession activation failed: \(error.localizedDescription)")
        } else {
            print("✅ WCSession activated successfully")
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("📱 WCSession became inactive")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        print("📱 WCSession deactivated")
        // Reactivate the session
        session.activate()
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            if let messageType = message["type"] as? String {
                switch messageType {
                case "sessionUpdate":
                    self.handleSessionUpdateFromWatch(message)
                case "completedSession":
                    self.handleCompletedSessionFromWatch(message)
                default:
                    break
                }
            }
        }
    }
    
    private func handleSessionUpdateFromWatch(_ message: [String: Any]) {
        guard let sessionManager = sessionManager else { return }
        
        // Update session state from watch
        let isRunning = message["isRunning"] as? Bool ?? false
        let isPaused = message["isPaused"] as? Bool ?? false
        let sessionTypeString = message["sessionType"] as? String ?? ""
        let sessionStartTimeInterval = message["sessionStartTime"] as? TimeInterval ?? 0
        let pausedDuration = message["pausedDuration"] as? TimeInterval ?? 0
        let selectedGoalDuration = message["selectedGoalDuration"] as? TimeInterval ?? 0
        
        // Only update if the watch session is different from current
        if sessionManager.isRunning != isRunning || sessionManager.isPaused != isPaused {
            print("📱 Syncing session state from watch")
            
            if let sessionType = SessionType(rawValue: sessionTypeString) {
                sessionManager.sessionType = sessionType
            }
            
            if sessionStartTimeInterval > 0 {
                sessionManager.sessionStartTime = Date(timeIntervalSince1970: sessionStartTimeInterval)
            }
            
            sessionManager.pausedDuration = pausedDuration
            
            if selectedGoalDuration > 0 {
                // Find matching goal
                let allGoals = SessionGoal.saunaGoals + SessionGoal.coldGoals
                sessionManager.selectedGoal = allGoals.first { $0.duration == selectedGoalDuration }
            }
            
            sessionManager.isRunning = isRunning
            sessionManager.isPaused = isPaused
        }
    }
    
    private func handleCompletedSessionFromWatch(_ message: [String: Any]) {
        guard let sessionManager = sessionManager else { return }
        
        let sessionTypeString = message["sessionType"] as? String ?? ""
        let startTimeInterval = message["startTime"] as? TimeInterval ?? 0
        let endTimeInterval = message["endTime"] as? TimeInterval ?? 0
        let goalDuration = message["goalDuration"] as? TimeInterval ?? 0
        let actualDuration = message["actualDuration"] as? TimeInterval ?? 0
        let wasGoalMet = message["wasGoalMet"] as? Bool ?? false
        
        guard let sessionType = SessionType(rawValue: sessionTypeString),
              startTimeInterval > 0, endTimeInterval > 0 else { return }
        
        let startTime = Date(timeIntervalSince1970: startTimeInterval)
        let endTime = Date(timeIntervalSince1970: endTimeInterval)
        
        let completedSession = CompletedSession(
            sessionType: sessionType,
            startTime: startTime,
            endTime: endTime,
            goalDuration: goalDuration,
            actualDuration: actualDuration,
            wasGoalMet: wasGoalMet
        )
        
        print("📱 Received completed session from watch: \(sessionType.displayName) - \(completedSession.durationString)")
        
        // Add to session manager
        sessionManager.completedSessions.append(completedSession)
        sessionManager.lastCompletedSession = completedSession
        sessionManager.saveSessions()
        
        // Sync with Firebase
        Task {
            await sessionManager.firebaseManager?.updateUserStats(with: completedSession)
        }
    }
}

