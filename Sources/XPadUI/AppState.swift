import SwiftUI
import AppKit
import XPadCore
import XPadTheory
import XPadController
import XPadMIDI
import XPadAudio
import XPadSequencer
import XPadPractice

/// Central application state coordinating all engines.
@Observable
@MainActor
public final class AppState: @unchecked Sendable {
    /// Held for the app's lifetime to prevent macOS App Nap from throttling
    /// real-time MIDI output and audio processing when another app (e.g. Ableton) has focus.
    private let backgroundActivity: NSObjectProtocol = ProcessInfo.processInfo.beginActivity(
        options: [.userInitiated, .latencyCritical],
        reason: "XPadInput requires continuous low-latency gamepad, MIDI, and audio processing"
    )

    public var controllerManager = ControllerManager()
    public var midiEngine: MIDIEngine
    public var audioEngine = AudioEngine()
    public var mpeManager: MPEManager
    public var performanceEngine = InstrumentPerformanceEngine()
    public var midiTranslator = TechniqueMIDITranslator()
    public var techniqueRecorder = TechniqueRecorder()
    public var virtualAudioDriver = VirtualAudioDriver.shared
    public var loopbackEngine = VirtualAudioLoopbackEngine.shared
    public var multiJamManager = MultiControllerJammingManager()
    public var smartSoloEngine = SmartSoloEngine()
    public var ocdsManager = OCDSManager.shared
    public var sequencer = Sequencer()
    public var practiceEngine = PracticeEngine()
    public var progressTracker = ProgressTracker.shared
    public var isSoloModeActive: Bool = false
    public private(set) var performanceRegisters = PerformanceLaneRegisters.defaults(for: .guitar)

    @available(*, deprecated, message: "Use performanceRegisters and the lane-specific register setters.")
    public var performanceOctaveOffset: Int {
        get {
            let defaultOctave = PerformanceLaneRegisters.defaults(for: instrumentProfile.family).strumOctave
            return performanceRegisters.strumOctave - defaultOctave
        }
        set {
            var updated = PerformanceLaneRegisters.defaults(for: instrumentProfile.family)
            updated.shiftBoth(by: newValue)
            applyPerformanceRegisters(updated)
        }
    }
    public var voicingInversion: Int = 0

    public var currentKey: PitchClass = .d
    public var currentScale: Scale = .naturalMinor
    public var currentTemperament: MicrotonalTemperament = .equalTemperament
    public var isPlaying: Bool = false {
        didSet {
            if isPlaying {
                sequencer.play()
            } else {
                sequencer.stop()
            }
        }
    }
    public var isRecording: Bool = false
    public var bpm: Double = 120.0 {
        didSet {
            sequencer.transport.bpm = bpm
        }
    }
    public var isLooping: Bool = false {
        didSet {
            sequencer.transport.loopEnabled = isLooping
        }
    }
    public var metronomeEnabled: Bool = false

    public var diatonicChords: [Chord] = []
    public var selectedChordIndex: Int = 0
    public var currentChord: Chord?
    public var previousVoicing: ChordVoicing?

    /// Last 8 chords played, newest first. Used by ChordHistoryStrip in PlayView.
    public private(set) var chordHistory: [Chord] = []
    private static let chordHistoryCapacity = 8

    public var activeNotes: [Note] = []
    public var lastStrumDirection: StrumDirection = .none
    public var lastVelocity: UInt8 = 0
    /// 16-bit companion to `lastVelocity` — preserved from the strum intensity
    /// float so MIDI 2 NoteOn carries native resolution rather than a 7→16 upscale.
    public var lastVelocity16: UInt16 = 0
    public var lastStrumTime: Date?

    public var selectedWorkspace: Workspace = .play
    public var showDiagnostics: Bool = false

    /// Onboarding — set false once the user completes or dismisses the tutorial.
    public var showOnboarding: Bool = !UserDefaults.standard.bool(forKey: "xpi_onboarding_complete")

    public var pluginInstallStatus: PluginInstaller.Status = PluginInstaller.shared.status

    public func installPlugins() {
        pluginInstallStatus = PluginInstaller.shared.install()
    }

    public func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "xpi_onboarding_complete")
        showOnboarding = false
    }

    /// Help panel visibility
    public var showHelpPanel: Bool = false

    // MARK: - Workspace Layout & Section Visibility

    /// Horizontal split ratio between Left (Harmonic) and Right (Controller/DSP) columns.
    public var playSplitRatio: CGFloat = {
        let stored = UserDefaults.standard.double(forKey: "xpi_play_split_ratio")
        return stored > 0.15 && stored < 0.85 ? CGFloat(stored) : 0.38
    }() {
        didSet {
            UserDefaults.standard.set(Double(playSplitRatio), forKey: "xpi_play_split_ratio")
        }
    }

    /// Vertical split ratio inside Left Column between Harmonic Wheel and Tabbed Area.
    public var leftVerticalSplitRatio: CGFloat = {
        let stored = UserDefaults.standard.double(forKey: "xpi_left_vsplit_ratio")
        return stored > 0.20 && stored < 0.85 ? CGFloat(stored) : 0.58
    }() {
        didSet {
            UserDefaults.standard.set(Double(leftVerticalSplitRatio), forKey: "xpi_left_vsplit_ratio")
        }
    }

    /// Vertical split ratio inside Right Column between Controller HUD and DSP Workspace.
    public var rightVerticalSplitRatio: CGFloat = {
        let stored = UserDefaults.standard.double(forKey: "xpi_right_vsplit_ratio")
        return stored > 0.20 && stored < 0.85 ? CGFloat(stored) : 0.48
    }() {
        didSet {
            UserDefaults.standard.set(Double(rightVerticalSplitRatio), forKey: "xpi_right_vsplit_ratio")
        }
    }

    public var showHarmonicPanel: Bool = {
        UserDefaults.standard.object(forKey: "xpi_show_harmonic_panel") != nil ? UserDefaults.standard.bool(forKey: "xpi_show_harmonic_panel") : true
    }() {
        didSet { UserDefaults.standard.set(showHarmonicPanel, forKey: "xpi_show_harmonic_panel") }
    }

    public var showControllerVisualizer: Bool = {
        UserDefaults.standard.object(forKey: "xpi_show_controller_viz") != nil ? UserDefaults.standard.bool(forKey: "xpi_show_controller_viz") : true
    }() {
        didSet { UserDefaults.standard.set(showControllerVisualizer, forKey: "xpi_show_controller_viz") }
    }

    public var showPerformanceQuickControls: Bool = {
        UserDefaults.standard.object(forKey: "xpi_show_quick_controls") != nil ? UserDefaults.standard.bool(forKey: "xpi_show_quick_controls") : true
    }() {
        didSet { UserDefaults.standard.set(showPerformanceQuickControls, forKey: "xpi_show_quick_controls") }
    }

    public var showPerformanceMonitor: Bool = {
        UserDefaults.standard.object(forKey: "xpi_show_perf_monitor") != nil ? UserDefaults.standard.bool(forKey: "xpi_show_perf_monitor") : true
    }() {
        didSet { UserDefaults.standard.set(showPerformanceMonitor, forKey: "xpi_show_perf_monitor") }
    }

    public var showDSPWorkspace: Bool = {
        UserDefaults.standard.object(forKey: "xpi_show_dsp_workspace") != nil ? UserDefaults.standard.bool(forKey: "xpi_show_dsp_workspace") : true
    }() {
        didSet { UserDefaults.standard.set(showDSPWorkspace, forKey: "xpi_show_dsp_workspace") }
    }

    public var showStrumMidiBar: Bool = {
        UserDefaults.standard.object(forKey: "xpi_show_strum_midi_bar") != nil ? UserDefaults.standard.bool(forKey: "xpi_show_strum_midi_bar") : true
    }() {
        didSet { UserDefaults.standard.set(showStrumMidiBar, forKey: "xpi_show_strum_midi_bar") }
    }

    public var showHarmonicTabSection: Bool = {
        UserDefaults.standard.object(forKey: "xpi_show_harmonic_tabs") != nil ? UserDefaults.standard.bool(forKey: "xpi_show_harmonic_tabs") : true
    }() {
        didSet { UserDefaults.standard.set(showHarmonicTabSection, forKey: "xpi_show_harmonic_tabs") }
    }

    public func resetPlayLayout() {
        playSplitRatio = 0.38
        leftVerticalSplitRatio = 0.58
        rightVerticalSplitRatio = 0.48
        showHarmonicPanel = true
        showControllerVisualizer = true
        showPerformanceQuickControls = true
        showPerformanceMonitor = true
        showDSPWorkspace = true
        showStrumMidiBar = true
        showHarmonicTabSection = true
    }

    // MARK: Learn Hub — guided interactive tutorials

    /// Live engine validating controller input against the active mission steps.
    public let tutorialEngine = TutorialEngine()
    public var showLearnHub: Bool = false
    public var activeTutorialMissionID: String?

    public var activeTutorialMission: TutorialMission? {
        guard let id = activeTutorialMissionID else { return nil }
        return TutorialMission.factoryPresets().first { $0.id == id }
    }

    public func startTutorial(missionID: String) {
        guard let mission = TutorialMission.factoryPresets().first(where: { $0.id == missionID }) else { return }
        tutorialEngine.onMissionComplete = { [weak self] in
            Task { @MainActor in
                if let id = self?.activeTutorialMissionID {
                    TutorialMissionStore.markCompleted(id)
                }
            }
        }
        tutorialEngine.load(mission: mission)
        activeTutorialMissionID = missionID
        showLearnHub = false
    }

    public func endActiveTutorial(markCompleteIfFinished: Bool) {
        if markCompleteIfFinished, tutorialEngine.currentProgress.isMissionComplete,
           let id = activeTutorialMissionID {
            TutorialMissionStore.markCompleted(id)
        }
        tutorialEngine.reset()
        activeTutorialMissionID = nil
    }

    /// Transport bar visibility — persisted so it stays hidden across launches.
    public var showTransportBar: Bool = !UserDefaults.standard.bool(forKey: "xpi_transport_bar_hidden")

    public func toggleTransportBar() {
        showTransportBar.toggle()
        UserDefaults.standard.set(!showTransportBar, forKey: "xpi_transport_bar_hidden")
    }

    /// Practice is opt-in: it is never the launch workspace and does not occupy
    /// persistent chrome until the user explicitly requests it.
    public var isPracticeRequested: Bool {
        selectedWorkspace == .practice
    }

    public func requestPractice() {
        selectedWorkspace = .practice
    }

    public func dismissPractice() {
        if practiceEngine.isPracticeActive {
            practiceEngine.stopPractice()
        }
        selectedWorkspace = .play
    }

    public func togglePractice() {
        if isPracticeRequested {
            dismissPractice()
        } else {
            requestPractice()
        }
    }

    public func toggleRecording() {
        isRecording.toggle()
        sequencer.transport.isRecording = isRecording
        if isRecording {
            sequencer.transport.currentTick = 0
            if !sequencer.transport.isPlaying {
                sequencer.play()
            }
            techniqueRecorder.start()
        } else {
            _ = techniqueRecorder.stop()
            sequencer.stop()
        }
    }

    public var instrumentProfile: InstrumentProfile = .guitar
    public var destinationProfile: DestinationCapabilityProfile = .internalSynth
    public var hostSelection: DAWHostKind = .autoDetect
    public var activeHostKind: DAWHostKind = .internalSynth
    public var activeHostContext: HostMIDIContext = .internalSynth
    public var hostDetectionNote: String = "No DAW detected. Using Internal Synth."
    public var trackChannelMode: DAWTrackChannelMode = .omni
    public var resolvedLayout = HostMIDIContextResolver.resolveLayout(
        context: .internalSynth,
        trackMode: .omni
    )
    public var expressionSettings = ExpressionSettings()
    public var performancePreset: PerformancePreset = .guitarCleanExpressive
    public var lastFrame: PerformanceFrame?
    public var lastMIDITranslation: MIDITranslationResult?
    public var currentTick: UInt64 {
        sequencer.transport.currentTick
    }
    public var selectedPlayMode: InstrumentPlayMode = .chords
    public var arpeggiatorConfiguration = ArpeggiatorConfiguration()
    public private(set) var arpeggiatorEngine = ArpeggiatorEngine()
    private var arpeggiatorTimer: DispatchSourceTimer?
    public var chordGateConfiguration = ChordGateConfiguration(mode: .timed, timedDuration: 0.85)
    public var duoPerformanceMode: DuoPerformanceMode = .instrumentOnly
    public var lastDrumHit: DuoDrumHit?
    public var midiPassthruMode: MIDIPassthruMode = .full

    // MARK: Arcade Frets (hidden Guitar Hero-style mode)
    public private(set) var isArcadeModeEnabled: Bool = false
    public private(set) var lastArcadeFrame: ArcadeFretFrame = .empty
    /// The dedicated arcade menu-bar entry only materialises after the secret
    /// key combination is discovered. Nothing in the visible UI references it.
    public private(set) var isArcadeMenuUnlocked: Bool = false
    private var arcadeEngine = ArcadeFretEngine()
    private var arcadeStatusItemStorage: ArcadeStatusItemCoordinator?
    private var arcadeUnlockMonitor: Any?

    /// Lazily materialised so the coordinator can capture `self` after init.
    @MainActor
    private var arcadeStatusItem: ArcadeStatusItemCoordinator {
        if let arcadeStatusItemStorage { return arcadeStatusItemStorage }
        let coordinator = ArcadeStatusItemCoordinator(appState: self)
        arcadeStatusItemStorage = coordinator
        return coordinator
    }
    public var expressionTrails = ExpressionTrailHistory()

    private var strumState = StrumState()
    private var heldFaceNotes: [ChordToneRole: Note] = [:]
    private var soundingChordNotes: Set<UInt8> = []
    private var pendingStrumNotes: [DispatchWorkItem] = []
    private var chordGateReleaseWorkItem: DispatchWorkItem?
    private var strumGeneration: UInt64 = 0
    private var lastInputTime = ProcessInfo.processInfo.systemUptime
    private var lastHint: String?
    private var chordGateEngine = ChordGateEngine(
        configuration: ChordGateConfiguration(mode: .timed, timedDuration: 0.85)
    )
    private var arcadeGateEngine = ChordGateEngine(
        configuration: ChordGateConfiguration(mode: .momentary)
    )
    private var velocityStabilizer = VelocityStabilizer()
    private var duoControlEngine = DuoControlEngine()
    private var performanceRegisterMemory = PerformanceLaneRegisterMemory()
    @ObservationIgnored nonisolated(unsafe) private var hostDetectionObserver: (any NSObjectProtocol)?

    public init() {
        let midiEngine = MIDIEngine()
        self.midiEngine = midiEngine
        self.mpeManager = MPEManager(
            midiEngine: midiEngine,
            bendRangeSemitones: DestinationCapabilityProfile.internalSynth.bendRangeSemitones
        )
    }

    public func initialize() {
        // Prevent macOS from terminating XPadInput when it's backgrounded behind Ableton.
        // The backgroundActivity token disables App Nap; these calls prevent auto/sudden termination.
        ProcessInfo.processInfo.disableAutomaticTermination("Active MIDI instrument session")
        ProcessInfo.processInfo.disableSuddenTermination()
        _ = backgroundActivity // Force evaluation of the lazy activity token

        updateDiatonicChords()
        audioEngine.start()
        XPadPluginRegistrar.registerPluginComponents()
        setupIncomingMIDIPassthru()
        installArcadeUnlockMonitor()
        midiEngine.onVirtualMIDIChanged = { [weak self] enabled in
            guard let self else { return }
            if enabled {
                self.mpeManager.sendMPEZoneConfiguration()
            } else {
                self.panic()
            }
        }
        if midiEngine.virtualMIDIEnabled {
            mpeManager.sendMPEZoneConfiguration()
        }
        applyInstrument(instrumentProfile)

        controllerManager.onStateChanged = { [weak self] state in
            self?.handleControllerInput(state)
        }
        controllerManager.onDisconnected = { [weak self] in
            self?.panic()
        }
        controllerManager.onSchemeChanged = { [weak self] _ in
            self?.panic()
        }
        applyHostRouting()
        let notificationCenter = NSWorkspace.shared.notificationCenter
        if let hostDetectionObserver {
            notificationCenter.removeObserver(hostDetectionObserver)
        }
        hostDetectionObserver = notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.hostSelection == .autoDetect else { return }
                let detected = HostMIDIContextResolver.resolve(
                    selection: .autoDetect,
                    signals: HostRuntimeDetector.signals()
                )
                guard detected.kind != self.activeHostKind else { return }
                self.applyHostRouting()
            }
        }
    }

    deinit {
        if let hostDetectionObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(hostDetectionObserver)
        }
    }

    public func setMIDIPassthruMode(_ mode: MIDIPassthruMode) {
        midiPassthruMode = mode
        midiEngine.passthruMode = mode
    }

    public var isSynthMuted: Bool {
        audioEngine.isMuted
    }

    public func toggleSynthMute() {
        audioEngine.toggleMute()
    }

    public func setSynthMuted(_ muted: Bool) {
        audioEngine.setMuted(muted)
    }

    private func setupIncomingMIDIPassthru() {
        midiEngine.passthruMode = midiPassthruMode
        midiEngine.onIncomingEvent = { [weak self] event, _ in
            guard let self else { return }
            guard self.midiPassthruMode.routesToAudio, !self.audioEngine.isMuted else { return }
            Task { @MainActor in
                switch event {
                case .noteOn(_, let note, let velocity):
                    self.audioEngine.noteOn(note: note, velocity: velocity)
                case .noteOff(_, let note):
                    self.audioEngine.noteOff(note: note)
                case .pitchBend(_, let value):
                    let semitones = MIDIValueCodec.semitones(
                        fromPitchBend14: MIDIValueCodec.unsignedPitchBend14(signed: value),
                        range: self.destinationProfile.bendRangeSemitones
                    )
                    for activeNote in self.activeNotes {
                        self.audioEngine.setPitchBend(for: activeNote.midiNote, semitones: semitones)
                    }
                case .channelPressure(_, let pressure):
                    let norm = Double(pressure) / 127.0
                    for activeNote in self.activeNotes {
                        self.audioEngine.setPressure(for: activeNote.midiNote, pressure: norm)
                    }
                case .polyPressure(_, let note, let pressure):
                    let norm = Double(pressure) / 127.0
                    self.audioEngine.setPressure(for: note, pressure: norm)
                case .timbreCC74(_, let value):
                    let norm = Double(value) / 127.0
                    for activeNote in self.activeNotes {
                        self.audioEngine.setTimbre(for: activeNote.midiNote, timbre: norm)
                    }
                case .controlChange(_, let controller, _):
                    if controller == 123 || controller == 120 {
                        self.audioEngine.panic()
                    }
                case .allNotesOff:
                    self.audioEngine.panic()
                }
            }
        }
        midiEngine.onIncomingPerNotePitchBend = { [weak self] _, note, semitones in
            guard let self, self.midiPassthruMode.routesToAudio, !self.audioEngine.isMuted else { return }
            Task { @MainActor in
                self.audioEngine.setPitchBend(for: note, semitones: semitones)
            }
        }
        midiEngine.onIncomingPerNotePressure = { [weak self] _, note, pressure in
            guard let self, self.midiPassthruMode.routesToAudio, !self.audioEngine.isMuted else { return }
            Task { @MainActor in
                self.audioEngine.setPressure(for: note, pressure: pressure)
            }
        }
        midiEngine.onIncomingPerNoteController = { [weak self] _, note, controller, value in
            guard let self, self.midiPassthruMode.routesToAudio, !self.audioEngine.isMuted else { return }
            if controller == 74 {
                Task { @MainActor in
                    self.audioEngine.setTimbre(for: note, timbre: value)
                }
            }
        }
    }

    public func updateDiatonicChords() {
        diatonicChords = Chord.diatonicChords(root: currentKey, scale: currentScale)
        if diatonicChords.isEmpty == false {
            selectedChordIndex = min(selectedChordIndex, diatonicChords.count - 1)
            currentChord = diatonicChords[selectedChordIndex]
        }
    }

    public func setKey(_ key: PitchClass) {
        currentKey = key
        currentScale = Scale(root: key, type: currentScale.type)
        audioEngine.scaleRoot = key
        updateDiatonicChords()
    }

    public func setScale(_ scale: Scale) {
        currentScale = Scale(root: currentKey, type: scale.type)
        updateDiatonicChords()
    }

    /// Transpose the current key up or down by `semitones` (typically ±1).
    public func transpose(by semitones: Int) {
        guard semitones != 0 else { return }
        let all = PitchClass.allCases
        guard let idx = all.firstIndex(of: currentKey) else { return }
        let newIdx = ((idx + semitones) % all.count + all.count) % all.count
        setKey(all[newIdx])
        panic()
    }

    public func setTemperament(_ temperament: MicrotonalTemperament) {
        currentTemperament = temperament
        audioEngine.temperament = temperament
        audioEngine.scaleRoot = currentKey
        mpeManager.temperament = temperament
    }

    public func setInstrument(_ profile: InstrumentProfile) {
        stopActiveNotes()
        droneEngine.resetSilently()
        applyInstrument(profile)
    }

    public func setStrumOctave(_ octave: Int) {
        var updated = performanceRegisters
        updated.setStrumOctave(octave)
        applyPerformanceRegisters(updated)
    }

    public func setFaceButtonOctave(_ octave: Int) {
        var updated = performanceRegisters
        updated.setFaceButtonOctave(octave)
        applyPerformanceRegisters(updated)
    }

    public func shiftPerformanceOctaves(by octaveDelta: Int) {
        var updated = performanceRegisters
        updated.shiftBoth(by: octaveDelta)
        applyPerformanceRegisters(updated)
    }

    private func applyPerformanceRegisters(_ updated: PerformanceLaneRegisters) {
        let strumChanged = updated.strumOctave != performanceRegisters.strumOctave
        let faceChanged = updated.faceButtonOctave != performanceRegisters.faceButtonOctave
        guard strumChanged || faceChanged else { return }

        if strumChanged {
            stopStrumLane()
            previousVoicing = nil
        }
        if faceChanged {
            stopFaceLane()
            performanceEngine.resetMelodicTargeting(rearmFaceButtons: true)
        }

        performanceRegisters = updated
        performanceRegisterMemory.remember(updated, for: instrumentProfile)
    }

    private func stopStrumLane() {
        chordGateReleaseWorkItem?.cancel()
        chordGateReleaseWorkItem = nil
        cancelPendingStrumNotes()
        let releaseEvents = chordGateEngine.releaseAll()
        handleChordGateEvents(
            releaseEvents,
            velocity: lastVelocity,
            direction: lastStrumDirection
        )
        velocityStabilizer.reset()
        strumState = StrumState()
    }

    private func stopFaceLane() {
        for role in Array(heldFaceNotes.keys) {
            stopFaceNote(for: role)
        }
    }

    public func setPerformancePreset(_ preset: PerformancePreset) {
        performancePreset = preset
        setInstrument(preset.applied(to: InstrumentProfile.profile(for: preset.family)))
    }

    public func setDestination(_ destination: DestinationCapabilityProfile) {
        if let kind = DAWHostKind(rawValue: destination.name), kind != .autoDetect {
            setHostSelection(kind)
            return
        }
        switch destination.name {
        case DestinationCapabilityProfile.internalSynth.name:
            setHostSelection(.internalSynth)
        case DestinationCapabilityProfile.genericMPE.name:
            setHostSelection(.genericMPE)
        case DestinationCapabilityProfile.genericMIDI.name:
            setHostSelection(.genericMIDI)
        default:
            applyDestination(destination)
        }
    }

    public func setHostSelection(_ kind: DAWHostKind) {
        hostSelection = kind
        applyHostRouting()
    }

    /// `0` means the DAW track is set to All / Any Channels. `1...16` is a filtered track.
    public func setTrackMIDIChannel(_ displayChannel: Int) {
        if displayChannel <= 0 {
            trackChannelMode = .omni
        } else {
            trackChannelMode = .filtered(UInt8(min(16, displayChannel) - 1))
        }
        applyHostRouting()
    }

    public var trackMIDIChannelDisplay: Int {
        switch trackChannelMode {
        case .omni: return 0
        case .filtered(let channel): return Int(channel) + 1
        }
    }

    public func refreshHostDetection() {
        applyHostRouting()
    }

    public func midiChannel(forRole role: MIDISourceRole) -> UInt8 {
        resolvedLayout.channel(for: role)
    }

    public func sendAuditionNotes(
        _ midiNotes: [UInt8],
        port: VirtualPort,
        velocity: UInt8,
        duration: TimeInterval
    ) {
        let channel = midiChannel(for: port)
        for note in midiNotes {
            midiEngine.sendNoteOn(port: port, channel: channel, note: note, velocity: velocity)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            guard let self else { return }
            let offChannel = self.midiChannel(for: port)
            for note in midiNotes {
                self.midiEngine.sendNoteOff(port: port, channel: offChannel, note: note)
            }
        }
    }

    private func applyHostRouting() {
        stopActiveNotes()
        let detected = HostMIDIContextResolver.resolve(
            selection: hostSelection,
            signals: HostRuntimeDetector.signals()
        )
        activeHostKind = detected.kind
        activeHostContext = detected.context
        hostDetectionNote = detected.note
        resolvedLayout = HostMIDIContextResolver.resolveLayout(
            context: detected.context,
            trackMode: trackChannelMode
        )

        var destination = detected.context.destinationProfile
        if !resolvedLayout.usesMPE {
            destination = DestinationCapabilityProfile(
                name: detected.context.name,
                supportsMPE: false,
                supportsChannelPressure: true,
                supportsPolyPressure: false,
                bendRangeSemitones: min(2, detected.context.bendRangeSemitones),
                supportsCC74: true,
                supportsKeyswitchArticulations: false,
                supportsPortamento: false,
                supportsLegatoOverlap: true,
                pressureMode: .channelPressure
            )
        }
        applyDestination(destination)
        mpeManager.applyZoneLayout(
            resolvedLayout.mpeZone,
            sendConfiguration: midiEngine.virtualMIDIEnabled && resolvedLayout.usesMPE
        )
        multiJamManager.applyChannelMap(resolvedLayout.channels)
    }

    private func applyDestination(_ destination: DestinationCapabilityProfile) {
        destinationProfile = destination
        midiTranslator.destination = destination
        performanceEngine.setDestination(destination)
        mpeManager.bendRangeSemitones = destination.bendRangeSemitones
    }

    public func setPitchAssist(_ assist: PitchAssistMode) {
        expressionSettings.pitchAssist = assist
        performanceEngine.setAssist(assist)
    }

    public func setChordHoldMode(_ mode: ChordHoldMode) {
        var updated = chordGateConfiguration
        updated.mode = mode
        applyChordGateConfiguration(updated)
    }

    public func setChordTimedDuration(_ duration: TimeInterval) {
        var updated = chordGateConfiguration
        updated.setTimedDuration(duration)
        applyChordGateConfiguration(updated)
    }

    public func setDuoPerformanceMode(_ mode: DuoPerformanceMode) {
        guard duoPerformanceMode != mode else { return }
        stopActiveNotes()
        duoPerformanceMode = mode
        duoControlEngine.setMode(mode)
        lastDrumHit = nil
    }

    // MARK: Arcade Frets Mode

    /// Toggles the hidden Guitar Hero-style fret lane. Enabling reroutes the rear
    /// buttons into instant chord frets and retires strumming until disabled.
    public func setArcadeModeEnabled(_ enabled: Bool) {
        guard isArcadeModeEnabled != enabled else { return }
        panic()
        isArcadeModeEnabled = enabled
        arcadeEngine.reset()
        _ = arcadeGateEngine.releaseAll()
        lastArcadeFrame = .empty
    }

    public func toggleArcadeMode() {
        setArcadeModeEnabled(!isArcadeModeEnabled)
    }

    /// Reveals the secret Arcade Frets menu-bar entry. Triggered only by the
    /// hidden ⌘⌥⇧G key combination; there is no visible affordance anywhere.
    public func unlockArcadeFretsMenu() {
        guard !isArcadeMenuUnlocked else { return }
        isArcadeMenuUnlocked = true
        arcadeStatusItem.reveal()
    }

    private func installArcadeUnlockMonitor() {
        arcadeUnlockMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if event.keyCode == 5, // G
               event.modifierFlags.contains(.command),
               event.modifierFlags.contains(.option),
               event.modifierFlags.contains(.shift) {
                self.unlockArcadeFretsMenu()
                return nil
            }
            return event
        }
    }

    public func setVelocityCurve(_ curve: SynthVelocityCurve) {
        audioEngine.setVelocityCurve(curve)
        let configuration: VelocityStabilizerConfiguration
        switch curve {
        case .expressive:
            configuration = VelocityStabilizerConfiguration(floor: 28, ceiling: 124, smoothing: 0.68, maximumStep: 28)
        case .balanced:
            configuration = VelocityStabilizerConfiguration(floor: 36, ceiling: 120, smoothing: 0.45, maximumStep: 18)
        case .even:
            configuration = VelocityStabilizerConfiguration(floor: 48, ceiling: 112, smoothing: 0.28, maximumStep: 10)
        }
        velocityStabilizer.updateConfiguration(configuration)
        duoControlEngine.drumVelocityStabilizer.updateConfiguration(configuration)
    }

    private func applyChordGateConfiguration(_ configuration: ChordGateConfiguration) {
        chordGateReleaseWorkItem?.cancel()
        chordGateReleaseWorkItem = nil
        let releaseEvents = chordGateEngine.updateConfiguration(configuration)
        chordGateConfiguration = configuration
        handleChordGateEvents(releaseEvents, velocity: lastVelocity, direction: lastStrumDirection)
    }

    public func setPlayMode(_ mode: InstrumentPlayMode) {
        guard selectedPlayMode != mode else { return }
        stopArpeggiator()
        if selectedPlayMode == .drone {
            handleDroneEvents(droneEngine.releaseAll())
        }
        selectedPlayMode = mode
    }

    // MARK: Drone Pad

    /// Sustained chord bed for Drone Pad mode. Morphs with chord selection;
    /// note-offs fire only on chord change or panic.
    public private(set) var droneEngine = DroneBedEngine()

    private func updateDroneBed(state: ControllerState, timestamp: TimeInterval) {
        var chord = currentChord ?? diatonicChords.first ?? Chord(root: currentKey, quality: .major)
        chord = applyModifier(chord, modifier: state.activeModifier)
        let voice = makeChordVoice(chord)
        let events = droneEngine.setVoice(voice, timestamp: timestamp)
        handleDroneEvents(events)
    }

    private func handleDroneEvents(_ events: [DroneBedEngine.Event]) {
        for event in events {
            switch event {
            case .noteOn(let note, let velocity):
                beginPhysicalVoice(note, velocity: velocity, technique: .normal)
                if !destinationProfile.supportsMPE {
                    midiEngine.sendNoteOn(
                        port: .chords,
                        channel: midiChannel(.chords),
                        note: note.midiNote,
                        velocity: velocity
                    )
                }
                addActiveNote(note)
            case .noteOff(let note):
                if !destinationProfile.supportsMPE {
                    midiEngine.sendNoteOff(port: .chords, channel: midiChannel(.chords), note: note.midiNote)
                }
                removeActiveNote(note)
                finishPhysicalVoiceIfUnowned(note)
            }
        }
    }

    public func updateArpeggiatorConfiguration(_ configuration: ArpeggiatorConfiguration) {
        arpeggiatorConfiguration = configuration
        _ = arpeggiatorEngine.updateConfiguration(configuration)
        if arpeggiatorTimer != nil {
            startArpeggiatorTimer()
        }
    }

    public func startArpeggiator(with voice: ChordGateVoice? = nil) {
        let activeChord = voice?.chord ?? currentChord ?? diatonicChords.first ?? Chord(root: currentKey, quality: .major)
        let resolvedVoice = voice ?? makeChordVoice(activeChord)
        let events = arpeggiatorEngine.setVoice(resolvedVoice)
        handleArpeggiatorEvents(events)
        startArpeggiatorTimer()
    }

    public func stopArpeggiator() {
        stopArpeggiatorTimer()
        let events = arpeggiatorEngine.releaseAll()
        handleArpeggiatorEvents(events)
    }

    private func startArpeggiatorTimer() {
        stopArpeggiatorTimer()
        let timer = DispatchSource.makeTimerSource(queue: .main)
        let interval = arpeggiatorConfiguration.rate.secondsPerStep(tempoBPM: bpm)
        timer.schedule(deadline: .now(), repeating: interval, leeway: .milliseconds(2))
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            let events = self.arpeggiatorEngine.advance(
                timestamp: ProcessInfo.processInfo.systemUptime,
                tempoBPM: self.bpm,
                velocity: self.lastVelocity
            )
            self.handleArpeggiatorEvents(events)
        }
        arpeggiatorTimer = timer
        timer.resume()
    }

    private func stopArpeggiatorTimer() {
        arpeggiatorTimer?.cancel()
        arpeggiatorTimer = nil
    }

    private func handleArpeggiatorEvents(_ events: [ArpeggiatorEvent]) {
        for event in events {
            switch event {
            case .noteOn(let note, let velocity):
                let technique: MusicalTechnique = controllerManager.performanceState.leftTrigger.value > 0.35 ? .palmMute : .normal
                beginPhysicalVoice(note, velocity: velocity, technique: technique)
                if !destinationProfile.supportsMPE {
                    midiEngine.sendNoteOn(
                        port: .chords,
                        channel: midiChannel(.chords),
                        note: note.midiNote,
                        velocity: velocity
                    )
                }
                addActiveNote(note)
            case .noteOff(let note):
                if !destinationProfile.supportsMPE {
                    midiEngine.sendNoteOff(port: .chords, channel: midiChannel(.chords), note: note.midiNote)
                }
                removeActiveNote(note)
                finishPhysicalVoiceIfUnowned(note)
            }
        }
    }

    public func toggleArpeggiator() {
        setPlayMode(selectedPlayMode == .arp ? .chords : .arp)
    }

    private func applyInstrument(_ profile: InstrumentProfile) {
        performanceRegisterMemory.remember(performanceRegisters, for: instrumentProfile)
        instrumentProfile = profile
        performanceRegisters = performanceRegisterMemory.settings(for: profile)
        controllerManager.configureForInstrumentProfile(profile)
        performanceEngine.setProfile(profile)
        midiTranslator.profile = profile
        midiTranslator.destination = destinationProfile
        previousVoicing = nil
        lastFrame = nil
        lastHint = nil
    }

    private func musicalContext(currentNote: Note? = nil) -> MusicalContext {
        MusicalContext(
            key: currentKey,
            scale: currentScale,
            chord: currentChord,
            previousNote: activeNotes.last,
            currentNote: currentNote ?? activeNotes.max(),
            chromaticMode: expressionSettings.chromaticMode,
            pitchAssist: expressionSettings.pitchAssist,
            registerOctave: performanceRegisters.faceButtonOctave
        )
    }

    private func handleControllerInput(_ state: ControllerState) {
        let now = ProcessInfo.processInfo.systemUptime
        let surface = controllerManager.surfaceFrame
        applySurfaceActions(surface)
        if surface.didRise(.panic) { return }

        // Guided tutorial validation runs alongside live performance.
        if activeTutorialMissionID != nil {
            _ = tutorialEngine.process(state: state, timestamp: now)
        }
        handleChordSelection(state)

        // Drone Pad: the sustained bed follows chord selection every frame;
        // no strum gate is involved.
        if selectedPlayMode == .drone {
            updateDroneBed(state: state, timestamp: now)
        }

        // Duo drums are suspended while the fret lane owns the triggers & face cluster.
        var suppressesInstrumentFaceButtons = false
        if !isArcadeModeEnabled {
            let drumVelocity = UInt8(clamping: 72 + Int(Double(state.rightTrigger.value) * 48))
            let duoFrame = duoControlEngine.process(state: state, drumVelocity: drumVelocity)
            handleDuoDrumHits(duoFrame.drumHits)
            suppressesInstrumentFaceButtons = duoFrame.suppressesInstrumentFaceButtons
        }

        // Voice-led smart soloing engine
        if instrumentProfile.family == .synthLead || isSoloModeActive {
            let soloResult = smartSoloEngine.process(
                stick: StickCoordinates(x: Double(state.rightStick.x), y: Double(state.rightStick.y)),
                movementVelocity: Double(state.rightStick.movementVelocity),
                context: musicalContext(),
                timestamp: now
            )
            if let off = soloResult.noteOff {
                finishPhysicalVoiceIfUnowned(off)
                midiEngine.sendNoteOff(port: melodicMIDIPort, channel: soloMIDIChannel, note: off.midiNote)
            }
            if let on = soloResult.noteOn {
                beginPhysicalVoice(on, velocity: soloResult.event?.velocity ?? 100, technique: soloResult.event?.technique ?? .normal)
                midiEngine.sendNoteOn(port: melodicMIDIPort, channel: soloMIDIChannel, note: on.midiNote, velocity: soloResult.event?.velocity ?? 100)
            }
        }

        let frame = performanceEngine.process(
            state: isArcadeModeEnabled ? arcadeSanitizedState(state) : state,
            context: musicalContext(),
            heldNotes: activeNotes,
            timestamp: now
        )
        lastFrame = frame
        expressionTrails.push(
            bend: frame.bend.bendSemitones,
            pressure: frame.pressure.smoothed,
            timbre: frame.timbre,
            mute: frame.palmMuteAmount
        )
        if let hint = frame.hint { lastHint = hint }

        if isArcadeModeEnabled {
            processArcadeFretLane(state, timestamp: now)
        } else if !suppressesInstrumentFaceButtons {
            handleFaceEvents(frame.faceEvents)
        }
        applyExpression(frame)

        if isArcadeModeEnabled {
            // The fret lane replaces strumming entirely — chords fire on press.
        } else if !frame.suppressStrum && !isSoloModeActive {
            handleStrumming(state, timestamp: now)
        } else if instrumentProfile.family == .synthLead || instrumentProfile.family == .genericMPE {
            applyLeadTimbre(frame.timbre)
        }

        if let haptic = frame.haptic {
            controllerManager.playTechniqueHaptic(haptic)
        }

        if state.hasMotion && controllerManager.activeScheme.isMotionEnabled {
            // Update DSP binaural coordinates using stable gravity vector and gyro
            let az = Float(state.rollTilt * 180.0 + state.gyroZ * 30.0)
            let el = Float(state.pitchTilt * 60.0 + state.gyroX * 20.0)
            let dist = Float(max(0.3, 1.0 - min(0.6, state.shakeMagnitude * 0.2)))
            audioEngine.spatialEngine.setCoordinates(azimuth: az, elevation: el, distance: dist)

            // Live polyphonic MPE modulation from DualSense tilt & shake
            let normPan = (state.rollTilt.clamped(to: -1.0...1.0) + 1.0) * 0.5 // 0.0 (Left) ... 1.0 (Right)
            let normTimbre = (state.pitchTilt.clamped(to: -1.0...1.0) + 1.0) * 0.5 // 0.0 (Down) ... 1.0 (Up)

            for note in activeNotes {
                audioEngine.setPan(for: note.midiNote, pan: normPan)
                if abs(state.pitchTilt) > 0.05 {
                    audioEngine.setTimbre(for: note.midiNote, timbre: normTimbre)
                }

                if midiEngine.virtualMIDIEnabled {
                    let ch = mpeManager.activeVoice(for: note.midiNote)?.channel ?? 0
                    // Continuous CC10 Pan & RPNC 10 (Pan)
                    midiEngine.sendCC(port: .mpe, channel: ch, controller: 10, value: UInt8(normPan * 127.0))
                    midiEngine.sendPerNoteRegisteredController(port: .mpe, channel: ch, note: note.midiNote, controller: .pan, normalizedValue: normPan)

                    if state.shakeMagnitude > 0.35 {
                        let shakeMod = min(1.0, (state.shakeMagnitude - 0.35) * 1.5)
                        midiEngine.sendCC(port: .mpe, channel: ch, controller: 1, value: UInt8(shakeMod * 127.0))
                    }
                }
            }
        }

        lastInputTime = now
    }

    // MARK: - Arcade Frets Lane

    /// Rear-panel fret lane: triggers & bumpers fire diatonic chords the moment
    /// they are pressed, face buttons colour the chord quality. No strum gesture
    /// is consulted; the chord gate releases when every fret is released.
    private func processArcadeFretLane(_ state: ControllerState, timestamp: TimeInterval) {
        let input = ArcadeFretInput(
            leftTriggerValue: state.leftTrigger.value,
            rightTriggerValue: state.rightTrigger.value,
            leftShoulderPressed: state.leftShoulder,
            rightShoulderPressed: state.rightShoulder,
            southPressed: state.buttonA,
            westPressed: state.buttonX,
            northPressed: state.buttonY,
            eastPressed: state.buttonB
        )
        let frame = arcadeEngine.process(input: input, chords: diatonicChords, timestamp: timestamp)
        lastArcadeFrame = frame

        if let strike = frame.strikes.last {
            // Hammer-on style: a new fret replaces the sounding lane chord even
            // while other frets stay held.
            handleChordGateEvents(arcadeGateEngine.releaseAll(), velocity: lastVelocity, direction: .down)
            var chord = strike.chord
            chord.inversion = voicingInversion
            let voice = makeChordVoice(chord)
            lastVelocity = strike.velocity
            lastStrumDirection = .down
            lastStrumTime = Date()
            let events = arcadeGateEngine.process(voice: voice, isGestureActive: true, timestamp: timestamp)
            handleChordGateEvents(events, velocity: strike.velocity, direction: .down)
            controllerManager.playTechniqueHaptic(.chordChange)
        } else {
            let events = arcadeGateEngine.process(
                voice: nil,
                isGestureActive: frame.isLaneActive,
                timestamp: timestamp
            )
            handleChordGateEvents(events, velocity: lastVelocity, direction: lastStrumDirection)
        }
    }

    /// Performance-engine view of the controller while the fret lane is active.
    /// Triggers and face buttons are neutralised so pulling frets never leaks
    /// palm-mute/pressure expression or stray single-note plucks into the mix;
    /// sticks, motion, and utility controls keep their normal roles.
    private func arcadeSanitizedState(_ state: ControllerState) -> ControllerState {
        let sanitized = ControllerState()
        sanitized.leftStick = state.leftStick
        sanitized.rightStick = state.rightStick
        sanitized.dpadUp = state.dpadUp
        sanitized.dpadDown = state.dpadDown
        sanitized.dpadLeft = state.dpadLeft
        sanitized.dpadRight = state.dpadRight
        sanitized.leftStickButton = state.leftStickButton
        sanitized.rightStickButton = state.rightStickButton
        sanitized.menuButton = state.menuButton
        sanitized.optionsButton = state.optionsButton
        sanitized.touchpadX = state.touchpadX
        sanitized.touchpadY = state.touchpadY
        sanitized.touchpadActive = state.touchpadActive
        sanitized.gyroX = state.gyroX
        sanitized.gyroY = state.gyroY
        sanitized.gyroZ = state.gyroZ
        sanitized.accelX = state.accelX
        sanitized.accelY = state.accelY
        sanitized.accelZ = state.accelZ
        sanitized.hasMotion = state.hasMotion
        return sanitized
    }

    private func applySurfaceActions(_ frame: ControlSurfaceFrame) {
        if frame.didRise(.octaveUp) {
            shiftPerformanceOctaves(by: 1)
            controllerManager.playTechniqueHaptic(.octaveShift)
        }
        if frame.didRise(.octaveDown) {
            shiftPerformanceOctaves(by: -1)
            controllerManager.playTechniqueHaptic(.octaveShift)
        }
        if frame.didRise(.voicingNext) {
            cycleVoicing(by: 1)
            controllerManager.playTechniqueHaptic(.chordChange)
        }
        if frame.didRise(.voicingPrevious) {
            cycleVoicing(by: -1)
            controllerManager.playTechniqueHaptic(.chordChange)
        }
        if frame.didRise(.soloModeToggle) {
            isSoloModeActive.toggle()
            controllerManager.playTechniqueHaptic(.buttonConfirm)
        }
        if frame.didRise(.duoModeToggle) {
            setDuoPerformanceMode(
                duoPerformanceMode == .instrumentOnly ? .drumsAndInstrument : .instrumentOnly
            )
            controllerManager.playTechniqueHaptic(.buttonConfirm)
        }
        if frame.didRise(.panic) {
            panic()
            return
        }
        if frame.didRise(.metronomeToggle) {
            metronomeEnabled.toggle()
        }
    }

    private func cycleVoicing(by delta: Int) {
        guard var chord = currentChord else { return }
        let toneCount = max(1, chord.quality.intervals.count)
        let next = (chord.inversion + delta) % toneCount
        chord.inversion = next < 0 ? next + toneCount : next
        voicingInversion = chord.inversion
        currentChord = chord
        if selectedChordIndex < diatonicChords.count {
            diatonicChords[selectedChordIndex].inversion = chord.inversion
        }
        previousVoicing = nil
    }

    private func handleChordSelection(_ state: ControllerState) {
        guard state.leftStickMagnitude > 0.3 else { return }

        let angle = state.leftStickAngle
        let chordCount = diatonicChords.count
        guard chordCount > 0 else { return }

        var normalised = -(angle - .pi / 2)
        if normalised < 0 { normalised += 2 * .pi }

        let sliceAngle = (2.0 * .pi) / Double(chordCount)
        let centred = (normalised + sliceAngle / 2).truncatingRemainder(dividingBy: 2 * .pi)
        let slicePosition = centred / sliceAngle
        let index = Int(slicePosition) % chordCount
        let positionWithinSlice = slicePosition - floor(slicePosition)

        // Leave a narrow neutral band at sector boundaries so small analog
        // jitter cannot make the harmonic wheel flicker between neighbours.
        guard positionWithinSlice > 0.14, positionWithinSlice < 0.86 else { return }

        if index != selectedChordIndex {
            let old = currentChord ?? diatonicChords[selectedChordIndex]
            selectedChordIndex = index
            var new = diatonicChords[index]
            new.inversion = voicingInversion
            currentChord = new
            recordChordHistory(new)
            retargetHeldChordTones()
            controllerManager.playTechniqueHaptic(.chordChange)
            multiJamManager.updateSharedHarmony(key: currentKey, scale: currentScale, chord: new)
            _ = smartSoloEngine.handleChordChange(oldChord: old, newChord: new, context: musicalContext())
            if selectedWorkspace == .practice && practiceEngine.isPracticeActive {
                practiceEngine.evaluateChordInput(new)
            }
        }
    }

    private func recordChordHistory(_ chord: Chord) {
        // Avoid duplicate consecutive entries
        if let last = chordHistory.first,
           last.root == chord.root && last.quality == chord.quality { return }
        chordHistory.insert(chord, at: 0)
        if chordHistory.count > Self.chordHistoryCapacity {
            chordHistory.removeLast()
        }
    }

    private func retargetHeldChordTones() {
        guard expressionSettings.chordToneLayout, let chord = currentChord else { return }
        let targeter = ContextualPitchTargeter()
        let heldSnapshot = Array(heldFaceNotes)
        let baseOctave = performanceRegisters.faceButtonOctave
        for (role, previous) in heldSnapshot {
            let next = targeter.note(for: role, chord: chord, previous: previous, baseOctave: baseOctave)
            if next.midiNote != previous.midiNote {
                stopFaceNote(for: role, recordsEvent: false)
                startFaceNote(
                    FaceButtonNoteEvent(
                        role: role,
                        note: next,
                        isOn: true,
                        technique: .legato,
                        velocity: 86
                    ),
                    recordsEvent: false
                )
            }
        }
    }

    public func handleFaceButtonEvent(role: ChordToneRole, isPressed: Bool, velocity: UInt8 = 100) {
        let chord = currentChord ?? diatonicChords.first ?? Chord(root: currentKey, quality: .major)
        let targeter = ContextualPitchTargeter()
        let note = targeter.note(for: role, chord: chord, previous: heldFaceNotes[role], baseOctave: performanceRegisters.faceButtonOctave)
        if isPressed {
            startFaceNote(FaceButtonNoteEvent(role: role, note: note, isOn: true, technique: .normal, velocity: velocity))
        } else {
            stopFaceNote(for: role)
        }
    }

    private func handleFaceEvents(_ events: [FaceButtonNoteEvent]) {
        for event in events {
            if event.isOn {
                startFaceNote(event)
            } else {
                stopFaceNote(for: event.role)
            }
        }
    }

    private func startFaceNote(_ event: FaceButtonNoteEvent, recordsEvent: Bool = true) {
        if let previous = heldFaceNotes[event.role] {
            guard previous.midiNote != event.note.midiNote else { return }
            stopFaceNote(for: event.role, recordsEvent: recordsEvent)
        }

        let wasSounding = isNoteOwned(event.note.midiNote)
        let alreadyOwnedByFace = heldFaceNotes.values.contains { $0.midiNote == event.note.midiNote }
        heldFaceNotes[event.role] = event.note

        if !wasSounding {
            beginPhysicalVoice(event.note, velocity: event.velocity, velocity16: event.velocity16, technique: event.technique)
        }
        if !destinationProfile.supportsMPE, !alreadyOwnedByFace {
            midiEngine.sendNoteOn(
                port: melodicMIDIPort,
                channel: midiChannel(for: melodicMIDIPort),
                note: event.note.midiNote,
                velocity: event.velocity,
                velocity16: event.velocity16
            )
        }
        addActiveNote(event.note)

        if recordsEvent, isRecording {
            techniqueRecorder.record(
                InstrumentPerformanceEvent(
                    note: event.note,
                    phase: .began,
                    technique: event.technique,
                    velocity: event.velocity,
                    role: event.role
                ),
                tick: currentTick
            )
            sequencer.recordNoteOn(note: event.note.midiNote, velocity: event.velocity)
        }
    }

    private func stopFaceNote(for role: ChordToneRole, recordsEvent: Bool = true) {
        guard let held = heldFaceNotes.removeValue(forKey: role) else { return }
        let stillOwnedByFace = heldFaceNotes.values.contains { $0.midiNote == held.midiNote }

        if !destinationProfile.supportsMPE, !stillOwnedByFace {
            midiEngine.sendNoteOff(port: melodicMIDIPort, channel: midiChannel(for: melodicMIDIPort), note: held.midiNote)
            if heldFaceNotes.isEmpty {
                resetConventionalExpression(on: melodicMIDIPort)
            }
        }
        finishPhysicalVoiceIfUnowned(held)

        if recordsEvent, isRecording {
            techniqueRecorder.recordNoteOff(note: held.midiNote, tick: currentTick)
            sequencer.recordNoteOff(note: held.midiNote)
        }
    }

    private func applyExpression(_ frame: PerformanceFrame) {
        guard let lead = bendLeadNote() else { return }
        let conventionalPorts = midiPorts(for: lead.midiNote)

        let bend = frame.bend.totalSemitones + (frame.slide.isSliding ? frame.slide.pitchOffset : 0)
        let context = musicalContext(currentNote: lead)
        let chordBender = HarmonicChordBender()
        let noteBends = chordBender.bends(
            for: activeNotes,
            leadBendSemitones: bend,
            context: context,
            bendRangeSemitones: destinationProfile.bendRangeSemitones
        )

        if destinationProfile.supportsMPE {
            for note in activeNotes {
                let noteBend = noteBends[note.midiNote] ?? bend
                audioEngine.setPitchBend(for: note.midiNote, semitones: noteBend)
                mpeManager.setPitchBend(for: note.midiNote, semitones: noteBend)
            }
            lastMIDITranslation = midiTranslator.translateBend(
                semitones: bend,
                channel: mpeManager.voice(for: lead.midiNote)?.channel ?? 0,
                activeVoiceCount: activeNotes.count
            )
        } else {
            for note in activeNotes {
                let noteBend = noteBends[note.midiNote] ?? bend
                audioEngine.setPitchBend(for: note.midiNote, semitones: noteBend)
            }
            for port in conventionalPorts {
                midiEngine.sendPitchBend(
                    port: port,
                    channel: midiChannel(for: port),
                    semitoneOffset: bend,
                    bendRangeSemitones: destinationProfile.bendRangeSemitones
                )
            }
            lastMIDITranslation = midiTranslator.translateBend(
                semitones: bend,
                channel: midiChannel(for: conventionalPorts.first ?? .main),
                activeVoiceCount: activeNotes.count
            )
        }

        let pressure = frame.pressure.smoothed
        audioEngine.setPressure(for: lead.midiNote, pressure: pressure)
        LiveExpressionDispatch.sendPressure(
            mpe: mpeManager,
            midi: midiEngine,
            destination: destinationProfile,
            preferredPressureMode: instrumentProfile.pressureMode,
            note: lead.midiNote,
            ports: conventionalPorts,
            normalizedPressure: frame.pressure.smoothed
        )

        let timbre = frame.timbre
        audioEngine.setTimbre(for: lead.midiNote, timbre: timbre)
        LiveExpressionDispatch.sendTimbre(
            mpe: mpeManager,
            midi: midiEngine,
            destination: destinationProfile,
            note: lead.midiNote,
            ports: conventionalPorts,
            normalizedTimbre: frame.timbre
        )

        for note in activeNotes {
            audioEngine.setDamping(for: note.midiNote, damping: frame.palmMuteAmount)
        }

        if frame.slide.arrived, let source = frame.slide.source, let dest = frame.slide.destination {
            mpeManager.retarget(from: source.midiNote, to: dest.midiNote)
            controllerManager.playTechniqueHaptic(.slideArrival)
        }

        if isRecording {
            for event in frame.expressionEvents {
                techniqueRecorder.record(event, tick: currentTick)
            }
        }
    }

    private func bendLeadNote() -> Note? {
        activeNotes.max()
    }

    private func applyLeadTimbre(_ timbre: Double) {
        guard let lead = bendLeadNote() else { return }
        audioEngine.setTimbre(for: lead.midiNote, timbre: timbre)
        LiveExpressionDispatch.sendTimbre(
            mpe: mpeManager,
            midi: midiEngine,
            destination: destinationProfile,
            note: lead.midiNote,
            ports: midiPorts(for: lead.midiNote),
            normalizedTimbre: timbre
        )
    }

    private func handleStrumming(_ state: ControllerState, timestamp: TimeInterval) {
        let rightY = state.rightStickY
        let travel = abs(rightY)
        let attackThreshold: Float = 0.22
        let releaseThreshold: Float = 0.15

        if travel > attackThreshold {
            let direction: StrumDirection = rightY > 0 ? .down : .up

            if direction != strumState.lastDirection || strumState.hasReset {
                if !strumState.hasReset, direction != strumState.lastDirection {
                    let releaseEvents = chordGateEngine.process(
                        voice: nil,
                        isGestureActive: false,
                        timestamp: timestamp
                    )
                    handleChordGateEvents(
                        releaseEvents,
                        velocity: lastVelocity,
                        direction: lastStrumDirection
                    )
                }

                strumState.lastDirection = direction
                strumState.hasReset = false
                lastStrumDirection = direction

                let travelIntensity = min(1, Double(travel) * 0.72)
                let axisIntensity = min(1, Double(abs(state.rightStick.yVelocity)) / 8)
                let motionIntensity = min(1, Double(state.rightStick.movementVelocity) / 10)
                let intensity = max(travelIntensity, axisIntensity, motionIntensity)
                let (velocity, velocity16) = velocityStabilizer.process16(normalizedIntensity: intensity)
                lastVelocity = velocity
                lastVelocity16 = velocity16
                lastStrumTime = Date()

                var chord = currentChord ?? diatonicChords.first ?? Chord(root: currentKey, quality: .major)
                chord = applyModifier(chord, modifier: state.activeModifier)
                let voice = makeChordVoice(chord)
                if selectedPlayMode == .arp {
                    let events = arpeggiatorEngine.setVoice(voice)
                    handleArpeggiatorEvents(events)
                    startArpeggiatorTimer()
                } else if selectedPlayMode == .drone {
                    // Strum accents the sustained bed without re-gating it.
                    let events = droneEngine.rearticulate(velocity: velocity)
                    handleDroneEvents(events)
                } else {
                    let events = chordGateEngine.process(
                        voice: voice,
                        isGestureActive: true,
                        timestamp: timestamp
                    )
                    handleChordGateEvents(events, velocity: velocity, velocity16: velocity16, direction: direction)
                }
            }
        } else if travel < releaseThreshold {
            strumState.hasReset = true
            if selectedPlayMode == .arp {
                if !arpeggiatorConfiguration.isLatched && chordGateConfiguration.mode == .momentary {
                    stopArpeggiator()
                }
            } else if selectedPlayMode == .drone {
                // Sustain: release does nothing — note-offs fire on chord change or panic.
            } else {
                let events = chordGateEngine.process(
                    voice: nil,
                    isGestureActive: false,
                    timestamp: timestamp
                )
                handleChordGateEvents(events, velocity: lastVelocity, direction: lastStrumDirection)
            }
        } else {
            if selectedPlayMode != .arp && selectedPlayMode != .drone {
                let events = chordGateEngine.advance(timestamp: timestamp)
                handleChordGateEvents(events, velocity: lastVelocity, direction: lastStrumDirection)
            }
        }
    }

    private func applyModifier(_ chord: Chord, modifier: ControllerModifier) -> Chord {
        switch modifier {
        case .leftShoulder:
            switch chord.quality {
            case .major: return Chord(root: chord.root, quality: .major7)
            case .minor: return Chord(root: chord.root, quality: .minor7)
            case .diminished: return Chord(root: chord.root, quality: .halfDiminished7)
            default: return chord
            }
        case .rightShoulder:
            switch chord.quality {
            case .major: return Chord(root: chord.root, quality: .sus4)
            case .minor: return Chord(root: chord.root, quality: .sus2)
            default: return chord
            }
        case .leftTrigger:
            switch chord.quality {
            case .major: return Chord(root: chord.root, quality: .add9)
            case .minor: return Chord(root: chord.root, quality: .minor9)
            default: return chord
            }
        case .rightTrigger:
            switch chord.quality {
            case .major: return Chord(root: chord.root, quality: .sixth)
            case .minor: return Chord(root: chord.root, quality: .minorSixth)
            default: return chord
            }
        default:
            return chord
        }
    }

    private func makeChordVoice(_ chord: Chord) -> ChordGateVoice {
        let voicing: ChordVoicing
        let voiceCount = instrumentProfile.stringCount == 0 ? 5 : instrumentProfile.stringCount
        let baseOctave = performanceRegisters.strumOctave
        if let prev = previousVoicing {
            voicing = ChordVoicing.voiceLed(
                chord: chord,
                from: prev,
                baseOctave: baseOctave,
                voiceCount: voiceCount
            )
        } else {
            voicing = ChordVoicing.strummed(
                chord: chord,
                strings: voiceCount,
                baseOctave: baseOctave
            )
        }
        previousVoicing = voicing
        return ChordGateVoice(chord: chord, notes: voicing.notes)
    }

    private func handleChordGateEvents(
        _ events: [ChordGateEvent],
        velocity: UInt8,
        velocity16: UInt16? = nil,
        direction: StrumDirection
    ) {
        for event in events {
            switch event {
            case .began(let voice):
                startChordVoice(voice, velocity: velocity, velocity16: velocity16, direction: direction)
                scheduleTimedChordReleaseIfNeeded()
            case .ended(let voice):
                chordGateReleaseWorkItem?.cancel()
                chordGateReleaseWorkItem = nil
                stopChordVoice(voice)
            }
        }
    }

    private func scheduleTimedChordReleaseIfNeeded() {
        chordGateReleaseWorkItem?.cancel()
        chordGateReleaseWorkItem = nil
        guard chordGateConfiguration.mode == .timed else { return }

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let events = self.chordGateEngine.advance(
                timestamp: ProcessInfo.processInfo.systemUptime
            )
            self.handleChordGateEvents(
                events,
                velocity: self.lastVelocity,
                velocity16: self.lastVelocity16,
                direction: self.lastStrumDirection
            )
        }
        chordGateReleaseWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + chordGateConfiguration.timedDuration,
            execute: workItem
        )
    }

    private func startChordVoice(
        _ voice: ChordGateVoice,
        velocity: UInt8,
        velocity16: UInt16? = nil,
        direction: StrumDirection
    ) {
        cancelPendingStrumNotes()

        var notes = voice.notes
        if direction == .up {
            notes.reverse()
        }
        let technique: MusicalTechnique = controllerManager.performanceState.leftTrigger.value > 0.35 ? .palmMute : .normal
        let strumDelay = 0.012
        let generation = strumGeneration
        for (i, note) in notes.enumerated() {
            let delay = Double(i) * strumDelay
            let noteVel = max(30, Int(velocity) - i * 3)
            // Scale the 16-bit value proportionally for per-string velocity taper.
            let noteVel16: UInt16? = velocity16.map { base in
                let ratio = Double(noteVel) / Double(max(1, velocity))
                return UInt16(clamping: Int((Double(base) * ratio).rounded()))
            }
            let workItem = DispatchWorkItem { [weak self] in
                guard let self, self.strumGeneration == generation else { return }
                let wasSounding = self.isNoteOwned(note.midiNote)
                let wasInserted = self.soundingChordNotes.insert(note.midiNote).inserted
                guard wasInserted else { return }

                if !wasSounding {
                    self.beginPhysicalVoice(
                        note,
                        velocity: UInt8(noteVel),
                        velocity16: noteVel16,
                        technique: technique
                    )
                }
                if !self.destinationProfile.supportsMPE {
                    self.midiEngine.sendNoteOn(
                        port: .chords,
                        channel: self.midiChannel(.chords),
                        note: note.midiNote,
                        velocity: UInt8(noteVel),
                        velocity16: noteVel16
                    )
                }
                self.addActiveNote(note)
            }
            pendingStrumNotes.append(workItem)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
        }
    }

    private func stopChordVoice(_ voice: ChordGateVoice) {
        cancelPendingStrumNotes()
        var releasedConventionalVoice = false
        for note in voice.notes {
            guard soundingChordNotes.remove(note.midiNote) != nil else { continue }
            if !destinationProfile.supportsMPE {
                midiEngine.sendNoteOff(port: .chords, channel: midiChannel(.chords), note: note.midiNote)
                releasedConventionalVoice = true
            }
            finishPhysicalVoiceIfUnowned(note)
        }
        if releasedConventionalVoice {
            resetConventionalExpression(on: .chords)
        }
    }

    private func beginPhysicalVoice(_ note: Note, velocity: UInt8, velocity16: UInt16? = nil, technique: MusicalTechnique) {
        if destinationProfile.supportsMPE {
            mpeManager.noteOn(note: note.midiNote, velocity: velocity, velocity16: velocity16, technique: technique)
        }
        if !audioEngine.isMuted {
            audioEngine.noteOn(note: note.midiNote, velocity: velocity, technique: technique)
        }
        if isRecording {
            sequencer.recordNoteOn(note: note.midiNote, velocity: velocity)
        }
        controllerManager.coreHapticsEngine.playNotePluck(velocity: velocity)
        lastMIDITranslation = midiTranslator.translate(
            InstrumentPerformanceEvent(note: note, phase: .began, technique: technique, velocity: velocity),
            memberChannel: mpeManager.voice(for: note.midiNote)?.channel
        )
    }

    private func finishPhysicalVoiceIfUnowned(_ note: Note) {
        guard !isNoteOwned(note.midiNote) else { return }
        if destinationProfile.supportsMPE {
            mpeManager.setPitchBend(for: note.midiNote, semitones: 0)
            mpeManager.noteOff(note: note.midiNote)
        }
        if !audioEngine.isMuted {
            audioEngine.noteOff(note: note.midiNote)
            audioEngine.setPitchBend(for: note.midiNote, semitones: 0)
        }
        if isRecording {
            sequencer.recordNoteOff(note: note.midiNote)
        }
        activeNotes.removeAll { $0.midiNote == note.midiNote }
        if activeNotes.isEmpty {
            performanceEngine.pitchEngine.reset()
        }
    }

    private func addActiveNote(_ note: Note) {
        if !activeNotes.contains(where: { $0.midiNote == note.midiNote }) {
            activeNotes.append(note)
        }
    }

    private func removeActiveNote(_ note: Note) {
        activeNotes.removeAll(where: { $0.midiNote == note.midiNote })
    }

    private func isNoteOwned(_ midiNote: UInt8) -> Bool {
        soundingChordNotes.contains(midiNote)
            || heldFaceNotes.values.contains { $0.midiNote == midiNote }
    }

    private var melodicMIDIPort: VirtualPort {
        instrumentProfile.family == .bass ? .bass : .melody
    }

    private func midiChannel(_ role: MIDISourceRole) -> UInt8 {
        resolvedLayout.channel(for: role)
    }

    private func midiChannel(for port: VirtualPort) -> UInt8 {
        switch port {
        case .chords: return midiChannel(.chords)
        case .melody, .main: return midiChannel(.melody)
        case .bass: return midiChannel(.bass)
        case .drums: return midiChannel(.drums)
        case .mpe: return mpeManager.currentZoneLayout.masterChannel
        }
    }

    private var soloMIDIChannel: UInt8 { midiChannel(.solo) }

    private func midiPorts(for midiNote: UInt8) -> [VirtualPort] {
        var ports: [VirtualPort] = []
        if soundingChordNotes.contains(midiNote) {
            ports.append(.chords)
        }
        if heldFaceNotes.values.contains(where: { $0.midiNote == midiNote }) {
            ports.append(melodicMIDIPort)
        }
        return ports.isEmpty ? [.main] : ports
    }

    private func resetConventionalExpression(on port: VirtualPort) {
        let channel = midiChannel(for: port)
        midiEngine.sendPitchBend(port: port, channel: channel, value: 8192)
        midiEngine.sendChannelPressure(port: port, channel: channel, pressure: 0)
        midiEngine.sendCC(port: port, channel: channel, controller: 11, value: 127)
        midiEngine.sendCC(port: port, channel: channel, controller: 64, value: 0)
        midiEngine.sendTimbreCC74(port: port, channel: channel, value: 64)
    }

    private func handleDuoDrumHits(_ hits: [DuoDrumHit]) {
        for hit in hits {
            let sound: BuiltInDrumSound
            switch hit.voice {
            case .kick: sound = .kick
            case .snare: sound = .snare
            case .closedHat: sound = .closedHiHat
            case .openHat: sound = .openHiHat
            }

            audioEngine.triggerDrum(sound, velocity: hit.velocity)
            controllerManager.playTechniqueHaptic(.drumHit)
            midiEngine.sendNoteOn(
                port: .drums,
                channel: midiChannel(.drums),
                note: hit.voice.generalMIDINote,
                velocity: hit.velocity
            )
            if isRecording {
                sequencer.recordNoteOn(note: hit.voice.generalMIDINote, velocity: hit.velocity)
            }
            lastDrumHit = hit

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
                self?.midiEngine.sendNoteOff(
                    port: .drums,
                    channel: self?.midiChannel(.drums) ?? 9,
                    note: hit.voice.generalMIDINote
                )
                if self?.isRecording == true {
                    self?.sequencer.recordNoteOff(note: hit.voice.generalMIDINote)
                }
            }
        }
    }

    public func stopActiveNotes() {
        if isRecording {
            for note in activeNotes {
                sequencer.recordNoteOff(note: note.midiNote)
            }
        }
        chordGateReleaseWorkItem?.cancel()
        chordGateReleaseWorkItem = nil
        cancelPendingStrumNotes()
        _ = chordGateEngine.releaseAll()
        _ = arcadeGateEngine.releaseAll()
        audioEngine.panic()
        mpeManager.stopAllNotes()
        midiEngine.sendAllNotesOff(port: .chords, channel: midiChannel(.chords))
        midiEngine.sendAllNotesOff(port: .melody, channel: midiChannel(.melody))
        midiEngine.sendAllNotesOff(port: .bass, channel: midiChannel(.bass))
        midiEngine.sendAllNotesOff(port: .drums, channel: midiChannel(.drums))
        activeNotes.removeAll()
        heldFaceNotes.removeAll()
        soundingChordNotes.removeAll()
        velocityStabilizer.reset()
        duoControlEngine.drumVelocityStabilizer.reset()
        strumState = StrumState()
        performanceEngine.pitchEngine.reset()
    }

    public func panic() {
        stopActiveNotes()
        droneEngine.resetSilently()
        midiEngine.panic()
        lastFrame = nil
        lastDrumHit = nil
        expressionTrails.reset()
    }

    public func setBPM(_ newBPM: Double) {
        let clamped = max(30.0, min(300.0, newBPM))
        self.bpm = clamped
        self.sequencer.transport.bpm = clamped
    }

    private func cancelPendingStrumNotes() {
        strumGeneration &+= 1
        pendingStrumNotes.forEach { $0.cancel() }
        pendingStrumNotes.removeAll(keepingCapacity: true)
    }

    public var instrumentStatusLabel: String {
        lastFrame?.instrumentStatusLabel ?? instrumentProfile.family.shortName
    }

    public var hudLabels: GestureHUDLabels {
        controllerManager.activeScheme.overlayHUDLabels(instrumentProfile.defaultGestureMapping)
    }

    public var activeTechniqueLabel: String? {
        guard let frame = lastFrame else { return nil }
        if frame.bend.isBending && abs(frame.bend.bendSemitones) > 0.08 {
            return frame.bend.displayLabel.map { "Bend \($0)" } ?? "Bend"
        }
        return frame.activeTechnique.playLabel
    }

    public var contextualHint: String? {
        if selectedWorkspace == .practice {
            return practiceEngine.feedbackMessage.isEmpty ? nil : practiceEngine.feedbackMessage
        }
        return lastFrame?.hint ?? lastHint
    }
}

public enum StrumDirection: String, Sendable {
    case up = "Up"
    case down = "Down"
    case none = "—"
}

enum HostRuntimeDetector {
    static func signals() -> HostDetectionSignals {
        let apps = NSWorkspace.shared.runningApplications
        let front = NSWorkspace.shared.frontmostApplication
        var bundles: [String] = []
        if let identifier = front?.bundleIdentifier {
            bundles.append(identifier)
        }
        bundles.append(contentsOf: apps.compactMap(\.bundleIdentifier))
        let names = apps.compactMap(\.localizedName)
        return HostDetectionSignals(
            frontmostBundleIdentifier: front?.bundleIdentifier,
            frontmostProcessName: front?.localizedName,
            bundleIdentifiers: bundles,
            processNames: names,
            midiClientNames: names
        )
    }
}

public struct StrumState {
    public var lastDirection: StrumDirection = .none
    public var hasReset: Bool = true
    public var lastCrossTime: Date?

    public init() {}
}

public enum Workspace: String, CaseIterable, Identifiable {
    case play = "Play"
    case harmony = "Harmony"
    case sequence = "Sequence"
    case map = "Map"
    case library = "Library"
    case practice = "Practice"

    public var id: String { rawValue }

    /// Workspaces allowed in persistent chrome. Practice is omitted so first
    /// launch does not spend screenspace on an unrequested learning mode.
    public static var persistentCases: [Workspace] {
        allCases.filter { $0 != .practice }
    }

    public var icon: String {
        switch self {
        case .play: return "gamecontroller.fill"
        case .harmony: return "music.note.list"
        case .sequence: return "rectangle.3.group.fill"
        case .map: return "slider.horizontal.3"
        case .library: return "books.vertical.fill"
        case .practice: return "graduationcap.fill"
        }
    }
}

// MARK: - Expression Trail Buffer

public struct ExpressionTrailHistory: Sendable {
    public static let capacity = 64
    
    // Store data in pre-allocated buffers
    private var bendBuffer: [Double] = Array(repeating: 0.0, count: capacity)
    private var pressureBuffer: [Double] = Array(repeating: 0.0, count: capacity)
    private var timbreBuffer: [Double] = Array(repeating: 0.0, count: capacity)
    private var muteBuffer: [Double] = Array(repeating: 0.0, count: capacity)
    
    // Ring buffer state
    private var writeIndex: Int = 0
    private var count: Int = 0

    public init() {}

    public mutating func push(bend: Double, pressure: Double, timbre: Double, mute: Double) {
        bendBuffer[writeIndex] = bend
        pressureBuffer[writeIndex] = pressure
        timbreBuffer[writeIndex] = timbre
        muteBuffer[writeIndex] = mute
        
        writeIndex = (writeIndex + 1) % Self.capacity
        if count < Self.capacity {
            count += 1
        }
    }

    public mutating func reset() {
        bendBuffer = Array(repeating: 0.0, count: Self.capacity)
        pressureBuffer = Array(repeating: 0.0, count: Self.capacity)
        timbreBuffer = Array(repeating: 0.0, count: Self.capacity)
        muteBuffer = Array(repeating: 0.0, count: Self.capacity)
        writeIndex = 0
        count = 0
    }
    
    // Ordered access for UI rendering (oldest to newest)
    public var bend: [Double] { ordered(bendBuffer) }
    public var pressure: [Double] { ordered(pressureBuffer) }
    public var timbre: [Double] { ordered(timbreBuffer) }
    public var mute: [Double] { ordered(muteBuffer) }
    
    private func ordered(_ buffer: [Double]) -> [Double] {
        guard count > 0 else { return [] }
        if count < Self.capacity {
            return Array(buffer[0..<count])
        }
        // If full, oldest data is at writeIndex
        return Array(buffer[writeIndex..<Self.capacity]) + Array(buffer[0..<writeIndex])
    }
}
