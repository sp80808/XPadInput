import SwiftUI
import XPadCore
import XPadTheory
import XPadMIDI
import XPadAudio

public struct HarmonyWorkspaceView: View {
    @Binding var currentScale: Scale
    @State private var activeProgression: Progression
    @State private var selectedBlockIndex: Int? = 0
    @State private var voiceLeadingStrategy: VoiceLeadingStrategy = .smooth
    @State private var modulationTargetKey: PitchClass = .g
    @State private var isPlayingProgression: Bool = false

    private let suggestionEngine = HarmonicSuggestionEngine()
    private let modulationEngine = ModulationEngine()

    public init(currentScale: Binding<Scale>) {
        self._currentScale = currentScale
        let initialProg = Progression.factoryPresets(for: currentScale.wrappedValue).first ?? Progression(scale: currentScale.wrappedValue)
        self._activeProgression = State(initialValue: initialProg)
    }

    private var selectedChord: Chord {
        if let idx = selectedBlockIndex, idx < activeProgression.blocks.count {
            return activeProgression.blocks[idx].chord
        }
        return Chord(root: currentScale.root, quality: .major)
    }

    private var suggestions: [ChordSuggestion] {
        suggestionEngine.suggestions(for: selectedChord, in: currentScale)
    }

    private var modulationPaths: [ModulationPath] {
        let targetScale = Scale(root: modulationTargetKey, type: currentScale.type)
        return modulationEngine.pathways(from: currentScale, to: targetScale)
    }

    public var body: some View {
        HSplitView {
            // Left Column: Progression Builder & Modulation Explorer
            VStack(alignment: .leading, spacing: 20) {
                // Progression Builder
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Chord Progression Builder")
                            .font(.headline)
                        Spacer()
                        Button {
                            activeProgression = activeProgression.mutated(complexity: 0.4)
                        } label: {
                            Label("Mutate", systemImage: "wand.and.stars")
                        }
                        .buttonStyle(.bordered)

                        Button {
                            playProgression()
                        } label: {
                            Label(isPlayingProgression ? "Stop" : "Play All", systemImage: isPlayingProgression ? "stop.fill" : "play.fill")
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    // Chord Blocks Row
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Array(activeProgression.blocks.enumerated()), id: \.offset) { index, block in
                                ChordBlockCard(
                                    block: block,
                                    isSelected: selectedBlockIndex == index
                                )
                                .onTapGesture {
                                    selectedBlockIndex = index
                                    auditionChord(block.chord)
                                }
                            }

                            // Add Block Button
                            Button {
                                let newBlock = ChordBlock(chord: suggestions.first?.chord ?? selectedChord, durationBeats: 4.0)
                                activeProgression.blocks.append(newBlock)
                            } label: {
                                Image(systemName: "plus")
                                    .font(.title2)
                                    .frame(width: 60, height: 100)
                                    .background(Material.ultraThinMaterial)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding()
                .background(Material.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                // Modulation Explorer
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Modulation Explorer: \(currentScale.root.standardName) → ")
                            .font(.headline)
                        Picker("Target Key", selection: $modulationTargetKey) {
                            ForEach(PitchClass.allCases) { pc in
                                Text(pc.standardName).tag(pc)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    ForEach(modulationPaths) { path in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(path.type.rawValue)
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(Color.accentColor)
                                Spacer()
                                Button("Audition Path") {
                                    playModulationPath(path)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            Text(path.explanation)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 8) {
                                ForEach(path.intermediateChords) { chord in
                                    Text(chord.symbol)
                                        .font(.caption.monospaced())
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.white.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                            }
                        }
                        .padding(10)
                        .background(Color.black.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding()
                .background(Material.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding()
            .frame(minWidth: 420)

            // Right Column: "What Next?" Harmonic Suggestions & Voice Leading
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Harmonic Suggestions for \(selectedChord.symbol)")
                        .font(.headline)
                    Spacer()
                    Picker("Voice Leading", selection: $voiceLeadingStrategy) {
                        ForEach(VoiceLeadingStrategy.allCases) { strat in
                            Text(strat.rawValue).tag(strat)
                        }
                    }
                    .pickerStyle(.menu)
                }

                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(suggestions) { item in
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(item.chord.symbol)
                                            .font(.system(size: 18, weight: .bold, design: .rounded))
                                        Text(item.category.rawValue)
                                            .font(.caption2)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.accentColor.opacity(0.2))
                                            .clipShape(Capsule())
                                    }
                                    Text(item.reason)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Audition") {
                                    auditionChord(item.chord)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)

                                Button("Add") {
                                    activeProgression.blocks.append(ChordBlock(chord: item.chord, durationBeats: 4.0))
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                            }
                            .padding(12)
                            .background(Material.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            }
            .padding()
            .frame(minWidth: 380)
        }
    }

    private func auditionChord(_ chord: Chord) {
        let notes = chord.voicedNotes()
        for note in notes {
            AudioEngine.shared.noteOn(note: note.midiNumber, velocity: 100)
            MIDIManager.shared.sendNoteOn(port: .chords, channel: 0, note: note.midiNumber, velocity: 100)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            for note in notes {
                AudioEngine.shared.noteOff(note: note.midiNumber)
                MIDIManager.shared.sendNoteOff(port: .chords, channel: 0, note: note.midiNumber)
            }
        }
    }

    private func playProgression() {
        guard !isPlayingProgression else {
            isPlayingProgression = false
            return
        }
        isPlayingProgression = true
        var delay: Double = 0.0

        for block in activeProgression.blocks {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard isPlayingProgression else { return }
                auditionChord(block.chord)
            }
            delay += 1.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            isPlayingProgression = false
        }
    }

    private func playModulationPath(_ path: ModulationPath) {
        var delay: Double = 0.0
        for chord in path.intermediateChords {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                auditionChord(chord)
            }
            delay += 1.2
        }
    }
}

private struct ChordBlockCard: View {
    let block: ChordBlock
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 6) {
            Text(block.romanNumeral)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(block.chord.symbol)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
            Text("\(Int(block.durationBeats)) beats")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(width: 110, height: 100)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.accentColor : Color.white.opacity(0.1), lineWidth: 2)
        )
    }
}
