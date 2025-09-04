//
//  ContentView.swift
//  Purgo
//
//  Created by Max Danley on 8/27/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var sessionManager = SessionManager()
    @StateObject private var liveActivityManager = LiveActivityManager()
    @ObservedObject private var firebaseManager = FirebaseManager.shared
    @State private var animateSauna = false
    @State private var animateCold = false
    @State private var selectedTab: AppTab = .timer
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Timer Tab
            TimerPageView(
                sessionManager: sessionManager,
                liveActivityManager: liveActivityManager,
                firebaseManager: firebaseManager,
                animateSauna: $animateSauna,
                animateCold: $animateCold
            )
            .tag(AppTab.timer)
            
            // Friends Tab
            FriendsPageView(firebaseManager: firebaseManager)
            .tag(AppTab.friends)
            
            // Sessions/Achievements Tab  
            AchievementsPageView(sessionManager: sessionManager, firebaseManager: firebaseManager)
            .tag(AppTab.achievements)
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        .background(Color.black.ignoresSafeArea())
        .overlay(
            // Custom tab bar at bottom
            CustomTabBar(selectedTab: $selectedTab)
            , alignment: .bottom
        )
        .sheet(isPresented: $sessionManager.showingGoalSelection) {
            GoalSelectionView(sessionManager: sessionManager)
        }
        .sheet(isPresented: $sessionManager.showingSessionStats) {
            SessionStatsView(sessionManager: sessionManager)
        }
        .onAppear {
            // Ensure FirebaseManager is connected to SessionManager
            sessionManager.setFirebaseManager(firebaseManager)
            
            // Check authentication state when app appears
            firebaseManager.checkAuthenticationState()
        }
    }
}

// MARK: - App Tabs
enum AppTab: String, CaseIterable {
    case timer
    case friends
    case achievements
    
    var title: String {
        switch self {
        case .timer: return "Timer"
        case .friends: return "Friends"
        case .achievements: return "Achievements"
        }
    }
    
    var icon: String {
        switch self {
        case .timer: return "infinity"
        case .friends: return "person.2.fill"
        case .achievements: return "trophy.fill"
        }
    }
}

// MARK: - Timer Page (Original Main Screen)
struct TimerPageView: View {
    @ObservedObject var sessionManager: SessionManager
    @ObservedObject var liveActivityManager: LiveActivityManager
    @ObservedObject var firebaseManager: FirebaseManager
    @Binding var animateSauna: Bool
    @Binding var animateCold: Bool
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dark background
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Timer display at top
                    TimerDisplayView(sessionManager: sessionManager)
                        .padding(.top, 20)
                        .frame(height: 120)
                        .animation(.easeInOut(duration: 0.6), value: sessionManager.isRunning)
                        .animation(.easeInOut(duration: 0.6), value: sessionManager.isPaused)
                    
                    // Dynamic button layout based on session state
                    if sessionManager.isRunning || sessionManager.isPaused {
                        // Session active layout
                        VStack(spacing: 0) {
                            // Pause/Resume button in top position
                            BigSessionButton(
                                title: sessionManager.isPaused ? "RESUME" : "PAUSE",
                                glowColor: .white,
                                fadeDirection: .topToBottom,
                                action: {
                                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                        if sessionManager.isPaused {
                                            sessionManager.resumeSession()
                                        } else {
                                            sessionManager.pauseSession()
                                        }
                                    }
                                }
                            )
                            .frame(height: geometry.size.height * 0.14) // Made even skinnier and closer
                            .transition(.asymmetric(
                                insertion: .scale.combined(with: .opacity).animation(.spring(response: 0.8, dampingFraction: 0.7)),
                                removal: .scale.combined(with: .opacity).animation(.easeInOut(duration: 0.5))
                            ))
                            
                            // Bigger Infinity Icon in middle
                            InfinityIconView(
                                animateSauna: $animateSauna,
                                animateCold: $animateCold,
                                sessionType: sessionManager.sessionType,
                                isRunning: sessionManager.isRunning,
                                progressPercentage: sessionManager.progressPercentage
                            )
                            .frame(width: min(geometry.size.width * 0.7, 250), height: min(geometry.size.width * 0.7, 250))
                            .frame(height: geometry.size.height * 0.48) // Reduced to make more room for bottom button
                            .scaleEffect(sessionManager.isRunning ? 1.0 : 0.9)
                            .animation(.spring(response: 0.8, dampingFraction: 0.6), value: sessionManager.isRunning)
                            .animation(.spring(response: 0.8, dampingFraction: 0.6), value: sessionManager.isPaused)
                            
                            // End Session button in lower middle
                            BigSessionButton(
                                title: "END SESSION",
                                glowColor: .red,
                                fadeDirection: .bottomToTop,
                                action: {
                                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                        sessionManager.endSession()
                                    }
                                }
                            )
                            .frame(height: geometry.size.height * 0.14) // Made even skinnier and closer
                            .transition(.asymmetric(
                                insertion: .scale.combined(with: .opacity).animation(.spring(response: 0.8, dampingFraction: 0.7)),
                                removal: .scale.combined(with: .opacity).animation(.easeInOut(duration: 0.5))
                            ))
                        }
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity).animation(.spring(response: 1.0, dampingFraction: 0.8)),
                            removal: .move(edge: .top).combined(with: .opacity).animation(.easeInOut(duration: 0.8))
                        ))
                    } else {
                        // Default layout with start session buttons
                        VStack(spacing: 0) {
                            // Start Sauna Session Button - top half
                            BigSessionButton(
                                title: "START SAUNA SESSION",
                                glowColor: .orange,
                                fadeDirection: .topToBottom,
                                action: {
                                    withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                                        animateSauna = true
                                        sessionManager.setLiveActivityManager(liveActivityManager)
                                        sessionManager.setFirebaseManager(firebaseManager)
                                        sessionManager.pendingSessionType = .sauna
                                        sessionManager.showingGoalSelection = true
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                        withAnimation(.easeOut(duration: 0.3)) {
                                            animateSauna = false
                                        }
                                    }
                                }
                            )
                            .frame(height: geometry.size.height * 0.14) // Made even skinnier and closer
                            .transition(.asymmetric(
                                insertion: .scale.combined(with: .opacity).animation(.spring(response: 0.8, dampingFraction: 0.7)),
                                removal: .scale.combined(with: .opacity).animation(.easeInOut(duration: 0.5))
                            ))
                            
                            // Bigger Infinity Icon in middle
                            InfinityIconView(
                                animateSauna: $animateSauna,
                                animateCold: $animateCold,
                                sessionType: sessionManager.sessionType,
                                isRunning: sessionManager.isRunning,
                                progressPercentage: sessionManager.progressPercentage
                            )
                            .frame(width: min(geometry.size.width * 0.7, 250), height: min(geometry.size.width * 0.7, 250))
                            .frame(height: geometry.size.height * 0.48) // Reduced to make more room for bottom button
                            .scaleEffect(animateSauna || animateCold ? 1.1 : 1.0)
                            .animation(.spring(response: 0.8, dampingFraction: 0.6), value: animateSauna)
                            .animation(.spring(response: 0.8, dampingFraction: 0.6), value: animateCold)
                            
                            // Start Cold Session Button - bottom half
                            BigSessionButton(
                                title: "START COLD TUB SESSION",
                                glowColor: .cyan,
                                fadeDirection: .bottomToTop,
                                action: {
                                    withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                                        animateCold = true
                                        sessionManager.setLiveActivityManager(liveActivityManager)
                                        sessionManager.setFirebaseManager(firebaseManager)
                                        sessionManager.pendingSessionType = .cold
                                        sessionManager.showingGoalSelection = true
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                        withAnimation(.easeOut(duration: 0.3)) {
                                            animateCold = false
                                        }
                                    }
                                }
                            )
                            .frame(height: geometry.size.height * 0.14) // Made even skinnier and closer
                            .transition(.asymmetric(
                                insertion: .scale.combined(with: .opacity).animation(.spring(response: 0.8, dampingFraction: 0.7)),
                                removal: .scale.combined(with: .opacity).animation(.easeInOut(duration: 0.5))
                            ))
                        }
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity).animation(.spring(response: 1.0, dampingFraction: 0.8)),
                            removal: .move(edge: .bottom).combined(with: .opacity).animation(.easeInOut(duration: 0.8))
                        ))
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 120) // Increased bottom padding to prevent overlap with custom tab bar
            }
        }
        .animation(.spring(response: 0.8, dampingFraction: 0.8), value: sessionManager.isRunning)
        .animation(.spring(response: 0.8, dampingFraction: 0.8), value: sessionManager.isPaused)
    }
}

// MARK: - Custom Tab Bar
struct CustomTabBar: View {
    @Binding var selectedTab: AppTab
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 20, weight: selectedTab == tab ? .semibold : .medium))
                            .foregroundColor(selectedTab == tab ? .white : .white.opacity(0.6))
                        
                        Text(tab.title)
                            .font(.caption2)
                            .fontWeight(selectedTab == tab ? .semibold : .medium)
                            .foregroundColor(selectedTab == tab ? .white : .white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 0)
                            .fill(selectedTab == tab ? Color.white.opacity(0.1) : Color.clear)
                    )
                }
            }
        }
        .background(
            Rectangle()
                .fill(Color.black.opacity(0.9))
                .blur(radius: 20)
        )
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(.white.opacity(0.2)),
            alignment: .top
        )
    }
}

// Enhanced Big Session Button Component with colored glow effect and directional fade
enum FadeDirection {
    case topToBottom
    case bottomToTop
}

struct BigSessionButton: View {
    let title: String
    let glowColor: Color
    let fadeDirection: FadeDirection
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                action()
            }
        }) {
            ZStack {
                // Very subtle colored glow background - elegant and understated
                ZStack {
                    // Inner glow layer - barely visible
                    RoundedRectangle(cornerRadius: 25)
                        .fill(
                            LinearGradient(
                                colors: [
                                    glowColor.opacity(0.08),
                                    glowColor.opacity(0.04),
                                    glowColor.opacity(0.02),
                                    Color.clear,
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .blur(radius: 8)
                        .scaleEffect(1.02)
                    
                    // Outer glow layer - extremely gentle
                    RoundedRectangle(cornerRadius: 25)
                        .fill(
                            LinearGradient(
                                colors: [
                                    glowColor.opacity(0.05),
                                    glowColor.opacity(0.02),
                                    glowColor.opacity(0.01),
                                    Color.clear,
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .blur(radius: 15)
                        .scaleEffect(1.05)
                }
                .opacity(isPressed ? 0.2 : 0.5)
                
                // Main button content with directional fade effect
                ZStack {
                    // Button background (invisible but for shape)
                    RoundedRectangle(cornerRadius: 25)
                        .fill(Color.clear)
                    
                    // Directional fading border effect
                    RoundedRectangle(cornerRadius: 25)
                        .stroke(
                            LinearGradient(
                                colors: fadeDirection == .topToBottom ? [
                                    Color.gray.opacity(0.3),
                                    Color.gray.opacity(0.2),
                                    Color.gray.opacity(0.1),
                                    Color.clear
                                ] : [
                                    Color.clear,
                                    Color.gray.opacity(0.1),
                                    Color.gray.opacity(0.2),
                                    Color.gray.opacity(0.3)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1.5
                        )
                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                    
                    // Text content
                    Text(title)
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .mask(
                            // Directional text fade for consistency
                            LinearGradient(
                                colors: fadeDirection == .topToBottom ? [
                                    Color.white,
                                    Color.white,
                                    Color.white.opacity(0.9),
                                    Color.white.opacity(0.8)
                                ] : [
                                    Color.white.opacity(0.8),
                                    Color.white.opacity(0.9),
                                    Color.white,
                                    Color.white
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .scaleEffect(isPressed ? 0.95 : 1.0)
                .opacity(isPressed ? 0.8 : 1.0)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
        .contentShape(RoundedRectangle(cornerRadius: 25))
    }
}

struct TimerDisplayView: View {
    @ObservedObject var sessionManager: SessionManager
    
    var body: some View {
        VStack(spacing: 4) {
            if sessionManager.isRunning || sessionManager.isPaused {
                HStack {
                    Text(sessionManager.sessionType?.displayName ?? "")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                        .textCase(.uppercase)
                        .tracking(1)
                    
                    if sessionManager.isPaused {
                        Text("PAUSED")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.yellow.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
                
                Text(sessionManager.timeString)
                    .font(.system(size: 32, weight: .light, design: .monospaced))
                    .foregroundColor(.white)
                
                // Goal progress
                if let goal = sessionManager.selectedGoal {
                    HStack {
                        Text("Goal: \(goal.displayName)")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.5))
                        
                        Spacer()
                        
                        if sessionManager.isGoalMet {
                            Text("🎉 Goal Achieved!")
                                .font(.caption2)
                                .foregroundColor(.green)
                        } else {
                            Text("\(sessionManager.timeRemainingString) left")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Progress bar
                    ProgressView(value: sessionManager.progressPercentage)
                        .progressViewStyle(LinearProgressViewStyle(tint: sessionManager.sessionType == .sauna ? .orange : .cyan))
                        .scaleEffect(x: 1, y: 0.5)
                        .padding(.horizontal, 20)
                }
            }
        }
        .frame(minHeight: 80)
    }
}

struct InfinityIconView: View {
    @Binding var animateSauna: Bool
    @Binding var animateCold: Bool
    let sessionType: SessionType?
    let isRunning: Bool
    let progressPercentage: Double
    
    var body: some View {
        ZStack {
            // Fire embers for sauna
            if sessionType == .sauna && isRunning {
                FireEmbersView()
            }
            
            // Snowflakes for cold
            if sessionType == .cold && isRunning {
                SnowflakesView()
            }
            
            // Main infinity icon
            if let _ = UIImage(named: "InfinityIcon") {
                Image("InfinityIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .opacity(isRunning ? 1.0 : 0.6)
                    .modifier(PulsingGlowModifier(
                        isActive: isRunning,
                        color: sessionType == .sauna ? .orange : .cyan
                    ))
            } else {
                // Fallback to SF Symbol
                Image(systemName: "infinity")
                    .font(.system(size: 80, weight: .light))
                    .foregroundColor(.white)
                    .opacity(isRunning ? 1.0 : 0.6)
                    .modifier(PulsingGlowModifier(
                        isActive: isRunning,
                        color: sessionType == .sauna ? .orange : .cyan
                    ))
            }
            
            // Progress ring around icon for goals
            if isRunning, progressPercentage > 0 {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 3)
                    .overlay(
                        Circle()
                            .trim(from: 0, to: progressPercentage)
                            .stroke(
                                sessionType == .sauna ? 
                                LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing) :
                                LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing),
                                style: StrokeStyle(lineWidth: 3, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.5), value: progressPercentage)
                    )
                    .padding(10)
            }
        }
    }
}

struct InfinityHalf: View {
    let isTop: Bool
    let gradient: LinearGradient
    let animate: Bool
    let isActive: Bool
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                let centerX = width / 2
                let centerY = height / 2
                
                if isTop {
                    // Top loop of vertical infinity (sauna)
                    path.move(to: CGPoint(x: centerX, y: centerY))
                    path.addCurve(
                        to: CGPoint(x: centerX, y: height * 0.15),
                        control1: CGPoint(x: width * 0.15, y: height * 0.3),
                        control2: CGPoint(x: width * 0.15, y: height * 0.15)
                    )
                    path.addCurve(
                        to: CGPoint(x: centerX, y: centerY),
                        control1: CGPoint(x: width * 0.85, y: height * 0.15),
                        control2: CGPoint(x: width * 0.85, y: height * 0.3)
                    )
                } else {
                    // Bottom loop of vertical infinity (cold)
                    path.move(to: CGPoint(x: centerX, y: centerY))
                    path.addCurve(
                        to: CGPoint(x: centerX, y: height * 0.85),
                        control1: CGPoint(x: width * 0.15, y: height * 0.7),
                        control2: CGPoint(x: width * 0.15, y: height * 0.85)
                    )
                    path.addCurve(
                        to: CGPoint(x: centerX, y: centerY),
                        control1: CGPoint(x: width * 0.85, y: height * 0.85),
                        control2: CGPoint(x: width * 0.85, y: height * 0.7)
                    )
                }
            }
            .stroke(gradient, lineWidth: 8)
            .opacity(isActive ? 1.0 : 0.6)
            .modifier(PulsingGlowModifier(isActive: isActive, color: isTop ? .orange : .cyan))
        }
    }
}

enum SessionType: String, Codable, CaseIterable {
    case sauna
    case cold
    
    var displayName: String {
        switch self {
        case .sauna: return "Sauna Session"
        case .cold: return "Cold Session"
        }
    }
}

class TimerManager: ObservableObject {
    @Published var isRunning = false
    @Published var sessionType: SessionType?
    @Published var sessionStartTime: Date?
    
    private var displayTimer: Timer?
    private var liveActivityManager: LiveActivityManager?
    
    // Computed property that calculates elapsed time based on start time
    var timeElapsed: TimeInterval {
        guard let startTime = sessionStartTime, isRunning else { return 0 }
        let elapsed = Date().timeIntervalSince(startTime)
        return elapsed
    }
    
    var timeString: String {
        let elapsed = timeElapsed
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    func setLiveActivityManager(_ manager: LiveActivityManager) {
        self.liveActivityManager = manager
    }
    
    func startSession(_ type: SessionType) {
        if isRunning {
            stopSession()
        }
        
        sessionType = type
        sessionStartTime = Date() // This is our source of truth
        isRunning = true
        
        // Start Live Activity
        liveActivityManager?.startLiveActivity(for: type)
        
        // Timer only for UI updates in the main app
        displayTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            DispatchQueue.main.async {
                // Force UI update by triggering objectWillChange
                self.objectWillChange.send()
            }
        }
        
        // Add to common run loop to survive scrolling
        if let timer = displayTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    func stopSession() {
        displayTimer?.invalidate()
        displayTimer = nil
        isRunning = false
        sessionType = nil
        sessionStartTime = nil
        
        // End Live Activity
        liveActivityManager?.endLiveActivity()
    }
}

// MARK: - Animation Components

struct PulsingGlowModifier: ViewModifier {
    let isActive: Bool
    let color: Color
    @State private var glowIntensity: Double = 0.0
    @State private var colorIntensity: Double = 1.0
    
    func body(content: Content) -> some View {
        content
            .shadow(color: isActive ? color.opacity(glowIntensity) : .clear, radius: isActive ? 15 : 0)
            .shadow(color: isActive ? color.opacity(glowIntensity * 0.5) : .clear, radius: isActive ? 25 : 0)
            .scaleEffect(1.0) // Keep object stationary
            .onChange(of: isActive) { active in
                if active {
                    // Start pulsing glow animation
                    withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                        glowIntensity = 0.8
                    }
                    withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                        colorIntensity = 1.3
                    }
                } else {
                    // Stop pulsing
                    withAnimation(.easeOut(duration: 0.5)) {
                        glowIntensity = 0.0
                        colorIntensity = 1.0
                    }
                }
            }
    }
}

struct FireEmbersView: View {
    @State private var embers: [EmberParticle] = []
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(embers) { ember in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.orange, .red, .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: ember.size / 2
                            )
                        )
                        .frame(width: ember.size, height: ember.size)
                        .position(ember.position)
                        .opacity(ember.opacity)
                        .blur(radius: ember.blur)
                }
            }
        }
        .onAppear {
            startEmberAnimation()
        }
    }
    
    private func startEmberAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
            addEmber()
        }
    }
    
    private func addEmber() {
        let newEmber = EmberParticle()
        embers.append(newEmber)
        
        withAnimation(.easeOut(duration: 3.0)) {
            if let index = embers.firstIndex(where: { $0.id == newEmber.id }) {
                embers[index].position.y -= 200
                embers[index].position.x += Double.random(in: -30...30)
                embers[index].opacity = 0
                embers[index].size *= 0.3
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            embers.removeAll { $0.id == newEmber.id }
        }
    }
}

struct SnowflakesView: View {
    @State private var snowflakes: [SnowflakeParticle] = []
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(snowflakes) { snowflake in
                    Image(systemName: "snowflake")
                        .foregroundColor(.white)
                        .font(.system(size: snowflake.size))
                        .position(snowflake.position)
                        .opacity(snowflake.opacity)
                        .rotationEffect(.degrees(snowflake.rotation))
                }
            }
        }
        .onAppear {
            startSnowflakeAnimation()
        }
    }
    
    private func startSnowflakeAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            addSnowflake()
        }
    }
    
    private func addSnowflake() {
        let newSnowflake = SnowflakeParticle()
        snowflakes.append(newSnowflake)
        
        withAnimation(.linear(duration: 5.0)) {
            if let index = snowflakes.firstIndex(where: { $0.id == newSnowflake.id }) {
                snowflakes[index].position.y += 250 // Move down more
                snowflakes[index].position.x += Double.random(in: -5...5) // Very slight horizontal drift
                snowflakes[index].opacity = 0
                snowflakes[index].rotation += 90 // Gentle rotation
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            snowflakes.removeAll { $0.id == newSnowflake.id }
        }
    }
}

struct EmberParticle: Identifiable {
    let id = UUID()
    var position = CGPoint(x: Double.random(in: 30...90), y: 120)
    var size = Double.random(in: 3...8)
    var opacity = Double.random(in: 0.6...1.0)
    var blur = Double.random(in: 0...2)
}

struct SnowflakeParticle: Identifiable {
    let id = UUID()
    var position = CGPoint(x: Double.random(in: 20...100), y: 20) // Start higher up
    var size = Double.random(in: 8...16)
    var opacity = Double.random(in: 0.5...0.9)
    var rotation = Double.random(in: 0...360)
}



// MARK: - Goal Selection View
struct GoalSelectionView: View {
    @ObservedObject var sessionManager: SessionManager
    @State private var selectedGoal: SessionGoal?
    @State private var sessionTypeToStart: SessionType = .sauna
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                VStack(spacing: 10) {
                    Image(systemName: "infinity")
                        .font(.system(size: 60, weight: .light))
                        .foregroundColor(.white)
                        .frame(width: 80, height: 80)
                    
                    Text("Choose Your Goal")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("How long would you like to session?")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 15) {
                    ForEach(SessionGoal.goals, id: \.duration) { goal in
                        GoalButton(
                            goal: goal,
                            isSelected: selectedGoal?.duration == goal.duration,
                            isRecommended: goal.duration == sessionManager.suggestedNextGoal?.duration
                        ) {
                            selectedGoal = goal
                        }
                    }
                }
                
                if let selected = selectedGoal {
                    Button("Start Session") {
                        sessionManager.selectGoalAndStart(selected, type: sessionTypeToStart)
                    }
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: sessionTypeToStart == .sauna ? [.orange, .red] : [.cyan, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(25)
                }
                
                Spacer()
            }
            .padding()
            .background(Color.black.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        sessionManager.showingGoalSelection = false
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            sessionTypeToStart = sessionManager.pendingSessionType ?? .sauna
            selectedGoal = sessionManager.suggestedNextGoal
        }
    }
}

struct GoalButton: View {
    let goal: SessionGoal
    let isSelected: Bool
    let isRecommended: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                if isRecommended {
                    Text("RECOMMENDED")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(8)
                }
                
                Text(goal.displayName)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text("Goal Duration")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(isSelected ? Color.white.opacity(0.2) : Color.white.opacity(0.05))
                    .stroke(isSelected ? Color.white.opacity(0.6) : Color.clear, lineWidth: 2)
            )
        }
    }
}

// MARK: - Session Stats View
struct SessionStatsView: View {
    @ObservedObject var sessionManager: SessionManager
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                if let session = sessionManager.lastCompletedSession {
                    VStack(spacing: 20) {
                        // Success indicator
                        ZStack {
                            Circle()
                                .fill(session.wasGoalMet ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                                .frame(width: 100, height: 100)
                            
                            Image(systemName: "infinity")
                                .font(.system(size: 50, weight: .light))
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                        }
                        
                        VStack(spacing: 8) {
                            Text(session.wasGoalMet ? "🎉 Goal Achieved!" : "💪 Great Session!")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("\(session.sessionType.displayName) Complete")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        // Session details
                        VStack(spacing: 15) {
                            StatRow(title: "Duration", value: session.durationString)
                            if session.goalDuration > 0 {
                                StatRow(title: "Goal", value: session.goalString)
                            }
                            StatRow(title: "Session Type", value: session.sessionType.displayName)
                        }
                        .padding(.horizontal)
                        
                        // Encouragement for next session
                        if let suggested = sessionManager.suggestedNextGoal {
                            VStack(spacing: 8) {
                                Text("💡 Next Challenge")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Text("Try a \(suggested.displayName) session next time!")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.7))
                                    .multilineTextAlignment(.center)
                            }
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(15)
                        }
                    }
                }
                
                Spacer()
                
                Button("Continue") {
                    sessionManager.showingSessionStats = false
                }
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 40)
                .padding(.vertical, 16)
                .background(Color.white.opacity(0.2))
                .cornerRadius(25)
            }
            .padding()
            .background(Color.black.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Session Complete")
        }
    }
}

struct StatRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.05))
        .cornerRadius(10)
    }
}

// MARK: - Session History View
struct SessionHistoryView: View {
    @ObservedObject var sessionManager: SessionManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Session history list
                if sessionManager.completedSessions.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "infinity")
                            .font(.system(size: 50, weight: .light))
                            .foregroundColor(.white.opacity(0.5))
                        
                        Text("No Sessions Yet")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Text("Start your first session to see your progress here!")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Recent Sessions")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Spacer()
                        }
                        .padding(.horizontal)
                        
                        LazyVStack(spacing: 12) {
                            ForEach(sessionManager.completedSessions.reversed().prefix(20), id: \.id) { session in
                                SessionHistoryRow(session: session)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
        .background(Color.black.ignoresSafeArea())
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.white.opacity(0.8))
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.white.opacity(0.05))
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

struct SessionHistoryRow: View {
    let session: CompletedSession
    
    var body: some View {
        HStack(spacing: 12) {
            // Session type indicator
            ZStack {
                Circle()
                    .fill(session.sessionType == .sauna ? 
                          LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing) :
                          LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 40, height: 40)
                
                Image(systemName: session.sessionType == .sauna ? "flame.fill" : "snowflake")
                    .foregroundColor(.white)
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(session.sessionType.displayName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    if session.wasGoalMet {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }
                
                HStack {
                    Text(session.durationString)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.8))
                    
                    if session.goalDuration > 0 {
                        Text("• Goal: \(session.goalString)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    Spacer()
                    
                    Text(session.startTime, style: .date)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.03))
                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        )
    }
}

// Old FriendsView removed - replaced with FriendsPageView

enum FriendsTab: String, CaseIterable {
    case friends
    case leaderboard
    case profile
    
    var displayName: String {
        switch self {
        case .friends: return "Friends"
        case .leaderboard: return "Leaderboard"
        case .profile: return "Profile"
        }
    }
}

// MARK: - Friends List View
struct FriendsListView: View {
    @ObservedObject var firebaseManager: FirebaseManager
    @Binding var searchText: String
    @State private var searchResults: [PurgoUser] = []
    @State private var isSearching = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.white.opacity(0.6))
                
                TextField("Search username...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .foregroundColor(.white)
                    .onChange(of: searchText) { newValue in
                        if !newValue.isEmpty {
                            searchUsers()
                        } else {
                            searchResults = []
                        }
                    }
                
                if !searchText.isEmpty {
                    Button("Clear") {
                        searchText = ""
                        searchResults = []
                    }
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.white.opacity(0.1))
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .padding()
            
            ScrollView {
                LazyVStack(spacing: 12) {
                    // Friend requests section
                    if !firebaseManager.friendRequests.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Friend Requests")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal)
                            
                            ForEach(firebaseManager.friendRequests) { user in
                                FriendRequestRow(user: user, firebaseManager: firebaseManager)
                            }
                        }
                        .padding(.bottom)
                    }
                    
                    // Search results
                    if !searchResults.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Search Results")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal)
                            
                            ForEach(searchResults) { user in
                                UserSearchRow(user: user, firebaseManager: firebaseManager)
                            }
                        }
                        .padding(.bottom)
                    }
                    
                    // Friends list
                    if !firebaseManager.friends.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Friends (\(firebaseManager.friends.count))")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal)
                            
                            ForEach(firebaseManager.friends) { friend in
                                FriendRow(user: friend)
                            }
                        }
                    } else if searchText.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "person.2")
                                .font(.system(size: 50, weight: .light))
                                .foregroundColor(.white.opacity(0.5))
                            
                            Text("No Friends Yet")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            
                            Text("Search for friends by username to get started!")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 60)
                    }
                }
            }
        }
    }
    
    private func searchUsers() {
        isSearching = true
        Task {
            let results = await firebaseManager.searchUsers(by: searchText)
            DispatchQueue.main.async {
                self.searchResults = results.filter { $0.id != self.firebaseManager.currentUser?.id }
                self.isSearching = false
            }
        }
    }
}

// Old LeaderboardView removed - replaced with FitnessStyleLeaderboardView

// MARK: - Profile View (Updated for new design)
struct ProfileView: View {
    @ObservedObject var firebaseManager: FirebaseManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let user = firebaseManager.currentUser {
                    // Profile header with larger photo
                    VStack(spacing: 16) {
                        AsyncImage(url: URL(string: user.photoURL ?? "")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle()
                                .fill(Color.white.opacity(0.2))
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .foregroundColor(.white.opacity(0.6))
                                        .font(.system(size: 40))
                                )
                        }
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 3)
                        )
                        
                        VStack(spacing: 6) {
                            Text(user.displayName)
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("@\(user.username)")
                                .font(.headline)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        // Sign out button
                        Button("Sign Out") {
                            firebaseManager.signOut()
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.red.opacity(0.2))
                                .stroke(Color.red.opacity(0.4), lineWidth: 1)
                        )
                    }
                    
                    // Enhanced stats grid with better visual hierarchy
                    VStack(spacing: 16) {
                        HStack {
                            Text("Your Stats")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Spacer()
                        }
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                            EnhancedStatCard(title: "Total Sessions", value: "\(user.totalSessions)", icon: "infinity", color: .orange)
                            EnhancedStatCard(title: "Total Time", value: timeString(from: user.totalTimeSpent), icon: "clock", color: .blue)
                            EnhancedStatCard(title: "Sauna Sessions", value: "\(user.saunaSessionCount)", icon: "flame.fill", color: .red)
                            EnhancedStatCard(title: "Cold Sessions", value: "\(user.coldSessionCount)", icon: "snowflake", color: .cyan)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding()
        }
        .background(Color.black.ignoresSafeArea())
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let totalMinutes = Int(timeInterval) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Enhanced Stat Card
struct EnhancedStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 15)
                    .fill(color.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
            }
            
            VStack(spacing: 4) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.white.opacity(0.05))
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Supporting Views
struct FriendRequestRow: View {
    let user: PurgoUser
    @ObservedObject var firebaseManager: FirebaseManager
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: user.photoURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.white.opacity(0.6))
                    )
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text("@\(user.username)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button("Accept") {
                    // Accept friend request logic
                }
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.3))
                .cornerRadius(15)
                
                Button("Decline") {
                    // Decline friend request logic
                }
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.red.opacity(0.3))
                .cornerRadius(15)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.03))
                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        )
        .padding(.horizontal)
    }
}

struct UserSearchRow: View {
    let user: PurgoUser
    @ObservedObject var firebaseManager: FirebaseManager
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: user.photoURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.white.opacity(0.6))
                    )
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text("@\(user.username)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            Button("Follow") {
                Task {
                    await firebaseManager.sendFriendRequest(to: user.id)
                }
            }
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.3))
            .cornerRadius(15)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.03))
                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        )
        .padding(.horizontal)
    }
}

struct FriendRow: View {
    let user: PurgoUser
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: user.photoURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.white.opacity(0.6))
                    )
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text("@\(user.username)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                
                Text("\(user.totalSessions) sessions • \(timeString(from: user.totalTimeSpent))")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Spacer()
            
            // Online indicator (if active recently)
            if user.lastActiveAt.timeIntervalSinceNow > -300 { // 5 minutes
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.03))
                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        )
        .padding(.horizontal)
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let totalMinutes = Int(timeInterval) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// Old LeaderboardRow removed - replaced with FitnessStyleLeaderboardRow

// MARK: - Friends Page
struct FriendsPageView: View {
    @ObservedObject var firebaseManager: FirebaseManager
    @State private var selectedFriendsTab: FriendsTab = .leaderboard
    @State private var searchText = ""
    @State private var selectedLeaderboardPeriod: LeaderboardPeriod = .weekly
    @State private var selectedLeaderboardScope: LeaderboardScope = .friends
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 16) {
                Text("Friends")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.top, 20)
                
                if !firebaseManager.isAuthenticated {
                    // Sign in prompt
                    VStack(spacing: 20) {
                        VStack(spacing: 12) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 50, weight: .light))
                                .foregroundColor(.white.opacity(0.7))
                            
                            Text("Connect with Friends")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            
                            Text("Sign in to compete with friends and climb the leaderboards!")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                        
                        Button("Sign in with Google") {
                            Task {
                                await firebaseManager.signInWithGoogle()
                            }
                        }
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 16)
                        .background(Color.white)
                        .cornerRadius(25)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Tab selector
                    HStack(spacing: 0) {
                        ForEach(FriendsTab.allCases, id: \.self) { tab in
                            Button(tab.displayName) {
                                selectedFriendsTab = tab
                            }
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(selectedFriendsTab == tab ? .white : .white.opacity(0.6))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 15)
                                    .fill(selectedFriendsTab == tab ? Color.white.opacity(0.15) : Color.clear)
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(20)
                    .padding(.horizontal)
                }
            }
            
            if firebaseManager.isAuthenticated {
                // Tab content
                TabView(selection: $selectedFriendsTab) {
                    FriendsListView(firebaseManager: firebaseManager, searchText: $searchText)
                        .tag(FriendsTab.friends)
                    
                    FitnessStyleLeaderboardView(
                        firebaseManager: firebaseManager,
                        selectedPeriod: $selectedLeaderboardPeriod,
                        selectedScope: $selectedLeaderboardScope
                    )
                    .tag(FriendsTab.leaderboard)
                    
                    ProfileView(firebaseManager: firebaseManager)
                        .tag(FriendsTab.profile)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            
            Spacer()
        }
        .background(Color.black.ignoresSafeArea())
        .padding(.bottom, 80) // Account for custom tab bar
    }
}

// MARK: - Achievements Page
struct AchievementsPageView: View {
    @ObservedObject var sessionManager: SessionManager
    @ObservedObject var firebaseManager: FirebaseManager
    @State private var selectedAchievementsTab: AchievementsTab = .badges
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 16) {
                Text("Achievements")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.top, 20)
                
                // Tab selector
                HStack(spacing: 0) {
                    ForEach(AchievementsTab.allCases, id: \.self) { tab in
                        Button(tab.displayName) {
                            selectedAchievementsTab = tab
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(selectedAchievementsTab == tab ? .white : .white.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 15)
                                .fill(selectedAchievementsTab == tab ? Color.white.opacity(0.15) : Color.clear)
                        )
                    }
                }
                .padding(.horizontal, 16)
                .background(Color.white.opacity(0.05))
                .cornerRadius(20)
                .padding(.horizontal)
            }
            
            // Tab content
            TabView(selection: $selectedAchievementsTab) {
                BadgesView(sessionManager: sessionManager, firebaseManager: firebaseManager)
                    .tag(AchievementsTab.badges)
                
                SessionHistoryView(sessionManager: sessionManager)
                    .tag(AchievementsTab.sessions)
                
                StatsView(sessionManager: sessionManager, firebaseManager: firebaseManager)
                    .tag(AchievementsTab.stats)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            
            Spacer()
        }
        .background(Color.black.ignoresSafeArea())
        .padding(.bottom, 80) // Account for custom tab bar
    }
}

// MARK: - Achievement Tabs
enum AchievementsTab: String, CaseIterable {
    case badges
    case sessions
    case stats
    
    var displayName: String {
        switch self {
        case .badges: return "Badges"
        case .sessions: return "Sessions"
        case .stats: return "Stats"
        }
    }
}

// MARK: - Fitness-Style Leaderboard
struct FitnessStyleLeaderboardView: View {
    @ObservedObject var firebaseManager: FirebaseManager
    @Binding var selectedPeriod: LeaderboardPeriod
    @Binding var selectedScope: LeaderboardScope
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Period and scope selectors
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        ForEach(LeaderboardPeriod.allCases, id: \.self) { period in
                            Button(period.displayName) {
                                selectedPeriod = period
                                loadLeaderboard()
                            }
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(selectedPeriod == period ? .black : .white.opacity(0.7))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(selectedPeriod == period ? Color.white : Color.white.opacity(0.1))
                            )
                        }
                    }
                    
                    HStack(spacing: 8) {
                        ForEach(LeaderboardScope.allCases, id: \.self) { scope in
                            Button(scope.displayName) {
                                selectedScope = scope
                                loadLeaderboard()
                            }
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(selectedScope == scope ? .black : .white.opacity(0.7))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(selectedScope == scope ? Color.white : Color.white.opacity(0.1))
                            )
                        }
                    }
                }
                .padding(.horizontal)
                
                // Current user's rank (if available)
                if let currentUser = firebaseManager.currentUser,
                   let userEntry = firebaseManager.leaderboardEntries.first(where: { $0.userId == currentUser.id }) {
                    
                    VStack(spacing: 12) {
                        // User's rank display
                        HStack {
                            AsyncImage(url: URL(string: currentUser.photoURL ?? "")) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Circle()
                                    .fill(Color.white.opacity(0.2))
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .foregroundColor(.white.opacity(0.6))
                                    )
                            }
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(currentUser.displayName)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                
                                Text("@\(currentUser.username)")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.7))
                                
                                HStack {
                                    Image(systemName: "trophy.fill")
                                        .foregroundColor(.orange)
                                    Text("\(userEntry.rank) • 3rd Place")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.orange)
                                }
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("\(Int(userEntry.totalTime / 60))m")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                
                                Text("\(userEntry.sessionCount) sessions")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.orange.opacity(0.1))
                                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal)
                }
                
                // Leaderboard list
                LazyVStack(spacing: 12) {
                    ForEach(Array(firebaseManager.leaderboardEntries.enumerated()), id: \.element.id) { index, entry in
                        FitnessStyleLeaderboardRow(entry: entry, rank: index + 1)
                    }
                }
                .padding(.horizontal)
            }
        }
        .onAppear {
            loadLeaderboard()
        }
    }
    
    private func loadLeaderboard() {
        Task {
            await firebaseManager.loadLeaderboard(period: selectedPeriod, scope: selectedScope)
        }
    }
}

struct FitnessStyleLeaderboardRow: View {
    let entry: LeaderboardEntry
    let rank: Int
    
    var body: some View {
        HStack(spacing: 16) {
            // Rank number
            ZStack {
                Circle()
                    .fill(rankColor.opacity(0.2))
                    .frame(width: 35, height: 35)
                
                Text("\(rank)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(rankColor)
            }
            
            // Profile picture
            AsyncImage(url: URL(string: entry.photoURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.white.opacity(0.6))
                    )
            }
            .frame(width: 50, height: 50)
            .clipShape(Circle())
            
            // User info
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.displayName)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text("@\(entry.username)")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            // Stats with badge-like design
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 8) {
                    if rank <= 3 {
                        ZStack {
                            Circle()
                                .fill(rankColor.opacity(0.2))
                                .frame(width: 30, height: 30)
                            
                            Text("\(rank)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(rankColor)
                        }
                    }
                    
                    Text("\(Int(entry.totalTime / 60))m")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                
                Text("\(entry.sessionCount) sessions")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(rank <= 3 ? rankColor.opacity(0.05) : Color.white.opacity(0.03))
                .stroke(rank <= 3 ? rankColor.opacity(0.2) : Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .white
        }
    }
}

// MARK: - Badges View (Achievement System)
struct BadgesView: View {
    @ObservedObject var sessionManager: SessionManager
    @ObservedObject var firebaseManager: FirebaseManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Badges unlocked count
                VStack(spacing: 8) {
                    Text("\(unlockedBadgesCount)")
                        .font(.system(size: 60, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Badges Unlocked")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.top, 20)
                
                // Recent badges
                if !recentBadges.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Recent Badges")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Button("See All") {
                                // Show all badges
                            }
                            .font(.subheadline)
                            .foregroundColor(.orange)
                        }
                        .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(recentBadges, id: \.id) { badge in
                                    BadgeCard(badge: badge)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                
                // Your next badge
                if let nextBadge = nextBadgeToUnlock {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Your Next Badge")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Spacer()
                        }
                        .padding(.horizontal)
                        
                        NextBadgeCard(badge: nextBadge, progress: nextBadgeProgress)
                            .padding(.horizontal)
                    }
                }
                
                // All badges grid
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("All Badges")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                        ForEach(allBadges, id: \.id) { badge in
                            BadgeGridItem(badge: badge)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .background(Color.black.ignoresSafeArea())
        .padding(.bottom, 80) // Account for custom tab bar
    }
    
    // Badge logic
    private var unlockedBadgesCount: Int {
        allBadges.filter { $0.isUnlocked }.count
    }
    
    private var recentBadges: [Badge] {
        allBadges.filter { $0.isUnlocked }.suffix(3).reversed()
    }
    
    private var nextBadgeToUnlock: Badge? {
        allBadges.first { !$0.isUnlocked }
    }
    
    private var nextBadgeProgress: Double {
        guard let nextBadge = nextBadgeToUnlock else { return 0 }
        return nextBadge.progressPercentage(sessionManager: sessionManager)
    }
    
    private var allBadges: [Badge] {
        Badge.allBadges(sessionManager: sessionManager)
    }
}

// MARK: - Badge System
struct Badge: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let icon: String
    let color: Color
    let requirement: BadgeRequirement
    let isUnlocked: Bool
    
    func progressPercentage(sessionManager: SessionManager) -> Double {
        switch requirement {
        case .sessionsCompleted(let count):
            return min(1.0, Double(sessionManager.totalSessions) / Double(count))
        case .timeSpent(let seconds):
            return min(1.0, sessionManager.totalTimeSpent / seconds)
        case .streak(let days):
            return min(1.0, Double(Badge.currentStreak(sessionManager)) / Double(days))
        case .goalsMet(let count):
            let goalsMet = sessionManager.completedSessions.filter { $0.wasGoalMet }.count
            return min(1.0, Double(goalsMet) / Double(count))
        }
    }
    
    static func currentStreak(_ sessionManager: SessionManager) -> Int {
        // Calculate current streak based on session dates
        let sortedSessions = sessionManager.completedSessions.sorted { $0.startTime > $1.startTime }
        var streak = 0
        var lastDate: Date?
        
        for session in sortedSessions {
            let sessionDate = Calendar.current.startOfDay(for: session.startTime)
            
            if let last = lastDate {
                let daysBetween = Calendar.current.dateComponents([.day], from: sessionDate, to: last).day ?? 0
                if daysBetween <= 1 {
                    streak += 1
                } else {
                    break
                }
            } else {
                streak = 1
            }
            
            lastDate = sessionDate
        }
        
        return streak
    }
    
    static func allBadges(sessionManager: SessionManager) -> [Badge] {
        return [
            // Session count badges
            Badge(title: "First Steps", description: "Complete your first session", icon: "1.circle.fill", color: .green, requirement: .sessionsCompleted(1), isUnlocked: sessionManager.totalSessions >= 1),
            Badge(title: "Getting Started", description: "Complete 5 sessions", icon: "5.circle.fill", color: .blue, requirement: .sessionsCompleted(5), isUnlocked: sessionManager.totalSessions >= 5),
            Badge(title: "Committed", description: "Complete 25 sessions", icon: "25.circle.fill", color: .purple, requirement: .sessionsCompleted(25), isUnlocked: sessionManager.totalSessions >= 25),
            Badge(title: "Dedicated", description: "Complete 50 sessions", icon: "50.circle.fill", color: .orange, requirement: .sessionsCompleted(50), isUnlocked: sessionManager.totalSessions >= 50),
            Badge(title: "Master", description: "Complete 100 sessions", icon: "100.circle.fill", color: .red, requirement: .sessionsCompleted(100), isUnlocked: sessionManager.totalSessions >= 100),
            
            // Time-based badges
            Badge(title: "Hour Power", description: "Spend 1 hour total in sessions", icon: "clock.fill", color: .cyan, requirement: .timeSpent(3600), isUnlocked: sessionManager.totalTimeSpent >= 3600),
            Badge(title: "Time Warrior", description: "Spend 5 hours total in sessions", icon: "clock.badge.fill", color: .indigo, requirement: .timeSpent(18000), isUnlocked: sessionManager.totalTimeSpent >= 18000),
            Badge(title: "Endurance King", description: "Spend 24 hours total in sessions", icon: "crown.fill", color: .yellow, requirement: .timeSpent(86400), isUnlocked: sessionManager.totalTimeSpent >= 86400),
            
            // Streak badges
            Badge(title: "Consistent", description: "3 day streak", icon: "flame.fill", color: .orange, requirement: .streak(3), isUnlocked: Badge.currentStreak(sessionManager) >= 3),
            Badge(title: "Dedicated", description: "7 day streak", icon: "flame.fill", color: .red, requirement: .streak(7), isUnlocked: Badge.currentStreak(sessionManager) >= 7),
            Badge(title: "Unstoppable", description: "30 day streak", icon: "flame.fill", color: .pink, requirement: .streak(30), isUnlocked: Badge.currentStreak(sessionManager) >= 30),
            
            // Goal-based badges
            Badge(title: "Goal Crusher", description: "Meet 10 session goals", icon: "target", color: .green, requirement: .goalsMet(10), isUnlocked: sessionManager.completedSessions.filter { $0.wasGoalMet }.count >= 10),
            Badge(title: "Perfectionist", description: "Meet 25 session goals", icon: "checkmark.seal.fill", color: .mint, requirement: .goalsMet(25), isUnlocked: sessionManager.completedSessions.filter { $0.wasGoalMet }.count >= 25)
        ]
    }
}

enum BadgeRequirement {
    case sessionsCompleted(Int)
    case timeSpent(TimeInterval)
    case streak(Int)
    case goalsMet(Int)
}

// MARK: - Next Badge Card
struct NextBadgeCard: View {
    let badge: Badge
    let progress: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: badge.icon)
                    .font(.title2)
                    .foregroundColor(badge.color)
                
                Text(badge.title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            Text(badge.description)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
            
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: badge.color))
                .padding(.vertical, 8)
            
            Text("Progress: \(Int(progress * 100))%")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(badge.color.opacity(0.1))
                .stroke(badge.color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Badge Grid Item
struct BadgeGridItem: View {
    let badge: Badge
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: badge.icon)
                .font(.largeTitle)
                .foregroundColor(badge.color)
            
            Text(badge.title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text(badge.description)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(badge.color.opacity(0.05))
                .stroke(badge.color.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Stats View (Achievements Page)
struct StatsView: View {
    @ObservedObject var sessionManager: SessionManager
    @ObservedObject var firebaseManager: FirebaseManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Overall Stats
                VStack(spacing: 15) {
                    HStack {
                        Image(systemName: "chart.bar.xaxis")
                            .foregroundColor(.white.opacity(0.8))
                        Text("Overall Stats")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 15) {
                        StatCard(title: "Total Sessions", value: "\(sessionManager.totalSessions)", icon: "infinity")
                        StatCard(title: "Total Time", value: timeString(from: sessionManager.totalTimeSpent), icon: "clock")
                        StatCard(title: "Average Session", value: timeString(from: sessionManager.averageSessionDuration), icon: "chart.bar")
                        StatCard(title: "Longest Session", value: sessionManager.longestSession?.durationString ?? "0:00", icon: "trophy")
                    }
                    .padding(.horizontal)
                }
                
                // Session Type Stats
                VStack(spacing: 15) {
                    HStack {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.white.opacity(0.8))
                        Text("Session Type Stats")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 15) {
                        StatCard(title: "Sauna Sessions", value: "\(sessionManager.saunaSessionCount)", icon: "flame.fill")
                        StatCard(title: "Cold Sessions", value: "\(sessionManager.coldSessionCount)", icon: "snowflake")
                    }
                    .padding(.horizontal)
                }
                
                // Streak Stats
                VStack(spacing: 15) {
                    HStack {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.white.opacity(0.8))
                        Text("Streak Stats")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 15) {
                        StatCard(title: "Current Streak", value: "\(Badge.currentStreak(sessionManager)) days", icon: "flame.fill")
                        StatCard(title: "Longest Streak", value: "\(sessionManager.longestStreak) days", icon: "crown.fill")
                    }
                    .padding(.horizontal)
                }
                
                // Goal Achievement Stats
                VStack(spacing: 15) {
                    HStack {
                        Image(systemName: "target")
                            .foregroundColor(.white.opacity(0.8))
                        Text("Goal Achievement Stats")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 15) {
                        StatCard(title: "Total Goals Met", value: "\(sessionManager.totalGoalsMet)", icon: "checkmark.seal.fill")
                        StatCard(title: "Average Goals per Session", value: String(format: "%.1f", sessionManager.averageGoalsPerSession), icon: "chart.bar.xaxis")
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding()
        .background(Color.black.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Stats")
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let totalMinutes = Int(timeInterval) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Badge Card (Fitness App Style)
struct BadgeCard: View {
    let badge: Badge
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                // Badge background with hexagonal shape
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [badge.color.opacity(0.8), badge.color.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(badge.color.opacity(0.3), lineWidth: 2)
                    )
                
                Image(systemName: badge.icon)
                    .font(.title)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 4) {
                Text(badge.title)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("Jan 25, 2025")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .frame(width: 120)
    }
}

#Preview {
    ContentView()
}
