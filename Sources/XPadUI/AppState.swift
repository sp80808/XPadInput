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
    public var bpm: Double = 120
    public var isPlaying: Bool = false
    public var isRecording: Bool = false
    public var isLooping: Bool = false
    public var metronomeEnabled: Bool = false

    public var diatonicChords: [Chord] = []
    public var selectedChordIndex: Int = 0
    public var currentChord: Chord?
    public var previousVoicing: ChordVoicing?

    public var activeNotes: [Note] = []
    public var lastStrumDirection: StrumDirection = .none
    public var lastVelocity: UInt8 = 0
    public var lastStrumTime: Date?

    public var selectedWorkspace: Workspace = .play
    public var showDiagnostics: Bool = false

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
    public var currentTick: UInt64 = 0
    public var chordGateConfiguration = ChordGateConfiguration(mode: .timed, timedDuration: 0.85)
    public var duoPerformanceMode: DuoPerformanceMode = .instrumentOnly
    public var lastDrumHit: DuoDrumHit?
    public var midiPassthruMode: MIDIPassthruMode = .full

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
    private var velocityStabilizer = VelocityStabilizer()
    private var duoControlEngine = DuoControlEngine()
    private var performanceRegisterMemory = PerformanceLaneRegisterMemory()
    private var hostDetectionObserver: NSObjectProtocol?

    public init() {
        let midiEngine = MIDIEngine()
        self.midiEngine = midiEngine
        self.mpeManager = MPEManager(
            midiEngine: midiEngine,
            bendRangeSemitones: DestinationCapabilityProfile.internalSynth.bendRangeSemitones
        )
    }

    public func initialize() {
        updateDiatonicChords()
        audioEngine.start()
        XPadPluginRegistrar.registerPluginComponents()
        setupIncomingMIDIPassthru()
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
        updateDiatonicChords()
    }

    public func setScale(_ scale: Scale) {
        currentScale = Scale(root: currentKey, type: scale.type)
        updateDiatonicChords()
    }

    public func setInstrument(_ profile: InstrumentProfile) {
        stopActiveNotes()
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
        handleChordSelection(state)

        let drumVelocity = UInt8(clamping: 72 + Int(Double(state.rightTrigger.value) * 48))
        let duoFrame = duoControlEngine.process(state: state, drumVelocity: drumVelocity)
        handleDuoDrumHits(duoFrame.drumHits)

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
            state: state,
            context: musicalContext(),
            heldNotes: activeNotes,
            timestamp: now
        )
        lastFrame = frame
        if let hint = frame.hint { lastHint = hint }

        if !duoFrame.suppressesInstrumentFaceButtons {
            handleFaceEvents(frame.faceEvents)
        }
        applyExpression(frame)

        if !frame.suppressStrum && !isSoloModeActive {
            handleStrumming(state, timestamp: now)
        } else if instrumentProfile.family == .synthLead || instrumentProfile.family == .genericMPE {
            applyLeadTimbre(frame.timbre)
        }

        if let haptic = frame.haptic {
            controllerManager.playTechniqueHaptic(haptic)
        }

        if state.hasMotion {
            audioEngine.updateSpatialFromIMU(
                gyroPitch: Float(state.gyroX),
                gyroRoll: Float(state.gyroY),
                gyroYaw: Float(state.gyroZ)
            )
        }

        lastInputTime = now
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
            retargetHeldChordTones()
            controllerManager.playTechniqueHaptic(.chordChange)
            multiJamManager.updateSharedHarmony(key: currentKey, scale: currentScale, chord: new)
            _ = smartSoloEngine.handleChordChange(oldChord: old, newChord: new, context: musicalContext())
            if selectedWorkspace == .practice && practiceEngine.isPracticeActive {
                practiceEngine.evaluateChordInput(new)
            }
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
            beginPhysicalVoice(event.note, velocity: event.velocity, technique: event.technique)
        }
        if !destinationProfile.supportsMPE, !alreadyOwnedByFace {
            midiEngine.sendNoteOn(
                port: melodicMIDIPort,
                channel: midiChannel(for: melodicMIDIPort),
                note: event.note.midiNote,
                velocity: event.velocity
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
                let velocity = velocityStabilizer.process(normalizedIntensity: intensity)
                lastVelocity = velocity
                lastStrumTime = Date()

                var chord = currentChord ?? diatonicChords.first ?? Chord(root: currentKey, quality: .major)
                chord = applyModifier(chord, modifier: state.activeModifier)
                let voice = makeChordVoice(chord)
                let events = chordGateEngine.process(
                    voice: voice,
                    isGestureActive: true,
                    timestamp: timestamp
                )
                handleChordGateEvents(events, velocity: velocity, direction: direction)
            }
        } else if travel < releaseThreshold {
            strumState.hasReset = true
            let events = chordGateEngine.process(
                voice: nil,
                isGestureActive: false,
                timestamp: timestamp
            )
            handleChordGateEvents(events, velocity: lastVelocity, direction: lastStrumDirection)
        } else {
            let events = chordGateEngine.advance(timestamp: timestamp)
            handleChordGateEvents(events, velocity: lastVelocity, direction: lastStrumDirection)
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
        direction: StrumDirection
    ) {
        for event in events {
            switch event {
            case .began(let voice):
                startChordVoice(voice, velocity: velocity, direction: direction)
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
            let workItem = DispatchWorkItem { [weak self] in
                guard let self, self.strumGeneration == generation else { return }
                let wasSounding = self.isNoteOwned(note.midiNote)
                let wasInserted = self.soundingChordNotes.insert(note.midiNote).inserted
                guard wasInserted else { return }

                if !wasSounding {
                    self.beginPhysicalVoice(
                        note,
                        velocity: UInt8(noteVel),
                        technique: technique
                    )
                }
                if !self.destinationProfile.supportsMPE {
                    self.midiEngine.sendNoteOn(
                        port: .chords,
                        channel: self.midiChannel(.chords),
                        note: note.midiNote,
                        velocity: UInt8(noteVel)
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

    private func beginPhysicalVoice(_ note: Note, velocity: UInt8, technique: MusicalTechnique) {
        if destinationProfile.supportsMPE {
            mpeManager.noteOn(note: note.midiNote, velocity: velocity, technique: technique)
        }
        if !audioEngine.isMuted {
            audioEngine.noteOn(note: note.midiNote, velocity: velocity, technique: technique)
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
            lastDrumHit = hit

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
                self?.midiEngine.sendNoteOff(
                    port: .drums,
                    channel: self?.midiChannel(.drums) ?? 9,
                    note: hit.voice.generalMIDINote
                )
            }
        }
    }

    public func stopActiveNotes() {
        chordGateReleaseWorkItem?.cancel()
        chordGateReleaseWorkItem = nil
        cancelPendingStrumNotes()
        _ = chordGateEngine.releaseAll()
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
        midiEngine.panic()
        lastFrame = nil
        lastDrumHit = nil
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
