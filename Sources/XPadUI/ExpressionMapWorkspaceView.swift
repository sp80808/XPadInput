import SwiftUI
import XPadCore
import XPadTheory
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
    }

    var body: some View {
        @Bindable var state = appState
        HSplitView {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Section", selection: $section) {
                    ForEach(MapSection.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)

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
            Picker("Pitch Assist", selection: Binding(
                get: { state.expressionSettings.pitchAssist },
                set: { state.setPitchAssist($0) }
            )) {
                ForEach(PitchAssistMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Picker("Realism", selection: $state.expressionSettings.realism) {
                ForEach(RealismMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

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
            Picker("Destination", selection: Binding(
                get: { appState.destinationProfile.name },
                set: { name in
                    if let dest = DestinationCapabilityProfile.allProfiles.first(where: { $0.name == name }) {
                        appState.setDestination(dest)
                    }
                }
            )) {
                ForEach(DestinationCapabilityProfile.allProfiles) { dest in
                    Text(dest.name).tag(dest.name)
                }
            }

            labeled("MPE", appState.destinationProfile.supportsMPE ? "Yes" : "No")
            labeled("Bend range sent", String(format: "±%.0f st", appState.destinationProfile.bendRangeSemitones))
            labeled("Pressure", appState.destinationProfile.pressureMode.rawValue)
            labeled("Articulation", appState.instrumentProfile.midiArticulationStrategy.rawValue)
            labeled("Slide", appState.instrumentProfile.slideMIDIStrategy.rawValue)
            labeled("Right stick", appState.lastFrame?.ownedGesture.rawValue ?? "idle")
            labeled("Harmonic region", appState.harmonicSelection.region.rawValue)

            Text("If a destination lacks a feature, XPI falls back in this order: MPE → poly pressure → channel pressure → CC11. Per-note bend is refused on conventional MIDI chords.")
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
