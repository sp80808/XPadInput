import SwiftUI
import XPadController

/// A polished, high-performance HUD for visualising rich analog stick telemetry.
public struct AnalogStickHUD: View {
    public let state: ProcessedStickState
    public let color: Color
    public let label: String
    
    public init(state: ProcessedStickState, color: Color = .blue, label: String = "L") {
        self.state = state
        self.color = color
        self.label = label
    }
    
    public var body: some View {
        ZStack {
            // Background
            Circle()
                .fill(Color.black.opacity(0.4))
                .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
                .overlay {
                    // Near-edge ring pulse — layout-safe overlay
                    Circle()
                        .stroke(Color.orange.opacity(0.0), lineWidth: 1)
                        .xPulse(isActive: state.isNearEdge, color: .orange, speed: 1.2)
                }
                
            // Grid lines
            Path { path in
                let size: CGFloat = 100
                path.move(to: CGPoint(x: size/2, y: 0))
                path.addLine(to: CGPoint(x: size/2, y: size))
                path.move(to: CGPoint(x: 0, y: size/2))
                path.addLine(to: CGPoint(x: size, y: size/2))
            }
            .stroke(Color.white.opacity(0.1), lineWidth: 1)
            
            // Raw input ghost
            Circle()
                .fill(color.opacity(0.2))
                .frame(width: 16, height: 16)
                .offset(x: CGFloat(state.rawX) * 50, y: CGFloat(-state.rawY) * 50)
            
            // Processed stick position
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [color.opacity(0.8), color]),
                        center: .center,
                        startRadius: 0,
                        endRadius: 10
                    )
                )
                .frame(width: 20, height: 20)
                .shadow(color: color.opacity(0.5), radius: state.isNearEdge ? 8 : 4)
                .offset(x: CGFloat(state.x) * 50, y: CGFloat(-state.y) * 50)
            
            // Velocity pulse indicator when moving quickly
            if state.movementVelocity > 0.5 {
                VelocityPulse(color: color, velocity: state.movementVelocity)
                    .frame(width: 24, height: 24)
                    .offset(x: CGFloat(state.x) * 50, y: CGFloat(-state.y) * 50)
                    .id(state.movementVelocity)  // re-trigger onAppear each time velocity changes
            }
            
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(0.5))
                .offset(y: -65)
        }
        .frame(width: 100, height: 100)
    }
}

/// HUD for analog triggers displaying attack velocity and hold duration.
public struct AnalogTriggerHUD: View {
    public let state: ProcessedTriggerState
    public let color: Color
    public let label: String
    
    public init(state: ProcessedTriggerState, color: Color = .red, label: String = "L2") {
        self.state = state
        self.color = color
        self.label = label
    }
    
    public var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(0.5))
            
            ZStack(alignment: .bottom) {
                // Background
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.black.opacity(0.4))
                    .frame(width: 30, height: 100)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.1), lineWidth: 1))
                
                // Raw ghost
                RoundedRectangle(cornerRadius: 6)
                    .fill(color.opacity(0.2))
                    .frame(width: 30, height: CGFloat(state.rawValue) * 100)
                
                // Processed fill
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [color.opacity(0.6), color]),
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 30, height: CGFloat(state.value) * 100)
                    .shadow(color: color.opacity(0.5 * Double(state.value)), radius: 4)
                
                // Attack transient flash
                if state.attackVelocity > 0 {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(Double(min(1.0, state.attackVelocity))))
                        .frame(width: 30, height: CGFloat(state.value) * 100)
                        .blendMode(.overlay)
                        .animation(.easeOut(duration: 0.12), value: state.attackVelocity)
                }
            }
        }
    }
}

/// A subtle pulse animation effect driven by velocity.
public struct VelocityPulse: View {
    public let color: Color
    public let velocity: Float
    
    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 0.5
    
    public init(color: Color, velocity: Float) {
        self.color = color
        self.velocity = velocity
    }
    
    public var body: some View {
        Circle()
            .stroke(color, lineWidth: 2)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                // Reset then animate — .id(velocity) on parent ensures re-trigger each appearance
                scale   = 1.0
                opacity = 0.5
                let intensity = Double(min(1.0, velocity / 10.0))
                withAnimation(.easeOut(duration: 0.3 * (1.0 - intensity))) {
                    scale   = 1.0 + CGFloat(intensity) * 1.5
                    opacity = 0.0
                }
            }
    }
}

/// HUD displaying dynamic DualSense adaptive motor resistance feedback and detents.
public struct AdaptiveTriggerVisualizerHUD: View {
    public let feedbackState: AdaptiveTriggerFeedbackState
    public let label: String
    public let accentColor: Color

    public init(
        feedbackState: AdaptiveTriggerFeedbackState,
        label: String = "Adaptive Trigger",
        accentColor: Color = .green
    ) {
        self.feedbackState = feedbackState
        self.label = label
        self.accentColor = accentColor
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(accentColor)
                    Text(label)
                        .font(.system(size: 11, weight: .bold))
                }
                Spacer()
                Text(feedbackState.activeMode.displayName)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(accentColor)
            }

            // Dual bar: Position vs Resistive Motor Force with Detent Notches
            HStack(spacing: 10) {
                // Position Bar
                VStack(spacing: 2) {
                    Text("Pos")
                        .font(.system(size: 8))
                        .foregroundStyle(XTheme.textTertiary)
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 14, height: 54)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                LinearGradient(
                                    colors: [accentColor.opacity(0.5), accentColor],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .frame(width: 14, height: CGFloat(feedbackState.triggerPosition) * 54)
                            .xGlow(isActive: feedbackState.triggerPosition > 0.05, color: accentColor)
                    }
                }

                // Force Bar with Detent Ticks
                VStack(spacing: 2) {
                    Text("Force")
                        .font(.system(size: 8))
                        .foregroundStyle(XTheme.textTertiary)
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 14, height: 54)

                        // Detent Notch Markings (if in detent mode)
                        if feedbackState.activeMode == .modWheelDetents {
                            VStack(spacing: 5) {
                                ForEach(0..<8) { _ in
                                    Rectangle()
                                        .fill(Color.white.opacity(0.25))
                                        .frame(width: 14, height: 1)
                                }
                            }
                            .frame(height: 54)
                        }

                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        feedbackState.isInDetent ? Color.orange : Color.red.opacity(0.6),
                                        feedbackState.isInDetent ? Color.yellow : Color.red
                                    ],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .frame(width: 14, height: CGFloat(feedbackState.calculatedForce) * 54)
                            .xGlow(isActive: feedbackState.calculatedForce > 0.1, color: feedbackState.isInDetent ? .orange : .red)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(feedbackState.statusDescription)
                        .font(.system(size: 10))
                        .foregroundStyle(XTheme.textPrimary)
                        .lineLimit(2)

                    if feedbackState.isInDetent, let idx = feedbackState.activeDetentIndex {
                        HStack(spacing: 4) {
                            Image(systemName: "circle.circle.fill")
                                .font(.system(size: 7))
                                .foregroundStyle(Color.orange)
                            Text("Notch #\(idx) Locked")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color.orange)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: XTheme.radiusSmall)
                .fill(XTheme.surface.opacity(0.8))
        )
        .overlay(
            RoundedRectangle(cornerRadius: XTheme.radiusSmall)
                .stroke(XTheme.border, lineWidth: 1)
        )
        .xShimmer(isActive: feedbackState.isInDetent)
    }
}
