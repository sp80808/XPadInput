import SwiftUI
import XPadCore
import XPadController
import XPadMIDI
import XPadAudio

/// Central application state coordinating all engines.
@Observable
public final class AppState: @unchecked Sendable {
    // Engines
    public var controllerManager = ControllerManager()
    public var midiEngine = MIDIEngine()
    public var audioEngine = AudioEngine()
    
    // Music state
    public var currentKey: PitchClass = .d
    public var currentScale: Scale = .naturalMinor
    public var bpm: Double = 120
    public var isPlaying: Bool = false
    public var isRecording: Bool = false
    public var isLooping: Bool = false
    public var metronomeEnabled: Bool = false
    
    // Chord state
    public var diatonicChords: [Chord] = []
    public var selectedChordIndex: Int = 0
    public var currentChord: Chord?
    public var previousVoicing: ChordVoicing?
    
    // Active notes being played
    public var activeNotes: [Note] = []
    
    // Performance state
    public var lastStrumDirection: StrumDirection = .none
    public var lastVelocity: UInt8 = 0
    public var lastStrumTime: Date?
    
    // Navigation
    public var selectedWorkspace: Workspace = .play
    
    // UI state
    public var showDiagnostics: Bool = false
    
    public init() {}
    
    public func initialize() {
        updateDiatonicChords()
        audioEngine.start()
        
        // Wire controller to performance engine
        controllerManager.onStateChanged = { [weak self] state in
            self?.handleControllerInput(state)
        }
    }
    
    public func updateDiatonicChords() {
        diatonicChords = Chord.diatonicChords(root: currentKey, scale: currentScale)
        if diatonicChords.isEmpty == false {
            selectedChordIndex = 0
            currentChord = diatonicChords[0]
        }
    }
    
    public func setKey(_ key: PitchClass) {
        currentKey = key
        updateDiatonicChords()
    }
    
    public func setScale(_ scale: Scale) {
        currentScale = scale
        updateDiatonicChords()
    }
    
    // MARK: - Controller Input Handling
    
    private var strumState: StrumState = StrumState()
    
    private func handleControllerInput(_ state: ControllerState) {
        // Left stick: Chord selection via angle
        handleChordSelection(state)
        
        // Right stick: Strumming
        handleStrumming(state)
        
        // Modifiers
        handleModifiers(state)
    }
    
    private func handleChordSelection(_ state: ControllerState) {
        guard state.leftStickMagnitude > 0.3 else { return }
        
        let angle = state.leftStickAngle
        let chordCount = diatonicChords.count
        guard chordCount > 0 else { return }
        
        // Map angle to chord index
        // Top = I, clockwise through the diatonic chords
        // Normalise angle: 0 = up, clockwise positive
        var normalised = -(angle - .pi / 2)
        if normalised < 0 { normalised += 2 * .pi }
        
        let sliceAngle = (2.0 * .pi) / Double(chordCount)
        let index = Int(normalised / sliceAngle) % chordCount
        
        if index != selectedChordIndex {
            selectedChordIndex = index
            currentChord = diatonicChords[index]
        }
    }
    
    private func handleStrumming(_ state: ControllerState) {
        let rightY = state.rightStickY
        let speed = abs(rightY)
        let threshold: Float = 0.25
        
        // Detect strum crossing
        if speed > threshold {
            let direction: StrumDirection = rightY > 0 ? .down : .up
            
            if direction != strumState.lastDirection || strumState.hasReset {
                // New strum detected
                strumState.lastDirection = direction
                strumState.hasReset = false
                lastStrumDirection = direction
                
                // Calculate velocity from speed
                let velocity = UInt8(max(30, min(127, Int(speed * 140))))
                lastVelocity = velocity
                lastStrumTime = Date()
                
                // Apply modifier for chord quality changes
                var chord = currentChord ?? diatonicChords.first ?? Chord(root: currentKey, quality: .major)
                let modifier = state.activeModifier
                chord = applyModifier(chord, modifier: modifier)
                
                triggerChord(chord, velocity: velocity, direction: direction)
            }
        } else {
            strumState.hasReset = true
        }
    }
    
    private func applyModifier(_ chord: Chord, modifier: ControllerModifier) -> Chord {
        switch modifier {
        case .leftShoulder:
            // Add 7th
            switch chord.quality {
            case .major: return Chord(root: chord.root, quality: .major7)
            case .minor: return Chord(root: chord.root, quality: .minor7)
            case .diminished: return Chord(root: chord.root, quality: .halfDiminished7)
            default: return chord
            }
        case .rightShoulder:
            // Sus chords
            switch chord.quality {
            case .major: return Chord(root: chord.root, quality: .sus4)
            case .minor: return Chord(root: chord.root, quality: .sus2)
            default: return chord
            }
        case .leftTrigger:
            // Add 9
            switch chord.quality {
            case .major: return Chord(root: chord.root, quality: .add9)
            case .minor: return Chord(root: chord.root, quality: .minor9)
            default: return chord
            }
        case .rightTrigger:
            // 6th chords
            switch chord.quality {
            case .major: return Chord(root: chord.root, quality: .sixth)
            case .minor: return Chord(root: chord.root, quality: .minorSixth)
            default: return chord
            }
        default:
            return chord
        }
    }
    
    private func triggerChord(_ chord: Chord, velocity: UInt8, direction: StrumDirection) {
        // Stop previous notes
        stopActiveNotes()
        
        // Create voicing
        let voicing: ChordVoicing
        if let prev = previousVoicing {
            voicing = ChordVoicing.voiceLed(chord: chord, from: prev)
        } else {
            voicing = ChordVoicing.strummed(chord: chord, strings: 5, baseOctave: 3)
        }
        
        previousVoicing = voicing
        
        // Get notes in strum order
        var notes = voicing.notes
        if direction == .up {
            notes = notes.reversed()
        }
        
        activeNotes = notes
        
        // Strum with slight delays between notes
        let strumDelay = 0.012 // 12ms between notes
        for (i, note) in notes.enumerated() {
            let delay = Double(i) * strumDelay
            let noteVel = max(30, Int(velocity) - i * 3) // Slightly decrease velocity per string
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.audioEngine.noteOn(note: note.midiNote, velocity: UInt8(noteVel))
                self?.midiEngine.sendNoteOn(note: note.midiNote, velocity: UInt8(noteVel))
            }
        }
    }
    
    public func stopActiveNotes() {
        for note in activeNotes {
            audioEngine.noteOff(note: note.midiNote)
            midiEngine.sendNoteOff(note: note.midiNote)
        }
        activeNotes.removeAll()
    }
    
    private func handleModifiers(_ state: ControllerState) {
        // Face buttons as direct triggers
        if state.buttonA {
            // Root note
            let rootNote = Note(pitchClass: currentKey, octave: 3)
            audioEngine.noteOn(note: rootNote.midiNote, velocity: 100)
            midiEngine.sendNoteOn(note: rootNote.midiNote, velocity: 100)
        }
    }
}

/// Strum direction
public enum StrumDirection: String, Sendable {
    case up = "Up"
    case down = "Down"
    case none = "—"
}

/// Internal strum tracking state
public struct StrumState {
    public var lastDirection: StrumDirection = .none
    public var hasReset: Bool = true
    public var lastCrossTime: Date?
    
    public init() {}
}

/// Main workspace navigation
public enum Workspace: String, CaseIterable, Identifiable {
    case play = "Play"
    case harmony = "Harmony"
    case sequence = "Sequence"
    case map = "Map"
    case library = "Library"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .play: return "gamecontroller.fill"
        case .harmony: return "music.note.list"
        case .sequence: return "rectangle.3.group.fill"
        case .map: return "slider.horizontal.3"
        case .library: return "books.vertical.fill"
        }
    }
}
