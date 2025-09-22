//
//  DeviceDetection.swift
//  Purgo
//
//  Created by Max Danley on 8/27/25.
//

import SwiftUI
import UIKit

struct DeviceDetection {
    static var isIPad: Bool {
        return UIDevice.current.userInterfaceIdiom == .pad
    }
    
    static var isIPhone: Bool {
        return UIDevice.current.userInterfaceIdiom == .phone
    }
    
    static var isRunningInCompatibilityMode: Bool {
        // Check if we're running on iPad but the app is iPhone-only
        return isIPad && !isUniversalApp
    }
    
    static var isUniversalApp: Bool {
        // Check if the app supports iPad natively
        guard let info = Bundle.main.infoDictionary,
              let deviceFamily = info["UIDeviceFamily"] as? [Int] else {
            return false
        }
        return deviceFamily.contains(2) // 2 = iPad
    }
}

// MARK: - View Modifier for iPad Compatibility
struct iPadCompatibilityModifier: ViewModifier {
    func body(content: Content) -> some View {
        if DeviceDetection.isRunningInCompatibilityMode {
            ScrollView {
                content
            }
        } else {
            content
        }
    }
}

extension View {
    func iPadCompatibility() -> some View {
        modifier(iPadCompatibilityModifier())
    }
}
