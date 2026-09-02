import Foundation
import XCTest
@testable import XPadCore
@testable import XPadController

final class ArcadeFretEngineTests: XCTestCase {
    private let diatonic = Chord.diatonicChords(root: .c, scale: .major)

    func testSlotDegreeMapping() {
        XCTAssertEqual(ArcadeFretSlot.leftTrigger.diatonicDegreeIndex, 0)
        XCTAssertEqual(ArcadeFretSlot.leftShoulder.diatonicDegreeIndex, 3)
        XCTAssertEqual(ArcadeFretSlot.rightShoulder.diatonicDegreeIndex, 4)
        XCTAssertEqual(ArcadeFretSlot.rightTrigger.diatonicDegreeIndex, 5)
    }

    func testTriggerPressFiresInstantStrikeWithoutStrum() {
        var engine = ArcadeFretEngine()

        // Frame 1: trigger below threshold — nothing fires.
        let idle = engine.process(
            input: ArcadeFretInput(leftTriggerValue: 0.10),
            chords: diatonic,
            timestamp: 0
        )
        XCTAssertTrue(idle.strikes.isEmpty)

        // Frame 2: crossing the press threshold fires the degree-I chord immediately.
        let frame = engine.process(
            input: ArcadeFretInput(leftTriggerValue: 0.62),
            chords: diatonic,
            timestamp: 1
        )
        XCTAssertEqual(frame.strikes.count, 1)
        XCTAssertEqual(frame.strikes.first?.slot, .leftTrigger)
        XCTAssertEqual(frame.strikes.first?.chord.root, PitchClass.c)
        XCTAssertTrue(frame.isLaneActive)
        XCTAssertFalse(frame.releases.contains(.leftTrigger))
    }

    func testReleaseEmitsFallingEdgeAndLaneGoesInactive() {
        var engine = ArcadeFretEngine()
        _ = engine.process(input: ArcadeFretInput(rightShoulderPressed: true), chords: diatonic, timestamp: 0)
        let frame = engine.process(input: .neutral, chords: diatonic, timestamp: 1)

        XCTAssertEqual(frame.releases, [.rightShoulder])
        XCTAssertFalse(frame.isLaneActive)
    }

    func testBumperVelocityIsFixedAndTriggerVelocityScalesWithDepth() {
        var engine = ArcadeFretEngine()
        let soft = engine.process(input: ArcadeFretInput(leftTriggerValue: 0.35), chords: diatonic, timestamp: 0)
        let hard = engine.process(
            input: ArcadeFretInput(leftTriggerValue: 0.05, rightShoulderPressed: true),
            chords: diatonic,
            timestamp: 1
        )

        XCTAssertLessThan(soft.strikes[0].velocity, hard.strikes[0].velocity)
        XCTAssertEqual(hard.strikes.last?.velocity, ArcadeFretEngine.bumperVelocity)
    }

    func testFaceModifiersColourTheChordQuality() {
        var engine = ArcadeFretEngine()
        let frame = engine.process(
            input: ArcadeFretInput(leftTriggerValue: 0.8, southPressed: true),
            chords: diatonic,
            timestamp: 0
        )

        guard let strike = frame.strikes.first else {
            return XCTFail("Expected a strike")
        }
        // C major diatonic I coloured by ✕ becomes Cmaj7.
        XCTAssertEqual(strike.chord.quality, .major7)
        XCTAssertEqual(strike.appliedModifiers, [.seventh])
    }

    func testMinorDegreeReceivesMinorSeventhColouring() {
        var engine = ArcadeFretEngine()
        let frame = engine.process(
            input: ArcadeFretInput(leftTriggerValue: 0.8, southPressed: true),
            chords: Chord.diatonicChords(root: .a, scale: .minor),
            timestamp: 0
        )
        // A natural minor degree vi is F major → ✕ yields Fmaj7.
        XCTAssertEqual(frame.strikes.first?.chord.quality, .major7)
        XCTAssertEqual(frame.strikes.first?.chord.root, PitchClass.f)
    }

    func testModifierPriorityIsDeterministicWhenStacked() {
        let base = Chord(root: .g, quality: .major)
        let stacked = ArcadeFretModifier.priorityOrder.reduce(base) { chord, modifier in
            modifier.applied(to: chord)
        }
        // Seventh wins over ninth/sixth/sus on the priority ladder.
        XCTAssertEqual(stacked.quality, .major7)

        let susOnly = ArcadeFretModifier.sus.applied(to: base)
        XCTAssertEqual(susOnly.quality, .sus4)

        // Extensions applied to an already-extended chord are no-ops.
        XCTAssertEqual(ArcadeFretModifier.ninth.applied(to: stacked).quality, .major7)
    }

    func testHammerOnReplacementWhileLaneStaysHeld() {
        var engine = ArcadeFretEngine()
        _ = engine.process(input: ArcadeFretInput(leftTriggerValue: 0.7), chords: diatonic, timestamp: 0)

        // Second fret rises while the first stays held — new strike replaces the chord.
        let frame = engine.process(
            input: ArcadeFretInput(leftTriggerValue: 0.9, rightTriggerValue: 0.5),
            chords: diatonic,
            timestamp: 1
        )

        XCTAssertEqual(frame.strikes.count, 1)
        XCTAssertEqual(frame.strikes.first?.slot, .rightTrigger)
        XCTAssertTrue(frame.isLaneActive)
        XCTAssertEqual(frame.heldSlots, [.leftTrigger, .rightTrigger])
    }

    func testResetClearsEdgeHistory() {
        var engine = ArcadeFretEngine()
        _ = engine.process(input: ArcadeFretInput(leftTriggerValue: 0.8), chords: diatonic, timestamp: 0)
        engine.reset()

        let frame = engine.process(input: ArcadeFretInput(leftTriggerValue: 0.8), chords: diatonic, timestamp: 1)
        // Without reset this would be treated as still-held and emit no strike.
        XCTAssertEqual(frame.strikes.count, 1)
    }

    func testMissingDiatonicDegreesAreSkippedSafely() {
        var engine = ArcadeFretEngine()
        let frame = engine.process(
            input: ArcadeFretInput(leftTriggerValue: 0.8),
            chords: [],
            timestamp: 0
        )
        XCTAssertTrue(frame.strikes.isEmpty)
        XCTAssertTrue(frame.heldSlots.contains(.leftTrigger))
    }

    func testAllSlotsRoundTripThroughCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for slot in ArcadeFretSlot.allCases {
            let data = try encoder.encode([slot])
            XCTAssertEqual(try decoder.decode([ArcadeFretSlot].self, from: data), [slot])
        }
        for modifier in ArcadeFretModifier.allCases {
            let data = try encoder.encode([modifier])
            XCTAssertEqual(try decoder.decode([ArcadeFretModifier].self, from: data), [modifier])
        }
    }

    func testTriggerReleaseHysteresisIgnoresBandOscillation() {
        var engine = ArcadeFretEngine()
        _ = engine.process(input: ArcadeFretInput(leftTriggerValue: 0.62), chords: diatonic, timestamp: 0)

        // Jitter inside the 0.22...0.30 hysteresis band must not re-edge the latch.
        for (offset, depth) in [Float(0.28), 0.24, 0.28, 0.24, 0.29].enumerated() {
            let frame = engine.process(
                input: ArcadeFretInput(leftTriggerValue: depth),
                chords: diatonic,
                timestamp: TimeInterval(offset + 1)
            )
            XCTAssertTrue(frame.strikes.isEmpty, "depth \(depth) must not strike")
            XCTAssertTrue(frame.releases.isEmpty, "depth \(depth) must not release")
            XCTAssertTrue(frame.isLaneActive, "latch stays logically held inside the band")
        }

        let releaseFrame = engine.process(input: ArcadeFretInput(leftTriggerValue: 0.10), chords: diatonic, timestamp: 99)
        XCTAssertEqual(releaseFrame.releases, [.leftTrigger])
        XCTAssertFalse(releaseFrame.isLaneActive)
        XCTAssertTrue(releaseFrame.strikes.isEmpty)
    }

    func testReArmRequiresCrossingPressThresholdAgain() {
        var engine = ArcadeFretEngine()
        _ = engine.process(input: ArcadeFretInput(rightTriggerValue: 0.70), chords: diatonic, timestamp: 0)
        _ = engine.process(input: ArcadeFretInput(rightTriggerValue: 0.10), chords: diatonic, timestamp: 1)

        // Shallow travel after a release sits inside the deadband — no strike.
        let shallow = engine.process(input: ArcadeFretInput(rightTriggerValue: 0.25), chords: diatonic, timestamp: 2)
        XCTAssertTrue(shallow.strikes.isEmpty)
        XCTAssertTrue(shallow.releases.isEmpty)

        let rearmed = engine.process(input: ArcadeFretInput(rightTriggerValue: 0.45), chords: diatonic, timestamp: 3)
        XCTAssertEqual(rearmed.strikes.count, 1)
        XCTAssertEqual(rearmed.strikes.first?.slot, .rightTrigger)
    }

    func testShoulderEdgesStayUnaffectedByTriggerHysteresis() {
        var engine = ArcadeFretEngine()
        _ = engine.process(
            input: ArcadeFretInput(leftTriggerValue: 0.62, leftShoulderPressed: true),
            chords: diatonic,
            timestamp: 0
        )

        // Bumpers toggle per frame with plain bool edges while the trigger latches on.
        let bumperOff = engine.process(input: ArcadeFretInput(leftTriggerValue: 0.26), chords: diatonic, timestamp: 1)
        XCTAssertEqual(bumperOff.releases, [.leftShoulder])
        XCTAssertTrue(bumperOff.heldSlots.contains(.leftTrigger))

        let bumperOn = engine.process(
            input: ArcadeFretInput(leftTriggerValue: 0.26, leftShoulderPressed: true),
            chords: diatonic,
            timestamp: 2
        )
        XCTAssertEqual(bumperOn.strikes.count, 1)
        XCTAssertEqual(bumperOn.strikes.first?.slot, .leftShoulder)
        XCTAssertEqual(bumperOn.strikes.first?.velocity, ArcadeFretEngine.bumperVelocity)
    }
}
