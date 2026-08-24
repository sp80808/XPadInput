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
    case spatial = "Spatial 3D"
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
            let metrics = ViewportMetrics(size: geo.size)
            let leftWidth = geo.size.width * metrics.leftColumnRatio
            let rightWidth = geo.size.width - leftWidth
            
            let isCompactH = metrics.isCompactHeight
            let isExpandedH = metrics.heightClass == .expanded
            
            let chordDisplayHeight: CGFloat = isCompactH ? 58 : (isExpandedH ? 80 : 72)
            let wheelMinH: CGFloat = isCompactH ? 180 : (isExpandedH ? 280 : 230)
            let arcadeLaneH: CGFloat = isCompactH ? 108 : 128
            let tabMinH: CGFloat = isCompactH ? 130 : 170
            let controllerH: CGFloat = isCompactH ? 215 : (isExpandedH ? 295 : 255)
            let quickControlsH: CGFloat = isCompactH ? 44 : 50
            let perfMonitorH: CGFloat = isCompactH ? 76 : (isExpandedH ? 96 : 88)
            let dspTabMinH: CGFloat = isCompactH ? 120 : 145
            let strumMidiH: CGFloat = isCompactH ? 50 : (isExpandedH ? 64 : 58)
            let colPadding: CGFloat = isCompactH ? 8 : (metrics.isCompactWidth ? 10 : 12)
            let colSpacing: CGFloat = isCompactH ? 6 : 8
            
            HStack(spacing: 0) {
                // LEFT COLUMN: Harmonic Workspace
                VStack(spacing: colSpacing) {
                    // Multi-Jam Bar (when active)
                    if appState.multiJamManager.isSessionActive {
                        MultiControllerJammingBarView(jammingManager: appState.multiJamManager)
                            .transition(.opacity)
                    }

                    // Current Chord Display
                    EnhancedChordDisplayView()
                        .frame(height: chordDisplayHeight)

                    // Solo HUD (when active)
                    if appState.instrumentProfile.family == .synthLead || appState.isSoloModeActive {
                        SmartSoloHUDView(telemetry: appState.smartSoloEngine.telemetry, chord: appState.currentChord)
                            .transition(.opacity)
                    }

                    // Contextual Hint (when active)
                    ContextualHintSlot()

                    // Arcade Frets lane (hidden Guitar Hero mode)
                    if appState.isArcadeModeEnabled {
                        ArcadeLaneView()
                            .frame(height: arcadeLaneH)
                            .transition(.opacity)
                    }

                    // Harmonic Wheel - chord selection via stick
                    HarmonicWheelView()
                        .frame(minHeight: wheelMinH, maxHeight: .infinity)
                        .padding(.vertical, isCompactH ? 2 : 4)

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
                    .frame(minHeight: tabMinH, maxHeight: .infinity)

                    // Active Notes
                    ActiveNotesView()
                }
                .padding(colPadding)
                .frame(width: leftWidth)
                .animation(.easeInOut(duration: 0.25), value: appState.multiJamManager.isSessionActive)
                .animation(.easeInOut(duration: 0.25), value: appState.isSoloModeActive)
                .animation(.easeInOut(duration: 0.25), value: appState.isArcadeModeEnabled)
                
                Divider().background(XTheme.border)
                
                // RIGHT COLUMN: Controller & Performance Workspace - Primary focus
                VStack(spacing: colSpacing) {
                    // Controller Visualizer - Prominent
                    ControllerVisualizerView()
                        .frame(height: controllerH)

                    // Performance Quick Controls
                    PerformanceQuickControlsView()
                        .frame(height: quickControlsH)

                    // Real-time Performance Monitor
                    PerformanceMonitorView()
                        .frame(height: perfMonitorH)

                    // Tabbed: Performance | Synth | FX
                    DSPTabbedWorkspace(
                        tab: $dspWorkspaceTab,
                        cutoff: $filterCutoff,
                        resonance: $filterResonance,
                        drive: $saturation,
                        reverb: $reverbMix
                    )
                    .frame(minHeight: dspTabMinH, maxHeight: .infinity)

                    // Strum Indicator & MIDI Activity
                    HStack(spacing: 8) {
                        StrumIndicatorView()
                        MIDIActivityView()
                    }
                    .frame(height: strumMidiH)
                }
                .padding(colPadding)
                .frame(width: rightWidth)
            }
            .environment(\.viewportMetrics, metrics)
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
        if let hint = appState.contextualHint, !appState.activeNotes.isEmpty {
            HStack {
                TechniqueHintBanner(text: hint)
                Spacer()
            }
            .frame(height: 32)
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .move(edge: .top)),
                removal:   .opacity
            ))
        }
    }
}

// MARK: - Enhanced Chord Display with Always-Visible Key/Scale

struct EnhancedChordDisplayView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.viewportMetrics) private var viewport
    @State private var previousChordName: String?
    @State private var chordFlash: Bool = false
    
    var body: some View {
        let currentName = appState.currentChord?.displayName ?? "-"
        let chordChanged = previousChordName != currentName && previousChordName != nil
        let displayName = chordChanged && !reduceMotion ? (previousChordName ?? "-") : currentName
        let isCompact = viewport.isCompactHeight
        
        HStack(spacing: isCompact ? 10 : 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(.system(size: isCompact ? 26 : 34, weight: .bold, design: .rounded))
                    .foregroundColor(XTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(height: isCompact ? 30 : 38)
                    .animation(reduceMotion ? nil : .spring(response: 0.2, dampingFraction: 0.75), value: currentName)
                    .overlay {
                        if chordFlash && !reduceMotion {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(XTheme.primary.opacity(0.22))
                                .allowsHitTesting(false)
                        }
                    }
                if let chord = appState.currentChord {
                    HStack(spacing: 6) {
                        if let roman = chord.romanNumeral(in: appState.currentKey, scale: appState.currentScale) {
                            Text(roman).font(.system(size: isCompact ? 13 : 15, weight: .semibold, design: .monospaced)).foregroundColor(XTheme.primary)
                        }
                        TensionBadge(tension: chord.tension(in: appState.currentKey, scale: appState.currentScale))
                    }
                    .frame(height: isCompact ? 18 : 22)
                } else {
                    Spacer().frame(height: isCompact ? 18 : 22)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: isCompact ? 2 : 4) {
                ActiveTechniqueStatusView(compact: isCompact)
                    .frame(height: isCompact ? 20 : 24)
                HStack(spacing: 4) {
                    Text(appState.currentKey.displayName)
                        .font(.system(size: isCompact ? 15 : 18, weight: .bold, design: .rounded))
                        .foregroundColor(XTheme.primary)
                    Text("•")
                        .font(.system(size: isCompact ? 14 : 18, weight: .bold))
                        .foregroundColor(XTheme.textTertiary)
                    Text(appState.currentScale.displayName)
                        .font(.system(size: isCompact ? 12 : 14, weight: .medium))
                        .foregroundColor(XTheme.textSecondary)
                        .lineLimit(1)
                }
                .frame(height: isCompact ? 22 : 28)
            }
        }
        .padding(.horizontal, isCompact ? 10 : 14)
        .xCard(isActive: appState.currentChord != nil)
        .onChange(of: currentName) { _, newName in
            previousChordName = newName
            guard !reduceMotion else { return }
            chordFlash = true
            withAnimation(.easeOut(duration: 0.35)) { chordFlash = false }
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
    @Namespace private var tabNS
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(HarmonicWorkspaceTab.allCases) { t in
                    TabButton(title: t.rawValue, isSelected: tab == t, action: { tab = t },
                              namespace: tabNS, namespaceID: "harmonic-tab-pill")
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
    @Namespace private var dspTabNS
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(DSPWorkspaceTab.allCases) { t in
                    TabButton(title: t.rawValue, isSelected: tab == t, action: { tab = t },
                              namespace: dspTabNS, namespaceID: "dsp-tab-pill")
                }
                Spacer()
            }
            .padding(.horizontal, 4)
            ZStack {
                switch tab {
                case .performance: PerformanceDSPPanel()
                case .synth: MasterDSPStrip(cutoff: $cutoff, resonance: $resonance, drive: $drive, reverb: $reverb)
                case .fx: FXDSPPanel(cutoff: $cutoff, resonance: $resonance, drive: $drive, reverb: $reverb)
                case .spatial: SpatialAudioVisualizerView()
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
    var namespace: Namespace.ID? = nil
    var namespaceID: String = ""

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(isSelected ? XTheme.primary : XTheme.textTertiary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .frame(minWidth: 48)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(XTheme.primary.opacity(0.18))
                            .overlay(Capsule().stroke(XTheme.primary, lineWidth: 1))
                            .matchedGeometryEffect(id: namespaceID, in: namespace ?? Namespace().wrappedValue)
                    } else {
                        Capsule().fill(Color.clear)
                    }
                }
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(XTheme.snappy, value: isSelected)
    }
}

// MARK: - DSP Panels

private struct PerformanceDSPPanel: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("PERFORMANCE LANES")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(XTheme.textTertiary)
                Spacer()
                Text(appState.instrumentProfile.name.uppercased())
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(XTheme.primary)
            }

            HStack(spacing: 8) {
                RegisterLaneStepper(
                    title: "Strum",
                    subtitle: "Chord voicing",
                    icon: "guitars.fill",
                    accent: XTheme.primary,
                    value: Binding(
                        get: { appState.performanceRegisters.strumOctave },
                        set: { appState.setStrumOctave($0) }
                    )
                )

                RegisterLaneStepper(
                    title: "Face",
                    subtitle: "Root · 3rd · 5th · 7th",
                    icon: "circle.grid.2x2.fill",
                    accent: XTheme.expression,
                    value: Binding(
                        get: { appState.performanceRegisters.faceButtonOctave },
                        set: { appState.setFaceButtonOctave($0) }
                    )
                )

                PerformanceOutputStatus()
            }
        }
        .padding(4)
    }
}

private struct RegisterLaneStepper: View {
    let title: String
    let subtitle: String
    let icon: String
    let accent: Color
    let value: Binding<Int>

    var body: some View {
        Stepper(value: value, in: PerformanceLaneRegisters.supportedOctaves) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(accent)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(XTheme.textPrimary)
                        Text("OCT \(value.wrappedValue)")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(accent)
                    }
                    Text(subtitle)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(XTheme.textTertiary)
                        .lineLimit(1)
                }
            }
        }
        .controlSize(.small)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 52)
        .background(
            RoundedRectangle(cornerRadius: XTheme.radiusSmall)
                .fill(XTheme.surfaceElevated.opacity(0.78))
                .overlay(
                    RoundedRectangle(cornerRadius: XTheme.radiusSmall)
                        .stroke(accent.opacity(0.24), lineWidth: 1)
                )
        )
        .accessibilityLabel("\(title) register")
        .accessibilityValue("Octave \(value.wrappedValue)")
        .help("Set the \(title.lowercased()) lane to octave \(value.wrappedValue)")
    }
}

private struct PerformanceOutputStatus: View {
    @Environment(AppState.self) private var appState

    private var protocolLabel: String {
        appState.resolvedLayout.usesMPE ? "MPE" : "MIDI"
    }

    private var outputState: String {
        if appState.midiEngine.virtualMIDIEnabled,
           appState.midiEngine.setupErrorDescription != nil {
            return "MIDI SETUP ERROR"
        }
        return appState.midiEngine.virtualMIDIEnabled ? "VIRTUAL MIDI ON" : "INTERNAL AUDIO"
    }

    private var statusColor: Color {
        if appState.midiEngine.virtualMIDIEnabled,
           appState.midiEngine.setupErrorDescription != nil {
            return XTheme.tense
        }
        return appState.midiEngine.virtualMIDIEnabled ? XTheme.midiActivity : XTheme.primary
    }

    private var bendLabel: String {
        let range = appState.destinationProfile.bendRangeSemitones
        return range.rounded() == range ? "±\(Int(range)) ST" : String(format: "±%.1f ST", range)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)
                Text(outputState)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(XTheme.textSecondary)
            }

            Text(appState.activeHostKind.rawValue)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(XTheme.textPrimary)
                .lineLimit(1)

            Text("\(protocolLabel) · \(bendLabel)")
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundColor(XTheme.textTertiary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(minWidth: 122, maxWidth: .infinity, minHeight: 52, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: XTheme.radiusSmall)
                .fill(XTheme.surface.opacity(0.72))
                .overlay(
                    RoundedRectangle(cornerRadius: XTheme.radiusSmall)
                        .stroke(XTheme.border, lineWidth: 1)
                )
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Performance output")
        .accessibilityValue("\(outputState), \(appState.activeHostKind.rawValue), \(protocolLabel), bend range \(bendLabel)")
        .help(
            appState.midiEngine.virtualMIDIEnabled
                ? appState.midiEngine.setupErrorDescription ?? "Virtual MIDI sources are enabled"
                : "Internal audio is active; virtual MIDI sources are off"
        )
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
                    ChordPadButton(chord: chord, index: index, isActive: isActive, reduceMotion: reduceMotion, onSelect: onSelect)
                }
            }
        }
        .padding(10).background(XTheme.surface.opacity(0.5)).clipShape(RoundedRectangle(cornerRadius: 8))
    }
    private func romanNumeral(for degree: Int) -> String {
        ["I","ii","iii","IV","V","vi","vii°"][degree-1] ?? "\(degree)"
    }
}

/// Individual diatonic chord pad — isolated so xRipple state is per-pad.
private struct ChordPadButton: View {
    let chord: Chord
    let index: Int
    let isActive: Bool
    let reduceMotion: Bool
    let onSelect: (Chord) -> Void
    @State private var rippleTrigger = 0

    private func romanNumeral(for degree: Int) -> String {
        ["I","ii","iii","IV","V","vi","vii°"][degree-1] ?? "\(degree)"
    }

    var body: some View {
        Button {
            if !reduceMotion { rippleTrigger += 1 }
            onSelect(chord)
        } label: {
            VStack(spacing: 3) {
                Text(romanNumeral(for: index + 1)).font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(isActive ? XTheme.primaryLight : XTheme.primary)
                Text(chord.symbol).font(.system(size: 11, weight: .bold)).foregroundColor(isActive ? .white : XTheme.textPrimary).lineLimit(1).fixedSize(horizontal: true, vertical: false)
            }
            .frame(maxWidth: .infinity, minHeight: 54, maxHeight: 54)
            .background(isActive ? XTheme.primary.opacity(0.3) : XTheme.surface)
            .xShimmer(isActive: isActive)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(isActive ? XTheme.primary : XTheme.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .scaleEffect(isActive && !reduceMotion ? 0.94 : 1.0)
        .animation(reduceMotion ? nil : XTheme.feedbackFast, value: isActive)
        .xRipple(trigger: rippleTrigger, color: XTheme.primary, size: 54)
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
                            .xShimmer(isActive: isSelected)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(isSelected ? XTheme.primary : XTheme.border, lineWidth: 1.5))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        .animation(XTheme.snappy, value: isSelected)
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
                    icon: "arrow.left.and.right",
                    value: appState.lastFrame?.bend.bendSemitones ?? 0,
                    range: -12...12,
                    color: XTheme.expression,
                    trail: appState.expressionTrails.bend
                )
                
                // Pressure / Aftertouch
                ExpressionBar(
                    label: "Pressure",
                    icon: "hand.raised.fill",
                    value: appState.lastFrame?.pressure.smoothed ?? 0,
                    range: 0...1,
                    color: XTheme.primary,
                    trail: appState.expressionTrails.pressure
                )
                
                // Timbre / CC74
                ExpressionBar(
                    label: "Timbre",
                    icon: "slider.horizontal.2.square",
                    value: appState.lastFrame?.timbre ?? 0,
                    range: 0...1,
                    color: XTheme.tense,
                    trail: appState.expressionTrails.timbre
                )
                
                // Palm Mute
                ExpressionBar(
                    label: "Mute",
                    icon: "hand.tap.fill",
                    value: appState.lastFrame?.palmMuteAmount ?? 0,
                    range: 0...1,
                    color: XTheme.accent,
                    trail: appState.expressionTrails.mute
                )
                
                // Active notes count
                VStack(spacing: 2) {
                    Image(systemName: "music.note")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(XTheme.textTertiary)
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
    var icon: String? = nil          // optional SF Symbol prefix
    let value: Double
    let range: ClosedRange<Double>
    let color: Color
    var trail: [Double]? = nil
    
    private var normalized: Double {
        let minVal = range.lowerBound
        let maxVal = range.upperBound
        guard maxVal > minVal else { return 0 }
        return (value - minVal) / (maxVal - minVal)
    }
    
    private var isBipolar: Bool { range.lowerBound < 0 }
    
    var body: some View {
        VStack(spacing: 2) {
            // Icon + label row
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(color.opacity(0.75))
            }
            Text(label)
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundColor(XTheme.textTertiary)
            GeometryReader { geo in
                let width = geo.size.width
                let height = geo.size.height
                let mid = width / 2
                
                ZStack(alignment: .leading) {
                    // Waveform Sparkline Trail in background
                    if let trail = trail, trail.count > 1 {
                        ExpressionSparkline(values: trail, range: range, color: color)
                            .frame(width: width, height: height)
                    }

                    // Track
                    Capsule()
                        .fill(XTheme.surface.opacity(trail != nil ? 0.45 : 1.0))
                        .frame(height: 6)
                        .position(x: mid, y: height / 2)

                    if isBipolar {
                        // Center marker
                        Rectangle()
                            .fill(XTheme.border)
                            .frame(width: 1, height: 6)
                            .position(x: mid, y: height / 2)
                        // Fill from center
                        if normalized >= 0.5 {
                            Capsule()
                                .fill(color.opacity(0.85))
                                .frame(width: max(0, (normalized - 0.5) * width), height: 6)
                                .position(x: mid + max(0, (normalized - 0.5) * width) / 2, y: height / 2)
                        } else {
                            Capsule()
                                .fill(color.opacity(0.85))
                                .frame(width: max(0, (0.5 - normalized) * width), height: 6)
                                .position(x: normalized * width + max(0, (0.5 - normalized) * width) / 2, y: height / 2)
                        }
                    } else {
                        Capsule()
                            .fill(color.opacity(0.85))
                            .frame(width: max(0, normalized * width), height: 6)
                            .position(x: max(0, normalized * width) / 2, y: height / 2)
                    }
                }
            }
            .frame(height: 14)
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

private struct ExpressionSparkline: View {
    let values: [Double]
    let range: ClosedRange<Double>
    let color: Color

    var body: some View {
        Canvas { context, size in
            guard values.count > 1, size.width > 0, size.height > 0 else { return }
            let minVal = range.lowerBound
            let maxVal = range.upperBound
            guard maxVal > minVal else { return }
            let span = maxVal - minVal

            var path = Path()
            let step = size.width / CGFloat(values.count - 1)

            for (index, val) in values.enumerated() {
                let clamped = max(minVal, min(maxVal, val))
                let norm = (clamped - minVal) / span
                let x = CGFloat(index) * step
                let y = (1.0 - CGFloat(norm)) * (size.height - 2) + 1

                if index == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }

            context.stroke(
                path,
                with: .color(color.opacity(0.35)),
                lineWidth: 1.5
            )
        }
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
