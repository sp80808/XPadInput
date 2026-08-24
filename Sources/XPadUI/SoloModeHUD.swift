import SwiftUI
import XPadCore
import XPadTheory
import XPadController

/// Visual HUD display for Voice-Led Lead Guitar Solo Mode telemetry.
public struct SmartSoloHUDView: View {
    public var telemetry: SmartSoloTelemetry
    public var chord: Chord?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(telemetry: SmartSoloTelemetry, chord: Chord?) {
        self.telemetry = telemetry
        self.chord = chord
    }

    public var body: some View {
        VStack(spacing: 8) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "guitars.fill")
                        .foregroundStyle(Color.orange)
                    Text("Voice-Led Solo Engine")
                        .font(.caption.bold())
                }
                Spacer()
                if let chord {
                    Text("Harmonic Lock: \(chord.displayName)")
                        .font(.caption2.bold())
                        .foregroundStyle(Color.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.15))
                        .clipShape(Capsule())
                        .xShimmer(isActive: true)
                }
            }

            // Target Resolution & 2D Polar Compass Display
            HStack(spacing: 14) {
                // 2D Polar Stick Compass
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.15), lineWidth: 1.5)
                        .frame(width: 48, height: 48)

                    Circle()
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                        .frame(width: 24, height: 24)

                    // Quadrant Markers
                    Text("N")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(Color.green)
                        .offset(y: -18)
                    Text("S")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(Color.cyan)
                        .offset(y: 18)
                    Text("E")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(Color.purple)
                        .offset(x: 18)
                    Text("W")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(Color.orange)
                        .offset(x: -18)

                    // Stick Cursor
                    let stickRadius = CGFloat(telemetry.stickRadius) * 20
                    let angle = CGFloat(telemetry.stickAngle)
                    Circle()
                        .fill(telemetry.isActive ? Color.orange : Color.gray)
                        .frame(width: 8, height: 8)
                        .xGlow(isActive: telemetry.isActive, color: .orange)
                        .offset(
                            x: stickRadius * cos(angle),
                            y: -stickRadius * sin(angle)
                        )
                }
                .frame(width: 52, height: 52)

                // Target Note Details
                if let target = telemetry.currentTarget, telemetry.isActive {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(target.targetNote.pitchClass.displayName)
                                .font(.system(size: 22, weight: .black, design: .rounded))
                                .foregroundStyle(Color.orange)
                                .contentTransition(.numericText())
                                .animation(reduceMotion ? nil : XTheme.snappy, value: target.targetNote.pitchClass.displayName)
                                .xRipple(trigger: target.targetNote.pitchClass.displayName, color: .orange, size: 36)
                            Text("Octave \(target.targetNote.octave)")
                                .font(.caption2)
                                .monospacedDigit()
                                .foregroundStyle(XTheme.textTertiary)
                        }
                        Text(target.roleLabel)
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 3) {
                        Text(target.articulation.rawValue.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.25))
                            .clipShape(Capsule())
                        Text(target.theoryExplanation)
                            .font(.system(size: 9))
                            .foregroundStyle(XTheme.textSecondary)
                            .lineLimit(1)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Voice-Led Solo Ready")
                            .font(.caption.bold())
                            .foregroundStyle(Color.white.opacity(0.9))
                        Text("North: Guide Tones • South: Bass • East: Runs • West: Blues")
                            .font(.system(size: 9))
                            .foregroundStyle(XTheme.textTertiary)
                    }
                    Spacer()
                }
            }
            .padding(8)
            .background(Color.orange.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: XTheme.radiusMedium)
                .fill(XTheme.surface.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: XTheme.radiusMedium)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }
}
