//
//  PermissionManager.swift
//  Purgo
//
//  Created by Max Danley on 8/27/25.
//

import Foundation
import UserNotifications
import AppTrackingTransparency
import UIKit

class PermissionManager: ObservableObject {
    static let shared = PermissionManager()
    
    @Published var notificationPermissionGranted: Bool = false
    @Published var trackingPermissionGranted: Bool = false
    @Published var permissionsCompleted: Bool = false
    
    private init() {
        checkNotificationPermission()
        checkTrackingPermission()
    }
    
    // MARK: - Permission Requests
    
    func requestAllPermissions() {
        print("🔐 Starting permission request sequence...")
        
        // First request notification permission
        requestNotificationPermission { [weak self] notificationGranted in
            DispatchQueue.main.async {
                self?.notificationPermissionGranted = notificationGranted
                print("📱 Notification permission completed: \(notificationGranted)")
                
                // Request tracking permission with proper timing (back-to-back)
                print("🎯 About to request tracking permission...")
                
                // Use a longer delay to ensure notification permission is fully processed
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    print("🎯 Now requesting tracking permission (1 second delay)...")
                    self?.requestTrackingPermission { trackingGranted in
                        DispatchQueue.main.async {
                            self?.trackingPermissionGranted = trackingGranted
                            self?.permissionsCompleted = true
                            print("✅ All permissions completed - Notifications: \(notificationGranted), Tracking: \(trackingGranted)")
                        }
                    }
                }
            }
        }
    }
    
    private func requestNotificationPermission(completion: @escaping (Bool) -> Void) {
        print("📱 Requesting notification permission...")
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            print("📱 Notification permission result: \(granted)")
            if let error = error {
                print("❌ Notification permission error: \(error)")
            }
            
            // Register for remote notifications if permission granted
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
            
            completion(granted)
        }
    }
    
    private func requestTrackingPermission(completion: @escaping (Bool) -> Void) {
        print("🎯 Requesting tracking permission...")
        
        if #available(iOS 14.5, *) {
            print("🎯 iOS 14.5+ detected, requesting tracking authorization...")
            let currentStatus = ATTrackingManager.trackingAuthorizationStatus
            print("🎯 Current tracking status: \(currentStatus.rawValue)")
            
            // Check if we can actually request tracking permission
            if currentStatus == .notDetermined {
                print("🎯 Status is notDetermined, requesting authorization...")
                print("🎯 Now calling ATTrackingManager.requestTrackingAuthorization...")
                ATTrackingManager.requestTrackingAuthorization { status in
                    let granted = (status == .authorized)
                    print("🎯 Tracking permission result: \(granted) (status: \(status.rawValue))")
                    print("🎯 Status meanings: 0=notDetermined, 1=restricted, 2=denied, 3=authorized")
                    
                    if status == .notDetermined {
                        print("🎯 WARNING: Status is still notDetermined - tracking prompt did not appear!")
                        print("🎯 This means the system prevented the prompt from showing")
                    }
                    
                    completion(granted)
                }
            } else {
                print("🎯 Status is already determined (\(currentStatus.rawValue)), not requesting again")
                let granted = (currentStatus == .authorized)
                completion(granted)
            }
        } else {
            // For iOS versions below 14.5, tracking is allowed by default
            print("🎯 Tracking permission granted (iOS < 14.5)")
            completion(true)
        }
    }
    
    // MARK: - Permission Status Checks
    
    private func checkNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.notificationPermissionGranted = (settings.authorizationStatus == .authorized)
            }
        }
    }
    
    private func checkTrackingPermission() {
        if #available(iOS 14.5, *) {
            let status = ATTrackingManager.trackingAuthorizationStatus
            trackingPermissionGranted = (status == .authorized)
        } else {
            trackingPermissionGranted = true
        }
    }
    
    // MARK: - Public Methods
    
    var shouldRequestPermissions: Bool {
        return !permissionsCompleted && (!notificationPermissionGranted || !trackingPermissionGranted)
    }
    
    var canTrack: Bool {
        return trackingPermissionGranted
    }
    
    var canSendNotifications: Bool {
        return notificationPermissionGranted
    }
}
