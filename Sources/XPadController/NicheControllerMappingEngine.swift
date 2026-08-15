import Foundation
import XPadCore
import XPadTheory

/// Output musical action produced from specialized rhythm and niche controller events.
public enum NicheMusicalAction: Sendable {
    case chordStrum(notes: [Note], velocity: UInt8, direction: StrumDirection)
    case singleNoteOn(note: UInt8, velocity: UInt8)
    case singleNoteOff(note: UInt8)
    case pitchBend(cents: Double) // -200 to +200 cents or MPE bend
    case timbreCutoff(value: Double) // 0.0 to 1.0 (CC74)
    case masterDynamic(value: Double) // 0.0 to 1.0 (CC11 Expression)
    case arpeggioTrigger(subdivision: RhythmicSubdivision, root: Note)
    case drumHit(type: DrumHitType, velocity: UInt8)
}

public enum DrumHitType: String, Sendable {
    case kick
    case snare
    case hihat
    case crash
    case tom
}

/// Specialized mapping engine translating rhythm controllers & niche hardware gestures into rich musical events.
public final class NicheControllerMappingEngine: Sendable {
    public init() {}

    // MARK: - Guitar Hero / Rock Band Processing
    public func processGuitarHero(
        state: GamepadState,
        scale: Scale,
        currentBaseOctave: Int = 3
    ) -> [NicheMusicalAction] {
        var actions: [NicheMusicalAction] = []

        // 1. Whammy Bar -> Continuous MPE Pitch Bend / Vibrato
        if state.whammy > 0.01 {
            let bendCents = -Double(state.whammy) * 200.0 // Pitch dive down up to 200 cents
            actions.append(.pitchBend(cents: bendCents))
            actions.append(.timbreCutoff(value: 0.5 + state.whammy * 0.5))
        }

        // 2. Fret Selection (5 frets -> Scale degrees: I, ii, iii, IV, V)
        var activeDegree = 0
        if state.fret1 || state.buttonA { activeDegree = 1 }
        else if state.fret2 || state.buttonB { activeDegree = 2 }
        else if state.fret3 || state.buttonY { activeDegree = 3 }
        else if state.fret4 || state.buttonX { activeDegree = 4 }
        else if state.fret5 || state.leftShoulder { activeDegree = 5 }

        // 3. Strum Bar Trigger
        if state.strumDown || state.dpadDown {
            let chord = buildDegreeChord(degree: activeDegree > 0 ? activeDegree : 1, scale: scale)
            let notes = chord.voicedNotes(baseOctave: currentBaseOctave)
            actions.append(.chordStrum(notes: notes, velocity: 110, direction: .down))
        } else if state.strumUp || state.dpadUp {
            let chord = buildDegreeChord(degree: activeDegree > 0 ? activeDegree : 1, scale: scale)
            let notes = chord.voicedNotes(baseOctave: currentBaseOctave)
            actions.append(.chordStrum(notes: notes, velocity: 95, direction: .up))
        }

        // 4. Tilt Sensor (Star Power burst)
        if state.tiltSensor > 0.6 || state.gyroPitch > 0.7 {
            let rootNote = Note(pitchClass: scale.root, octave: currentBaseOctave)
            actions.append(.arpeggioTrigger(subdivision: .sixteenth, root: rootNote))
        }

        return actions
    }

    // MARK: - Sound Voltex (SDVX) Processing
    public func processSoundVoltex(
        state: GamepadState,
        scale: Scale,
        currentBaseOctave: Int = 3
    ) -> [NicheMusicalAction] {
        var actions: [NicheMusicalAction] = []

        // VOL-L Knob -> Filter Cutoff sweep (CC74)
        let cutoff = (state.encoderL + 1.0) / 2.0
        actions.append(.timbreCutoff(value: max(0.0, min(1.0, cutoff))))

        // VOL-R Knob -> Pitch Bend / Resonance sweep
        let pitch = state.encoderR * 100.0 // +/- 100 cents
        actions.append(.pitchBend(cents: pitch))

        // BT-A, BT-B, BT-C, BT-D -> 4 Chord Inversions / Progressions (I, IV, V, vi)
        let degrees = [1, 4, 5, 6]
        let buttons = [state.buttonX, state.buttonY, state.buttonB, state.buttonA]

        for (idx, isPressed) in buttons.enumerated() {
            if isPressed {
                let chord = buildDegreeChord(degree: degrees[idx], scale: scale)
                let notes = chord.voicedNotes(baseOctave: currentBaseOctave)
                actions.append(.chordStrum(notes: notes, velocity: 105, direction: .down))
                break
            }
        }

        return actions
    }

    // MARK: - Beatmania IIDX Processing
    public func processBeatmania(
        state: GamepadState,
        scale: Scale,
        currentBaseOctave: Int = 3
    ) -> [NicheMusicalAction] {
        var actions: [NicheMusicalAction] = []

        // Turntable scratch -> Pitch scrub & filter modulation
        if abs(state.turntableVelocity) > 0.05 {
            actions.append(.pitchBend(cents: state.turntableVelocity * 150.0))
            actions.append(.timbreCutoff(value: 0.5 + state.turntableVelocity * 0.4))
        }

        // 7 Keys -> Diatonic Scale Notes
        let pitchClasses = scale.pitchClasses
        let keyPresses = [
            state.buttonA, state.buttonX, state.buttonB, state.buttonY,
            state.leftShoulder, state.rightShoulder, state.dpadUp
        ]

        for (idx, isPressed) in keyPresses.enumerated() {
            if isPressed && idx < pitchClasses.count {
                let note = Note(pitchClass: pitchClasses[idx], octave: currentBaseOctave)
                actions.append(.singleNoteOn(note: note.midiNumber, velocity: 100))
            }
        }

        return actions
    }

    // MARK: - Taiko Drum Processing
    public func processTaikoDrum(
        state: GamepadState,
        scale: Scale,
        currentBaseOctave: Int = 2
    ) -> [NicheMusicalAction] {
        var actions: [NicheMusicalAction] = []

        // Don Left/Right -> Heavy Kick & Bass Root Chord
        if state.buttonA || state.dpadDown {
            actions.append(.drumHit(type: .kick, velocity: 120))
            let rootNote = Note(pitchClass: scale.root, octave: currentBaseOctave)
            actions.append(.singleNoteOn(note: rootNote.midiNumber, velocity: 110))
        }

        // Ka Left/Right -> Snare / Hi-Hat & Upper Chord Strum
        if state.buttonY || state.dpadUp {
            actions.append(.drumHit(type: .snare, velocity: 115))
            let fifthChord = Chord(root: scale.pitchClasses[min(4, scale.pitchClasses.count - 1)], quality: .major)
            actions.append(.chordStrum(notes: fifthChord.voicedNotes(baseOctave: currentBaseOctave + 1), velocity: 90, direction: .up))
        }

        return actions
    }

    // MARK: - Flight Sim HOTAS Processing
    public func processFlightHOTAS(
        state: GamepadState,
        scale: Scale,
        currentBaseOctave: Int = 3
    ) -> [NicheMusicalAction] {
        var actions: [NicheMusicalAction] = []

        // Throttle -> Master Dynamic Swell (CC11)
        actions.append(.masterDynamic(value: state.throttle))

        // Stick Y (Pitch) -> Filter Cutoff
        let pitchCutoff = Double(state.leftStick.y + 1.0) / 2.0
        actions.append(.timbreCutoff(value: pitchCutoff))

        // Rudder Z-Twist -> MPE Pitch Bend
        let twistBend = state.rudderTwist * 200.0 // +/- 200 cents
        actions.append(.pitchBend(cents: twistBend))

        // Trigger -> Fire Chord Strum
        if state.rightTrigger > 0.7 || state.buttonA {
            let chord = Chord(root: scale.root, quality: .major7)
            actions.append(.chordStrum(notes: chord.voicedNotes(baseOctave: currentBaseOctave), velocity: UInt8(state.rightTrigger * 127), direction: .down))
        }

        return actions
    }

    // MARK: - Racing Wheel Processing
    public func processRacingWheel(
        state: GamepadState,
        scale: Scale,
        currentBaseOctave: Int = 3
    ) -> [NicheMusicalAction] {
        var actions: [NicheMusicalAction] = []

        // Wheel angle -> Circle of Fifths degree rotation
        let wheelNorm = (state.wheelAngle + 1.0) / 2.0 // 0.0 to 1.0
        let degreeIndex = Int(wheelNorm * Double(scale.pitchClasses.count)) % max(1, scale.pitchClasses.count)
        let selectedRoot = scale.pitchClasses[degreeIndex]

        // Gas Pedal -> Chord strum velocity
        if state.pedalGas > 0.15 {
            let chord = Chord(root: selectedRoot, quality: .major)
            let vel = UInt8(min(127, max(40, state.pedalGas * 127)))
            actions.append(.chordStrum(notes: chord.voicedNotes(baseOctave: currentBaseOctave), velocity: vel, direction: .down))
        }

        // Brake Pedal -> Palm Mute damping
        if state.pedalBrake > 0.05 {
            actions.append(.timbreCutoff(value: 1.0 - state.pedalBrake))
        }

        return actions
    }

    // MARK: - Private Helpers
    private func buildDegreeChord(degree: Int, scale: Scale) -> Chord {
        let count = scale.pitchClasses.count
        guard count > 0 else { return Chord(root: .c, quality: .major) }
        let root = scale.pitchClasses[(degree - 1) % count]
        let quality: ChordQuality = (degree == 1 || degree == 4 || degree == 5) ? .major : .minor
        return Chord(root: root, quality: quality)
    }
}
