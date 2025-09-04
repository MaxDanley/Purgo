//
//  PurgoWidgetsBundle.swift
//  PurgoWidgets
//
//  Created by Max Danley on 8/27/25.
//

import WidgetKit
import SwiftUI

@main
struct PurgoWidgetsBundle: WidgetBundle {
    var body: some Widget {
        PurgoWidget() // Our custom lock screen widget
        
        #if canImport(ActivityKit)
        if #available(iOS 16.1, *) {
            PurgoTimerLiveActivity() // Our custom Live Activity
        }
        #endif
    }
}
