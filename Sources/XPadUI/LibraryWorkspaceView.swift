import SwiftUI
import XPadCore
import XPadTheory
import XPadAudio
import XPadMIDI

public struct LibraryWorkspaceView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedPreset: SynthPreset = .acousticSine

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Sound Presets
                VStack(alignment: .leading, spacing: 12) {
                    Text("Built-In Sound Engine Presets")
                        .font(.headline)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 180))], spacing: 12) {
                        ForEach(SynthPreset.allPresets, id: \.id) { preset in
                            PresetCard(
                                preset: preset,
                                isSelected: selectedPreset.id == preset.id,
                                onSelect: {
                                    selectedPreset = preset
                                    AudioEngine.shared.setPreset(preset)
                                    auditionPreset()
                                }
                            )
                        }
                    }
                }

                // CoreAudio Virtual Audio Driver & Loopback Section
                VirtualAudioView()

                Divider()

                // Guided Interactive Tutorials (Learn Hub)
                Button {
                    appState.showLearnHub = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "graduationcap.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(XTheme.primary)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Learn Hub — Guided Interactive Tutorials")
                                .font(.headline)
                                .foregroundColor(XTheme.textPrimary)
                            Text("Five missions that watch your controller input in real time and coach you through strumming, MPE expression, harmony navigation, finger drumming and sustain technique.")
                                .font(.caption)
                                .foregroundColor(XTheme.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(XTheme.textTertiary)
                    }
                    .padding(14)
                    .background(XTheme.surface)
                    .overlay(RoundedRectangle(cornerRadius: XTheme.radiusMedium).strokeBorder(XTheme.primary.opacity(0.35), lineWidth: 1))
                }
                .buttonStyle(.plain)

                Divider()

                // Ways to Play — one-tap control-scheme gallery
                WaysToPlayGallery()

                Divider()

                // DAW Integration & Plugin Hosting Guide
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("DAW Integration, AUv3 / VST3 Hosting & Virtual MIDI")
                            .font(.headline)
                        Spacer()
                        Text("AUv3 Instrument ('xpii') • AUv3 MIDI FX ('xpim')")
                            .font(.caption.monospaced())
                            .foregroundColor(XTheme.primary)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        dawGuideCard(
                            daw: "Auto-Detect MIDI Channels (MAP → MIDI Translation)",
                            steps: "• Leave Host on Auto-Detect to follow the frontmost DAW (Logic, Live, Bitwig, Cubase, Studio One, REAPER, and others).\n• Set DAW track MIDI channel to All / Any for MPE. A filtered track channel (1–16) collapses pitched roles onto that channel so notes are not dropped.\n• Manual host selection always wins over Auto-Detect."
                        )

                        dawGuideCard(
                            daw: "Apple Logic Pro (AUv3 MIDI FX & Instrument)",
                            steps: "• MIDI FX Slot: Insert 'XPI MIDI FX' on any software instrument track for automatic chord/scale voice-leading.\n• Instrument Slot: Load 'XPI Instrument' (AUv3 Music Device) for direct polyphonic PolyBLEP playback.\n• MPE Track: Select MIDI Input 'XPI Expression (MPE)' to drive Alchemy or Sculpture with ±48st pitch bend."
                        )

                        dawGuideCard(
                            daw: "Ableton Live 11 / 12 (AUv3 / VST3 & MPE)",
                            steps: "• Preferences → Link/MIDI: Enable 'Track' and 'MPE' on 'XPI Main' or 'XPI Expression'.\n• Load 'XPad: XPI Instrument' AUv3/VST3 into a MIDI track.\n• Use MPE Pitch Bend (±48 st) and CC74 Timbre on Wavetable and Drift devices."
                        )

                        dawGuideCard(
                            daw: "Bitwig Studio & Reaper (Native AUv3 / VST3)",
                            steps: "• Bitwig: Add 'XPI MIDI FX' inside Note FX chains before Polymer or Grid devices.\n• Reaper: Insert 'AU: XPad: XPI Instrument' on any track with multi-channel MPE routing."
                        )

                        dawGuideCard(
                            daw: "OBS & Stream Audio Capture (Zero-Configuration Loopback)",
                            steps: "• Enable 'CoreAudio Virtual Audio Driver' above.\n• In OBS or DAW, select Audio Input Device: 'XPI Virtual Loopback Input' for pristine 32-bit float audio capture without virtual cables."
                        )
                    }
                }

                Divider()

                // OCDS Open Controller Definition Standard Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Open Controller Definition Standard (OCDS)")
                            .font(.headline)
                        Spacer()
                        Text("JSON Schema v1.0.0 • 13 Bundled Profiles")
                            .font(.caption.monospaced())
                            .foregroundColor(XTheme.primary)
                    }

                    OCDSProfileManagerView()
                }
            }
            .padding()
        }
    }

    private func dawGuideCard(daw: String, steps: String) -> some View {
        DAWGuideCard(daw: daw, steps: steps)
    }

    private func auditionPreset() {
        let testNotes: [UInt8] = [60, 64, 67, 71] // Cmaj7
        for note in testNotes {
            AudioEngine.shared.noteOn(note: note, velocity: 100)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            for note in testNotes {
                AudioEngine.shared.noteOff(note: note)
            }
        }
    }
}

private struct DAWGuideCard: View {
    let daw: String
    let steps: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(daw)
                .font(.subheadline.bold())
                .foregroundStyle(Color.accentColor)
            Text(steps)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Material.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .scaleEffect(reduceMotion ? 1 : (isHovering ? 1.01 : 1.0))
        .shadow(color: .black.opacity(reduceMotion ? 0 : (isHovering ? 0.2 : 0)), radius: reduceMotion ? 0 : (isHovering ? 8 : 0), y: reduceMotion ? 0 : (isHovering ? 3 : 0))
        .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.8), value: isHovering)
        .onHover { isHovering = $0 }
    }
}

private struct PresetCard: View {
    let preset: SynthPreset
    let isSelected: Bool
    let onSelect: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(preset.name)
                .font(.subheadline)
                .fontWeight(.bold)
            Text("Osc: \(preset.osc1Type.rawValue) + \(preset.osc2Type.rawValue)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            if isSelected {
                Button("Active", action: onSelect)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            } else {
                Button("Select", action: onSelect)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Material.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .scaleEffect(reduceMotion ? 1 : (isHovering ? 1.02 : 1.0))
        .shadow(color: .black.opacity(reduceMotion ? 0 : (isHovering ? 0.2 : 0)), radius: reduceMotion ? 0 : (isHovering ? 8 : 0), y: reduceMotion ? 0 : (isHovering ? 3 : 0))
        .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.8), value: isHovering)
        .onHover { isHovering = $0 }
    }
}
