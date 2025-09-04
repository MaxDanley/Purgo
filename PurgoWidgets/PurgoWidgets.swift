//
//  PurgoWidgets.swift
//  PurgoWidgets
//
//  Created by Max Danley on 8/27/25.
//

import WidgetKit
import SwiftUI
import Intents

// MARK: - Session Type for Widgets
enum SessionType: String, CaseIterable {
    case sauna
    case cold
    
    var displayName: String {
        switch self {
        case .sauna: return "Sauna Session"
        case .cold: return "Cold Session"
        }
    }
}

// MARK: - Widget Timeline Provider
struct PurgoWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> PurgoWidgetEntry {
        PurgoWidgetEntry(date: Date(), sessionType: nil, isRunning: false, startTime: nil)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (PurgoWidgetEntry) -> ()) {
        let entry = PurgoWidgetEntry(date: Date(), sessionType: nil, isRunning: false, startTime: nil)
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<PurgoWidgetEntry>) -> ()) {
        let currentDate = Date()
        
        // Create entries for the next hour, updating every 15 seconds for real-time feel
        var entries: [PurgoWidgetEntry] = []
        
        for secondOffset in stride(from: 0, to: 3600, by: 15) { // Every 15 seconds for 1 hour
            let entryDate = Calendar.current.date(byAdding: .second, value: secondOffset, to: currentDate)!
            let entry = PurgoWidgetEntry(date: entryDate, sessionType: nil, isRunning: false, startTime: nil)
            entries.append(entry)
        }
        
        // Reload timeline every hour
        let nextReload = Calendar.current.date(byAdding: .hour, value: 1, to: currentDate)!
        let timeline = Timeline(entries: entries, policy: .after(nextReload))
        
        completion(timeline)
    }
}

struct PurgoWidgetEntry: TimelineEntry {
    let date: Date
    let sessionType: SessionType?
    let isRunning: Bool
    let startTime: Date?
}

// MARK: - Widget Views
struct PurgoWidgetView: View {
    var entry: PurgoWidgetProvider.Entry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .accessoryCircular:
            AccessoryCircularWidgetView(entry: entry)
        case .accessoryRectangular:
            AccessoryRectangularWidgetView(entry: entry)
        case .accessoryInline:
            AccessoryInlineWidgetView(entry: entry)
        case .systemSmall:
            SystemSmallWidgetView(entry: entry)
        case .systemMedium:
            SystemMediumWidgetView(entry: entry)
        case .systemLarge:
            SystemLargeWidgetView(entry: entry)
        default:
            Text("Unsupported")
        }
    }
}

struct AccessoryCircularWidgetView: View {
    let entry: PurgoWidgetEntry
    
    var body: some View {
        ZStack {
            if entry.isRunning, let startTime = entry.startTime {
                // Show timer
                VStack(spacing: 2) {
                    Image(systemName: entry.sessionType == .sauna ? "flame.fill" : "snowflake")
                        .font(.caption)
                        .foregroundColor(entry.sessionType == .sauna ? .orange : .blue)
                    
                    Text(timerText(from: startTime))
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .minimumScaleFactor(0.6)
                }
            } else {
                // Show infinity sign when idle
                Image(systemName: "infinity")
                    .font(.title3)
                    .foregroundColor(.white)
                    .opacity(0.8)
            }
        }
        .containerBackground(.clear, for: .widget)
    }
    
    private func timerText(from startTime: Date) -> String {
        let elapsed = max(0, entry.date.timeIntervalSince(startTime)) // Ensure non-negative
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct AccessoryRectangularWidgetView: View {
    let entry: PurgoWidgetEntry
    
    var body: some View {
        HStack(spacing: 8) {
            // Infinity sign or session icon
            if entry.isRunning {
                Image(systemName: entry.sessionType == .sauna ? "flame.fill" : "snowflake")
                    .foregroundColor(entry.sessionType == .sauna ? .orange : .blue)
                    .font(.title2)
            } else {
                Image(systemName: "infinity")
                    .font(.caption)
                    .foregroundColor(.white)
                    .opacity(0.8)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                if entry.isRunning, let startTime = entry.startTime {
                    Text(entry.sessionType?.displayName ?? "Session")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Text(timerText(from: startTime))
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(.semibold)
                } else {
                    Text("Purgo")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Text("Ready for session")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .containerBackground(.clear, for: .widget)
    }
    
    private func timerText(from startTime: Date) -> String {
        let elapsed = entry.date.timeIntervalSince(startTime)
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct AccessoryInlineWidgetView: View {
    let entry: PurgoWidgetEntry
    
    var body: some View {
        if entry.isRunning, let startTime = entry.startTime {
            HStack(spacing: 4) {
                Image(systemName: entry.sessionType == .sauna ? "flame.fill" : "snowflake")
                    .foregroundColor(entry.sessionType == .sauna ? .orange : .blue)
                
                Text(timerText(from: startTime))
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.semibold)
            }
        } else {
            HStack {
                Image(systemName: "infinity")
                    .font(.caption2)
                    .frame(width: 16, height: 16)
                Text("Purgo")
                    .font(.caption2)
                    .fontWeight(.medium)
            }
        }
    }
    
    private func timerText(from startTime: Date) -> String {
        let elapsed = entry.date.timeIntervalSince(startTime)
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct SystemSmallWidgetView: View {
    let entry: PurgoWidgetEntry
    
    var body: some View {
        VStack(spacing: 12) {
                // App title
                Text("Purgo")
                    .font(.headline)
                    .foregroundColor(.white)
                    .fontWeight(.bold)
                
                // Large infinity sign
                Image(systemName: "infinity")
                    .font(.system(size: 30, weight: .light))
                    .foregroundColor(.white)
                    .opacity(entry.isRunning ? 1.0 : 0.8)
                    .scaleEffect(entry.isRunning ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: entry.isRunning)
                
                // Timer or status
                if entry.isRunning, let startTime = entry.startTime {
                    VStack(spacing: 2) {
                        Text(entry.sessionType?.displayName ?? "Session")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                        
                        Text(timerText(from: startTime))
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                } else {
                    Text("Ready")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
        }
        .padding()
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color.black, Color.gray.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private func timerText(from startTime: Date) -> String {
        let elapsed = entry.date.timeIntervalSince(startTime)
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct SystemMediumWidgetView: View {
    let entry: PurgoWidgetEntry
    
         var body: some View {
         HStack(spacing: 20) {
                // Left side - Infinity sign
                VStack {
                    Text("Purgo")
                        .font(.title2)
                        .foregroundColor(.white)
                        .fontWeight(.bold)
                    
                    Image(systemName: "infinity")
                        .font(.system(size: 40, weight: .light))
                        .foregroundColor(.white)
                        .opacity(entry.isRunning ? 1.0 : 0.8)
                        .scaleEffect(entry.isRunning ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: entry.isRunning)
                }
                
                Spacer()
                
                // Right side - Session info
                VStack(alignment: .trailing, spacing: 8) {
                    if entry.isRunning, let startTime = entry.startTime {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(entry.sessionType?.displayName ?? "Session")
                                .font(.headline)
                                .foregroundColor(.white)
                                .fontWeight(.semibold)
                            
                            Text("In Progress")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Elapsed Time")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.7))
                                .textCase(.uppercase)
                            
                            Text(timerText(from: startTime))
                                .font(.system(size: 24, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                    } else {
                        Text("Ready for Session")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.trailing)
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                                            HStack {
                    Image(systemName: "infinity")
                        .font(.caption2)
                        .frame(width: 12, height: 12)
                    Text("Sauna")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                                                          HStack {
                                  Image(systemName: "infinity")
                                      .font(.caption2)
                                      .frame(width: 12, height: 12)
                                  Text("Cold Tub")
                                      .font(.caption)
                                      .foregroundColor(.cyan)
                              }
                                             }
                 }
             }
         }
         .padding()
         .containerBackground(for: .widget) {
             LinearGradient(
                 colors: [Color.black, Color.gray.opacity(0.3)],
                 startPoint: .topLeading,
                 endPoint: .bottomTrailing
             )
         }
     }
     
     private func timerText(from startTime: Date) -> String {
         let elapsed = entry.date.timeIntervalSince(startTime)
         let minutes = Int(elapsed) / 60
         let seconds = Int(elapsed) % 60
         return String(format: "%02d:%02d", minutes, seconds)
     }
 }
 
 struct SystemLargeWidgetView: View {
    let entry: PurgoWidgetEntry
    
         var body: some View {
         VStack(spacing: 20) {
                // Header
                HStack {
                    Text("Purgo")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    if entry.isRunning {
                        Text("🔴 LIVE")
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.2))
                            .cornerRadius(8)
                    }
                }
                
                // Large infinity sign
                Image(systemName: "infinity")
                    .font(.system(size: 60, weight: .light))
                    .foregroundColor(.white)
                    .opacity(entry.isRunning ? 1.0 : 0.8)
                    .scaleEffect(entry.isRunning ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: entry.isRunning)
                
                // Session info
                if entry.isRunning, let startTime = entry.startTime {
                    VStack(spacing: 8) {
                        Text(entry.sessionType?.displayName ?? "Session")
                            .font(.title)
                            .foregroundColor(.white)
                            .fontWeight(.semibold)
                        
                        Text("Session in Progress")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        
                        Text(timerText(from: startTime))
                            .font(.system(size: 32, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                } else {
                    VStack(spacing: 8) {
                        Text("Ready for Session")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.8))
                        
                        HStack(spacing: 20) {
                            HStack {
                                Image(systemName: "infinity")
                                    .font(.headline)
                                    .frame(width: 20, height: 20)
                                Text("Sauna")
                            }
                            .foregroundColor(.orange)
                            
                            HStack {
                                Image(systemName: "infinity")
                                    .font(.headline)
                                    .frame(width: 20, height: 20)
                                Text("Cold Tub")
                            }
                            .foregroundColor(.cyan)
                        }
                        .font(.headline)
                                     }
             }
         }
         .padding()
         .containerBackground(for: .widget) {
             LinearGradient(
                 colors: [Color.black, Color.gray.opacity(0.3)],
                 startPoint: .topLeading,
                 endPoint: .bottomTrailing
             )
         }
     }
     
     private func timerText(from startTime: Date) -> String {
         let elapsed = entry.date.timeIntervalSince(startTime)
         let minutes = Int(elapsed) / 60
         let seconds = Int(elapsed) % 60
         return String(format: "%02d:%02d", minutes, seconds)
     }
 }
 
 

// MARK: - Widget Configuration
struct PurgoWidget: Widget {
    let kind: String = "PurgoWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PurgoWidgetProvider()) { entry in
            PurgoWidgetView(entry: entry)
        }
        .configurationDisplayName("Purgo Timer")
        .description("Track your sauna and cold sessions")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .systemSmall, .systemMedium, .systemLarge])
    }
}

#Preview(as: .systemSmall) {
    PurgoWidget()
} timeline: {
    PurgoWidgetEntry(date: Date(), sessionType: .sauna, isRunning: true, startTime: Date())
}

#Preview(as: .systemMedium) {
    PurgoWidget()
} timeline: {
    PurgoWidgetEntry(date: Date(), sessionType: nil, isRunning: false, startTime: nil)
}

#Preview(as: .accessoryCircular) {
    PurgoWidget()
} timeline: {
    PurgoWidgetEntry(date: Date(), sessionType: .cold, isRunning: true, startTime: Date())
}
