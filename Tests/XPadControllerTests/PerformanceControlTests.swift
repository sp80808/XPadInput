import XCTest
@testable import XPadCore
@testable import XPadController

final class PerformanceControlTests: XCTestCase {
    private let cMajorVoice = ChordGateVoice(
        chord: Chord(root: .c, quality: .major),
        notes: [
            Note(pitchClass: .c, octave: 3),
            Note(pitchClass: .e, octave: 3),
            Note(pitchClass: .g, octave: 3)
        ]
    )

    private let fMajorVoice = ChordGateVoice(
        chord: Chord(root: .f, quality: .major),
        notes: [
            Note(pitchClass: .f, octave: 3),
            Note(pitchClass: .a, octave: 3),
            Note(pitchClass: .c, octave: 4)
        ]
    )

    func testMomentaryChordGateBeginsOnceAndEndsOnGestureRelease() {
        var gate = ChordGateEngine(
            configuration: ChordGateConfiguration(mode: .momentary)
        )

        XCTAssertEqual(
            gate.process(voice: cMajorVoice, isGestureActive: true, timestamp: 1.0),
            [.began(cMajorVoice)]
        )
        XCTAssertTrue(
            gate.process(voice: cMajorVoice, isGestureActive: true, timestamp: 1.1).isEmpty,
            "A held gesture must not retrigger its chord."
        )
        XCTAssertEqual(
            gate.process(voice: fMajorVoice, isGestureActive: false, timestamp: 1.2),
            [.ended(cMajorVoice)],
            "Release must target the originally voiced notes, not the newly selected chord."
        )
        XCTAssertNil(gate.activeVoice)
    }

    func testTimedChordGateReleasesAtDeadlineWithoutWaitingForGestureRelease() {
        var gate = ChordGateEngine(
            configuration: ChordGateConfiguration(mode: .timed, timedDuration: 0.5)
        )

        XCTAssertEqual(
            gate.process(voice: cMajorVoice, isGestureActive: true, timestamp: 2.0),
            [.began(cMajorVoice)]
        )
        XCTAssertTrue(gate.advance(timestamp: 2.499).isEmpty)
        XCTAssertEqual(gate.advance(timestamp: 2.5), [.ended(cMajorVoice)])
        XCTAssertTrue(gate.advance(timestamp: 3.0).isEmpty)
    }

    func testLatchTogglesMatchingChordAndReplacesDifferentChord() {
        var gate = ChordGateEngine(
            configuration: ChordGateConfiguration(mode: .latch)
        )

        XCTAssertEqual(
            gate.process(voice: cMajorVoice, isGestureActive: true, timestamp: 1.0),
            [.began(cMajorVoice)]
        )
        _ = gate.process(voice: cMajorVoice, isGestureActive: false, timestamp: 1.1)
        XCTAssertEqual(
            gate.process(voice: fMajorVoice, isGestureActive: true, timestamp: 1.2),
            [.ended(cMajorVoice), .began(fMajorVoice)]
        )
        _ = gate.process(voice: fMajorVoice, isGestureActive: false, timestamp: 1.3)
        XCTAssertEqual(
            gate.process(voice: fMajorVoice, isGestureActive: true, timestamp: 1.4),
            [.ended(fMajorVoice)]
        )
    }

    func testChangingChordGateConfigurationSafelyReleasesOwnedNotes() {
        var gate = ChordGateEngine(
            configuration: ChordGateConfiguration(mode: .latch)
        )
        _ = gate.process(voice: cMajorVoice, isGestureActive: true, timestamp: 1.0)

        let released = gate.updateConfiguration(
            ChordGateConfiguration(mode: .momentary)
        )
        XCTAssertEqual(released, [.ended(cMajorVoice)])
        XCTAssertNil(gate.activeVoice)
    }

    func testVelocityStabilizerClampsSmoothsAndPreservesZero() {
        var stabilizer = VelocityStabilizer(
            configuration: VelocityStabilizerConfiguration(
                floor: 40,
                ceiling: 110,
                smoothing: 0.5,
                maximumStep: 12
            )
        )

        XCTAssertEqual(stabilizer.process(rawVelocity: 10), 40)
        XCTAssertEqual(stabilizer.process(rawVelocity: 110), 52)
        XCTAssertEqual(stabilizer.process(rawVelocity: 110), 64)
        XCTAssertEqual(stabilizer.process(rawVelocity: 0), 0)
        XCTAssertEqual(stabilizer.lastVelocity, 64, "A note-off velocity must not alter attack history.")

        stabilizer.reset()
        XCTAssertEqual(stabilizer.process(normalizedIntensity: 1), 110)
        XCTAssertEqual(stabilizer.process(normalizedIntensity: 0), 0)
    }

    func testDuoSchemeUsesIndependentStickAndDrumLanesWithoutRetrigger() {
        var engine = DuoControlEngine(mode: .drumsAndInstrument)
        let state = ControllerState()
        state.leftStick = ProcessedStickState(x: 0.6, y: 0.8, radius: 1.0)
        state.rightStick = ProcessedStickState(x: 0, y: -0.75, radius: 0.75, movementVelocity: 4)

        let idle = engine.process(state: state)
        XCTAssertTrue(idle.drumHits.isEmpty)
        XCTAssertEqual(idle.chordSelection.magnitude, 1, accuracy: 0.0001)
        XCTAssertEqual(idle.instrumentGesture.y, -0.75, accuracy: 0.0001)
        XCTAssertTrue(idle.suppressesInstrumentFaceButtons)

        state.buttonA = true
        state.buttonY = true
        let attack = engine.process(state: state, drumVelocity: 100)
        XCTAssertEqual(attack.drumHits.map(\.voice), [.kick, .closedHat])
        XCTAssertEqual(attack.drumHits.map { $0.voice.generalMIDINote }, [36, 42])
        XCTAssertEqual(Set(attack.drumHits.map(\.velocity)), Set([UInt8(100)]))
        XCTAssertEqual(attack.chordSelection.x, 0.6, accuracy: 0.0001)
        XCTAssertEqual(attack.instrumentGesture.y, -0.75, accuracy: 0.0001)

        let held = engine.process(state: state, drumVelocity: 127)
        XCTAssertTrue(held.drumHits.isEmpty, "Held face buttons must not machine-gun drum notes.")

        state.buttonA = false
        state.buttonY = false
        _ = engine.process(state: state)
        state.buttonX = true
        state.buttonB = true
        let secondAttack = engine.process(state: state, drumVelocity: 100)
        XCTAssertEqual(secondAttack.drumHits.map(\.voice), [.snare, .openHat])
    }

    func testInstrumentOnlyModeNeverClaimsFaceButtons() {
        var engine = DuoControlEngine(mode: .instrumentOnly)
        let state = ControllerState()
        state.buttonA = true
        state.buttonB = true

        let frame = engine.process(state: state)
        XCTAssertTrue(frame.drumHits.isEmpty)
        XCTAssertFalse(frame.suppressesInstrumentFaceButtons)
    }
}
