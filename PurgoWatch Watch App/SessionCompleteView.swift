//
//  SessionCompleteView.swift
//  PurgoWatch
//
//  Created by Max Danley on 8/27/25.
//

import SwiftUI

struct SessionCompleteView: View {
    @EnvironmentObject var watchSessionManager: WatchSessionManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Success Indicator
                ZStack {
                    Circle()
                        .fill(watchSessionManager.lastCompletedSession?.wasGoalMet == true ? 
                              Color.green.opacity(0.2) : Color.white.opacity(0.2))
                        .frame(width: 60, height: 60)
                    
                    Image("InfinityIcon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 35, height: 35)
                }
                
                // Title
                VStack(spacing: 4) {
                    Text(watchSessionManager.lastCompletedSession?.wasGoalMet == true ? 
                         "🎉 Goal Achieved!" : "💪 Great Session!")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("\(watchSessionManager.lastCompletedSession?.sessionType.displayName ?? "Session") Complete")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                // Session Details
                if let session = watchSessionManager.lastCompletedSession {
                    VStack(spacing: 8) {
                        StatRow(title: "Duration", value: session.durationString)
                        if session.goalDuration > 0 {
                            StatRow(title: "Goal", value: session.goalString)
                        }
                        StatRow(title: "Type", value: session.sessionType.displayName)
                    }
                    .padding(.horizontal, 16)
                }
                
                // Continue Button
                Button("Continue") {
                    dismiss()
                }
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.2))
                .cornerRadius(12)
                .padding(.horizontal, 16)
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.ignoresSafeArea())
            .navigationBarHidden(true)
        }
    }
}

struct StatRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }
}

#Preview {
    SessionCompleteView()
        .environmentObject(WatchSessionManager())
}
