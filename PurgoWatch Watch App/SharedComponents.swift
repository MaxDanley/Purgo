//
//  SharedComponents.swift
//  PurgoWatch
//
//  Created by Max Danley on 8/27/25.
//

import SwiftUI

// MARK: - Watch Session Button (Adapted from main app)
enum FadeDirection {
    case topToBottom
    case bottomToTop
}

struct WatchSessionButton: View {
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
                RoundedRectangle(cornerRadius: 15)
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
                    .blur(radius: 4)
                
                // Button border with full gradient
                RoundedRectangle(cornerRadius: 15)
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
                        lineWidth: 1.0
                    )
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                
                // Text content
                Text(title)
                    .font(.system(size: 11, weight: .light, design: .monospaced))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .multilineTextAlignment(.center)
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
        .contentShape(RoundedRectangle(cornerRadius: 15))
    }
}

// MARK: - Infinity Icon View (Adapted for Watch)
struct InfinityIconView: View {
    @Binding var animateSauna: Bool
    @Binding var animateCold: Bool
    let sessionType: SessionType?
    let isRunning: Bool
    let progressPercentage: Double
    
    var body: some View {
        ZStack {
            // Fire embers for sauna (simplified for watch)
            if sessionType == .sauna && isRunning {
                FireEmbersView()
            }
            
            // Snowflakes for cold (simplified for watch)
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
                    .stroke(Color.white.opacity(0.2), lineWidth: 2)
                    .overlay(
                        Circle()
                            .trim(from: 0, to: progressPercentage)
                            .stroke(
                                sessionType == .sauna ? 
                                LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing) :
                                LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing),
                                style: StrokeStyle(lineWidth: 2, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.5), value: progressPercentage)
                    )
                    .padding(6)
            }
        }
    }
}

// MARK: - Animation Components (Simplified for Watch)

struct PulsingGlowModifier: ViewModifier {
    let isActive: Bool
    let color: Color
    @State private var glowIntensity: Double = 0.0
    
    func body(content: Content) -> some View {
        content
            .shadow(color: isActive ? color.opacity(glowIntensity) : .clear, radius: isActive ? 8 : 0)
            .scaleEffect(1.0)
            .onChange(of: isActive) { newValue in
                if newValue {
                    withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                        glowIntensity = 0.6
                    }
                } else {
                    withAnimation(.easeOut(duration: 0.5)) {
                        glowIntensity = 0.0
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
            .onChange(of: geometry.size) { newValue in
                viewSize = newValue
            }
        }
    }
    
    private func startEmberAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
            addEmber()
        }
    }
    
    private func addEmber() {
        let centerX = viewSize.width / 2
        let centerY = viewSize.height / 2
        let newEmber = EmberParticle(centerX: centerX, centerY: centerY)
        embers.append(newEmber)
        
        withAnimation(.easeOut(duration: 1.5)) {
            if let index = embers.firstIndex(where: { $0.id == newEmber.id }) {
                embers[index].position.y -= 80
                embers[index].position.x += Double.random(in: -10...10)
                embers[index].opacity = 0
                embers[index].size *= 0.3
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
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
            .onChange(of: geometry.size) { newValue in
                viewSize = newValue
            }
        }
    }
    
    private func startSnowflakeAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            addSnowflake()
        }
    }
    
    private func addSnowflake() {
        let centerX = viewSize.width / 2
        let centerY = viewSize.height / 2
        let newSnowflake = SnowflakeParticle(centerX: centerX, centerY: centerY)
        snowflakes.append(newSnowflake)
        
        withAnimation(.linear(duration: 2.0)) {
            if let index = snowflakes.firstIndex(where: { $0.id == newSnowflake.id }) {
                snowflakes[index].position.y += 100
                snowflakes[index].position.x += Double.random(in: -5...5)
                snowflakes[index].opacity = 0
                snowflakes[index].rotation += 180
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            snowflakes.removeAll { $0.id == newSnowflake.id }
        }
    }
}

struct EmberParticle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var size = Double.random(in: 2...5)
    var opacity = Double.random(in: 0.6...1.0)
    var blur = Double.random(in: 0...1)
    
    init(centerX: Double, centerY: Double) {
        self.position = CGPoint(
            x: centerX + Double.random(in: -10...10),
            y: centerY + Double.random(in: -5...5)
        )
    }
}

struct SnowflakeParticle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var size = Double.random(in: 6...12)
    var opacity = Double.random(in: 0.5...0.9)
    var rotation = Double.random(in: 0...360)
    
    init(centerX: Double, centerY: Double) {
        self.position = CGPoint(
            x: centerX + Double.random(in: -15...15),
            y: centerY + Double.random(in: -10...0)
        )
    }
}
