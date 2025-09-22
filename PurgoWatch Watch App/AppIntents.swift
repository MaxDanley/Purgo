//
//  AppIntents.swift
//  PurgoWatch
//
//  Created by Max Danley on 8/27/25.
//

import Foundation
import AppIntents
import SwiftUI

// MARK: - Start Sauna Session Intent
@available(watchOS 10.0, *)
struct StartSaunaSessionIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Sauna Session"
    static var description = IntentDescription("Start a sauna session with your default goal")
    
    func perform() async throws -> some IntentResult {
        // This will be handled by the watch app when launched
        return .result()
    }
}

// MARK: - Start Cold Tub Session Intent
@available(watchOS 10.0, *)
struct StartColdTubSessionIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Cold Tub Session"
    static var description = IntentDescription("Start a cold tub session with your default goal")
    
    func perform() async throws -> some IntentResult {
        // This will be handled by the watch app when launched
        return .result()
    }
}

// MARK: - Quick Start Sauna Intent
@available(watchOS 10.0, *)
struct QuickStartSaunaIntent: AppIntent {
    static var title: LocalizedStringResource = "Quick Sauna"
    static var description = IntentDescription("Start a 10-minute sauna session")
    
    func perform() async throws -> some IntentResult {
        // This will be handled by the watch app when launched
        return .result()
    }
}

// MARK: - Quick Start Cold Intent
@available(watchOS 10.0, *)
struct QuickStartColdIntent: AppIntent {
    static var title: LocalizedStringResource = "Quick Cold"
    static var description = IntentDescription("Start a 3-minute cold tub session")
    
    func perform() async throws -> some IntentResult {
        // This will be handled by the watch app when launched
        return .result()
    }
}

// MARK: - App Intent Provider
@available(watchOS 10.0, *)
struct PurgoAppIntentProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartSaunaSessionIntent(),
            phrases: [
                "Start sauna session in \(.applicationName)",
                "Begin sauna in \(.applicationName)",
                "Start sauna in \(.applicationName)"
            ],
            shortTitle: "Start Sauna",
            systemImageName: "flame.fill"
        )
        
        AppShortcut(
            intent: StartColdTubSessionIntent(),
            phrases: [
                "Start cold tub session in \(.applicationName)",
                "Begin cold tub in \(.applicationName)",
                "Start cold tub in \(.applicationName)"
            ],
            shortTitle: "Start Cold Tub",
            systemImageName: "snowflake"
        )
        
        AppShortcut(
            intent: QuickStartSaunaIntent(),
            phrases: [
                "Quick sauna in \(.applicationName)",
                "10 minute sauna in \(.applicationName)"
            ],
            shortTitle: "Quick Sauna",
            systemImageName: "flame"
        )
        
        AppShortcut(
            intent: QuickStartColdIntent(),
            phrases: [
                "Quick cold in \(.applicationName)",
                "3 minute cold in \(.applicationName)"
            ],
            shortTitle: "Quick Cold",
            systemImageName: "snowflake"
        )
    }
}
