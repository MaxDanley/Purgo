//
//  PurgoApp.swift
//  Purgo
//
//  Created by Max Danley on 8/27/25.
//

import SwiftUI
import FirebaseCore
import GoogleSignIn
#if canImport(ActivityKit)
import ActivityKit
#endif

@main
struct PurgoApp: App {
    init() {
        FirebaseManager.configureFirebase()
        // Initialize the singleton to start auth state listening immediately
        _ = FirebaseManager.shared
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    // App is coming back to foreground - timers will automatically recalculate based on Date
                    print("🔄 App entering foreground - timers will auto-sync")
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    // App is going to background - time-based calculation ensures accuracy
                    print("📱 App entering background - time calculation continues")
                }
                .onOpenURL { url in
                    // Handle Google Sign-In callback
                    print("📱 Handling URL: \(url)")
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
