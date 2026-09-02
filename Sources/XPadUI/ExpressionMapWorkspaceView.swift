import SwiftUI
import XPadCore
import XPadController
import XPadMIDI

/// MAP is the deep expressive setup area. PLAY stays simple.
struct ExpressionMapWorkspaceView: View {
    @Environment(AppState.self) private var appState
    @State private var section: MapSection = .instrument

    enum MapSection: String, CaseIterable, Identifiable {
        case physical = "Physical Input"
        case gesture = "Musical Gesture"
        case instrument = "Instrument"
        case midi = "MIDI Translation"

        var id: String { rawValue }

        var compactTitle: String {
            switch self {
            case .physical: return "Input"
            case .gesture: return "Gesture"
            case .instrument: return "Instrument"
            case .midi: return "MIDI"
            }
        }

        var iconName: String {
            switch self {
            case .physical:   return "l.joystick.fill"
            case .gesture:    return "hand.draw.fill"
            case .instrument: return "pianokeys"
            case .midi:       return "cable.connector"
            }
        }

        var accentColor: Color {
            switch self {
            case .physical:   return XTheme.primary
            case .gesture:    return XTheme.expression
            case .instrument: return XTheme.accent
            case .midi:       return XTheme.creative
            }
        }

        var contextHint: String {
            switch self {
            case .physical:   return "Deadzone, response curves, and smoothing for sticks and triggers."
            case .gesture:    return "Pitch assist, realism, and theory-aware chord-tone layout."
            case .instrument: return "Family, preset, bend range, vibrato, and articulation windows."
            case .midi:       return "Host, channel routing, MPE zone, pressure mode, and passthru."
            }
        }
    }

    var body: some View {
        @Bindable var state = appState
        HSplitView {
            VStack(alignment: .leading, spacing: 16) {
                XWidthSafePicker("Section", selection: $section) {
                    ForEach(MapSection.allCases) { item in
                        Text(item.compactTitle).tag(item)
                    }
                }
                .accessibilityValue(section.rawValue)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        switch section {
                        case .physical:
                            physicalSection
                        case .gesture:
                            gestureSection
                        case .instrument:
                            instrumentSection
                        case .midi:
                            midiSection
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
            .padding()
            .frame(minWidth: 420)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(XTheme.primary)
                    Text("Technique Monitor")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(XTheme.textPrimary)
                }
                if let translation = appState.lastMIDITranslation {
                    VStack(alignment: .leading, spacing: 6) {
                        // Technique name badge
                        HStack(spacing: 6) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(XTheme.accent)
                            Text(translation.technique.displayName)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(XTheme.textPrimary)
                            Spacer()
                            Text("LIVE")
                                .font(.system(size: 8, weight: .black, design: .monospaced))
                                .foregroundColor(XTheme.primary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(XTheme.primary.opacity(0.12))
                                .clipShape(Capsule())
                        }
                        Divider().background(XTheme.border)
                        Text(translation.diagnosticSummary)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(XTheme.textSecondary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .xCard(isActive: true)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "play.circle")
                            .font(.system(size: 20))
                            .foregroundColor(XTheme.textTertiary)
                        Text("Play a technique to inspect MIDI here.\nThis detail stays out of PLAY.")
                            .font(.caption)
                            .foregroundStyle(XTheme.textTertiary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(XTheme.surface.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: XTheme.radiusSmall))
                }

                if let fallback = appState.lastMIDITranslation?.fallbackDescription {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(XTheme.tense)
                        Text(fallback)
                            .font(.caption)
                            .foregroundStyle(XTheme.tense)
                    }
                }

                // Section-specific quick legend
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 5) {
                        Image(systemName: section.iconName)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(section.accentColor)
                        Text(section.rawValue)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(section.accentColor)
                    }
                    Text(section.contextHint)
                        .font(.system(size: 10))
                        .foregroundColor(XTheme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .background(section.accentColor.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: XTheme.radiusSmall))
                .overlay(
                    RoundedRectangle(cornerRadius: XTheme.radiusSmall)
                        .stroke(section.accentColor.opacity(0.2), lineWidth: 1)
                )

                Spacer()
            }
            .padding()
            .frame(minWidth: 280)
        }
        .background(XTheme.background)
    }

    private var physicalSection: some View {
        Group {
            labeled("Left stick", appState.controllerManager.leftStickProcessor.profile.name)
            labeled("Right stick", appState.controllerManager.rightStickProcessor.profile.name)
            Text("Deadzone, response, and smoothing are owned by the stick processors. PLAY never shows these numbers.")
                .font(.caption)
                .foregroundStyle(XTheme.textTertiary)
        }
    }

    private var gestureSection: some View {
        @Bindable var state = appState
        return VStack(alignment: .leading, spacing: 12) {
            XWidthSafePicker("Pitch Assist", selection: Binding(
                get: { state.expressionSettings.pitchAssist },
                set: { state.setPitchAssist($0) }
            )) {
                ForEach(PitchAssistMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }

            XWidthSafePicker("Realism", selection: $state.expressionSettings.realism) {
                ForEach(RealismMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }

            Toggle("Theory Assist", isOn: $state.expressionSettings.theoryAssist)
            Toggle("Chromatic / Free pitch", isOn: $state.expressionSettings.chromaticMode)
            Toggle("Chord-tone face buttons", isOn: $state.expressionSettings.chordToneLayout)
        }
    }

    private var instrumentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Family", selection: Binding(
                get: { appState.instrumentProfile.family },
                set: { appState.setInstrument(InstrumentProfile.profile(for: $0)) }
            )) {
                ForEach(InstrumentProfile.playableProfiles, id: \.family) { profile in
                    Text(profile.name).tag(profile.family)
                }
            }

            Picker("Preset", selection: Binding(
                get: { appState.performancePreset },
                set: { appState.setPerformancePreset($0) }
            )) {
                ForEach(PerformancePreset.allCases) { preset in
                    Text(preset.rawValue).tag(preset)
                }
            }

            labeled("Bend range", String(format: "±%.0f st", appState.instrumentProfile.preferredPitchBendRange))
            labeled("Vibrato", String(format: "%.2f st @ %.1f Hz", appState.instrumentProfile.vibratoDepthSemitones, appState.instrumentProfile.vibratoRateHz))
            labeled("Hammer-on window", "\(Int(appState.instrumentProfile.hammerOnMaxGapMs)) ms / \(appState.instrumentProfile.hammerOnMaxInterval) st")
        }
    }

    private var midiSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Host", selection: Binding(
                get: { appState.hostSelection },
                set: { appState.setHostSelection($0) }
            )) {
                ForEach(DAWHostKind.allCases) { host in
                    Text(host.rawValue).tag(host)
                }
            }
            .pickerStyle(.menu)

            Picker("DAW track MIDI channel", selection: Binding(
                get: { appState.trackMIDIChannelDisplay },
                set: { appState.setTrackMIDIChannel($0) }
            )) {
                Text("All / Any").tag(0)
                ForEach(1...16, id: \.self) { channel in
                    Text("Ch \(channel)").tag(channel)
                }
            }
            .pickerStyle(.menu)

            labeled("Active host", appState.activeHostKind.rawValue)
            if appState.hostSelection == .autoDetect {
                Button("Re-detect") {
                    appState.refreshHostDetection()
                }
                .controlSize(.small)
            }
            labeled("Detection", appState.hostDetectionNote)
            labeled("MPE output", appState.resolvedLayout.usesMPE ? "Yes" : "No")
            labeled("MPE zone", appState.resolvedLayout.mpeZone.displaySummary)
            labeled("Bend range sent", String(format: "±%.0f st", appState.destinationProfile.bendRangeSemitones))
            labeled("Melody / solo", "Ch \(appState.resolvedLayout.channels.displayChannel(for: .melody)) / \(appState.resolvedLayout.channels.displayChannel(for: .solo))")
            labeled("Chords / bass", "Ch \(appState.resolvedLayout.channels.displayChannel(for: .chords)) / \(appState.resolvedLayout.channels.displayChannel(for: .bass))")
            labeled("Drums", "Ch \(appState.resolvedLayout.channels.displayChannel(for: .drums))")
            labeled("Pressure", appState.destinationProfile.pressureMode.rawValue)
            labeled("Articulation", appState.instrumentProfile.midiArticulationStrategy.rawValue)
            labeled("Slide", appState.instrumentProfile.slideMIDIStrategy.rawValue)

            Text(appState.activeHostContext.setupHint)
                .font(.caption)
                .foregroundStyle(XTheme.textSecondary)

            if let diagnostic = appState.resolvedLayout.diagnostic {
                Text(diagnostic)
                    .font(.caption)
                    .foregroundStyle(XTheme.tense)
            }

            Picker("MIDI Passthru", selection: Binding(
                get: { appState.midiPassthruMode },
                set: { appState.setMIDIPassthruMode($0) }
            )) {
                ForEach(MIDIPassthruMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            labeled("Passthru Routing", appState.midiPassthruMode.description)

            Text("Auto-Detect uses the frontmost macOS DAW. A filtered track channel (1–16) collapses pitched roles onto that channel and disables MPE, because Live/Logic/Cubase MPE needs All / Any Channels.")
                .font(.caption)
                .foregroundStyle(XTheme.textTertiary)
        }
    }

    private func labeled(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(XTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.body.monospaced())
        }
    }
}
