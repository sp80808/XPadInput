import SwiftUI
import XPadCore
import XPadController

/// Guitar Hero-style fret lane visualizer. Four colour lanes mirror the rear
/// buttons (L2/L1/R1/R2); each fires its diatonic chord instantly on press.
/// Face-button quality modifiers light up while held.
public struct ArcadeLaneView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var flashSlot: ArcadeFretSlot?
    @State private var strikePulseActive = false
    @State private var pulseGeneration: UInt = 0

    public init() {}

    private var chords: [Chord] { appState.diatonicChords }

    /// Lane whose diatonic chord matches the wheel-selected chord by root + quality.
    private var wheelPickSlot: ArcadeFretSlot? {
        guard let pick = appState.currentChord else { return nil }
        return ArcadeFretSlot.allCases.first { slot in
            guard let chord = laneChord(for: slot) else { return false }
            return chord.root == pick.root && chord.quality == pick.quality
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "guitars.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(XTheme.primary)
                Text("ARCADE FRETS")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(XTheme.textTertiary)
                Spacer()
                if let strike = appState.lastArcadeFrame.lastStrike {
                    Text(strike.chord.displayName)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(XTheme.textPrimary)
                        .transition(.opacity)
                }
            }

            HStack(spacing: 6) {
                ForEach(ArcadeFretSlot.allCases) { slot in
                    ArcadeLaneColumn(
                        slot: slot,
                        chord: laneChord(for: slot),
                        isHeld: appState.lastArcadeFrame.heldSlots.contains(slot),
                        isPicked: wheelPickSlot == slot,
                        isFlashing: strikePulseActive && flashSlot == slot,
                        controlLabel: controlLabel(for: slot),
                        reduceMotion: reduceMotion
                    )
                }
            }
            .frame(maxHeight: .infinity)

            HStack(spacing: 5) {
                Text("HOLD")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(XTheme.textTertiary)
                ForEach(ArcadeFretModifier.allCases) { modifier in
                    ArcadeModifierChip(
                        modifier: modifier,
                        isHeld: isModifierHeld(modifier)
                    )
                }
                Spacer()
                Text("NO STRUM · PRESS TO FIRE")
                    .font(.system(size: 7, weight: .semibold, design: .monospaced))
                    .foregroundColor(XTheme.textTertiary.opacity(0.7))
            }
        }
        .padding(10)
        .background(XTheme.surface.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onChange(of: appState.lastArcadeFrame.lastStrike) { _, strike in
            guard let strike else { return }
            fireStrikePulse(strike.slot)
        }
        .animation(reduceMotion ? nil : XTheme.feedbackFast, value: appState.lastArcadeFrame.heldSlots)
    }

    /// Springs a white flash up on the struck lane, then lets it decay. Skipped
    /// entirely under Reduce Motion; repeated pulses cancel the pending decay so
    /// rapid re-strikes re-trigger cleanly.
    private func fireStrikePulse(_ slot: ArcadeFretSlot) {
        guard !reduceMotion else { return }
        flashSlot = slot
        pulseGeneration &+= 1
        let generation = pulseGeneration
        withAnimation(XTheme.snappy) { strikePulseActive = true }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))
            guard generation == pulseGeneration, strikePulseActive else { return }
            withAnimation(.easeOut(duration: 0.22)) { strikePulseActive = false }
        }
    }

    private func laneChord(for slot: ArcadeFretSlot) -> Chord? {
        let index = slot.diatonicDegreeIndex
        guard chords.indices.contains(index) else { return nil }
        return chords[index]
    }

    private func controlLabel(for slot: ArcadeFretSlot) -> String {
        switch slot {
        case .leftTrigger: return appState.controllerManager.physicalLabel(for: .leftTrigger)
        case .leftShoulder: return appState.controllerManager.physicalLabel(for: .leftShoulder)
        case .rightShoulder: return appState.controllerManager.physicalLabel(for: .rightShoulder)
        case .rightTrigger: return appState.controllerManager.physicalLabel(for: .rightTrigger)
        }
    }

    private func isModifierHeld(_ modifier: ArcadeFretModifier) -> Bool {
        let raw = appState.controllerManager.controllerState
        switch modifier {
        case .seventh: return raw.buttonA
        case .sus: return raw.buttonX
        case .ninth: return raw.buttonY
        case .sixth: return raw.buttonB
        }
    }
}

private struct ArcadeLaneColumn: View {
    let slot: ArcadeFretSlot
    let chord: Chord?
    let isHeld: Bool
    let isPicked: Bool
    let isFlashing: Bool
    let controlLabel: String
    let reduceMotion: Bool

    private var laneColor: Color {
        switch slot.laneColorRole {
        case .green: return Color(hue: 0.36, saturation: 0.85, brightness: 0.75)
        case .red: return Color(hue: 0.99, saturation: 0.78, brightness: 0.80)
        case .yellow: return Color(hue: 0.13, saturation: 0.90, brightness: 0.92)
        case .blue: return Color(hue: 0.58, saturation: 0.80, brightness: 0.90)
        case .orange: return Color(hue: 0.07, saturation: 0.88, brightness: 0.90)
        }
    }

    /// Wheel-pick accent; mirrors the reserved `.orange` lane role.
    private var pickAccent: Color {
        Color(hue: 0.07, saturation: 0.88, brightness: 0.90)
    }

    private var idleStrokeColor: Color { isPicked ? pickAccent : laneColor.opacity(0.25) }

    var body: some View {
        VStack(spacing: 4) {
            Text(controlLabel)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(isHeld ? .white : XTheme.textSecondary)

            Circle()
                .fill(isHeld ? laneColor : laneColor.opacity(0.16))
                .overlay(Circle().stroke(laneColor.opacity(isHeld ? 1 : 0.35), lineWidth: 1.5))
                .shadow(color: isHeld ? laneColor.opacity(0.65) : .clear, radius: 6)
                .frame(height: 14)
                .scaleEffect(isHeld && !reduceMotion ? 1.12 : 1.0)

            VStack(spacing: 1) {
                Text(slot.romanNumeralLabel)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(isHeld ? .white : (isPicked ? pickAccent : laneColor))
                Text(chord?.displayName ?? "—")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(isHeld ? .white : XTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHeld ? laneColor.opacity(0.28) : (isPicked ? pickAccent.opacity(0.12) : XTheme.surface.opacity(0.55)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(
                    isHeld ? laneColor.opacity(0.95) : idleStrokeColor,
                    lineWidth: isHeld ? 1.5 : (isPicked ? 2 : 1)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(isFlashing ? 0.45 : 0))
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .animation(reduceMotion ? nil : XTheme.snappy, value: isHeld)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(slot.romanNumeralLabel) fret on \(controlLabel)")
        .accessibilityValue(accessibilitySummary)
        .accessibilityAddTraits(isHeld ? [.isSelected] : [])
    }

    private var accessibilitySummary: String {
        var parts = [chord?.displayName ?? "unavailable"]
        if isPicked { parts.append("matches wheel chord") }
        return parts.joined(separator: ", ")
    }
}

private struct ArcadeModifierChip: View {
    let modifier: ArcadeFretModifier
    let isHeld: Bool

    private var accent: Color {
        switch modifier {
        case .seventh: return XTheme.expression
        case .sus: return XTheme.natural
        case .ninth: return XTheme.colourful
        case .sixth: return XTheme.strong
        }
    }

    var body: some View {
        HStack(spacing: 3) {
            Text(modifier.defaultControlLabel)
                .font(.system(size: 9, weight: .bold))
            Text(modifier.displayName)
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule().fill(isHeld ? accent.opacity(0.30) : XTheme.surfaceElevated.opacity(0.7))
        )
        .overlay(
            Capsule().stroke(accent.opacity(isHeld ? 1 : 0.30), lineWidth: 1)
        )
        .foregroundColor(isHeld ? accent : XTheme.textTertiary)
        .animation(XTheme.feedbackFast, value: isHeld)
        .accessibilityLabel("\(modifier.displayName) modifier")
        .accessibilityAddTraits(isHeld ? [.isSelected] : [])
    }
}
