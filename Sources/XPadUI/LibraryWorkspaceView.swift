import SwiftUI
import XPadCore
import XPadTheory
import XPadAudio
import XPadMIDI

public struct LibraryWorkspaceView: View {
    @State private var selectedPreset: SynthPreset = .polyLead

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

                Divider()

                // DAW Integration Guide
                VStack(alignment: .leading, spacing: 12) {
                    Text("DAW Integration & Virtual MIDI Routing")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 10) {
                        dawGuideCard(
                            daw: "Ableton Live 11 / 12",
                            steps: "1. Open Preferences → Link/MIDI.\n2. Enable 'Track' and 'Remote' on 'XPadInput Main' or 'XPadInput Chords'.\n3. Enable MPE Mode on MIDI tracks for expressive polyphonic bend."
                        )

                        dawGuideCard(
                            daw: "Apple Logic Pro",
                            steps: "1. Create a Software Instrument track.\n2. In Track Inspector, select MIDI Input Port: 'XPadInput Chords'.\n3. Enable MPE in Logic instrument settings (e.g. Alchemy / Sculpture)."
                        )

                        dawGuideCard(
                            daw: "Bitwig Studio",
                            steps: "1. Bitwig automatically detects 'XPadInput Expression (MPE)' as an MPE controller.\n2. Route channels directly to Polymer, Phase-4, or Grid devices."
                        )
                    }
                }
            }
            .padding()
        }
    }

    private func dawGuideCard(daw: String, steps: String) -> some View {
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

private struct PresetCard: View {
    let preset: SynthPreset
    let isSelected: Bool
    let onSelect: () -> Void

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
    }
}
