import XCTest
@testable import XPadCore
@testable import XPadTheory

final class PitchTargetExpressionTests: XCTestCase {
    private let engine = ContextualPitchExpressionEngine()

    func testChordThenScaleThenChromaticTargetRanking() {
        let context = PitchTargetContext(
            sourceNote: Note(pitchClass: .d, octave: 4),
            key: .d,
            scale: Scale(root: .d, type: .naturalMinor),
            chord: Chord(root: .d, quality: .minor),
            bendRangeSemitones: 3.0
        )

        let targets = engine.rankedTargets(in: context, direction: .ascending)
        XCTAssertEqual(targets.map(\.note.pitchClass), [.f, .e, .dSharp])
        XCTAssertTrue(targets[0].isChordTone)
        XCTAssertTrue(targets[1].isScaleTone)
        XCTAssertFalse(targets[2].isScaleTone)
    }

    func testCenterFullRangeAndAssistOffAreExact() {
        let context = PitchTargetContext(
            sourceNote: .middleC,
            scale: .cMajor,
            profile: .guitar,
            assistMode: .off
        )

        XCTAssertEqual(engine.evaluate(normalizedInput: 0.0, in: context), .centered)

        let full = engine.evaluate(normalizedInput: 1.0, in: context)
        XCTAssertEqual(full.rawOffsetSemitones, 2.0, accuracy: 0.000_001)
        XCTAssertEqual(full.assistedOffsetSemitones, 2.0, accuracy: 0.000_001)
        XCTAssertNil(full.target)
    }

    func testLightAssistAttractsWithoutHardSnap() {
        let context = PitchTargetContext(
            sourceNote: .middleC,
            key: .c,
            scale: .cMajor,
            chord: Chord(root: .c, quality: .major),
            profile: .guitar,
            assistMode: .light
        )

        let result = engine.evaluate(
            normalizedInput: 0.9,
            in: context,
            responseExponent: 1.0
        )

        XCTAssertEqual(result.rawOffsetSemitones, 1.8, accuracy: 0.000_001)
        XCTAssertEqual(result.target?.semitones, 2.0)
        XCTAssertGreaterThan(result.assistedOffsetSemitones, result.rawOffsetSemitones)
        XCTAssertLessThan(result.assistedOffsetSemitones, 2.0)
        XCTAssertGreaterThan(result.targetProximity, 0.0)
    }

    func testChromaticOverrideRemovesHarmonicRankingBias() {
        let harmonic = PitchTargetContext(
            sourceNote: .middleC,
            key: .c,
            scale: .cMajor,
            chord: Chord(root: .c, quality: .major),
            bendRangeSemitones: 2.0
        )
        let chromatic = PitchTargetContext(
            sourceNote: .middleC,
            key: .c,
            scale: .cMajor,
            chord: Chord(root: .c, quality: .major),
            bendRangeSemitones: 2.0,
            chromaticOverride: true
        )

        XCTAssertEqual(engine.rankedTargets(in: harmonic, direction: .ascending).first?.semitones, 2.0)
        XCTAssertEqual(engine.rankedTargets(in: chromatic, direction: .ascending).first?.semitones, 1.0)
    }

    func testDisabledDownwardBendReturnsCenteredState() {
        let context = PitchTargetContext(
            sourceNote: .middleC,
            scale: .cMajor,
            bendRangeSemitones: 2.0,
            allowsDownwardBend: false
        )

        XCTAssertEqual(engine.evaluate(normalizedInput: -1.0, in: context), .centered)
        XCTAssertTrue(engine.rankedTargets(in: context, direction: .descending).isEmpty)
    }

    func testTargetsNeverExceedFractionalOrZeroRange() {
        let fractional = PitchTargetContext(
            sourceNote: .middleC,
            scale: .cMajor,
            bendRangeSemitones: 1.5
        )
        let zero = PitchTargetContext(
            sourceNote: .middleC,
            scale: .cMajor,
            bendRangeSemitones: 0.0
        )

        XCTAssertTrue(
            engine.rankedTargets(in: fractional, direction: .ascending)
                .allSatisfy { abs($0.semitones) <= 1.5 }
        )
        XCTAssertTrue(engine.rankedTargets(in: zero, direction: .ascending).isEmpty)
    }
}
