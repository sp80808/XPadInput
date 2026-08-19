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
                Text("Technique Monitor")
                    .font(.headline)
                if let translation = appState.lastMIDITranslation {
                    Text(translation.diagnosticSummary)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(XTheme.textSecondary)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .xCard()
                } else {
                    Text("Play a technique to inspect MIDI here.\nThis detail stays out of PLAY.")
                        .font(.caption)
                        .foregroundStyle(XTheme.textTertiary)
                }

                if let fallback = appState.lastMIDITranslation?.fallbackDescription {
                    Text(fallback)
                        .font(.caption)
                        .foregroundStyle(XTheme.tense)
                }

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
