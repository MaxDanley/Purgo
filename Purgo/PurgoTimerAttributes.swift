//
//  PurgoTimerAttributes.swift
//  Purgo
//
//  Created by Max Danley on 8/27/25.
//

#if canImport(ActivityKit)
import ActivityKit
import Foundation

// MARK: - Activity Attributes (Shared between main app and widget extension)
@available(iOS 16.1, *)
public struct PurgoTimerAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public let sessionType: String
        public let startTime: Date
        public let isRunning: Bool
        
        public init(sessionType: String, startTime: Date, isRunning: Bool) {
            self.sessionType = sessionType
            self.startTime = startTime
            self.isRunning = isRunning
            
            // Debug logging
            print("📄 ContentState created:")
            print("   Session: \(sessionType)")
            print("   Start: \(startTime)")
            print("   Running: \(isRunning)")
        }
    }
    
    public let sessionName: String
    
    public init(sessionName: String) {
        self.sessionName = sessionName
        print("📝 PurgoTimerAttributes created for: \(sessionName)")
    }
}

#endif 