//
//  ContentView.swift
//  PurgoWatch
//
//  Created by Max Danley on 8/27/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var watchSessionManager: WatchSessionManager
    @State private var showingGoalSelection = false
    
    var body: some View {
        NavigationView {
            if watchSessionManager.isRunning || watchSessionManager.isPaused {
                ActiveSessionView()
            } else {
                SessionSelectionView(showingGoalSelection: $showingGoalSelection)
            }
        }
        .sheet(isPresented: $showingGoalSelection) {
            GoalSelectionView()
        }
        .sheet(isPresented: $watchSessionManager.showingSessionComplete) {
            SessionCompleteView()
        }
    }
}

struct SessionSelectionView: View {
    @EnvironmentObject var watchSessionManager: WatchSessionManager
    @Binding var showingGoalSelection: Bool
    @State private var animateSauna = false
    @State private var animateCold = false
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            // Sauna Button
            WatchSessionButton(
                title: "START SAUNA",
                glowColor: .orange,
                fadeDirection: .topToBottom,
                action: {
                    withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                        animateSauna = true
                        watchSessionManager.pendingSessionType = .sauna
                        showingGoalSelection = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            animateSauna = false
                        }
                    }
                }
            )
            .frame(height: 50)
            
            // Cold Tub Button
            WatchSessionButton(
                title: "START COLD",
                glowColor: .cyan,
                fadeDirection: .bottomToTop,
                action: {
                    withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                        animateCold = true
                        watchSessionManager.pendingSessionType = .cold
                        showingGoalSelection = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            animateCold = false
                        }
                    }
                }
            )
            .frame(height: 50)
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
        .navigationBarHidden(true)
    }
}

struct ActiveSessionView: View {
    @EnvironmentObject var watchSessionManager: WatchSessionManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Session Type and Status
                HStack {
                    Text(watchSessionManager.sessionType?.displayName ?? "")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                        .textCase(.uppercase)
                        .tracking(1)
                    
                    if watchSessionManager.isPaused {
                        Text("PAUSED")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.yellow.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
                .padding(.top, 8)
                
                // Timer Display
                Text(watchSessionManager.timeString)
                    .font(.system(size: 28, weight: .light, design: .monospaced))
                    .foregroundColor(.white)
                
                // Goal Progress
                if let goal = watchSessionManager.selectedGoal {
                    VStack(spacing: 4) {
                        HStack {
                            Text("Goal: \(goal.displayName)")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.5))
                            
                            Spacer()
                            
                            if watchSessionManager.isGoalMet {
                                Text("🎉 Goal Met!")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                            } else {
                                Text("\(watchSessionManager.timeRemainingString) left")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                        
                        // Progress bar
                        ProgressView(value: watchSessionManager.progressPercentage)
                            .progressViewStyle(LinearProgressViewStyle(tint: watchSessionManager.sessionType == .sauna ? .orange : .cyan))
                            .scaleEffect(x: 1, y: 0.5)
                    }
                    .padding(.horizontal, 20)
                }
                
                // Infinity Icon with progress ring
                InfinityIconView(
                    animateSauna: .constant(false),
                    animateCold: .constant(false),
                    sessionType: watchSessionManager.sessionType,
                    isRunning: watchSessionManager.isRunning,
                    progressPercentage: watchSessionManager.progressPercentage
                )
                .frame(width: 60, height: 60)
                .scaleEffect(watchSessionManager.isRunning ? 1.0 : 0.9)
                .animation(.spring(response: 0.8, dampingFraction: 0.6), value: watchSessionManager.isRunning)
                
                // Control Buttons
                HStack(spacing: 12) {
                    // Pause/Resume Button
                    WatchSessionButton(
                        title: watchSessionManager.isPaused ? "RESUME" : "PAUSE",
                        glowColor: .white,
                        fadeDirection: .topToBottom,
                        action: {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                if watchSessionManager.isPaused {
                                    watchSessionManager.resumeSession()
                                } else {
                                    watchSessionManager.pauseSession()
                                }
                            }
                        }
                    )
                    .frame(height: 40)
                    
                    // End Session Button
                    WatchSessionButton(
                        title: "END SESSION",
                        glowColor: .red,
                        fadeDirection: .bottomToTop,
                        action: {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                watchSessionManager.endSession()
                            }
                        }
                    )
                    .frame(height: 40)
                }
                .padding(.horizontal, 16)
                
                // Bottom padding for scroll
                Spacer()
                    .frame(height: 20)
            }
            .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
        .navigationBarHidden(true)
    }
}

#Preview {
    ContentView()
        .environmentObject(WatchSessionManager())
}
