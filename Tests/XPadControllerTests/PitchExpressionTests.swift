import XCTest
@testable import XPadCore
@testable import XPadTheory
@testable import XPadController

final class PitchExpressionAndLegatoTests: XCTestCase {
    func testCentreStickIsZeroBend() {
        var engine = PitchExpressionEngine(instrumentRange: 2, destinationRange: 48, assist: .off)
        let context = MusicalContext(key: .d, scale: Scale(root: .d, type: .naturalMinor))
        let mapped = engine.mappedSemitones(stickX: 0, heldNote: .middleC, context: context)
        XCTAssertEqual(mapped.semitones, 0, accuracy: 0.0001)
        XCTAssertEqual(PitchExpressionEngine.pitchBendValue(semitones: 0, range: 48), 8192)
    }

    func testFullRightStickReachesInstrumentRange() {
        var engine = PitchExpressionEngine(instrumentRange: 2, destinationRange: 48, curve: .linear, assist: .off, stickDeadzone: 0)
        let context = MusicalContext(key: .d, scale: Scale(root: .d, type: .naturalMinor))
        let mapped = engine.mappedSemitones(stickX: 1, heldNote: Note(pitchClass: .e, octave: 4), context: context)
        XCTAssertEqual(mapped.semitones, 2, accuracy: 0.05)
        let midi = PitchExpressionEngine.pitchBendValue(semitones: mapped.semitones, range: 48)
        XCTAssertGreaterThan(midi, 8192)
        XCTAssertLessThan(midi, 9000)
    }

    func testReturnToZeroSpringsCleanly() {
        var engine = PitchExpressionEngine(instrumentRange: 2, destinationRange: 48, curve: .linear, assist: .off, stickDeadzone: 0.1, springTau: 0.02)
        let context = MusicalContext(key: .e, scale: .cMajor)
        let note = Note(pitchClass: .e, octave: 4)
        _ = engine.process(stickX: 1, heldNote: note, context: context, vibratoSemitones: 0, dt: 0.05)
        var state = engine.process(stickX: 0, heldNote: note, context: context, vibratoSemitones: 0, dt: 0.05)
        for _ in 0..<12 {
            state = engine.process(stickX: 0, heldNote: note, context: context, vibratoSemitones: 0, dt: 0.02)
        }
        XCTAssertEqual(state.bendSemitones, 0, accuracy: 0.02)
        XCTAssertEqual(state.midiPitchBend, 8192)
    }

    func testSoftMagnetsDoNotHardSnap() {
        let attracted = PitchExpressionEngine.attract(1.85, to: [2.0], strength: 0.28)
        XCTAssertGreaterThan(attracted.value, 1.85)
        XCTAssertLessThan(attracted.value, 2.0)
        XCTAssertGreaterThan(attracted.proximity, 0.2)
    }

    func testPressureSmoothingAndLifecycle() {
        var engine = PressureEnvelopeEngine(curve: .linear, smoothingTau: 0.01)
        let attack = engine.process(raw: 0.2, noteHeld: true, dt: 0.02)
        XCTAssertGreaterThan(attack.smoothed, 0)
        var held = attack
        for _ in 0..<8 {
            held = engine.process(raw: 0.9, noteHeld: true, dt: 0.02)
        }
        XCTAssertGreaterThan(held.smoothed, attack.smoothed)
        XCTAssertNotEqual(held.midiValue, 0)
        engine.reset()
        let released = engine.process(raw: 0, noteHeld: false, dt: 0.02)
        XCTAssertFalse(released.isActive)
    }

    func testHammerOnUpwardWithoutPick() {
        let result = LegatoGestureInterpreter().interpret(
            previous: Note(pitchClass: .e, octave: 4),
            current: Note(pitchClass: .g, octave: 4),
            overlap: true,
            intervalMs: 80,
            hasPickAttack: false,
            slideModifier: false,
            profile: .guitar,
            realism: .natural,
            sameString: true,
            preparedLowerNote: false
        )
        XCTAssertEqual(result?.technique, .hammerOn)
        XCTAssertLessThan(result?.velocity ?? 127, 110)
    }

    func testHammerOnRejectedWithoutSource() {
        let result = LegatoGestureInterpreter().interpret(
            previous: nil,
            current: Note(pitchClass: .g, octave: 4),
            overlap: false,
            intervalMs: 40,
            hasPickAttack: false,
            slideModifier: false,
            profile: .guitar,
            realism: .natural,
            sameString: true,
            preparedLowerNote: false
        )
        XCTAssertEqual(result?.transition, .normalRetrigger)
    }

    func testPullOffDownwardPrepared() {
        let result = LegatoGestureInterpreter().interpret(
            previous: Note(pitchClass: .g, octave: 4),
            current: Note(pitchClass: .e, octave: 4),
            overlap: true,
            intervalMs: 90,
            hasPickAttack: false,
            slideModifier: false,
            profile: .guitar,
            realism: .natural,
            sameString: true,
            preparedLowerNote: true
        )
        XCTAssertEqual(result?.technique, .pullOff)
    }

    func testKeysDoNotHammerOn() {
        let result = LegatoGestureInterpreter().interpret(
            previous: Note(pitchClass: .c, octave: 4),
            current: Note(pitchClass: .e, octave: 4),
            overlap: true,
            intervalMs: 50,
            hasPickAttack: false,
            slideModifier: false,
            profile: .keys,
            realism: .natural,
            sameString: true,
            preparedLowerNote: false
        )
        XCTAssertEqual(result?.technique, .normal)
    }

    func testPriorityPinchBeatsNormal() {
        let resolved = TechniquePriority.resolve(
            candidates: [.normal, .pinchHarmonic, .bend],
            profile: .guitar
        )
        XCTAssertEqual(resolved, .pinchHarmonic)
    }

    func testSlideInterpolationArrives() {
        var engine = SlideEngine(duration: 0.1)
        engine.begin(from: Note(pitchClass: .e, octave: 4), to: Note(pitchClass: .g, octave: 4))
        var state = engine.advance(dt: 0.03)
        XCTAssertTrue(state.isSliding)
        XCTAssertGreaterThan(state.pitchOffset, 0)
        state = engine.advance(dt: 0.2)
        XCTAssertTrue(state.arrived)
        XCTAssertEqual(state.pitchOffset, 3, accuracy: 0.01)
    }

    func testGuitarVsLeadGestureInterpretation() {
        var guitar = InstrumentPerformanceEngine(profile: .guitar)
        var lead = InstrumentPerformanceEngine(profile: .synthLead)
        let chord = Chord(root: .d, quality: .minor)
        let context = MusicalContext(key: .d, scale: Scale(root: .d, type: .naturalMinor), chord: chord)
        let held = [Note(pitchClass: .e, octave: 4)]

        let guitarState = ControllerState()
        guitarState.rightStick = ProcessedStickState(x: 0.8, y: 0.1, radius: 0.81)
        let guitarFrame = guitar.process(state: guitarState, context: context, heldNotes: held, timestamp: 1)
        XCTAssertTrue(guitarFrame.bend.isBending)
        XCTAssertTrue(guitarFrame.suppressStrum)

        let leadState = ControllerState()
        leadState.rightStick = ProcessedStickState(x: 0.8, y: 0.6, radius: 1.0)
        let leadFrame = lead.process(state: leadState, context: context, heldNotes: held, timestamp: 1)
        XCTAssertTrue(leadFrame.suppressStrum)
        XCTAssertGreaterThan(leadFrame.timbre, 0.5)
    }
}
