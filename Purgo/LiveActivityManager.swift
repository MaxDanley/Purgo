//
//  LiveActivityManager.swift
//  Purgo
//
//  Created by Max Danley on 8/27/25.
//

#if canImport(ActivityKit)
import ActivityKit
#endif
import Foundation
import SwiftUI

// MARK: - Live Activity Manager
class LiveActivityManager: ObservableObject {
    #if canImport(ActivityKit)
    @available(iOS 16.1, *)
    @Published var currentActivity: Activity<PurgoTimerAttributes>?
    #endif
    
    func startLiveActivity(for sessionType: SessionType) {
        #if canImport(ActivityKit)
        if #available(iOS 16.1, *) {
            // Check if activities are enabled
            let authInfo = ActivityAuthorizationInfo()
            print("🔍 Live Activities authorization status: \(authInfo.areActivitiesEnabled)")
            
            guard authInfo.areActivitiesEnabled else {
                print("❌ Live Activities are not enabled. Go to Settings > Face ID & Passcode > Live Activities")
                return
            }
            
            // End any existing activity first
            if currentActivity != nil {
                print("🔄 Ending existing Live Activity...")
                endLiveActivity()
            }
            
            let attributes = PurgoTimerAttributes(sessionName: sessionType.displayName)
            let contentState = PurgoTimerAttributes.ContentState(
                sessionType: sessionType.rawValue,
                startTime: Date(),
                isRunning: true
            )
            
            print("🚀 Attempting to start Live Activity for: \(sessionType.displayName)")
            
            do {
                let activity = try Activity<PurgoTimerAttributes>.request(
                    attributes: attributes,
                    contentState: contentState,
                    pushType: nil
                )
                
                self.currentActivity = activity
                
                print("✅ Live Activity started successfully!")
                print("   Activity ID: \(activity.id)")
                print("   Activity state: \(activity.activityState)")
                print("   Attributes: \(activity.attributes)")
                print("   Content state: \(activity.contentState)")
            } catch {
                print("❌ Failed to start Live Activity")
                print("   Error: \(error.localizedDescription)")
                print("   Full error: \(error)")
                
                // Check specific error types
                if let activityError = error as NSError? {
                    print("   Error domain: \(activityError.domain)")
                    print("   Error code: \(activityError.code)")
                    print("   User info: \(activityError.userInfo)")
                }
            }
        } else {
            print("❌ Live Activities require iOS 16.1 or later")
        }
        #else
        print("❌ ActivityKit not available")
        #endif
    }
    
    func updateLiveActivity(sessionType: SessionType, startTime: Date) {
        // Live Activities are now self-updating based on timeline
        // No manual updates needed - they calculate time automatically
        print("ℹ️ Live Activity updates are now timeline-based, no manual update needed")
    }
    
    func endLiveActivity() {
        #if canImport(ActivityKit)
        if #available(iOS 16.1, *) {
            guard let activity = currentActivity else { return }
            
            let contentState = PurgoTimerAttributes.ContentState(
                sessionType: "",
                startTime: Date(),
                isRunning: false
            )
            
            Task {
                await activity.end(using: contentState, dismissalPolicy: .immediate)
                await MainActor.run {
                    self.currentActivity = nil
                }
            }
        }
        #endif
    }
}

 