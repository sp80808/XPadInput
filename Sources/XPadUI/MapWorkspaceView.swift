import SwiftUI
import XPadCore
import XPadController

public struct MapWorkspaceView: View {
    @ObservedObject var controllerManager: ControllerManager

    public init(controllerManager: ControllerManager) {
        self.controllerManager = controllerManager
    }

    private var state: GamepadState {
        controllerManager.currentState
    }

    public var body: some View {
        HSplitView {
            // Left: Controller Visualizer & HUD
            VStack(spacing: 20) {
                HStack {
                    Image(systemName: "gamecontroller.fill")
                        .font(.title2)
                    Text(controllerManager.controllerKind.rawValue)
                        .font(.headline)
                    Spacer()
                    Text(controllerManager.isHardwareConnected ? "Hardware Connected" : "Simulated Fallback")
                        .font(.caption)
                        .foregroundStyle(controllerManager.isHardwareConnected ? .green : .orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Material.ultraThinMaterial)
                        .clipShape(Capsule())
                }

                // Controller Diagram Card
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.black.opacity(0.35))
                        .frame(height: 280)
                        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.1), lineWidth: 1))

                    HStack(spacing: 40) {
                        // Left Stick & D-Pad
                        VStack(spacing: 16) {
                            stickVisualizer(label: "Left Stick (Harmonic Wheel)", stick: state.leftStick)
                            dpadVisualizer
                        }

                        // Center Gyro / IMU Status
                        VStack(spacing: 10) {
                            Text("6-Axis IMU Motion")
                                .font(.caption2.bold())
                                .foregroundStyle(.secondary)
                            Text("Pitch: \(String(format: "%.2f", state.gyroPitch))")
                                .font(.caption.monospaced())
                            Text("Roll: \(String(format: "%.2f", state.gyroRoll))")
                                .font(.caption.monospaced())
                            Text("Yaw: \(String(format: "%.2f", state.gyroYaw))")
                                .font(.caption.monospaced())
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        // Right Stick & Face Buttons
                        VStack(spacing: 16) {
                            faceButtonsVisualizer
                            stickVisualizer(label: "Right Stick (Strum)", stick: state.rightStick)
                        }
                    }
                }

                // Triggers & Shoulders Gauges
                HStack(spacing: 20) {
                    triggerGauge(label: "Left Trigger (L2 / Mute)", value: state.leftTrigger)
                    triggerGauge(label: "Right Trigger (R2 / Expression)", value: state.rightTrigger)
                }
            }
            .padding()
            .frame(minWidth: 440)

            // Right: Gesture-to-Music Modulation Matrix
            VStack(alignment: .leading, spacing: 16) {
                Text("Modulation & Gesture Matrix")
                    .font(.headline)

                ScrollView {
                    VStack(spacing: 12) {
                        modulationRow(source: "Left Stick Angle", dest: "Harmonic Wheel Sector", amount: "100%")
                        modulationRow(source: "Left Stick Radius", dest: "Harmonic Risk / Extensions", amount: "75%")
                        modulationRow(source: "Right Stick Velocity", dest: "Strum Dynamics & Velocity", amount: "100%")
                        modulationRow(source: "Left Trigger (L2)", dest: "Palm Mute & Filter Decay", amount: "100%")
                        modulationRow(source: "Motion Gyro Tilt", dest: "MPE Pitch Bend (±48 Semitones)", amount: "50%")
                        modulationRow(source: "Touchpad Y-Axis", dest: "MPE Timbre (CC 74)", amount: "80%")
                    }
                }
            }
            .padding()
            .frame(minWidth: 340)
        }
    }

    private func stickVisualizer(label: String, stick: StickCoordinates) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 2)
                    .frame(width: 70, height: 70)
                Circle()
                    .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                    .frame(width: 70 * CGFloat(stick.deadzone), height: 70 * CGFloat(stick.deadzone))
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 18, height: 18)
                    .offset(x: CGFloat(stick.x) * 26, y: -CGFloat(stick.y) * 26)
            }
        }
    }

    private var dpadVisualizer: some View {
        VStack(spacing: 2) {
            Circle().fill(state.dpadUp ? Color.green : Color.white.opacity(0.2)).frame(width: 8, height: 8)
            HStack(spacing: 8) {
                Circle().fill(state.dpadLeft ? Color.green : Color.white.opacity(0.2)).frame(width: 8, height: 8)
                Circle().fill(state.dpadRight ? Color.green : Color.white.opacity(0.2)).frame(width: 8, height: 8)
            }
            Circle().fill(state.dpadDown ? Color.green : Color.white.opacity(0.2)).frame(width: 8, height: 8)
        }
    }

    private var faceButtonsVisualizer: some View {
        VStack(spacing: 2) {
            buttonIndicator(label: "△", isPressed: state.buttonY)
            HStack(spacing: 12) {
                buttonIndicator(label: "□", isPressed: state.buttonX)
                buttonIndicator(label: "○", isPressed: state.buttonB)
            }
            buttonIndicator(label: "✕", isPressed: state.buttonA)
        }
    }

    private func buttonIndicator(label: String, isPressed: Bool) -> some View {
        Text(label)
            .font(.caption.bold())
            .frame(width: 22, height: 22)
            .background(isPressed ? Color.green : Color.white.opacity(0.15))
            .foregroundStyle(isPressed ? Color.black : Color.white)
            .clipShape(Circle())
    }

    private func triggerGauge(label: String, value: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(label): \(Int(value * 100))%")
                .font(.caption2)
                .foregroundStyle(.secondary)
            ProgressView(value: value, total: 1.0)
                .tint(.accentColor)
        }
        .padding(10)
        .background(Material.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func modulationRow(source: String, dest: String, amount: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(source)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("→ \(dest)")
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
            }
            Spacer()
            Text(amount)
                .font(.caption.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.1))
                .clipShape(Capsule())
        }
        .padding(10)
        .background(Material.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
