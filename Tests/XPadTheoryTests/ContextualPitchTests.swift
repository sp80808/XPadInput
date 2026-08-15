import XCTest
@testable import XPadCore
@testable import XPadTheory

final class ContextualPitchTests: XCTestCase {
    func testBendTargetsInDMinorFromE() {
        let context = MusicalContext(
            key: .d,
            scale: Scale(root: .d, type: .naturalMinor),
            chord: Chord(root: .d, quality: .minor)
        )
        let note = Note(pitchClass: .e, octave: 4)
        let targets = ContextualPitchTargeter().bendTargets(
            from: note,
            rangeSemitones: 2,
            context: context,
            allowDownward: true
        )
        XCTAssertTrue(targets.contains(where: { $0.note.pitchClass == .f && abs($0.semitones - 1) < 0.01 }))
        XCTAssertTrue(targets.contains(where: { $0.note.pitchClass == .g && abs($0.semitones - 2) < 0.01 }))
        XCTAssertTrue(targets.contains(where: { $0.isChordTone || $0.isScaleTone }))
    }

    func testHammerOnPrefersChordTone() {
        let context = MusicalContext(
            key: .d,
            scale: Scale(root: .d, type: .naturalMinor),
            chord: Chord(root: .d, quality: .minor)
        )
        let root = Note(pitchClass: .d, octave: 4)
        let target = ContextualPitchTargeter().hammerOnTarget(from: root, context: context)
        XCTAssertEqual(target?.pitchClass, .f)
    }

    func testIntervalMemoryFollowsChordTone() {
        let targeter = ContextualPitchTargeter()
        let first = Chord(root: .c, quality: .major)
        let e = targeter.note(for: .third, chord: first, previous: nil, baseOctave: 4)
        XCTAssertEqual(e.pitchClass, .e)
        let next = Chord(root: .a, quality: .minor)
        let voiceLed = targeter.note(for: .third, chord: next, previous: e, baseOctave: 4)
        XCTAssertEqual(voiceLed.pitchClass, .c)
        XCTAssertLessThanOrEqual(abs(Int(voiceLed.midiNote) - Int(e.midiNote)), 4)
    }

    func testChordToneTargetingDoesNotClimbOctavesAcrossCycles() {
        let targeter = ContextualPitchTargeter()
        let chords = [
            Chord(root: .d, quality: .minor),
            Chord(root: .f, quality: .major),
            Chord(root: .g, quality: .minor),
            Chord(root: .c, quality: .major)
        ]
        var note: Note?

        for _ in 0..<24 {
            for chord in chords {
                note = targeter.note(for: .third, chord: chord, previous: note, baseOctave: 3)
                XCTAssertTrue((36...72).contains(note?.midiNote ?? 127))
            }
        }
    }

    func testChromaticModeStillOffersStylisticIntervals() {
        var context = MusicalContext(key: .c, scale: .cMajor, chromaticMode: true)
        context.chord = Chord(root: .c, quality: .major)
        let targets = ContextualPitchTargeter().bendTargets(
            from: .middleC,
            rangeSemitones: 2,
            context: context,
            allowDownward: false
        )
        XCTAssertTrue(targets.contains(where: { abs($0.semitones - 2) < 0.01 }))
    }
}
