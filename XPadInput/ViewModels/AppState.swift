import SwiftUI

/// Central application state coordinating all engines.
@Observable
final class AppState: @unchecked Sendable {
    // Engines
    var controllerManager = ControllerManager()
    var midiEngine = MIDIEngine()
    var audioEngine = AudioEngine()

    // Music state
    var currentKey: PitchClass = .d
    var currentScale: Scale = .naturalMinor
    var bpm: Double = 120
    var isPlaying: Bool = false
    var isRecording: Bool = false
    var isLooping: Bool = false
    var metronomeEnabled: Bool = false

    // Harmonic wheel
    var harmonicWheel: HarmonicWheel!
    var activeLayer: WheelLayer = .diatonic
    var highlightedSector: WheelSector?

    // Chord state
    var diatonicChords: [Chord] = []
    var selectedChordIndex: Int = 0
    var currentChord: Chord?
    var previousVoicing: ChordVoicing?

    // Active notes being played
    var activeNotes: [Note] = []
    var activeChannelMap: [UInt8: UInt8] = [:]  // noteNumber → MIDI channel

    // Performance state
    var lastStrumDirection: StrumDirection = .none
    var lastVelocity: UInt8 = 0
    var lastStrumTime: Date?

    // Expression state
    var currentPitchBend: Double = 0       // -1 to 1
    var currentTimbre: Double = 0          // 0 to 1
    var currentPressure: Double = 0        // 0 to 1

    // Navigation
    var selectedWorkspace: Workspace = .play

    // UI state
    var showDiagnostics: Bool = false

    func initialize() {
        harmonicWheel = HarmonicWheel(root: currentKey, scale: currentScale)
        updateDiatonicChords()
        audioEngine.start()

        // Wire controller to performance engine
        controllerManager.onStateChanged = { [weak self] state in
            self?.handleControllerInput(state)
        }
    }

    func updateDiatonicChords() {
        diatonicChords = Chord.diatonicChords(root: currentKey, scale: currentScale)
        harmonicWheel = HarmonicWheel(root: currentKey, scale: currentScale)
        if !diatonicChords.isEmpty {
            selectedChordIndex = 0
            currentChord = diatonicChords[0]
        }
    }

    func setKey(_ key: PitchClass) {
        currentKey = key
        updateDiatonicChords()
    }

    func setScale(_ scale: Scale) {
        currentScale = scale
        updateDiatonicChords()
    }

    // MARK: - Controller Input Handling

    private var strumState = StrumState()
    private var lastDpadState: DpadState = .init()
    private var lastButtonState: ButtonState = .init()

    private func handleControllerInput(_ state: ControllerState) {
        // D-Pad: Key & Scale switching
        handleDpad(state)

        // Shoulder buttons: Layer switching
        handleLayerSwitching(state)

        // Left stick: Chord selection via harmonic wheel
        handleChordSelection(state)

        // Right stick: Strumming
        handleStrumming(state)

        // Face buttons: Quick triggers
        handleFaceButtons(state)

        // Triggers: Expression
        handleExpression(state)

        // Motion: Pitch bend & vibrato
        handleMotionExpression(state)
    }

    // MARK: - D-Pad (Key & Scale)

    private func handleDpad(_ state: ControllerState) {
        let dpad = DpadState(
            up: state.dpadUp, down: state.dpadDown,
            left: state.dpadLeft, right: state.dpadRight
        )

        // Key: Left/Right cycle through keys
        if dpad.left && !lastDpadState.left {
            let newKey = currentKey.transposed(by: -1)
            setKey(newKey)
        }
        if dpad.right && !lastDpadState.right {
            let newKey = currentKey.transposed(by: 1)
            setKey(newKey)
        }

        // Scale: Up/Down cycle through scales
        if dpad.up && !lastDpadState.up {
            cycleScale(forward: true)
        }
        if dpad.down && !lastDpadState.down {
            cycleScale(forward: false)
        }

        lastDpadState = dpad
    }

    private func cycleScale(forward: Bool) {
        let scales = Scale.allScales
        guard let idx = scales.firstIndex(where: { $0.id == currentScale.id }) else { return }
        let newIdx = forward ? (idx + 1) % scales.count : (idx - 1 + scales.count) % scales.count
        setScale(scales[newIdx])
    }

    // MARK: - Layer Switching (Shoulders)

    private func handleLayerSwitching(_ state: ControllerState) {
        if state.leftShoulder && state.rightShoulder {
            activeLayer = .mediant
        } else if state.leftShoulder {
            activeLayer = .colour
        } else if state.rightShoulder {
            activeLayer = .borrowed
        } else if state.leftTrigger > 0.8 && state.rightTrigger > 0.8 {
            activeLayer = .tension
        } else {
            activeLayer = .diatonic
        }
    }

    // MARK: - Chord Selection (Left Stick + Harmonic Wheel)

    private func handleChordSelection(_ state: ControllerState) {
        guard state.leftStickMagnitude > 0.3 else {
            highlightedSector = nil
            return
        }

        let angle = state.leftStickAngle
        guard let sector = harmonicWheel.sector(forAngle: angle, layer: activeLayer) else { return }

        highlightedSector = sector

        if sector.chord != currentChord {
            currentChord = sector.chord

            // Find diatonic index if applicable
            if let idx = diatonicChords.firstIndex(where: { $0.root == sector.chord.root && $0.quality == sector.chord.quality }) {
                selectedChordIndex = idx
            }
        }
    }

    // MARK: - Strumming (Right Stick)

    private func handleStrumming(_ state: ControllerState) {
        let rightY = state.rightStickY
        let speed = abs(rightY)
        let threshold: Float = 0.25

        if speed > threshold {
            let direction: StrumDirection = rightY > 0 ? .down : .up

            if direction != strumState.lastDirection || strumState.hasReset {
                strumState.lastDirection = direction
                strumState.hasReset = false
                lastStrumDirection = direction

                // Velocity from stick speed — wider dynamic range
                let velocity = UInt8(max(25, min(127, Int(speed * 155))))
                lastVelocity = velocity
                lastStrumTime = Date()

                let chord = currentChord ?? diatonicChords.first ?? Chord(root: currentKey, quality: .major)
                triggerChord(chord, velocity: velocity, direction: direction)
            }
        } else {
            strumState.hasReset = true
        }
    }

    // MARK: - Face Buttons

    private func handleFaceButtons(_ state: ControllerState) {
        let buttons = ButtonState(
            a: state.buttonA, b: state.buttonB,
            x: state.buttonX, y: state.buttonY
        )

        // Button A (Cross): Root bass note
        if buttons.a && !lastButtonState.a {
            let note = Note(pitchClass: currentKey, octave: 2)
            triggerSingleNote(note, velocity: 100)
        } else if !buttons.a && lastButtonState.a {
            let note = Note(pitchClass: currentKey, octave: 2)
            releaseSingleNote(note)
        }

        // Button B (Circle): Fifth
        if buttons.b && !lastButtonState.b {
            let note = Note(pitchClass: currentKey.transposed(by: 7), octave: 3)
            triggerSingleNote(note, velocity: 90)
        } else if !buttons.b && lastButtonState.b {
            let note = Note(pitchClass: currentKey.transposed(by: 7), octave: 3)
            releaseSingleNote(note)
        }

        // Button X (Square): Current chord root octave up
        if buttons.x && !lastButtonState.x {
            if let chord = currentChord {
                let note = Note(pitchClass: chord.root, octave: 4)
                triggerSingleNote(note, velocity: 85)
            }
        } else if !buttons.x && lastButtonState.x {
            if let chord = currentChord {
                let note = Note(pitchClass: chord.root, octave: 4)
                releaseSingleNote(note)
            }
        }

        // Button Y (Triangle): Stab (full chord instant trigger)
        if buttons.y && !lastButtonState.y {
            let chord = currentChord ?? Chord(root: currentKey, quality: .major)
            triggerChord(chord, velocity: 110, direction: .down)
        }

        lastButtonState = buttons
    }

    // MARK: - Expression (Triggers + Motion)

    private func handleExpression(_ state: ControllerState) {
        // Left trigger: CC74 (Brightness / Timbre) — affects all active notes
        if state.leftTrigger > 0.05 {
            let value = UInt8(state.leftTrigger * 127)
            currentTimbre = Double(state.leftTrigger)
            midiEngine.sendCC(controller: 74, value: value, channel: 0)

            // Per-note timbre for MPE
            for note in activeNotes {
                midiEngine.sendTimbre(note: note.midiNote, value: value)
            }
        }

        // Right trigger: Pressure / Aftertouch
        if state.rightTrigger > 0.05 {
            let value = UInt8(state.rightTrigger * 127)
            currentPressure = Double(state.rightTrigger)

            for note in activeNotes {
                midiEngine.sendPressure(note: note.midiNote, value: value)
            }
        }
    }

    private func handleMotionExpression(_ state: ControllerState) {
        guard state.hasMotion else { return }

        // Gyro Y → Pitch Bend
        let gyroSensitivity = 0.15
        let pitchBend = max(-1.0, min(1.0, state.gyroY * gyroSensitivity))
        currentPitchBend = pitchBend

        // Map -1...1 to 0...16383 (center = 8192)
        let bendValue = UInt16(max(0, min(16383, Int(pitchBend * 8191.0 + 8192.0))))
        midiEngine.sendPitchBend(value: bendValue, channel: 0)
    }

    // MARK: - Chord Triggering

    private func triggerChord(_ chord: Chord, velocity: UInt8, direction: StrumDirection) {
        stopActiveNotes()

        // Create voicing with voice-leading
        let voicing: ChordVoicing
        if let prev = previousVoicing {
            voicing = ChordVoicing.voiceLed(chord: chord, from: prev)
        } else {
            voicing = ChordVoicing.strummed(chord: chord, strings: 5, baseOctave: 3)
        }

        previousVoicing = voicing

        // Notes in strum order
        var notes = voicing.notes
        if direction == .up {
            notes = notes.reversed()
        }

        activeNotes = notes

        // Strum with slight delays for realism
        let strumDelay = 0.010   // 10ms per string
        for (i, note) in notes.enumerated() {
            let delay = Double(i) * strumDelay
            let noteVel = UInt8(max(25, Int(velocity) - i * 4))

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.audioEngine.noteOn(note: note.midiNote, velocity: noteVel)
                self?.midiEngine.sendNoteOn(note: note.midiNote, velocity: noteVel)
            }
        }
    }

    private func triggerSingleNote(_ note: Note, velocity: UInt8) {
        audioEngine.noteOn(note: note.midiNote, velocity: velocity)
        midiEngine.sendNoteOn(note: note.midiNote, velocity: velocity)
        if !activeNotes.contains(where: { $0.midiNote == note.midiNote }) {
            activeNotes.append(note)
        }
    }

    private func releaseSingleNote(_ note: Note) {
        audioEngine.noteOff(note: note.midiNote)
        midiEngine.sendNoteOff(note: note.midiNote)
        activeNotes.removeAll { $0.midiNote == note.midiNote }
    }

    func stopActiveNotes() {
        for note in activeNotes {
            audioEngine.noteOff(note: note.midiNote)
            midiEngine.sendNoteOff(note: note.midiNote)
        }
        activeNotes.removeAll()
    }
}

// MARK: - Support Types

/// Strum direction
enum StrumDirection: String, Sendable {
    case up = "Up"
    case down = "Down"
    case none = "—"
}

/// Internal strum tracking state
struct StrumState {
    var lastDirection: StrumDirection = .none
    var hasReset: Bool = true
    var lastCrossTime: Date?
}

/// D-pad edge detection
struct DpadState {
    var up = false
    var down = false
    var left = false
    var right = false
}

/// Face button edge detection
struct ButtonState {
    var a = false
    var b = false
    var x = false
    var y = false
}

/// Main workspace navigation
enum Workspace: String, CaseIterable, Identifiable {
    case play = "Play"
    case harmony = "Harmony"
    case sequence = "Sequence"
    case map = "Map"
    case library = "Library"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .play:     return "gamecontroller.fill"
        case .harmony:  return "music.note.list"
        case .sequence: return "rectangle.3.group.fill"
        case .map:      return "slider.horizontal.3"
        case .library:  return "books.vertical.fill"
        }
    }
}
