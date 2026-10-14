import XCTest
@testable import XPadCore
@testable import XPadTheory
@testable import XPadSequencer

@MainActor
final class BasslineGeneratorTests: XCTestCase {

    private func progression() -> Progression {
        var blocks: [ChordBlock] = [
            ChordBlock(chord: Chord(root: .c, quality: .major), durationBeats: 4, romanNumeral: "I"),
            ChordBlock(chord: Chord(root: .a, quality: .minor), durationBeats: 4, romanNumeral: "vi"),
            ChordBlock(chord: Chord(root: .f, quality: .major), durationBeats: 4, romanNumeral: "IV"),
            ChordBlock(chord: Chord(root: .g, quality: .dominant7), durationBeats: 4, romanNumeral: "V7")
        ]
        blocks.append(contentsOf: blocks)
        return Progression(name: "Pop Loop", root: .c, scale: Scale(root: .c, type: .major), blocks: blocks)
    }

    func testNoteForPitchClassMatchesMIDIConvention() {
        XCTAssertEqual(BasslineGenerator.note(for: .c, octave: 4), 60, "middle C is 60")
        XCTAssertEqual(BasslineGenerator.note(for: .a, octave: 4), 69)
        XCTAssertEqual(BasslineGenerator.note(for: .c, octave: 2), 36)
        XCTAssertEqual(BasslineGenerator.note(for: .c, octave: 8), 96, "the octave itself clamps")
        XCTAssertEqual(BasslineGenerator.note(for: .b, octave: 7), 107)
    }

    func testEveryFeelProducesPlayableNotes() {
        for feel in BasslineGenerator.Feel.allCases {
            let events = BasslineGenerator.generate(progression: progression(), feel: feel, seed: 3)
            XCTAssertFalse(events.isEmpty, feel.rawValue)
            for event in events {
                XCTAssertLessThanOrEqual(event.note, 127)
                XCTAssertGreaterThan(event.velocity, 0)
                XCTAssertLessThanOrEqual(event.velocity, 127)
                XCTAssertGreaterThan(event.durationTicks, 0)
            }
            // Sorted, and nothing starts before the progression does.
            XCTAssertEqual(events, events.sorted { $0.startTick < $1.startTick }, feel.rawValue)
            XCTAssertTrue(events.allSatisfy { $0.startTick < SequencerGrid.ticksPerBar * 8 }, feel.rawValue)
        }
    }

    func testBassNotesStayInBassRange() {
        for feel in BasslineGenerator.Feel.allCases {
            let events = BasslineGenerator.generate(progression: progression(), feel: feel, octave: 2, seed: 9)
            for event in events {
                XCTAssertGreaterThanOrEqual(event.note, 36, feel.rawValue)
                XCTAssertLessThanOrEqual(event.note, 59, "\(feel.rawValue) should stay below middle C")
            }
        }
    }

    func testDownbeatsPlayChordTones() {
        let progression = progression()
        for feel in BasslineGenerator.Feel.allCases {
            let events = BasslineGenerator.generate(progression: progression, feel: feel, seed: 1)
            for (index, block) in progression.blocks.enumerated() {
                let blockStartTick = UInt64(index) * SequencerGrid.ticksPerBar
                let downbeat = events.first { $0.startTick == blockStartTick }
                XCTAssertNotNil(downbeat, "\(feel.rawValue) missed the downbeat of block \(index)")
                guard let downbeat else { continue }
                let root = BasslineGenerator.note(for: block.chord.root, octave: 2)
                let chordTones = block.chord.quality.intervals.map { UInt8(Int(root) + $0) }
                XCTAssertTrue(
                    chordTones.contains(downbeat.note),
                    "\(feel.rawValue) played \(downbeat.note) on a downbeat instead of a chord tone"
                )
            }
        }
    }

    func testWalkingLineApproachesTheNextChord() {
        let progression = progression()
        let events = BasslineGenerator.generate(progression: progression, feel: .walking, seed: 5)
        let thirdBeat = UInt64(Int(SequencerGrid.ticksPerBar) - Int(SequencerGrid.ticksPerBeat))
        // The last beat of the first bar should lead into A minor by semitone.
        let approach = events.filter { $0.startTick == thirdBeat }
        XCTAssertEqual(approach.count, 1)
        XCTAssertEqual(approach.first?.note, BasslineGenerator.note(for: .a, octave: 2) - 1)
    }

    func testSyncopatedFeelAnticipatesTheChordChange() {
        let events = BasslineGenerator.generate(progression: progression(), feel: .syncopated, seed: 2)
        let lastEighth = UInt64(Int(SequencerGrid.ticksPerBar) - Int(SequencerGrid.ticksPerBeat) / 2)
        let anticipation = events.filter { $0.startTick == lastEighth }
        XCTAssertEqual(anticipation.first?.note, BasslineGenerator.note(for: .a, octave: 2))
    }

    func testOctavePulseAlternatesRootAndOctave() {
        let events = BasslineGenerator.generate(progression: progression(), feel: .octavePulse, seed: 4)
        let firstBar = events.filter { $0.startTick < SequencerGrid.ticksPerBar }
        XCTAssertEqual(firstBar.count, 8, "eighth notes across a bar")
        let root = BasslineGenerator.note(for: .c, octave: 2)
        XCTAssertEqual(firstBar.map(\.note), [root, root + 12, root, root + 12, root, root + 12, root, root + 12])
    }

    func testDroneHoldsThroughShortBlocks() {
        let progression = progression()
        let events = BasslineGenerator.generate(progression: progression, feel: .drone, seed: 6)
        for (index, block) in progression.blocks.enumerated() {
            let start = UInt64(index) * SequencerGrid.ticksPerBar
            let hit = events.first { $0.startTick == start }
            XCTAssertEqual(hit?.note, BasslineGenerator.note(for: block.chord.root, octave: 2))
            XCTAssertGreaterThan(hit?.durationTicks ?? 0, SequencerGrid.ticksPerBar / 2)
        }
    }

    func testGenerationIsReproducible() {
        let first = BasslineGenerator.generate(progression: progression(), feel: .rootNotes, seed: 42)
        let second = BasslineGenerator.generate(progression: progression(), feel: .rootNotes, seed: 42)
        XCTAssertEqual(first, second)
    }

    func testEmptyProgressionIsSilent() {
        let empty = Progression(name: "Empty", root: .c, scale: .major)
        XCTAssertTrue(BasslineGenerator.generate(progression: empty, feel: .walking).isEmpty)
    }

    func testFeelFollowsStyle() {
        XCTAssertEqual(BasslineGenerator.feel(forStyleName: "Jazz Standard"), .walking)
        XCTAssertEqual(BasslineGenerator.feel(forStyleName: "Neo-Soul"), .syncopated)
        XCTAssertEqual(BasslineGenerator.feel(forStyleName: "Gospel Soul"), .syncopated)
        XCTAssertEqual(BasslineGenerator.feel(forStyleName: "Deep House"), .octavePulse)
        XCTAssertEqual(BasslineGenerator.feel(forStyleName: "Synthwave"), .octavePulse)
        XCTAssertEqual(BasslineGenerator.feel(forStyleName: "Cinematic Trailer"), .drone)
        XCTAssertEqual(BasslineGenerator.feel(forStyleName: "Pop / Royal Road"), .rootNotes)
        XCTAssertEqual(BasslineGenerator.Feel.allCases.count, 5)
    }

    func testClipWrapsTheLine() {
        let clip = BasslineGenerator.clip(progression: progression(), feel: .walking, seed: 1)
        XCTAssertEqual(clip.startTick, 0)
        XCTAssertEqual(clip.durationTicks, SequencerGrid.ticksPerBar * 8)
        XCTAssertEqual(clip.notes.count, BasslineGenerator.generate(progression: progression(), feel: .walking, seed: 1).count)
        XCTAssertTrue(clip.name.hasPrefix("Bass"))
    }
}
