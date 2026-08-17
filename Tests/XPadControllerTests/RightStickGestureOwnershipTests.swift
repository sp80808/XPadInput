import XCTest
@testable import XPadCore
@testable import XPadTheory
@testable import XPadController

final class RightStickGestureOwnershipTests: XCTestCase {
    func testDiagonalAttackOwnsStrumInsteadOfBend() {
        var ownership = RightStickGestureOwnership()
        let owned = ownership.evaluate(x: 0.40, y: 0.82, notesHeld: false)
        XCTAssertEqual(owned, .strum)
        XCTAssertFalse(ownership.suppressesStrum)
        XCTAssertFalse(ownership.isBending)

        ownership.evaluate(x: 0.72, y: 0.80, notesHeld: true)
        XCTAssertEqual(ownership.owned, .strum, "Diagonal wobble must not steal a committed strum.")
        XCTAssertFalse(ownership.isBending)
    }

    func testStrumThenSustainThenBend() {
        var ownership = RightStickGestureOwnership()
        ownership.evaluate(x: 0.05, y: 0.85, notesHeld: false)
        XCTAssertEqual(ownership.owned, .strum)

        ownership.evaluate(x: 0.04, y: 0.08, notesHeld: true)
        XCTAssertEqual(ownership.owned, .sustain)

        ownership.evaluate(x: 0.80, y: 0.10, notesHeld: true)
        XCTAssertEqual(ownership.owned, .bend)
        XCTAssertTrue(ownership.suppressesStrum)
        XCTAssertTrue(ownership.isBending)
    }

    func testBendIgnoresNoisyCentreUntilExitThenReentryNeedsThreshold() {
        var ownership = RightStickGestureOwnership()
        ownership.evaluate(x: 0.05, y: 0.02, notesHeld: true)
        ownership.evaluate(x: 0.80, y: 0.08, notesHeld: true)
        XCTAssertEqual(ownership.owned, .bend)

        ownership.evaluate(x: 0.70, y: 0.45, notesHeld: true)
        XCTAssertEqual(ownership.owned, .bend)

        ownership.evaluate(x: 0.06, y: 0.04, notesHeld: true)
        XCTAssertEqual(ownership.owned, .sustain)

        ownership.evaluate(x: 0.14, y: 0.04, notesHeld: true)
        XCTAssertEqual(ownership.owned, .sustain, "Re-entry must use the enter threshold, not the exit threshold.")
    }

    func testKeysNeverInheritGuitarBend() {
        var ownership = RightStickGestureOwnership(policy: .policy(for: .keys))
        ownership.evaluate(x: 0.85, y: 0.10, notesHeld: true)
        XCTAssertEqual(ownership.owned, .idle)
        XCTAssertTrue(ownership.suppressesStrum)
        XCTAssertFalse(ownership.isBending)
    }

    func testStringsBowIsNotInterruptedByGuitarBendHeuristic() {
        var ownership = RightStickGestureOwnership(policy: .policy(for: .strings))
        ownership.evaluate(x: 0.20, y: 0.80, notesHeld: true)
        XCTAssertEqual(ownership.owned, .bow)
        XCTAssertTrue(ownership.suppressesStrum)

        ownership.evaluate(x: 0.90, y: 0.78, notesHeld: true)
        XCTAssertEqual(ownership.owned, .bow, "Bow ownership must not yield to a guitar bend heuristic.")
    }

    func testLeadIndependentAxesSuppressStrum() {
        var ownership = RightStickGestureOwnership(policy: .policy(for: .synthLead))
        ownership.evaluate(x: 0.80, y: 0.60, notesHeld: true)
        XCTAssertEqual(ownership.owned, .bend)
        XCTAssertTrue(ownership.suppressesStrum)
    }

    func testEngineDrivesSuppressStrumFromOwnership() {
        var guitar = InstrumentPerformanceEngine(profile: .guitar)
        let context = MusicalContext(
            key: .d,
            scale: Scale(root: .d, type: .naturalMinor),
            chord: Chord(root: .d, quality: .minor)
        )
        let held = [Note(pitchClass: .e, octave: 4)]

        let strumState = ControllerState()
        strumState.rightStick = ProcessedStickState(x: 0.35, y: 0.85, radius: 0.92)
        let strumFrame = guitar.process(state: strumState, context: context, heldNotes: held, timestamp: 1)
        XCTAssertEqual(strumFrame.ownedGesture, .strum)
        XCTAssertFalse(strumFrame.suppressStrum)
        XCTAssertFalse(strumFrame.bend.isBending)

        let release = ControllerState()
        release.rightStick = ProcessedStickState(x: 0.02, y: 0.05, radius: 0.05)
        _ = guitar.process(state: release, context: context, heldNotes: held, timestamp: 1.02)

        let bendState = ControllerState()
        bendState.rightStick = ProcessedStickState(x: 0.80, y: 0.10, radius: 0.81)
        let bendFrame = guitar.process(state: bendState, context: context, heldNotes: held, timestamp: 1.04)
        XCTAssertEqual(bendFrame.ownedGesture, .bend)
        XCTAssertTrue(bendFrame.suppressStrum)
        XCTAssertTrue(bendFrame.bend.isBending)

        var keys = InstrumentPerformanceEngine(profile: .keys)
        let keysFrame = keys.process(state: bendState, context: context, heldNotes: held, timestamp: 1)
        XCTAssertEqual(keysFrame.ownedGesture, .idle)
        XCTAssertFalse(keysFrame.bend.isBending)
        XCTAssertTrue(keysFrame.suppressStrum)
    }
}
