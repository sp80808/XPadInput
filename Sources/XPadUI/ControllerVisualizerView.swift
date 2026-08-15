import SwiftUI
import XPadCore
import XPadController

/// Live interactive controller visualiser showing all inputs and their musical assignments.
struct ControllerVisualizerView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        let state = appState.controllerManager.controllerState
        let isConnected = appState.controllerManager.isConnected
        let hasLiveInput = isConnected || state.hasVisiblePerformanceInput
        
        VStack(spacing: 18) {
            // Header
            HStack {
                Image(systemName: isConnected ? "gamecontroller.fill" : "gamecontroller")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isConnected ? XTheme.controllerConnected : XTheme.controllerDisconnected)
                
                Text(isConnected ? appState.controllerManager.controllerName : appState.controllerManager.controllerKind.rawValue)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(XTheme.textPrimary)
                    .lineLimit(1)
                
                Spacer()

                if let profile = appState.controllerManager.capabilityProfile {
                    Text(profile.capabilitySummary)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(XTheme.textTertiary)
                }

                Text(isConnected ? "LIVE" : hasLiveInput ? "SIM" : "PREVIEW")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(isConnected ? XTheme.controllerConnected : XTheme.warning)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill((isConnected ? XTheme.controllerConnected : XTheme.warning).opacity(0.10))
                    )
                    .overlay(
                        Capsule().stroke((isConnected ? XTheme.controllerConnected : XTheme.warning).opacity(0.26), lineWidth: 1)
                    )
            }

            ControllerPerformanceHUD(
                state: state,
                controllerKind: appState.controllerManager.controllerKind,
                isConnected: isConnected,
                labels: appState.hudLabels,
                frame: hasLiveInput ? appState.lastFrame : nil,
                instrument: appState.instrumentProfile,
                duoMode: appState.duoPerformanceMode,
                currentChord: appState.currentChord,
                lastVelocity: hasLiveInput ? appState.lastVelocity : 0,
                lastStrumDirection: hasLiveInput ? appState.lastStrumDirection : .none
            )
        }
        .padding(18)
        .xCard(isActive: isConnected)
    }
}

// MARK: - Stick Visualizer

struct StickVisualizer: View {
    let label: String
    let x: Float
    let y: Float
    let isPressed: Bool
    let role: String
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // Background circle
                Circle()
                    .stroke(XTheme.border, lineWidth: 1)
                    .frame(width: 70, height: 70)
                
                // Crosshair
                Path { path in
                    path.move(to: CGPoint(x: 35, y: 15))
                    path.addLine(to: CGPoint(x: 35, y: 55))
                    path.move(to: CGPoint(x: 15, y: 35))
                    path.addLine(to: CGPoint(x: 55, y: 35))
                }
                .stroke(XTheme.border, lineWidth: 0.5)
                .frame(width: 70, height: 70)
                
                // Stick position
                let dotX = 35 + CGFloat(x) * 25
                let dotY = 35 - CGFloat(y) * 25 // Invert Y
                
                Circle()
                    .fill(isPressed ? XTheme.accent : XTheme.primary)
                    .frame(width: isPressed ? 14 : 10, height: isPressed ? 14 : 10)
                    .xGlow(isActive: abs(x) > 0.1 || abs(y) > 0.1)
                    .position(x: dotX, y: dotY)
                    .animation(.linear(duration: 0.03), value: dotX)
                    .animation(.linear(duration: 0.03), value: dotY)
            }
            .frame(width: 70, height: 70)
            
            VStack(spacing: 1) {
                Text(label)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(XTheme.textSecondary)
                
                Text(role)
                    .font(.system(size: 8))
                    .foregroundColor(XTheme.textTertiary)
            }
        }
    }
}

// MARK: - Button Indicators

struct ButtonIndicator: View {
    let label: String
    let isPressed: Bool
    let role: String
    
    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(isPressed ? .white : XTheme.textTertiary)
                .frame(width: 32, height: 20)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isPressed ? XTheme.primary : XTheme.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(isPressed ? XTheme.primary : XTheme.border, lineWidth: 1)
                        )
                )
            
            Text(role)
                .font(.system(size: 7))
                .foregroundColor(XTheme.textTertiary)
        }
    }
}

struct TriggerIndicator: View {
    let label: String
    let value: Float
    let role: String
    
    var body: some View {
        VStack(spacing: 2) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(XTheme.surface)
                    .frame(width: 28, height: 30)
                
                RoundedRectangle(cornerRadius: 3)
                    .fill(XTheme.primaryGradient)
                    .frame(width: 28, height: CGFloat(value) * 30)
                
                Text(label)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(value > 0.5 ? .white : XTheme.textTertiary)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(value > 0.1 ? XTheme.primary.opacity(0.5) : XTheme.border, lineWidth: 1)
            )
            .frame(width: 28, height: 30)
            
            Text(role)
                .font(.system(size: 7))
                .foregroundColor(XTheme.textTertiary)
        }
    }
}

// MARK: - Face Buttons

struct FaceButtonsView: View {
    let state: ControllerState
    
    var body: some View {
        VStack(spacing: 2) {
            // Triangle/Y
            FaceButton(label: "△", isPressed: state.buttonY, color: XTheme.primary)
            
            HStack(spacing: 12) {
                // Square/X
                FaceButton(label: "□", isPressed: state.buttonX, color: XTheme.colourful)
                // Circle/B
                FaceButton(label: "○", isPressed: state.buttonB, color: XTheme.tense)
            }
            
            // Cross/A
            FaceButton(label: "✕", isPressed: state.buttonA, color: XTheme.natural)
        }
    }
}

struct FaceButton: View {
    let label: String
    let isPressed: Bool
    let color: Color
    
    var body: some View {
        Text(label)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(isPressed ? .white : XTheme.textTertiary)
            .frame(width: 24, height: 24)
            .background(
                Circle()
                    .fill(isPressed ? color : XTheme.surface)
                    .overlay(
                        Circle()
                            .stroke(isPressed ? color : XTheme.border, lineWidth: 1)
                    )
            )
            .xGlow(isActive: isPressed, color: color)
    }
}

// MARK: - D-Pad

struct DPadView: View {
    let state: ControllerState
    
    var body: some View {
        VStack(spacing: 0) {
            DPadArrow(direction: "chevron.up", isPressed: state.dpadUp)
            HStack(spacing: 8) {
                DPadArrow(direction: "chevron.left", isPressed: state.dpadLeft)
                Circle()
                    .fill(XTheme.surface)
                    .frame(width: 12, height: 12)
                DPadArrow(direction: "chevron.right", isPressed: state.dpadRight)
            }
            DPadArrow(direction: "chevron.down", isPressed: state.dpadDown)
        }
    }
}

struct DPadArrow: View {
    let direction: String
    let isPressed: Bool
    
    var body: some View {
        Image(systemName: direction)
            .font(.system(size: 8, weight: .bold))
            .foregroundColor(isPressed ? XTheme.primary : XTheme.textTertiary)
            .frame(width: 18, height: 18)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(isPressed ? XTheme.primary.opacity(0.2) : .clear)
            )
    }
}

// MARK: - Motion Data

struct MotionDataView: View {
    let state: ControllerState
    
    var body: some View {
        HStack(spacing: 16) {
            MotionAxis(label: "Gyro", x: state.gyroX, y: state.gyroY, z: state.gyroZ)
            MotionAxis(label: "Accel", x: state.accelX, y: state.accelY, z: state.accelZ)
        }
        .padding(8)
        .xCard()
    }
}

struct MotionAxis: View {
    let label: String
    let x: Double
    let y: Double
    let z: Double
    
    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(XTheme.textTertiary)
            
            HStack(spacing: 4) {
                AxisValue(axis: "X", value: x)
                AxisValue(axis: "Y", value: y)
                AxisValue(axis: "Z", value: z)
            }
        }
    }
}

struct AxisValue: View {
    let axis: String
    let value: Double
    
    var body: some View {
        Text("\(axis):\(value, specifier: "%.1f")")
            .font(.system(size: 8, design: .monospaced))
            .foregroundColor(abs(value) > 0.5 ? XTheme.accent : XTheme.textTertiary)
    }
}
