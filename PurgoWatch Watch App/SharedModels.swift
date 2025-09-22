//
//  SharedModels.swift
//  PurgoWatch
//
//  Created by Max Danley on 8/27/25.
//

import Foundation

// MARK: - Session Models (Shared with main app)
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
