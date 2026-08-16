import SwiftUI
import XPadCore
import XPadTheory
import XPadController
import XPadMIDI
import XPadAudio
import XPadSequencer

/// The unified Pro Play workspace - real-time gamepad performance & chord progression workstation.
public struct PlayView: View {
    @Environment(AppState.self) private var appState
    var onOpenSettings: () -> Void = {}
    
    @State private var activeProgression: Progression = Progression(scale: Scale(root: .c, type: .major))
    @State private var selectedBlockIndex: Int? = 0
    @State private var isPlayingProgression: Bool = false
    @State private var voiceLeadingStrategy: VoiceLeadingStrategy = .smooth
    
    // Quick DSP parameter state
    @State private var filterCutoff: Double = 3200.0
    @State private var filterResonance: Double = 0.25
    @State private var saturation: Double = 0.15
    @State private var reverbMix: Double = 12.0

    private let suggestionEngine = HarmonicSuggestionEngine()
    private let voiceLeadingEngine = VoiceLeadingEngine()
    
    public init(onOpenSettings: @escaping () -> Void = {}) {
        self.onOpenSettings = onOpenSettings
    }
    
    private var activeScale: Scale {
        appState.currentScale
    }
    
    private var diatonicChords: [Chord] {
        Chord.diatonicChords(root: appState.currentKey, scale: activeScale)
    }
    
    private var currentOrSelectedChord: Chord {
        if let chord = appState.currentChord {
            return chord
        }
        if let idx = selectedBlockIndex, idx < activeProgression.blocks.count {
            return activeProgression.blocks[idx].chord
        }
        return diatonicChords.first ?? Chord(root: appState.currentKey, quality: .major)
    }
    
    private var harmonicSuggestions: [ChordSuggestion] {
        suggestionEngine.suggestions(for: currentOrSelectedChord, in: activeScale)
    }
    
    public var body: some View {
        GeometryReader { geo in
            let isWide = geo.size.width >= 1380
            let harmonicWidth = isWide ? geo.size.width * 0.50 : geo.size.width * 0.48
            
            HStack(spacing: 0) {
                // Left Column: Harmonic Wheel, Chord Builder, Suggestions & Active Voices
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 14) {
                        // 4-Player Ensemble Jamming Bar (when active)
                        if appState.multiJamManager.isSessionActive {
                            MultiControllerJammingBarView(jammingManager: appState.multiJamManager)
                        }

                        // Current Chord Display Card
                        ChordDisplayView()

                        // Voice-Led Solo HUD (when solo mode is active)
                        if appState.instrumentProfile.family == .synthLead || appState.isSoloModeActive {
                            SmartSoloHUDView(telemetry: appState.smartSoloEngine.telemetry, chord: appState.currentChord)
                        }

                        if let hint = appState.contextualHint, appState.activeNotes.isEmpty == false {
                            TechniqueHintBanner(text: hint)
                        }

                        // Interactive Multi-Layer Harmonic Wheel
                        HarmonicWheelView()
                            .frame(height: isWide ? 290 : 250)
                            .padding(.vertical, 4)

                        // Diatonic Chord Trigger Pads
                        DiatonicChordPadsRow(
                            chords: diatonicChords,
                            activeChord: appState.currentChord,
                            onSelect: { chord in
                                auditionAndSetChord(chord)
                            }
                        )

                        // Integrated Chord Progression Builder
                        ChordProgressionBuilderSection(
                            progression: $activeProgression,
                            selectedBlockIndex: $selectedBlockIndex,
                            isPlaying: $isPlayingProgression,
                            currentChord: currentOrSelectedChord,
                            onAuditionChord: { chord in
                                auditionChord(chord)
                            },
                            onSendToSequencer: {
                                sendProgressionToSequencer()
                            }
                        )

                        // Smart Harmonic Suggestions ("What Next?")
                        HarmonicSuggestionsStrip(
                            suggestions: harmonicSuggestions,
                            onAudition: { chord in
                                auditionChord(chord)
                            },
                            onAdd: { chord in
                                addChordToProgression(chord)
                            }
                        )

                        // Active MPE Voice Visualizer
                        ActiveNotesView()
                    }
                    .padding(16)
                }
                .frame(width: harmonicWidth)
                
                Divider()
                    .background(XTheme.border)
                
                // Right Column: Gamepad Visualizer, DSP Controls, and Strummer
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 14) {
                        // Real-Time Hardware Gamepad Visualizer
                        ControllerVisualizerView()
                            .frame(maxWidth: .infinity)

                        // Performance Quick Controls (Octave, Strategy, MPE range)
                        PerformanceQuickControlsView()

                        // Master DSP Sound Sculptor
                        MasterDSPStrip(
                            cutoff: $filterCutoff,
                            resonance: $filterResonance,
                            drive: $saturation,
                            reverb: $reverbMix
                        )

                        // Strumming Dynamics & Technique Feedback Strip
                        StrumIndicatorView()
                    }
                    .padding(16)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            if activeProgression.blocks.isEmpty {
                activeProgression = Progression.factoryPresets(for: appState.currentScale).first ?? Progression(scale: appState.currentScale)
            }
        }
        .onChange(of: appState.currentScale) { _, newScale in
            if activeProgression.blocks.isEmpty {
                activeProgression = Progression.factoryPresets(for: newScale).first ?? Progression(scale: newScale)
            }
        }
    }
    
    // MARK: - Actions
    
    private func auditionAndSetChord(_ chord: Chord) {
        appState.currentChord = chord
        auditionChord(chord)
    }
    
    private func auditionChord(_ chord: Chord) {
        let notes = chord.voicedNotes(baseOctave: 3)
        for note in notes {
            AudioEngine.shared.noteOn(note: note.midiNumber, velocity: 95)
            MIDIManager.shared.sendNoteOn(port: .chords, channel: 0, note: note.midiNumber, velocity: 95)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            for note in notes {
                AudioEngine.shared.noteOff(note: note.midiNumber)
                MIDIManager.shared.sendNoteOff(port: .chords, channel: 0, note: note.midiNumber)
            }
        }
    }
    
    private func addChordToProgression(_ chord: Chord) {
        let newBlock = ChordBlock(chord: chord, durationBeats: 4.0)
        activeProgression.blocks.append(newBlock)
        selectedBlockIndex = activeProgression.blocks.count - 1
        auditionChord(chord)
    }
    
    private func sendProgressionToSequencer() {
        guard appState.sequencer.scenes.indices.contains(appState.sequencer.activeSceneIndex) else { return }
        let sceneIndex = appState.sequencer.activeSceneIndex
        guard let trackIndex = appState.sequencer.scenes[sceneIndex].tracks.firstIndex(where: { $0.type == .chords }) else { return }
        
        var currentTick: UInt64 = 0
        var clips: [SequencerClip] = []
        
        for block in activeProgression.blocks {
            let durationTicks = UInt64(block.durationBeats * 960.0)
            let clip = SequencerClip(
                name: "\(block.romanNumeral) \(block.chord.symbol)",
                startTick: currentTick,
                durationTicks: durationTicks
            )
            clips.append(clip)
            currentTick += durationTicks
        }
        
        appState.sequencer.scenes[sceneIndex].tracks[trackIndex].clips = clips
    }
}

// MARK: - Diatonic Chord Trigger Pads

struct DiatonicChordPadsRow: View {
    let chords: [Chord]
    let activeChord: Chord?
    let onSelect: (Chord) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("DIATONIC CHORDS")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(XTheme.textTertiary)
            
            HStack(spacing: 6) {
                ForEach(Array(chords.enumerated()), id: \.offset) { index, chord in
                    let isActive = activeChord?.symbol == chord.symbol
                    Button {
                        onSelect(chord)
                    } label: {
                        VStack(spacing: 3) {
                            Text(romanNumeral(for: index + 1))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(isActive ? XTheme.primaryLight : XTheme.primary)
                            Text(chord.symbol)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(isActive ? .white : XTheme.textPrimary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(isActive ? XTheme.primary.opacity(0.3) : XTheme.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isActive ? XTheme.primary : XTheme.border, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(10)
        .background(XTheme.surface.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private func romanNumeral(for degree: Int) -> String {
        switch degree {
        case 1: return "I"
        case 2: return "ii"
        case 3: return "iii"
        case 4: return "IV"
        case 5: return "V"
        case 6: return "vi"
        case 7: return "vii°"
        default: return "\(degree)"
        }
    }
}

// MARK: - Integrated Chord Progression Builder

struct ChordProgressionBuilderSection: View {
    @Binding var progression: Progression
    @Binding var selectedBlockIndex: Int?
    @Binding var isPlaying: Bool
    let currentChord: Chord
    let onAuditionChord: (Chord) -> Void
    let onSendToSequencer: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header & Tools
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(XTheme.primary)
                    Text("CHORD PROGRESSION")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(XTheme.textPrimary)
                }
                
                Spacer()
                
                // Mutate Button
                Button {
                    withAnimation(XTheme.springAnimation) {
                        progression = progression.mutated(complexity: 0.35)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 10))
                        Text("Mutate")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(XTheme.surfaceElevated)
                    .foregroundColor(XTheme.primary)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Intelligently mutate progression using modal interchange and secondary dominants")
                
                // Play / Loop Button
                Button {
                    togglePlayProgression()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                            .font(.system(size: 9))
                        Text(isPlaying ? "Stop" : "Play")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isPlaying ? XTheme.recording.opacity(0.3) : XTheme.primary.opacity(0.2))
                    .foregroundColor(isPlaying ? XTheme.recording : XTheme.primary)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                
                // Send to Timeline Sequencer Button
                Button {
                    onSendToSequencer()
                } label: {
                    Image(systemName: "arrow.right.to.line.compact")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(XTheme.textSecondary)
                        .padding(5)
                        .background(XTheme.surfaceElevated)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Send progression directly to 960 PPQN Timeline Sequencer")
            }
            
            // Progression Block Strip
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(progression.blocks.enumerated()), id: \.offset) { index, block in
                        let isSelected = selectedBlockIndex == index
                        
                        Button {
                            selectedBlockIndex = index
                            onAuditionChord(block.chord)
                        } label: {
                            VStack(spacing: 2) {
                                Text(block.romanNumeral)
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundColor(isSelected ? XTheme.primaryLight : XTheme.primary)
                                Text(block.chord.symbol)
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(isSelected ? .white : XTheme.textPrimary)
                                Text("\(Int(block.durationBeats))b")
                                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                                    .foregroundColor(XTheme.textTertiary)
                            }
                            .frame(width: 72, height: 60)
                            .background(isSelected ? XTheme.primary.opacity(0.22) : XTheme.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(isSelected ? XTheme.primary : XTheme.border, lineWidth: 1.5)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .contextMenu {
                                Button("Delete Block", role: .destructive) {
                                    if progression.blocks.count > index {
                                        progression.blocks.remove(at: index)
                                    }
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Add Current Chord Button
                    Button {
                        let newBlock = ChordBlock(chord: currentChord, durationBeats: 4.0)
                        progression.blocks.append(newBlock)
                        selectedBlockIndex = progression.blocks.count - 1
                        onAuditionChord(currentChord)
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(XTheme.primary)
                            Text("Add")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(XTheme.textSecondary)
                        }
                        .frame(width: 54, height: 60)
                        .background(XTheme.surface.opacity(0.6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(XTheme.border, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 2)
            }
        }
        .padding(12)
        .background(XTheme.surface.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    private func togglePlayProgression() {
        guard !isPlaying else {
            isPlaying = false
            return
        }
        isPlaying = true
        var delay: Double = 0.0
        
        for block in progression.blocks {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard isPlaying else { return }
                onAuditionChord(block.chord)
            }
            delay += 1.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            isPlaying = false
        }
    }
}

// MARK: - Harmonic Suggestions ("What Next?") Strip

struct HarmonicSuggestionsStrip: View {
    let suggestions: [ChordSuggestion]
    let onAudition: (Chord) -> Void
    let onAdd: (Chord) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("WHAT NEXT? HARMONIC SUGGESTIONS")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(XTheme.textTertiary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(suggestions.prefix(6)) { item in
                        HStack(spacing: 6) {
                            Button {
                                onAudition(item.chord)
                            } label: {
                                VStack(alignment: .leading, spacing: 1) {
                                    HStack(spacing: 4) {
                                        Text(item.chord.symbol)
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(XTheme.textPrimary)
                                        Text(item.category.rawValue)
                                            .font(.system(size: 7, weight: .semibold))
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(XTheme.primary.opacity(0.2))
                                            .foregroundColor(XTheme.primary)
                                            .clipShape(Capsule())
                                    }
                                    Text(item.reason)
                                        .font(.system(size: 8))
                                        .foregroundColor(XTheme.textTertiary)
                                        .lineLimit(1)
                                }
                            }
                            .buttonStyle(.plain)
                            
                            Button {
                                onAdd(item.chord)
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(XTheme.primary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(XTheme.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(XTheme.border, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
                .padding(.vertical, 1)
            }
        }
        .padding(10)
        .background(XTheme.surface.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Master DSP Sound Sculptor Strip

struct MasterDSPStrip: View {
    @Binding var cutoff: Double
    @Binding var resonance: Double
    @Binding var drive: Double
    @Binding var reverb: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SYNTH & MASTER DSP")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(XTheme.textTertiary)
            
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Cutoff: \(Int(cutoff))Hz")
                        .font(.system(size: 9))
                        .foregroundColor(XTheme.textSecondary)
                    Slider(value: $cutoff, in: 100...12000)
                        .tint(XTheme.primary)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Res: \(Int(resonance * 100))%")
                        .font(.system(size: 9))
                        .foregroundColor(XTheme.textSecondary)
                    Slider(value: $resonance, in: 0...0.9)
                        .tint(XTheme.expression)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Drive: \(Int(drive * 100))%")
                        .font(.system(size: 9))
                        .foregroundColor(XTheme.textSecondary)
                    Slider(value: $drive, in: 0...1.0)
                        .tint(XTheme.tense)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reverb: \(Int(reverb))%")
                        .font(.system(size: 9))
                        .foregroundColor(XTheme.textSecondary)
                    Slider(value: $reverb, in: 0...50)
                        .tint(XTheme.primary)
                }
            }
        }
        .padding(10)
        .background(XTheme.surface.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Chord Display

struct ChordDisplayView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        HStack(spacing: 16) {
            // Chord name & Roman Numeral
            VStack(alignment: .leading, spacing: 2) {
                Text(appState.currentChord?.displayName ?? "—")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(XTheme.textPrimary)
                    .contentTransition(.numericText())

                if let chord = appState.currentChord {
                    HStack(spacing: 8) {
                        if let roman = chord.romanNumeral(in: appState.currentKey, scale: appState.currentScale) {
                            Text(roman)
                                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                                .foregroundColor(XTheme.primary)
                        }

                        let tension = chord.tension(in: appState.currentKey, scale: appState.currentScale)
                        TensionBadge(tension: tension)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                ActiveTechniqueStatusView()

                Text("\(appState.currentKey.displayName) \(appState.currentScale.displayName)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(XTheme.textSecondary)
            }
        }
        .padding(14)
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
