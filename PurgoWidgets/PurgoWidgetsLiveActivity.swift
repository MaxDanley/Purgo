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
            // Lock screen/banner UI - this should NOT appear in Dynamic Island
            PurgoTimerLiveActivityView(context: context)
                .activitySystemActionForegroundColor(.white)
                .activityBackgroundTint(.black.opacity(0.8))
        } dynamicIsland: { context in
            DynamicIsland {
                // Minimal expanded region (required for generic parameter inference)
                DynamicIslandExpandedRegion(.leading) {
                    EmptyView()
                }
                
            } compactLeading: {
                // Small colored dot for session type
                Circle()
                    .fill(context.state.sessionType == "sauna" ? Color.orange : Color.cyan)
                    .frame(width: 8, height: 8)
                
            } compactTrailing: {
                // Timer with seconds - compact format
                Text(context.state.startTime, style: .timer)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(context.state.sessionType == "sauna" ? .orange : .cyan)
                    .contentTransition(.numericText())
                
            } minimal: {
                // Single small dot
                Circle()
                    .fill(context.state.sessionType == "sauna" ? Color.orange : Color.cyan)
                    .frame(width: 6, height: 6)
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
        // This is for lock screen/banner notifications only - NOT Dynamic Island
        HStack(spacing: 12) {
            // Session icon - smaller for banner
            ZStack {
                Circle()
                    .fill(context.state.sessionType == "sauna" ? 
                          LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing) :
                          LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 36, height: 36)
                
                Image(systemName: context.state.sessionType == "sauna" ? "flame.fill" : "snowflake")
                    .foregroundColor(.white)
                    .font(.system(size: 16))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(context.attributes.sessionName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("Session in progress")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(context.state.startTime, style: .timer)
                    .font(.system(.headline, design: .monospaced))
                    .fontWeight(.semibold)
                    .contentTransition(.numericText())
                
                Text("elapsed")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
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

