//
//  PurgoApp.swift
//  Purgo
//
//  Created by Max Danley on 8/27/25.
//

import SwiftUI
import FirebaseCore
import FirebaseMessaging
import GoogleSignIn
import AuthenticationServices
import UserNotifications
#if canImport(ActivityKit)
import ActivityKit
#endif

@main
struct PurgoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
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

// MARK: - App Delegate for FCM
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // Set FCM messaging delegate
        Messaging.messaging().delegate = self
        
        // Set UNUserNotificationCenter delegate
        UNUserNotificationCenter.current().delegate = self
        
        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            print("📱 Notification permission granted: \(granted)")
            if let error = error {
                print("❌ Notification permission error: \(error)")
            }
        }
        
        // Register for remote notifications
        application.registerForRemoteNotifications()
        
        return true
    }
    
    // MARK: - Remote Notifications
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("📱 APNs device token received")
        Messaging.messaging().apnsToken = deviceToken
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ Failed to register for remote notifications: \(error)")
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler([.alert, .badge, .sound])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        // Handle notification tap
        if let notificationType = userInfo["type"] as? String {
            switch notificationType {
            case "friend_request":
                // Navigate to friends tab
                print("📱 Opening app to friends tab for friend request")
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: NSNotification.Name("NavigateToFriends"), object: nil)
                }
            case "leaderboard_ranking":
                // Navigate to leaderboard
                print("📱 Opening app to leaderboard for ranking")
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: NSNotification.Name("NavigateToLeaderboard"), object: nil)
                }
            default:
                break
            }
        }
        
        completionHandler()
    }
    
    // MARK: - MessagingDelegate
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("📱 FCM registration token received")
        
        if let token = fcmToken {
            print("🔑 FCM Token: \(token)")
            // Save FCM token to Firebase for the current user
            Task {
                await FirebaseManager.shared.updateFCMToken(token)
            }
        }
    }
}
