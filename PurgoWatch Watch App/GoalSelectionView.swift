//
//  GoalSelectionView.swift
//  PurgoWatch
//
//  Created by Max Danley on 8/27/25.
//

import SwiftUI

struct GoalSelectionView: View {
    @EnvironmentObject var watchSessionManager: WatchSessionManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedGoal: SessionGoal?
    @State private var sessionTypeToStart: SessionType = .sauna
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Header with Cancel Button
                    HStack {
                        Button("Cancel") {
                            dismiss()
                        }
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    
                    // Header
                    VStack(spacing: 6) {
                        Text("Choose Goal")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("How long?")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    // Goals List
                    VStack(spacing: 8) {
                        ForEach(SessionGoal.goals(for: sessionTypeToStart), id: \.duration) { goal in
                            GoalButton(
                                goal: goal,
                                isSelected: selectedGoal?.duration == goal.duration,
                                sessionType: sessionTypeToStart
                            ) {
                                selectedGoal = goal
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    
                    // Start Button
                    if let selected = selectedGoal {
                        Button("Start Session") {
                            watchSessionManager.selectGoalAndStart(selected, type: sessionTypeToStart)
                            dismiss()
                        }
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(startButtonGradient())
                        .cornerRadius(12)
                        .padding(.horizontal, 16)
                    }
                    
                    // Bottom padding for scroll
                    Spacer()
                        .frame(height: 20)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .onAppear {
            sessionTypeToStart = watchSessionManager.pendingSessionType ?? .sauna
            selectedGoal = SessionGoal.defaultGoal(for: sessionTypeToStart)
        }
    }
    
    private func startButtonGradient() -> LinearGradient {
        LinearGradient(
            colors: sessionTypeToStart == .sauna ? [.orange, .red] : [.cyan, .blue],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

struct GoalButton: View {
    let goal: SessionGoal
    let isSelected: Bool
    let sessionType: SessionType
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.displayName)
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                    
                    Text("Goal Duration")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(goalButtonBackground())
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func goalButtonBackground() -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(isSelected ? Color.white.opacity(0.2) : Color.white.opacity(0.05))
            .stroke(isSelected ? Color.white.opacity(0.6) : Color.clear, lineWidth: 1)
    }
}

#Preview {
    GoalSelectionView()
        .environmentObject(WatchSessionManager())
}
