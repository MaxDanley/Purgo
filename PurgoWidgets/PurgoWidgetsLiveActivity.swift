//
//  PurgoWidgetsLiveActivity.swift
//  PurgoWidgets
//
//  Created by Max Danley on 8/27/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct PurgoWidgetsAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct PurgoWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PurgoWidgetsAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension PurgoWidgetsAttributes {
    fileprivate static var preview: PurgoWidgetsAttributes {
        PurgoWidgetsAttributes(name: "World")
    }
}

extension PurgoWidgetsAttributes.ContentState {
    fileprivate static var smiley: PurgoWidgetsAttributes.ContentState {
        PurgoWidgetsAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: PurgoWidgetsAttributes.ContentState {
         PurgoWidgetsAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: PurgoWidgetsAttributes.preview) {
   PurgoWidgetsLiveActivity()
} contentStates: {
    PurgoWidgetsAttributes.ContentState.smiley
    PurgoWidgetsAttributes.ContentState.starEyes
}
