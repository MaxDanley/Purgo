//
//  TrackingManager.swift
//  Purgo
//
//  Created by Max Danley on 8/27/25.
//

import Foundation
import AppTrackingTransparency
import AdSupport

class TrackingManager: ObservableObject {
    static let shared = TrackingManager()
    
    @Published var trackingAuthorizationStatus: ATTrackingManager.AuthorizationStatus = .notDetermined
    @Published var isTrackingEnabled: Bool = false
    
    private init() {
        updateTrackingStatus()
    }
    
    func requestTrackingPermission() {
        // Only request permission on iOS 14.5+
        if #available(iOS 14.5, *) {
            ATTrackingManager.requestTrackingAuthorization { [weak self] status in
                DispatchQueue.main.async {
                    self?.trackingAuthorizationStatus = status
                    self?.isTrackingEnabled = (status == .authorized)
                    self?.updateTrackingStatus()
                }
            }
        } else {
            // For iOS versions below 14.5, tracking is allowed by default
            trackingAuthorizationStatus = .authorized
            isTrackingEnabled = true
        }
    }
    
    private func updateTrackingStatus() {
        if #available(iOS 14.5, *) {
            trackingAuthorizationStatus = ATTrackingManager.trackingAuthorizationStatus
            isTrackingEnabled = (trackingAuthorizationStatus == .authorized)
        } else {
            trackingAuthorizationStatus = .authorized
            isTrackingEnabled = true
        }
    }
    
    var advertisingIdentifier: String? {
        guard isTrackingEnabled else { return nil }
        return ASIdentifierManager.shared().advertisingIdentifier.uuidString
    }
    
    var canTrack: Bool {
        return isTrackingEnabled
    }
    
    func getTrackingStatusDescription() -> String {
        switch trackingAuthorizationStatus {
        case .notDetermined:
            return "Not Determined"
        case .restricted:
            return "Restricted"
        case .denied:
            return "Denied"
        case .authorized:
            return "Authorized"
        @unknown default:
            return "Unknown"
        }
    }
}
