import SwiftUI
import XPadCore
import XPadTheory
import XPadController
import XPadMIDI
import XPadAudio
import XPadSequencer

// MARK: - Tab Enums

enum HarmonicWorkspaceTab: String, CaseIterable, Identifiable {
    case chords = "Chords"
    case progression = "Progression"
    case suggestions = "Suggestions"
    var id: String { rawValue }
}

enum DSPWorkspaceTab: String, CaseIterable, Identifiable {
    case performance = "Performance"
    case synth = "Synth"
    case fx = "FX"
    var id: String { rawValue }
}

// MARK: - Main PlayView

/// The unified Pro Play workspace - real-time gamepad performance & chord progression workstation.
/// Refactored for complete layout stability: no elements cause surrounding UI to shift.
public struct PlayView: View {
    @Environment(AppState.self) private var appState
    var onOpenSettings: () -> Void = {}
    
    @State private var activeProgression: Progression
    @State private var selectedBlockIndex: Int? = 0
    @State private var isPlayingProgression: Bool = false
    
    // DSP parameter state
    @State private var filterCutoff: Double = 3200.0
    @State private var filterResonance: Double = 0.25
    @State private var saturation: Double = 0.15
    @State private var reverbMix: Double = 12.0
    
    // Tab states
    @State private var harmonicWorkspaceTab: HarmonicWorkspaceTab = .chords
    @State private var dspWorkspaceTab: DSPWorkspaceTab = .performance
    
    private let suggestionEngine = HarmonicSuggestionEngine()
    
    public init(onOpenSettings: @escaping () -> Void = {}) {
        self.onOpenSettings = onOpenSettings
        self._activeProgression = State(initialValue: Progression(scale: Scale(root: .c, type: .major)))
    }
    
    private var activeScale: Scale { appState.currentScale }
    private var diatonicChords: [Chord] { Chord.diatonicChords(root: appState.currentKey, scale: activeScale) }
    
    private var currentOrSelectedChord: Chord {
        if let chord = appState.currentChord { return chord }
        if let idx = selectedBlockIndex, idx < activeProgression.blocks.count { return activeProgression.blocks[idx].chord }
        return diatonicChords.first ?? Chord(root: appState.currentKey, quality: .major)
    }
    
    private var harmonicSuggestions: [ChordSuggestion] {
        suggestionEngine.suggestions(for: currentOrSelectedChord, in: activeScale)
    }
    
    public var body: some View {
        GeometryReader { geo in
            let isWide = geo.size.width >= 1380
            let leftWidth = isWide ? geo.size.width * 0.40 : geo.size.width * 0.38
            let rightWidth = geo.size.width - leftWidth
            
            HStack(spacing: 0) {
                // LEFT COLUMN: Harmonic Workspace - Compact, supporting role
                VStack(spacing: 10) {
                    // Multi-Jam Bar or reserved space
                    if appState.multiJamManager.isSessionActive {
                        MultiControllerJammingBarView(jammingManager: appState.multiJamManager)
                            .transition(.opacity)
                    }
                    if !appState.multiJamManager.isSessionActive {
                        Spacer().frame(height: 90)
                    }

                    // Current Chord Display
                    EnhancedChordDisplayView()
                        .frame(height: 72)

                    // Solo HUD or reserved space
                    if appState.instrumentProfile.family == .synthLead || appState.isSoloModeActive {
                        SmartSoloHUDView(telemetry: appState.smartSoloEngine.telemetry, chord: appState.currentChord)
                            .transition(.opacity)
                    }
                    if !(appState.instrumentProfile.family == .synthLead || appState.isSoloModeActive) {
                        Spacer().frame(height: 100)
                    }

                    // Contextual Hint
                    ContextualHintSlot()
                        .frame(height: 32)

                    // Harmonic Wheel - chord selection via stick
                    HarmonicWheelView()
                        .frame(minHeight: 280, maxHeight: .infinity)
                        .padding(.vertical, 2)

                    // Tabbed: Chords | Progression | Suggestions
                    HarmonicTabbedWorkspace(
                        tab: $harmonicWorkspaceTab,
                        activeProgression: $activeProgression,
                        selectedBlockIndex: $selectedBlockIndex,
                        isPlayingProgression: $isPlayingProgression,
                        diatonicChords: diatonicChords,
                        currentOrSelectedChord: currentOrSelectedChord,
                        harmonicSuggestions: harmonicSuggestions,
                        onAuditionChord: auditionChord,
                        onSendToSequencer: sendProgressionToSequencer
                    )
                    .frame(height: 200)

                    // Active Notes
                    ActiveNotesView()
                        .frame(height: 40)
                }
                .padding(12)
                .frame(width: leftWidth)
                .animation(.easeInOut(duration: 0.25), value: appState.multiJamManager.isSessionActive)
                .animation(.easeInOut(duration: 0.25), value: appState.isSoloModeActive)
                
                Divider().background(XTheme.border)
                
                // RIGHT COLUMN: Controller & Performance Workspace - Primary focus
                VStack(spacing: 10) {
                    // Controller Visualizer - Prominent
                    ControllerVisualizerView()
                        .frame(height: 300)

                    // Performance Quick Controls
                    PerformanceQuickControlsView()
                        .frame(height: 52)

                    // Real-time Performance Monitor
                    PerformanceMonitorView()
                        .frame(height: 96)

                    // Tabbed: Performance | Synth | FX
                    DSPTabbedWorkspace(
                        tab: $dspWorkspaceTab,
                        cutoff: $filterCutoff,
                        resonance: $filterResonance,
                        drive: $saturation,
                        reverb: $reverbMix
                    )
                    .frame(height: 170)

                    // Strum Indicator & MIDI Activity
                    HStack(spacing: 10) {
                        StrumIndicatorView()
                        MIDIActivityView()
                    }
                    .frame(height: 64)
                }
                .padding(12)
                .frame(width: rightWidth)
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
    
    private func auditionChord(_ chord: Chord) {
        let notes = chord.voicedNotes(baseOctave: 3)
        let midiNotes = notes.map(\.midiNumber)
        for note in midiNotes {
            AudioEngine.shared.noteOn(note: note, velocity: 95)
        }
        appState.sendAuditionNotes(midiNotes, port: .chords, velocity: 95, duration: 0.9)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            for note in midiNotes {
                AudioEngine.shared.noteOff(note: note)
            }
        }
    }
    
    private func sendProgressionToSequencer() {
        guard appState.sequencer.scenes.indices.contains(appState.sequencer.activeSceneIndex) else { return }
        let sceneIndex = appState.sequencer.activeSceneIndex
        guard let trackIndex = appState.sequencer.scenes[sceneIndex].tracks.firstIndex(where: { $0.type == .chords }) else { return }
        var currentTick: UInt64 = 0
        var clips: [SequencerClip] = []
        for block in activeProgression.blocks {
            let durationTicks = UInt64(block.durationBeats * 960.0)
            let clip = SequencerClip(name: "\(block.romanNumeral) \(block.chord.symbol)", startTick: currentTick, durationTicks: durationTicks)
            clips.append(clip)
            currentTick += durationTicks
        }
        appState.sequencer.scenes[sceneIndex].tracks[trackIndex].clips = clips
    }
}

// MARK: - Contextual Hint Slot

private struct ContextualHintSlot: View {
    @Environment(AppState.self) private var appState
    var body: some View {
        HStack {
            if let hint = appState.contextualHint, !appState.activeNotes.isEmpty {
                TechniqueHintBanner(text: hint)
            }
            Spacer()
        }
        .frame(height: 36)
    }
}

// MARK: - Enhanced Chord Display with Always-Visible Key/Scale

struct EnhancedChordDisplayView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var previousChordName: String?
    
    var body: some View {
        let currentName = appState.currentChord?.displayName ?? "-"
        let chordChanged = previousChordName != currentName && previousChordName != nil
        let displayName = chordChanged && !reduceMotion ? (previousChordName ?? "-") : currentName
        
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(XTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(height: 40)
                    .animation(reduceMotion ? nil : .spring(response: 0.2, dampingFraction: 0.75), value: currentName)
                if let chord = appState.currentChord {
                    HStack(spacing: 8) {
                        if let roman = chord.romanNumeral(in: appState.currentKey, scale: appState.currentScale) {
                            Text(roman).font(.system(size: 15, weight: .semibold, design: .monospaced)).foregroundColor(XTheme.primary)
                        }
                        TensionBadge(tension: chord.tension(in: appState.currentKey, scale: appState.currentScale))
                    }
                    .frame(height: 22)
                } else {
                    Spacer().frame(height: 22)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                ActiveTechniqueStatusView()
                    .frame(height: 24)
                HStack(spacing: 4) {
                    Text(appState.currentKey.displayName)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(XTheme.primary)
                    Text("•")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(XTheme.textTertiary)
                    Text(appState.currentScale.displayName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(XTheme.textSecondary)
                        .lineLimit(1)
                }
                .frame(height: 28)
            }
        }
        .frame(height: 80)
        .padding(.horizontal, 14)
        .xCard(isActive: appState.currentChord != nil)
        .onChange(of: currentName) { _, newName in
            previousChordName = newName
        }
    }
}

// MARK: - Tabbed Workspaces

private struct HarmonicTabbedWorkspace: View {
    @Environment(AppState.self) private var appState
    @Binding var tab: HarmonicWorkspaceTab
    @Binding var activeProgression: Progression
    @Binding var selectedBlockIndex: Int?
    @Binding var isPlayingProgression: Bool
    let diatonicChords: [Chord]
    let currentOrSelectedChord: Chord
    let harmonicSuggestions: [ChordSuggestion]
    let onAuditionChord: (Chord) -> Void
    let onSendToSequencer: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(HarmonicWorkspaceTab.allCases) { t in
                    TabButton(title: t.rawValue, isSelected: tab == t) { tab = t }
                }
                Spacer()
            }
            .padding(.horizontal, 4)
            ZStack {
                switch tab {
                case .chords:
                    DiatonicChordPadsRow(chords: diatonicChords, activeChord: appState.currentChord, onSelect: { c in
                        appState.currentChord = c; onAuditionChord(c)
                    })
                case .progression:
                    ChordProgressionBuilderSection(progression: $activeProgression, selectedBlockIndex: $selectedBlockIndex, isPlaying: $isPlayingProgression, currentChord: currentOrSelectedChord, onAuditionChord: onAuditionChord, onSendToSequencer: onSendToSequencer)
                case .suggestions:
                    HarmonicSuggestionsStrip(suggestions: harmonicSuggestions, onAudition: onAuditionChord, onAdd: { c in
                        activeProgression.blocks.append(ChordBlock(chord: c, durationBeats: 4.0))
                        selectedBlockIndex = activeProgression.blocks.count - 1
                        onAuditionChord(c)
                    })
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(8)
        .background(XTheme.surface.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct DSPTabbedWorkspace: View {
    @Environment(AppState.self) private var appState
    @Binding var tab: DSPWorkspaceTab
    @Binding var cutoff: Double
    @Binding var resonance: Double
    @Binding var drive: Double
    @Binding var reverb: Double
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(DSPWorkspaceTab.allCases) { t in
                    TabButton(title: t.rawValue, isSelected: tab == t) { tab = t }
                }
                Spacer()
            }
            .padding(.horizontal, 4)
            ZStack {
                switch tab {
                case .performance: PerformanceDSPPanel()
                case .synth: MasterDSPStrip(cutoff: $cutoff, resonance: $resonance, drive: $drive, reverb: $reverb)
                case .fx: FXDSPPanel(cutoff: $cutoff, resonance: $resonance, drive: $drive, reverb: $reverb)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(8)
        .background(XTheme.surface.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(isSelected ? XTheme.primary : XTheme.textTertiary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .frame(minWidth: 48)
                .background(
                    Capsule()
                        .fill(isSelected ? XTheme.primary.opacity(0.18) : Color.clear)
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? XTheme.primary : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.22, dampingFraction: 0.78), value: isSelected)
    }
}

// MARK: - DSP Panels

private struct PerformanceDSPPanel: View {
    @Environment(AppState.self) private var appState
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PERFORMANCE").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(XTheme.textTertiary)
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Octave").font(.system(size: 9)).foregroundColor(XTheme.textSecondary)
                        Slider(value: .constant(0.5), in: -2...2).tint(XTheme.primary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Bend Range").font(.system(size: 9)).foregroundColor(XTheme.textSecondary)
                        Slider(value: .constant(2.0), in: 1...24).tint(XTheme.expression)
                    }
                }
            }
        }
        .padding(4)
    }
}

private struct FXDSPPanel: View {
    @Environment(AppState.self) private var appState
    @Binding var cutoff: Double
    @Binding var resonance: Double
    @Binding var drive: Double
    @Binding var reverb: Double
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("EFFECTS").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(XTheme.textTertiary)
            MasterDSPStrip(cutoff: $cutoff, resonance: $resonance, drive: $drive, reverb: $reverb)
            HStack(spacing: 12) {
                ToggleButton(icon: "slider.horizontal.3", label: "EQ", isOn: appState.audioEngine.effectsSettings.equalizer.isEnabled, color: XTheme.primary)
                ToggleButton(icon: "waveform.path.ecg", label: "Comp", isOn: appState.audioEngine.effectsSettings.compressor.isEnabled, color: XTheme.tense)
                ToggleButton(icon: "dot.radiowaves.left.and.right", label: "Verb", isOn: appState.audioEngine.effectsSettings.reverb.isEnabled, color: XTheme.expression)
            }
            .padding(.top, 8)
        }
        .padding(4)
    }
}

private struct ToggleButton: View {
    let icon: String; let label: String; let isOn: Bool; let color: Color
    var body: some View {
        Button { } label: {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 10))
                Text(label).font(.system(size: 10, weight: .semibold))
            }
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(isOn ? color.opacity(0.2) : XTheme.surface)
            .foregroundColor(isOn ? color : XTheme.textSecondary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Chord Components

struct DiatonicChordPadsRow: View {
    let chords: [Chord]; let activeChord: Chord?; let onSelect: (Chord) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("DIATONIC CHORDS").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(XTheme.textTertiary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(Array(chords.enumerated()), id: \.offset) { index, chord in
                    let isActive = activeChord?.symbol == chord.symbol
                    Button { onSelect(chord) } label: {
                        VStack(spacing: 3) {
                            Text(romanNumeral(for: index + 1)).font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(isActive ? XTheme.primaryLight : XTheme.primary)
                            Text(chord.symbol).font(.system(size: 11, weight: .bold)).foregroundColor(isActive ? .white : XTheme.textPrimary).lineLimit(1).fixedSize(horizontal: true, vertical: false)
                        }
                        .frame(maxWidth: .infinity, minHeight: 54, maxHeight: 54)
                        .background(isActive ? XTheme.primary.opacity(0.3) : XTheme.surface)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(isActive ? XTheme.primary : XTheme.border, lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .scaleEffect(isActive && !reduceMotion ? 0.94 : 1.0)
                    .animation(reduceMotion ? nil : XTheme.feedbackFast, value: isActive)
                }
            }
        }
        .padding(10).background(XTheme.surface.opacity(0.5)).clipShape(RoundedRectangle(cornerRadius: 8))
    }
    private func romanNumeral(for degree: Int) -> String {
        ["I","ii","iii","IV","V","vi","vii°"][degree-1] ?? "\(degree)"
    }
}

struct ChordProgressionBuilderSection: View {
    @Binding var progression: Progression; @Binding var selectedBlockIndex: Int?; @Binding var isPlaying: Bool
    let currentChord: Chord; let onAuditionChord: (Chord) -> Void; let onSendToSequencer: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "music.note.list").font(.system(size: 11, weight: .bold)).foregroundColor(XTheme.primary)
                    Text("CHORD PROGRESSION").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundColor(XTheme.textPrimary)
                }
                Spacer()
                Button { withAnimation(XTheme.springAnimation) { progression = progression.mutated(complexity: 0.35) } } label: {
                    HStack(spacing: 4) { Image(systemName: "wand.and.stars").font(.system(size: 10)); Text("Mutate").font(.system(size: 10, weight: .semibold)) }
                    .padding(.horizontal, 8).padding(.vertical, 4).background(XTheme.surfaceElevated).foregroundColor(XTheme.primary).clipShape(Capsule())
                }
                .buttonStyle(.plain)
                Button { togglePlay() } label: {
                    HStack(spacing: 4) { Image(systemName: isPlaying ? "stop.fill" : "play.fill").font(.system(size: 9)); Text(isPlaying ? "Stop" : "Play").font(.system(size: 10, weight: .semibold)) }
                    .padding(.horizontal, 8).padding(.vertical, 4).background(isPlaying ? XTheme.recording.opacity(0.3) : XTheme.primary.opacity(0.2)).foregroundColor(isPlaying ? XTheme.recording : XTheme.primary).clipShape(Capsule())
                }
                .buttonStyle(.plain)
                Button { onSendToSequencer() } label: {
                    Image(systemName: "arrow.right.to.line.compact").font(.system(size: 10, weight: .bold)).foregroundColor(XTheme.textSecondary).padding(5).background(XTheme.surfaceElevated).clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(progression.blocks.enumerated()), id: \.offset) { index, block in
                        let isSelected = selectedBlockIndex == index
                        Button { selectedBlockIndex = index; onAuditionChord(block.chord) } label: {
                            VStack(spacing: 2) {
                                Text(block.romanNumeral).font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(isSelected ? XTheme.primaryLight : XTheme.primary).lineLimit(1).minimumScaleFactor(0.7)
                                Text(block.chord.symbol).font(.system(size: 14, weight: .bold, design: .rounded)).foregroundColor(isSelected ? .white : XTheme.textPrimary).lineLimit(1).minimumScaleFactor(0.7)
                                Text("\(Int(block.durationBeats))b").font(.system(size: 8, weight: .medium, design: .monospaced)).foregroundColor(XTheme.textTertiary)
                            }
                            .frame(width: 72, height: 60)
                            .background(isSelected ? XTheme.primary.opacity(0.22) : XTheme.surface)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(isSelected ? XTheme.primary : XTheme.border, lineWidth: 1.5))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                    Button {
                        progression.blocks.append(ChordBlock(chord: currentChord, durationBeats: 4.0))
                        selectedBlockIndex = progression.blocks.count - 1
                        onAuditionChord(currentChord)
                    } label: {
                        VStack(spacing: 4) { Image(systemName: "plus").font(.system(size: 14, weight: .bold)).foregroundColor(XTheme.primary); Text("Add").font(.system(size: 9, weight: .bold)).foregroundColor(XTheme.textSecondary) }
                        .frame(width: 54, height: 60)
                        .background(XTheme.surface.opacity(0.6))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(XTheme.border, style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 2)
            }
        }
        .padding(12).background(XTheme.surface.opacity(0.6)).clipShape(RoundedRectangle(cornerRadius: 10))
    }
    private func togglePlay() {
        guard !isPlaying else { isPlaying = false; return }
        isPlaying = true; var delay: Double = 0.0
        for block in progression.blocks {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { guard isPlaying else { return }; onAuditionChord(block.chord) }
            delay += 1.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { isPlaying = false }
    }
}

struct HarmonicSuggestionsStrip: View {
    let suggestions: [ChordSuggestion]; let onAudition: (Chord) -> Void; let onAdd: (Chord) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("WHAT NEXT?").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(XTheme.textTertiary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(suggestions.prefix(6)) { item in
                        HStack(spacing: 6) {
                            Button { onAudition(item.chord) } label: {
                                VStack(alignment: .leading, spacing: 1) {
                                    HStack(spacing: 4) {
                                        Text(item.chord.symbol).font(.system(size: 12, weight: .bold)).foregroundColor(XTheme.textPrimary).lineLimit(1).fixedSize(horizontal: true, vertical: false)
                                        Text(item.category.rawValue).font(.system(size: 7, weight: .semibold)).padding(.horizontal, 4).padding(.vertical, 1).background(XTheme.primary.opacity(0.2)).foregroundColor(XTheme.primary).clipShape(Capsule()).fixedSize(horizontal: true, vertical: false)
                                    }
                                    Text(item.reason).font(.system(size: 8)).foregroundColor(XTheme.textTertiary).lineLimit(1).fixedSize(horizontal: true, vertical: false)
                                }
                            }
                            .buttonStyle(.plain)
                            Button { onAdd(item.chord) } label: { Image(systemName: "plus.circle.fill").font(.system(size: 13)).foregroundColor(XTheme.primary) }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 8).padding(.vertical, 6).background(XTheme.surface)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(XTheme.border, lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
                .padding(.vertical, 1)
            }
        }
        .padding(10).background(XTheme.surface.opacity(0.4)).clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct MasterDSPStrip: View {
    @Binding var cutoff: Double; @Binding var resonance: Double; @Binding var drive: Double; @Binding var reverb: Double
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SYNTH & MASTER").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(XTheme.textTertiary)
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    VStack(alignment: .leading, spacing: 2) { Text("Cutoff: \(Int(cutoff))Hz").font(.system(size: 9)).foregroundColor(XTheme.textSecondary).lineLimit(1).fixedSize(horizontal: true, vertical: false); Slider(value: $cutoff, in: 100...12000).tint(XTheme.primary) }
                    VStack(alignment: .leading, spacing: 2) { Text("Res: \(Int(resonance * 100))%").font(.system(size: 9)).foregroundColor(XTheme.textSecondary).lineLimit(1).fixedSize(horizontal: true, vertical: false); Slider(value: $resonance, in: 0...0.9).tint(XTheme.expression) }
                }
                GridRow {
                    VStack(alignment: .leading, spacing: 2) { Text("Drive: \(Int(drive * 100))%").font(.system(size: 9)).foregroundColor(XTheme.textSecondary).lineLimit(1).fixedSize(horizontal: true, vertical: false); Slider(value: $drive, in: 0...1.0).tint(XTheme.tense) }
                    VStack(alignment: .leading, spacing: 2) { Text("Reverb: \(Int(reverb))%").font(.system(size: 9)).foregroundColor(XTheme.textSecondary).lineLimit(1).fixedSize(horizontal: true, vertical: false); Slider(value: $reverb, in: 0...50).tint(XTheme.primary) }
                }
            }
        }
        .padding(10).background(XTheme.surface.opacity(0.5)).clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Remaining Views

struct ActiveNotesView: View {
    @Environment(AppState.self) private var appState
    var body: some View {
        HStack(spacing: 6) {
            ForEach(appState.activeNotes, id: \.midiNote) { note in ExpressiveNoteGlyph(note: note) }
            if appState.activeNotes.isEmpty { Text("No notes playing").font(.caption).foregroundColor(XTheme.textTertiary) }
            Spacer()
            if let theory = appState.lastFrame?.theoryExplanation {
                Text(theory).font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundColor(XTheme.accent).lineLimit(1).fixedSize(horizontal: true, vertical: false)
            }
        }
        .padding(.horizontal, 4).frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44, alignment: .leading)
    }
}

struct ExpressiveNoteGlyph: View {
    @Environment(AppState.self) private var appState; @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let note: Note; private var isLead: Bool { appState.activeNotes.max()?.midiNote == note.midiNote }
    private var bend: Double { guard isLead else { return 0 }; return appState.lastFrame?.bend.bendSemitones ?? 0 }
    private var pressure: Double { guard isLead else { return 0 }; return appState.lastFrame?.pressure.smoothed ?? 0 }
    var body: some View {
        let lift = reduceMotion ? 0 : CGFloat(max(-18, min(18, bend * 8))); let halo = 8 + pressure * 10
        ZStack {
            if isLead && abs(bend) > 0.08 {
                Path { p in p.move(to: CGPoint(x: 18, y: 22)); p.addQuadCurve(to: CGPoint(x: 18, y: 22 - lift), control: CGPoint(x: 28, y: 22 - lift * 0.5)) }
                    .stroke(XTheme.accent.opacity(0.8), lineWidth: 1.5).frame(width: 36, height: 36)
            }
            Text(note.displayName).font(.system(size: 12 + pressure * 3, weight: .medium, design: .monospaced)).foregroundColor(XTheme.textPrimary).padding(.horizontal, 8).padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 4).fill(XTheme.primary.opacity(0.2 + pressure * 0.25)).overlay(RoundedRectangle(cornerRadius: 4).stroke(XTheme.primary.opacity(0.4 + pressure * 0.4), lineWidth: 1)))
                .offset(y: -lift).shadow(color: XTheme.accent.opacity(pressure * 0.5), radius: halo)
        }
        .frame(height: 44)
    }
}

struct TechniqueHintBanner: View {
    let text: String
    var body: some View {
        Text(text).font(.system(size: 11, weight: .medium)).foregroundColor(XTheme.textSecondary).padding(.horizontal, 10).padding(.vertical, 6).background(Capsule().fill(XTheme.surfaceElevated))
    }
}

struct StrumIndicatorView: View {
    @Environment(AppState.self) private var appState
    var body: some View {
        let cs = appState.controllerManager.controllerState
        let hli = appState.controllerManager.isConnected || cs.hasVisiblePerformanceInput
        PerformanceFeedbackStrip(frame: hli ? appState.lastFrame : nil, velocity: hli ? appState.lastVelocity : 0, direction: hli ? appState.lastStrumDirection : .none, lastStrumTime: hli ? appState.lastStrumTime : nil, gestureLabel: appState.hudLabels.rightStick, supportsStrumming: appState.instrumentProfile.supportsStrumming, stringCount: appState.instrumentProfile.stringCount)
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
        Text(label).font(.system(size: 10, weight: .semibold)).foregroundColor(XTheme.tensionColor(tension)).padding(.horizontal, 8).padding(.vertical, 3).background(Capsule().fill(XTheme.tensionColor(tension).opacity(0.15)))
    }
}

// MARK: - Performance Monitor

struct PerformanceMonitorView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(XTheme.primary)
                Text("PERFORMANCE")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(XTheme.textTertiary)
                Spacer()
                if let technique = appState.lastFrame?.activeTechnique, technique != .normal {
                    Text(technique.playLabel ?? "")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(XTheme.primary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(XTheme.primary.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
            
            HStack(spacing: 12) {
                // Pitch Bend
                ExpressionBar(
                    label: "Bend",
                    value: appState.lastFrame?.bend.bendSemitones ?? 0,
                    range: -12...12,
                    color: XTheme.expression
                )
                
                // Pressure / Aftertouch
                ExpressionBar(
                    label: "Pressure",
                    value: appState.lastFrame?.pressure.smoothed ?? 0,
                    range: 0...1,
                    color: XTheme.primary
                )
                
                // Timbre / CC74
                ExpressionBar(
                    label: "Timbre",
                    value: appState.lastFrame?.timbre ?? 0,
                    range: 0...1,
                    color: XTheme.tense
                )
                
                // Palm Mute
                ExpressionBar(
                    label: "Mute",
                    value: appState.lastFrame?.palmMuteAmount ?? 0,
                    range: 0...1,
                    color: XTheme.accent
                )
                
                // Active notes count
                VStack(spacing: 2) {
                    Text("Notes")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundColor(XTheme.textTertiary)
                    Text("\(appState.activeNotes.count)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(appState.activeNotes.isEmpty ? XTheme.textTertiary : XTheme.textPrimary)
                        .contentTransition(.numericText())
                    Spacer()
                }
                .frame(width: 40)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(XTheme.surface.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct ExpressionBar: View {
    let label: String
    let value: Double
    let range: ClosedRange<Double>
    let color: Color
    
    private var normalized: Double {
        let minVal = range.lowerBound
        let maxVal = range.upperBound
        guard maxVal > minVal else { return 0 }
        return (value - minVal) / (maxVal - minVal)
    }
    
    private var isBipolar: Bool { range.lowerBound < 0 }
    
    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundColor(XTheme.textTertiary)
            GeometryReader { geo in
                let mid = geo.size.width / 2
                ZStack(alignment: .leading) {
                    // Track
                    Capsule()
                        .fill(XTheme.surface)
                        .frame(height: 6)
                    if isBipolar {
                        // Center marker
                        Rectangle()
                            .fill(XTheme.border)
                            .frame(width: 1, height: 6)
                            .offset(x: mid - 0.5)
                        // Fill from center
                        if normalized >= 0.5 {
                            Capsule()
                                .fill(color.opacity(0.7))
                                .frame(width: max(0, (normalized - 0.5) * geo.size.width), height: 6)
                                .offset(x: mid)
                        } else {
                            Capsule()
                                .fill(color.opacity(0.7))
                                .frame(width: max(0, (0.5 - normalized) * geo.size.width), height: 6)
                                .offset(x: normalized * geo.size.width)
                        }
                    } else {
                        Capsule()
                            .fill(color.opacity(0.7))
                            .frame(width: max(0, normalized * geo.size.width), height: 6)
                    }
                }
            }
            .frame(height: 6)
            Text(formatValue())
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(XTheme.textSecondary)
        }
        .frame(minWidth: 50)
    }
    
    private func formatValue() -> String {
        if isBipolar {
            return String(format: "%+.1f", value)
        }
        return String(format: "%.0f%%", normalized * 100)
    }
}

// MARK: - MIDI Activity Indicator

struct MIDIActivityView: View {
    @Environment(AppState.self) private var appState
    @State private var lastNoteOnTime: Date?
    @State private var lastNoteOffTime: Date?
    @State private var noteOnFlash: Bool = false
    @State private var noteOffFlash: Bool = false
    @State private var lastActiveCount: Int = 0
    
    var body: some View {
        VStack(spacing: 3) {
            Text("MIDI")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(XTheme.textTertiary)
            
            HStack(spacing: 6) {
                // Note On indicator
                Circle()
                    .fill(noteOnFlash ? XTheme.primary : XTheme.surface)
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle().stroke(XTheme.primary.opacity(0.4), lineWidth: 1)
                    )
                
                // Note count
                Text("\(appState.activeNotes.count)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(appState.activeNotes.isEmpty ? XTheme.textTertiary : XTheme.primary)
                    .contentTransition(.numericText())
                
                // Note Off indicator
                Circle()
                    .fill(noteOffFlash ? XTheme.tense : XTheme.surface)
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle().stroke(XTheme.tense.opacity(0.4), lineWidth: 1)
                    )
                
                Spacer()
                
                // Port indicator
                Text(appState.destinationProfile.supportsMPE ? "MPE" : "MIDI")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(appState.destinationProfile.supportsMPE ? XTheme.primary : XTheme.textSecondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(XTheme.surface.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onChange(of: appState.activeNotes.count) { _, newCount in
            if newCount > lastActiveCount {
                triggerNoteOnFlash()
            } else if newCount < lastActiveCount {
                triggerNoteOffFlash()
            }
            lastActiveCount = newCount
        }
    }
    
    private func triggerNoteOnFlash() {
        noteOnFlash = true
        withAnimation(.easeOut(duration: 0.15)) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { noteOnFlash = false }
        }
    }
    
    private func triggerNoteOffFlash() {
        noteOffFlash = true
        withAnimation(.easeOut(duration: 0.15)) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { noteOffFlash = false }
        }
    }
}
