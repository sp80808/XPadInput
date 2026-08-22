import SwiftUI
import XPadCore
import XPadAudio
import XPadController

/// Interactive 3D Spatial Audio & IMU Gyro Panning Visualizer.
public struct SpatialAudioVisualizerView: View {
    @Environment(AppState.self) private var appState
    @State private var pulseAnimation = false

    public init() {}

    public var body: some View {
        VStack(spacing: 12) {
            // Header: Mode Selector & Enable Toggle
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "headphones")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(XTheme.primary)
                    Text("3D SPATIAL AUDIO & GYRO PANNER")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(XTheme.textPrimary)
                }

                Spacer()

                // Mode Picker
                Picker("", selection: Binding(
                    get: { appState.audioEngine.spatialEngine.mode },
                    set: { appState.audioEngine.setSpatialMode($0) }
                )) {
                    ForEach(SpatialAudioMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 180)

                Toggle("", isOn: Binding(
                    get: { appState.audioEngine.spatialEngine.isEnabled },
                    set: { appState.audioEngine.setSpatialEnabled($0) }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
                .scaleEffect(0.7)
            }

            // Radar & Telemetry Display
            HStack(spacing: 16) {
                // 3D Polar Radar
                ZStack {
                    // Background Polar Rings
                    Circle()
                        .stroke(XTheme.border.opacity(0.4), lineWidth: 1)
                        .frame(width: 140, height: 140)
                    Circle()
                        .stroke(XTheme.border.opacity(0.6), lineWidth: 1)
                        .frame(width: 95, height: 95)
                    Circle()
                        .stroke(XTheme.border.opacity(0.8), lineWidth: 1)
                        .frame(width: 50, height: 50)

                    // Axes (Horizontal & Vertical)
                    Path { path in
                        path.move(to: CGPoint(x: 70, y: 0))
                        path.addLine(to: CGPoint(x: 70, y: 140))
                        path.move(to: CGPoint(x: 0, y: 70))
                        path.addLine(to: CGPoint(x: 140, y: 70))
                    }
                    .stroke(XTheme.border.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))

                    // Listener Head Indicator at Center
                    Circle()
                        .fill(XTheme.surfaceElevated)
                        .frame(width: 22, height: 22)
                        .overlay(
                            Circle().stroke(XTheme.primary.opacity(0.8), lineWidth: 1.5)
                        )
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(XTheme.primary)
                        )

                    // Sound Source Vector Point
                    let coords = appState.audioEngine.spatialEngine.currentCoordinates
                    let azRad = Double(coords.azimuthDegrees) * .pi / 180.0
                    let distNormalized = min(1.0, Double(coords.distanceMeters) / 3.0)
                    let radius = 60.0 * distNormalized
                    let sourceX = 70.0 + radius * sin(azRad)
                    let sourceY = 70.0 - radius * cos(azRad)

                    // Vector line from listener to source
                    Path { path in
                        path.move(to: CGPoint(x: 70, y: 70))
                        path.addLine(to: CGPoint(x: sourceX, y: sourceY))
                    }
                    .stroke(
                        LinearGradient(
                            colors: [XTheme.primary.opacity(0.2), XTheme.primary],
                            startPoint: .center,
                            endPoint: UnitPoint(x: sourceX / 140.0, y: sourceY / 140.0)
                        ),
                        lineWidth: 2
                    )

                    // Audio Source Node with Pulse Ring
                    Circle()
                        .fill(XTheme.primary.opacity(0.25))
                        .frame(width: 20, height: 20)
                        .scaleEffect(pulseAnimation ? 1.4 : 1.0)
                        .opacity(pulseAnimation ? 0.0 : 0.8)
                        .position(x: sourceX, y: sourceY)

                    Circle()
                        .fill(XTheme.primary)
                        .frame(width: 10, height: 10)
                        .shadow(color: XTheme.primary.opacity(0.8), radius: 6)
                        .position(x: sourceX, y: sourceY)
                }
                .frame(width: 140, height: 140)
                .background(XTheme.surface.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(XTheme.border, lineWidth: 1)
                )
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false)) {
                        pulseAnimation = true
                    }
                }

                // Spatial & Gyro IMU Telemetry
                VStack(alignment: .leading, spacing: 8) {
                    let coords = appState.audioEngine.spatialEngine.currentCoordinates

                    VStack(alignment: .leading, spacing: 4) {
                        telemetryRow(label: "Azimuth", value: String(format: "%+.1f°", coords.azimuthDegrees), icon: "arrow.left.and.right")
                        telemetryRow(label: "Elevation", value: String(format: "%+.1f°", coords.elevationDegrees), icon: "arrow.up.and.down")
                        telemetryRow(label: "Distance", value: String(format: "%.2f m", coords.distanceMeters), icon: "ruler")
                    }

                    Divider().background(XTheme.border.opacity(0.6))

                    // Haptics Quick Control
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "waveform")
                                .font(.system(size: 10))
                                .foregroundStyle(XTheme.textSecondary)
                            Text("DualSense Haptics")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(XTheme.textSecondary)
                            Spacer()
                            Text(appState.controllerManager.coreHapticsEngine.isRunning ? "Active" : "Standby")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(appState.controllerManager.coreHapticsEngine.isRunning ? XTheme.controllerConnected : XTheme.textTertiary)
                        }

                        Picker("", selection: Binding(
                            get: { appState.controllerManager.coreHapticsEngine.mode },
                            set: { appState.controllerManager.coreHapticsEngine.mode = $0 }
                        )) {
                            ForEach(HapticFeedbackMode.allCases) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .background(XTheme.surfaceElevated.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(XTheme.border, lineWidth: 1)
        )
    }

    private func telemetryRow(label: String, value: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundStyle(XTheme.textTertiary)
                .frame(width: 12)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(XTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(XTheme.textPrimary)
        }
    }
}
