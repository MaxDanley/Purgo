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
        PurgoWidgets()
        PurgoWidgetsControl()
        PurgoWidgetsLiveActivity()
    }
}
