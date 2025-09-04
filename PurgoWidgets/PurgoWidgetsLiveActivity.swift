//
//  PurgoWidgetsLiveActivity.swift
//  PurgoWidgets
//
//  Created by Max Danley on 8/27/25.
//

#if canImport(ActivityKit)
import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Activity Attributes (Must match the main app)
@available(iOS 16.1, *)
public struct PurgoTimerAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public let sessionType: String
        public let startTime: Date
        public let isRunning: Bool
        
        public init(sessionType: String, startTime: Date, isRunning: Bool) {
            self.sessionType = sessionType
            self.startTime = startTime
            self.isRunning = isRunning
        }
    }
    
    public let sessionName: String
    
    public init(sessionName: String) {
        self.sessionName = sessionName
    }
}

// MARK: - Live Activity Widget View
@available(iOS 16.1, *)
struct PurgoTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PurgoTimerAttributes.self) { context in
            // Lock screen/banner UI
            PurgoTimerLiveActivityView(context: context)
                .activitySystemActionForegroundColor(.white)
                .activityBackgroundTint(.black.opacity(0.8))
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here
                DynamicIslandExpandedRegion(.leading) {
                    HStack {
                        Image(systemName: context.state.sessionType == "sauna" ? "flame.fill" : "snowflake")
                            .foregroundColor(context.state.sessionType == "sauna" ? .orange : .blue)
                        Text(context.attributes.sessionName)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.startTime, style: .timer)
                        .font(.system(.title3, design: .monospaced))
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.trailing)
                        .contentTransition(.numericText())
                }
            } compactLeading: {
                Image(systemName: context.state.sessionType == "sauna" ? "flame.fill" : "snowflake")
                    .foregroundColor(context.state.sessionType == "sauna" ? .orange : .blue)
            } compactTrailing: {
                Text(context.state.startTime, style: .timer)
                    .font(.system(.caption2, design: .monospaced))
                    .fontWeight(.medium)
                    .contentTransition(.numericText())
            } minimal: {
                Image(systemName: context.state.sessionType == "sauna" ? "flame.fill" : "snowflake")
                    .foregroundColor(context.state.sessionType == "sauna" ? .orange : .blue)
            }
        }
    }
    
    private func timerText(from startTime: Date) -> String {
        let elapsed = Date().timeIntervalSince(startTime)
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

@available(iOS 16.1, *)
struct PurgoTimerLiveActivityView: View {
    let context: ActivityViewContext<PurgoTimerAttributes>
    
    var body: some View {
        HStack(spacing: 16) {
            // Session icon
            ZStack {
                Circle()
                    .fill(context.state.sessionType == "sauna" ? 
                          LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing) :
                          LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 44, height: 44)
                
                Image(systemName: context.state.sessionType == "sauna" ? "flame.fill" : "snowflake")
                    .foregroundColor(.white)
                    .font(.title3)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(context.attributes.sessionName)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("Session in progress")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(context.state.startTime, style: .timer)
                    .font(.system(.title2, design: .monospaced))
                    .fontWeight(.bold)
                    .contentTransition(.numericText())
                
                Text("elapsed")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(UIColor.systemBackground))
    }
    
    private func timerText(from startTime: Date) -> String {
        let now = Date()
        let elapsed = max(0, now.timeIntervalSince(startTime)) // Ensure non-negative
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        let timeString = String(format: "%02d:%02d", minutes, seconds)
        
        // Debug logging
        print("⏱️ Timer calculation:")
        print("   Now: \(now)")
        print("   Start: \(startTime)")
        print("   Elapsed: \(elapsed) seconds")
        print("   Display: \(timeString)")
        
        return timeString
    }
}

@available(iOS 16.1, *)
#Preview("Live Activity", as: .content, using: PurgoTimerAttributes(sessionName: "Sauna Session")) {
    PurgoTimerLiveActivity()
} contentStates: {
    PurgoTimerAttributes.ContentState(sessionType: "sauna", startTime: Date(), isRunning: true)
}

#endif

