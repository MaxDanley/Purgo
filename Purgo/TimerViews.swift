//
//  TimerViews.swift
//  Purgo
//
//  Created by Max Danley on 8/27/25.
//

import SwiftUI

// MARK: - Timer Page (Original Main Screen)
struct TimerPageView: View {
    @ObservedObject var sessionManager: SessionManager
    @ObservedObject var liveActivityManager: LiveActivityManager
    @ObservedObject var firebaseManager: FirebaseManager
    @Binding var animateSauna: Bool
    @Binding var animateCold: Bool
    @Binding var showingEncouragementPopup: Bool
    @Binding var currentEncouragementMessage: String
    @State private var triggeredMilestones: Set<Int> = []
    
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
                            .frame(height: geometry.size.height * 0.14)
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
                            .frame(height: geometry.size.height * 0.48)
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
                            .frame(height: geometry.size.height * 0.14)
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
                            .frame(height: geometry.size.height * 0.14)
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
                            .frame(height: geometry.size.height * 0.48)
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
                            .frame(height: geometry.size.height * 0.14)
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
                .padding(.bottom, 120)
                
                // Encouragement popup overlay
                if showingEncouragementPopup {
                    EncouragementPopupView(
                        message: currentEncouragementMessage,
                        sessionType: sessionManager.sessionType,
                        isShowing: $showingEncouragementPopup
                    )
                    .zIndex(1000)
                }
            }
        }
        .animation(.spring(response: 0.8, dampingFraction: 0.8), value: sessionManager.isRunning)
        .animation(.spring(response: 0.8, dampingFraction: 0.8), value: sessionManager.isPaused)
        .onReceive(Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()) { _ in
            if sessionManager.isRunning && !sessionManager.isPaused {
                checkForEncouragementTriggers(timeElapsed: sessionManager.timeElapsed)
            }
        }
        .onChange(of: sessionManager.isRunning) { isRunning in
            if isRunning {
                triggeredMilestones.removeAll()
            }
        }
    }
    
    // MARK: - Encouragement Logic
    private func checkForEncouragementTriggers(timeElapsed: TimeInterval) {
        guard sessionManager.isRunning && !sessionManager.isPaused && !showingEncouragementPopup else { return }
        
        let minutes = Int(timeElapsed) / 60
        let seconds = Int(timeElapsed) % 60
        
        guard seconds == 0 && !triggeredMilestones.contains(minutes) else { return }
        
        let sessionType = sessionManager.sessionType ?? .sauna
        var message: String?
        
        switch minutes {
        case 5:
            message = getEncouragementMessage(for: sessionType, milestone: .fiveMinutes)
        case 10:
            message = getEncouragementMessage(for: sessionType, milestone: .tenMinutes)
        case 15:
            message = getEncouragementMessage(for: sessionType, milestone: .fifteenMinutes)
        case 20:
            message = getEncouragementMessage(for: sessionType, milestone: .twentyMinutes)
        default:
            break
        }
        
        if let encouragementMessage = message {
            triggeredMilestones.insert(minutes)
            showEncouragementPopup(message: encouragementMessage)
        }
    }
    
    private func showEncouragementPopup(message: String) {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            currentEncouragementMessage = message
            showingEncouragementPopup = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            withAnimation(.easeOut(duration: 0.5)) {
                showingEncouragementPopup = false
            }
        }
    }
    
    private func getEncouragementMessage(for sessionType: SessionType, milestone: EncouragementMilestone) -> String {
        switch sessionType {
        case .sauna:
            return getSaunaEncouragementMessage(for: milestone)
        case .cold:
            return getColdEncouragementMessage(for: milestone)
        }
    }
    
    private func getSaunaEncouragementMessage(for milestone: EncouragementMilestone) -> String {
        switch milestone {
        case .fiveMinutes:
            return "🌡️ Great start! You've already boosted circulation and lowered stress hormones — keep going for muscle relaxation!"
        case .tenMinutes:
            return "🔥 Nice work! You've burned about 30 calories and improved circulation. Stay longer for deeper detox and cardiovascular benefits."
        case .fifteenMinutes:
            return "💪 Excellent! Heart rate is up, sweating is at its peak. You're burning up to 60 calories and unlocking recovery mode."
        case .twentyMinutes:
            return "🏆 Amazing! You've activated heat shock proteins for cellular repair and long-term health resilience. Maximum benefits achieved!"
        }
    }
    
    private func getColdEncouragementMessage(for milestone: EncouragementMilestone) -> String {
        switch milestone {
        case .fiveMinutes:
            return "🧊 Incredible willpower! You've triggered norepinephrine release and boosted mental resilience — push through for more benefits!"
        case .tenMinutes:
            return "❄️ Outstanding! You've activated brown fat burning and improved cold tolerance. Keep going for maximum metabolic boost!"
        case .fifteenMinutes:
            return "🌊 Phenomenal! You're maximizing dopamine release and building serious mental toughness. Elite-level cold exposure!"
        case .twentyMinutes:
            return "⚡ Legendary! You've achieved peak cold adaptation benefits. Your metabolism and mental strength are through the roof!"
        }
    }
}

// MARK: - Encouragement System
enum EncouragementMilestone {
    case fiveMinutes
    case tenMinutes
    case fifteenMinutes
    case twentyMinutes
}

struct EncouragementPopupView: View {
    let message: String
    let sessionType: SessionType?
    @Binding var isShowing: Bool
    @State private var animateIn = false
    
    var body: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 12) {
                Image(systemName: sessionType == .sauna ? "flame.fill" : "snowflake")
                    .font(.title)
                    .foregroundColor(sessionType == .sauna ? .orange : .cyan)
                    .scaleEffect(animateIn ? 1.2 : 0.8)
                    .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.2), value: animateIn)
                
                Text(message)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                    .padding(.horizontal, 8)
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.9))
                    .stroke(
                        LinearGradient(
                            colors: sessionType == .sauna ? 
                                [.orange.opacity(0.6), .red.opacity(0.4)] :
                                [.cyan.opacity(0.6), .blue.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .shadow(
                        color: sessionType == .sauna ? .orange.opacity(0.3) : .cyan.opacity(0.3),
                        radius: 15,
                        x: 0,
                        y: 5
                    )
            )
            .scaleEffect(animateIn ? 1.0 : 0.7)
            .opacity(animateIn ? 1.0 : 0.0)
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: animateIn)
            
            Spacer()
        }
        .padding(.horizontal, 40)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animateIn = true
            }
        }
        .onTapGesture {
            withAnimation(.easeOut(duration: 0.3)) {
                isShowing = false
            }
        }
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
            
            // Main infinity icon - Use the asset file
            Image("InfinityIcon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .opacity(isRunning ? 1.0 : 0.6)
                .modifier(PulsingGlowModifier(
                    isActive: isRunning,
                    color: sessionType == .sauna ? .orange : .cyan
                ))
            
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
                // Full button gradient background
                RoundedRectangle(cornerRadius: 25)
                    .fill(
                        LinearGradient(
                            colors: [
                                glowColor.opacity(0.15),
                                glowColor.opacity(0.08),
                                glowColor.opacity(0.04),
                                glowColor.opacity(0.0)
                            ],
                            startPoint: fadeDirection == .topToBottom ? .top : .bottom,
                            endPoint: fadeDirection == .topToBottom ? .bottom : .top
                        )
                    )
                    .blur(radius: 8)
                
                // Button border with full gradient
                RoundedRectangle(cornerRadius: 25)
                    .stroke(
                        LinearGradient(
                            colors: fadeDirection == .topToBottom ? [
                                Color.gray.opacity(0.4),
                                Color.gray.opacity(0.3),
                                Color.gray.opacity(0.15),
                                Color.gray.opacity(0.0)
                            ] : [
                                Color.gray.opacity(0.0),
                                Color.gray.opacity(0.15),
                                Color.gray.opacity(0.3),
                                Color.gray.opacity(0.4)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1.5
                    )
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                
                // Text content
                Text(title)
                    .font(.system(size: 16, weight: .light, design: .monospaced))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .opacity(isPressed ? 0.8 : 1.0)
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
            .scaleEffect(1.0)
            .onChange(of: isActive) { active in
                if active {
                    withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                        glowIntensity = 0.8
                    }
                    withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                        colorIntensity = 1.3
                    }
                } else {
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
    @State private var viewSize: CGSize = .zero
    
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
            .onAppear {
                viewSize = geometry.size
                startEmberAnimation()
            }
            .onChange(of: geometry.size) { newSize in
                viewSize = newSize
            }
        }
    }
    
    private func startEmberAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            addEmber()
        }
    }
    
    private func addEmber() {
        let centerX = viewSize.width / 2
        let centerY = viewSize.height / 2
        let newEmber = EmberParticle(centerX: centerX, centerY: centerY)
        embers.append(newEmber)
        
        withAnimation(.easeOut(duration: 2.0)) {
            if let index = embers.firstIndex(where: { $0.id == newEmber.id }) {
                embers[index].position.y -= 150
                embers[index].position.x += Double.random(in: -20...20)
                embers[index].opacity = 0
                embers[index].size *= 0.3
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            embers.removeAll { $0.id == newEmber.id }
        }
    }
}

struct SnowflakesView: View {
    @State private var snowflakes: [SnowflakeParticle] = []
    @State private var viewSize: CGSize = .zero
    
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
            .onAppear {
                viewSize = geometry.size
                startSnowflakeAnimation()
            }
            .onChange(of: geometry.size) { newSize in
                viewSize = newSize
            }
        }
    }
    
    private func startSnowflakeAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
            addSnowflake()
        }
    }
    
    private func addSnowflake() {
        let centerX = viewSize.width / 2
        let centerY = viewSize.height / 2
        let newSnowflake = SnowflakeParticle(centerX: centerX, centerY: centerY)
        snowflakes.append(newSnowflake)
        
        withAnimation(.linear(duration: 3.0)) {
            if let index = snowflakes.firstIndex(where: { $0.id == newSnowflake.id }) {
                snowflakes[index].position.y += 200
                snowflakes[index].position.x += Double.random(in: -10...10)
                snowflakes[index].opacity = 0
                snowflakes[index].rotation += 180
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            snowflakes.removeAll { $0.id == newSnowflake.id }
        }
    }
}

struct EmberParticle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var size = Double.random(in: 3...8)
    var opacity = Double.random(in: 0.6...1.0)
    var blur = Double.random(in: 0...2)
    
    init(centerX: Double, centerY: Double) {
        self.position = CGPoint(
            x: centerX + Double.random(in: -20...20),
            y: centerY + Double.random(in: -10...10)
        )
    }
}

struct SnowflakeParticle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var size = Double.random(in: 8...16)
    var opacity = Double.random(in: 0.5...0.9)
    var rotation = Double.random(in: 0...360)
    
    init(centerX: Double, centerY: Double) {
        self.position = CGPoint(
            x: centerX + Double.random(in: -30...30),
            y: centerY + Double.random(in: -20...0)
        )
    }
}
