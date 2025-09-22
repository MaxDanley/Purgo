//
//  PurgoWatchApp.swift
//  PurgoWatch
//
//  Created by Max Danley on 8/27/25.
//

import SwiftUI

@main
struct PurgoWatchApp: App {
    @StateObject private var watchSessionManager = WatchSessionManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(watchSessionManager)
        }
    }
}
