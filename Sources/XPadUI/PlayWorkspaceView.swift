import SwiftUI
import XPadCore
import XPadController

/// The main Play workspace - gamepad instrument mode.
public struct PlayView: View {
    @Environment(AppState.self) private var appState
    
    public init() {}
    
    public var body: some View {
        GeometryReader { geo in
            let harmonicWidth = geo.size.width * (geo.size.width >= 1500 ? 0.46 : 0.48)

            HStack(spacing: 0) {
                // Left panel: Harmonic wheel + chord info
                VStack(spacing: 16) {
                    // Current chord display
                    ChordDisplayView()

                    if let hint = appState.contextualHint, appState.activeNotes.isEmpty == false {
                        TechniqueHintBanner(text: hint)
                    }

                    // Harmonic wheel
                    HarmonicWheelView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // Active notes display
                    ActiveNotesView()
                }
                .padding(20)
                .frame(width: harmonicWidth)
                
                Divider()
                    .background(XTheme.border)
                
                // Right panel: Controller visualiser + strum info
                VStack(spacing: 16) {
                    ControllerVisualizerView()
                        .frame(maxWidth: .infinity, alignment: .top)

                    PerformanceQuickControlsView()

                    Spacer(minLength: 8)
                    
                    StrumIndicatorView()
                }
                .padding(16)
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Chord Display

struct ChordDisplayView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        HStack(spacing: 16) {
            // Chord name
            VStack(alignment: .leading, spacing: 4) {
                Text(appState.currentChord?.displayName ?? "—")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(XTheme.textPrimary)
                    .contentTransition(.numericText())

                if let chord = appState.currentChord {
                    HStack(spacing: 8) {
                        if let roman = chord.romanNumeral(in: appState.currentKey, scale: appState.currentScale) {
                            Text(roman)
                                .font(.system(size: 16, weight: .medium, design: .monospaced))
                                .foregroundColor(XTheme.primary)
                        }

                        let tension = chord.tension(in: appState.currentKey, scale: appState.currentScale)
                        TensionBadge(tension: tension)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Picker("Instrument", selection: Binding(
                    get: { appState.instrumentProfile.family },
                    set: { family in
                        appState.setInstrument(InstrumentProfile.profile(for: family))
                    }
                )) {
                    ForEach(InstrumentProfile.playableProfiles, id: \.family) { profile in
                        Text(profile.family.shortName).tag(profile.family)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 110)

                Text(appState.instrumentStatusLabel)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(appState.activeTechniqueLabel == nil ? XTheme.textSecondary : XTheme.accent)

                Text("\(appState.currentKey.displayName) \(appState.currentScale.name)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(XTheme.textSecondary)
            }
        }
        .padding(16)
        .xCard(isActive: appState.currentChord != nil)
    }
}

struct TensionBadge: View {
    let tension: Double
    
    var label: String {
        if tension < 0.15 { return "Stable" }
        if tension < 0.3 { return "Natural" }
        if tension < 0.5 { return "Colourful" }
        if tension < 0.7 { return "Adventurous" }
        return "Outside"
    }
    
    var body: some View {
        Text(label)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(XTheme.tensionColor(tension))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(XTheme.tensionColor(tension).opacity(0.15))
            )
    }
}

// MARK: - Active Notes

struct ActiveNotesView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        HStack(spacing: 6) {
            ForEach(appState.activeNotes, id: \.midiNote) { note in
                ExpressiveNoteGlyph(note: note)
            }

            if appState.activeNotes.isEmpty {
                Text("No notes playing")
                    .font(.caption)
                    .foregroundColor(XTheme.textTertiary)
            }

            Spacer()

            if let theory = appState.lastFrame?.theoryExplanation {
                Text(theory)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(XTheme.accent)
            }
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44, alignment: .leading)
        .accessibilityElement(children: .contain)
    }
}

struct ExpressiveNoteGlyph: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let note: Note

    private var isLead: Bool {
        appState.activeNotes.max()?.midiNote == note.midiNote
    }

    private var bend: Double {
        guard isLead else { return 0 }
        return appState.lastFrame?.bend.bendSemitones ?? 0
    }

    private var pressure: Double {
        guard isLead else { return 0 }
        return appState.lastFrame?.pressure.smoothed ?? 0
    }

    private var visual: TechniqueVisualHint {
        appState.lastFrame?.visual ?? TechniqueVisualHint()
    }

    var body: some View {
        let lift = reduceMotion ? 0 : CGFloat(max(-18, min(18, bend * 8)))
        let halo = 8 + pressure * 10
        ZStack {
            if isLead && visual.kind == .pinchHarmonic {
                Circle()
                    .stroke(XTheme.accent.opacity(0.7), lineWidth: 1)
                    .frame(width: 36, height: 36)
            }
            if isLead && abs(bend) > 0.08 {
                Path { path in
                    path.move(to: CGPoint(x: 18, y: 22))
                    path.addQuadCurve(to: CGPoint(x: 18, y: 22 - lift), control: CGPoint(x: 28, y: 22 - lift * 0.5))
                }
                .stroke(XTheme.accent.opacity(0.8), lineWidth: 1.5)
                .frame(width: 36, height: 36)
            }
            Text(note.displayName)
                .font(.system(size: 12 + pressure * 3, weight: .medium, design: .monospaced))
                .foregroundColor(XTheme.textPrimary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(XTheme.primary.opacity(0.2 + pressure * 0.25))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(XTheme.primary.opacity(0.4 + pressure * 0.4), lineWidth: 1)
                        )
                )
                .offset(y: -lift)
                .shadow(color: XTheme.accent.opacity(pressure * 0.5), radius: halo)

            if isLead, let target = appState.lastFrame?.bend.nearestTarget, (appState.lastFrame?.bend.targetProximity ?? 0) > 0.35 {
                Text(target.displayLabel)
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .foregroundColor(XTheme.accent.opacity(0.4 + (appState.lastFrame?.bend.targetProximity ?? 0) * 0.6))
                    .offset(y: -28 - lift)
            }
        }
        .frame(height: 44)
    }
}

struct TechniqueHintBanner: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(XTheme.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(XTheme.surfaceElevated)
            )
    }
}

// MARK: - Strum Indicator

struct StrumIndicatorView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        let controllerState = appState.controllerManager.controllerState
        let hasLiveInput = appState.controllerManager.isConnected || controllerState.hasVisiblePerformanceInput

        PerformanceFeedbackStrip(
            frame: hasLiveInput ? appState.lastFrame : nil,
            velocity: hasLiveInput ? appState.lastVelocity : 0,
            direction: hasLiveInput ? appState.lastStrumDirection : .none,
            lastStrumTime: hasLiveInput ? appState.lastStrumTime : nil,
            gestureLabel: appState.hudLabels.rightStick,
            supportsStrumming: appState.instrumentProfile.supportsStrumming,
            stringCount: appState.instrumentProfile.stringCount
        )
    }
}
