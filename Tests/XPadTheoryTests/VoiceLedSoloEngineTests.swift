import XCTest
@testable import XPadCore
@testable import XPadTheory

final class VoiceLedSoloEngineTests: XCTestCase {
    private let engine = VoiceLedSoloEngine()

    func testPolarQuadrantBoundariesAndInteriors() {
        let epsilon = 0.001

        XCTAssertEqual(engine.polarQuadrant(for: 0), .eastDiatonicScale)
        XCTAssertEqual(engine.polarQuadrant(for: .pi / 2), .northGuideTones)
        XCTAssertEqual(engine.polarQuadrant(for: -.pi / 2), .southBassAnchors)
        XCTAssertEqual(engine.polarQuadrant(for: .pi), .westEnclosures)
        XCTAssertEqual(engine.polarQuadrant(for: -.pi), .westEnclosures)

        XCTAssertEqual(engine.polarQuadrant(for: .pi * 0.25), .northGuideTones)
        XCTAssertEqual(engine.polarQuadrant(for: .pi * 0.75), .northGuideTones)
        XCTAssertEqual(engine.polarQuadrant(for: -.pi * 0.25), .southBassAnchors)
        XCTAssertEqual(engine.polarQuadrant(for: -.pi * 0.75), .southBassAnchors)
        XCTAssertEqual(engine.polarQuadrant(for: .pi * 0.25 - epsilon), .eastDiatonicScale)
        XCTAssertEqual(engine.polarQuadrant(for: .pi * 0.25 + epsilon), .northGuideTones)
        XCTAssertEqual(engine.polarQuadrant(for: .pi * 0.75 - epsilon), .northGuideTones)
        XCTAssertEqual(engine.polarQuadrant(for: .pi * 0.75 + epsilon), .westEnclosures)
        XCTAssertEqual(engine.polarQuadrant(for: -.pi * 0.25 - epsilon), .southBassAnchors)
        XCTAssertEqual(engine.polarQuadrant(for: -.pi * 0.25 + epsilon), .eastDiatonicScale)
        XCTAssertEqual(engine.polarQuadrant(for: -.pi * 0.75 - epsilon), .westEnclosures)
        XCTAssertEqual(engine.polarQuadrant(for: -.pi * 0.75 + epsilon), .southBassAnchors)
    }

    func testDeadzoneUsesPreviousTargetOrContextRootAndZeroVelocity() {
        let context = makeContext(registerOctave: 4)

        let withPrevious = engine.evaluateStick(
            stickX: 0,
            stickY: 0,
            radius: 0.08,
            angle: 0,
            velocity: 1,
            context: context,
            previousTarget: Note(pitchClass: .a, octave: 5)
        )
        XCTAssertEqual(withPrevious.targetNote, Note(pitchClass: .a, octave: 5))
        XCTAssertEqual(withPrevious.velocity, 0)

        let withoutPrevious = engine.evaluateStick(
            stickX: 0,
            stickY: 0,
            radius: 0,
            angle: 0,
            velocity: 1,
            context: context
        )
        XCTAssertEqual(withoutPrevious.targetNote, Note(pitchClass: .c, octave: 4))
        XCTAssertEqual(withoutPrevious.velocity, 0)
    }

    func testNorthSelectsFifthThirdAndSeventhAndScreamingBend() {
        let context = makeContext()

        let fifth = evaluate(radius: 0.40, angle: .pi / 2, context: context)
        XCTAssertEqual(fifth.targetNote.pitchClass, .g)
        XCTAssertTrue(fifth.roleLabel.contains("5th"))

        let third = evaluate(radius: 0.60, angle: .pi / 2, context: context)
        XCTAssertEqual(third.targetNote.pitchClass, .e)
        XCTAssertTrue(third.roleLabel.contains("3rd"))

        let seventh = evaluate(radius: 0.80, angle: .pi / 2, context: context)
        XCTAssertEqual(seventh.targetNote.pitchClass, .aSharp)
        XCTAssertTrue(seventh.isGuideTone)
        XCTAssertTrue(seventh.roleLabel.contains("7th"))

        let screaming = evaluate(radius: 0.94, angle: .pi / 2, context: context)
        XCTAssertEqual(screaming.targetNote.pitchClass, .aSharp)
        XCTAssertEqual(screaming.articulation, .screamingBend)
        XCTAssertEqual(screaming.velocity, 127)
        XCTAssertEqual(screaming.pitchBendSemitones, 2)
    }

    func testSouthUsesRootAndFifthInLowerRegister() {
        let context = makeContext(registerOctave: 3)

        let root = evaluate(radius: 0.50, angle: -.pi / 2, context: context)
        XCTAssertEqual(root.targetNote, Note(pitchClass: .c, octave: 2))
        XCTAssertTrue(root.roleLabel.contains("Root"))

        let fifth = evaluate(radius: 0.80, angle: -.pi / 2, context: context)
        XCTAssertEqual(fifth.targetNote, Note(pitchClass: .g, octave: 2))
        XCTAssertTrue(fifth.roleLabel.contains("5th"))
    }

    func testEastWalksScaleAndMarksNonChordTonesAsPassing() {
        let context = makeContext()

        let chordTone = evaluate(radius: 0.40, angle: 0, context: context)
        XCTAssertEqual(chordTone.targetNote.pitchClass, .e)
        XCTAssertTrue(chordTone.isChordTone)
        XCTAssertFalse(chordTone.isPassingTone)

        let passingTone = evaluate(radius: 0.50, angle: 0, context: context)
        XCTAssertEqual(passingTone.targetNote.pitchClass, .f)
        XCTAssertFalse(passingTone.isChordTone)
        XCTAssertTrue(passingTone.isPassingTone)
    }

    func testWestProvidesBlueNoteAndChromaticApproach() {
        let context = makeContext()

        let blue = evaluate(radius: 0.80, angle: .pi, context: context)
        XCTAssertEqual(blue.targetNote.pitchClass, .fSharp)
        XCTAssertTrue(blue.isBlueNote)
        XCTAssertTrue(blue.isPassingTone)
        XCTAssertEqual(blue.approachPath, [
            Note(pitchClass: .fSharp, octave: 4),
            Note(pitchClass: .e, octave: 4)
        ])

        let approach = evaluate(radius: 0.60, angle: .pi, context: context)
        XCTAssertEqual(approach.targetNote, Note(pitchClass: .e, octave: 4))
        XCTAssertEqual(approach.approachPath, [
            Note(pitchClass: .dSharp, octave: 4),
            Note(pitchClass: .e, octave: 4)
        ])
        XCTAssertEqual(approach.articulation, .graceNote)
    }

    func testPreviousTargetSelectsNearestVoicing() {
        let context = makeContext()
        let previous = Note(pitchClass: .c, octave: 5)
        let result = evaluate(
            radius: 0.60,
            angle: .pi / 2,
            context: context,
            previousTarget: previous
        )

        XCTAssertEqual(result.targetNote.pitchClass, .e)
        XCTAssertLessThanOrEqual(abs(Int(result.targetNote.midiNote) - Int(previous.midiNote)), 6)
    }

    func testChordTransitionUsesNearestWrappedGuideToneAndVoicing() {
        let oldChord = Chord(root: .d, quality: .minor7)
        let newChord = Chord(root: .g, quality: .dominant7)
        let previous = Note(pitchClass: .c, octave: 4)

        let iiV = engine.resolveChordTransition(
            from: previous,
            oldChord: oldChord,
            newChord: newChord,
            context: makeContext()
        )
        XCTAssertEqual(iiV.targetNote.pitchClass, .b)
        XCTAssertEqual(iiV.roleLabel, "3rd Guide Tone (B)")
        XCTAssertTrue(iiV.isGuideTone)
        XCTAssertLessThanOrEqual(abs(Int(iiV.targetNote.midiNote) - Int(previous.midiNote)), 6)

        let tritone = engine.resolveChordTransition(
            from: previous,
            oldChord: Chord(root: .c, quality: .major),
            newChord: Chord(root: .fSharp, quality: .dominant7),
            context: makeContext()
        )
        XCTAssertEqual(tritone.targetNote.pitchClass, .aSharp)
        XCTAssertEqual(tritone.roleLabel, "3rd Guide Tone (B♭)")
        XCTAssertTrue(tritone.isGuideTone)
    }

    func testVelocityIsClampedAcrossRadius() {
        let context = makeContext()
        let low = evaluate(radius: 0.09, angle: 0, context: context)
        let middle = evaluate(radius: 0.50, angle: 0, context: context)
        let high = evaluate(radius: 1.0, angle: 0, context: context)

        XCTAssertEqual(low.velocity, 56)
        XCTAssertEqual(middle.velocity, 88)
        XCTAssertEqual(high.velocity, 127)
        for result in [low, middle, high] {
            XCTAssertGreaterThanOrEqual(result.velocity, 45)
            XCTAssertLessThanOrEqual(result.velocity, 127)
        }
    }

    private func makeContext(registerOctave: Int = 4) -> MusicalContext {
        MusicalContext(
            key: .c,
            scale: .major,
            chord: Chord(root: .c, quality: .dominant7),
            registerOctave: registerOctave
        )
    }

    private func evaluate(
        radius: Double,
        angle: Double,
        context: MusicalContext,
        previousTarget: Note? = nil
    ) -> SoloTargetResolution {
        engine.evaluateStick(
            stickX: cos(angle) * radius,
            stickY: sin(angle) * radius,
            radius: radius,
            angle: angle,
            velocity: 1,
            context: context,
            previousTarget: previousTarget
        )
    }
}
