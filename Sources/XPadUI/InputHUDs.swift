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
                let intensity = Double(min(1.0, velocity / 10.0))
                withAnimation(.easeOut(duration: 0.3 * (1.0 - intensity)).repeatForever(autoreverses: false)) {
                    scale = 1.0 + CGFloat(intensity) * 1.5
                    opacity = 0.0
                }
            }
    }
}
