import XCTest
@testable import XPadCore

final class XPadCoreTests: XCTestCase {

    // MARK: - PitchClass Tests
    func testPitchClassRawValues() {
        XCTAssertEqual(PitchClass.allCases.count, 12)
        XCTAssertEqual(PitchClass.c.rawValue, 0)
        XCTAssertEqual(PitchClass.cSharp.rawValue, 1)
        XCTAssertEqual(PitchClass.d.rawValue, 2)
        XCTAssertEqual(PitchClass.dSharp.rawValue, 3)
        XCTAssertEqual(PitchClass.e.rawValue, 4)
        XCTAssertEqual(PitchClass.f.rawValue, 5)
        XCTAssertEqual(PitchClass.fSharp.rawValue, 6)
        XCTAssertEqual(PitchClass.g.rawValue, 7)
        XCTAssertEqual(PitchClass.gSharp.rawValue, 8)
        XCTAssertEqual(PitchClass.a.rawValue, 9)
        XCTAssertEqual(PitchClass.aSharp.rawValue, 10)
        XCTAssertEqual(PitchClass.b.rawValue, 11)
    }

    func testPitchClassNaming() {
        XCTAssertEqual(PitchClass.c.sharpName, "C")
        XCTAssertEqual(PitchClass.c.flatName, "C")
        XCTAssertEqual(PitchClass.cSharp.sharpName, "C♯")
        XCTAssertEqual(PitchClass.cSharp.flatName, "D♭")
        XCTAssertEqual(PitchClass.cSharp.standardName, "D♭")
        XCTAssertEqual(PitchClass.fSharp.sharpName, "F♯")
        XCTAssertEqual(PitchClass.fSharp.flatName, "G♭")
        XCTAssertEqual(PitchClass.aSharp.standardName, "B♭")
        XCTAssertEqual(PitchClass.e.standardName, "E")
    }

    func testPitchClassTransposition() {
        XCTAssertEqual(PitchClass.c.transposed(by: 0), .c)
        XCTAssertEqual(PitchClass.c.transposed(by: 12), .c)
        XCTAssertEqual(PitchClass.c.transposed(by: 24), .c)
        XCTAssertEqual(PitchClass.c.transposed(by: -12), .c)
        XCTAssertEqual(PitchClass.c.transposed(by: 4), .e)
        XCTAssertEqual(PitchClass.c.transposed(by: 7), .g)
        XCTAssertEqual(PitchClass.c.transposed(by: -1), .b)
        XCTAssertEqual(PitchClass.c.transposed(by: -13), .b)
        XCTAssertEqual(PitchClass.b.transposed(by: 1), .c)
        XCTAssertEqual(PitchClass.b.transposed(by: 2), .cSharp)
    }

    func testPitchClassSemitonesDistance() {
        XCTAssertEqual(PitchClass.c.semitones(to: .c), 0)
        XCTAssertEqual(PitchClass.c.semitones(to: .g), 7)
        XCTAssertEqual(PitchClass.g.semitones(to: .c), 5)
        XCTAssertEqual(PitchClass.b.semitones(to: .c), 1)
        XCTAssertEqual(PitchClass.c.semitones(to: .b), 11)
    }

    func testCircleOfFifthsIndices() {
        let expectedCoF: [PitchClass: Int] = [
            .c: 0, .g: 1, .d: 2, .a: 3, .e: 4, .b: 5,
            .fSharp: 6, .cSharp: 7, .gSharp: 8, .dSharp: 9, .aSharp: 10, .f: 11
        ]
        for (pc, index) in expectedCoF {
            XCTAssertEqual(pc.circleOfFifthsIndex, index)
        }
    }

    func testPitchClassComparable() {
        XCTAssertTrue(PitchClass.c < PitchClass.d)
        XCTAssertTrue(PitchClass.d < PitchClass.e)
        XCTAssertTrue(PitchClass.aSharp < PitchClass.b)
    }

    // MARK: - Interval Tests
    func testIntervalConstants() {
        let expected: [(Interval, Int, String)] = [
            (.unison, 0, "P1"),
            (.minorSecond, 1, "m2"),
            (.majorSecond, 2, "M2"),
            (.minorThird, 3, "m3"),
            (.majorThird, 4, "M3"),
            (.perfectFourth, 5, "P4"),
            (.tritone, 6, "TT"),
            (.perfectFifth, 7, "P5"),
            (.minorSixth, 8, "m6"),
            (.majorSixth, 9, "M6"),
            (.minorSeventh, 10, "m7"),
            (.majorSeventh, 11, "M7")
        ]

        XCTAssertEqual(Interval.allCases.count, expected.count)
        for (interval, semitones, shortName) in expected {
            XCTAssertEqual(interval.semitones, semitones)
            XCTAssertEqual(interval.shortName, shortName)
        }

        // Interval models pitch-class distance, so compound/negative values wrap mod 12.
        XCTAssertEqual(Interval(semitones: 12), .unison)
        XCTAssertEqual(Interval(semitones: 15), .minorThird)
        XCTAssertEqual(Interval(semitones: -1), .majorSeventh)
    }

    // MARK: - Note Tests
    func testNoteInitialization() {
        let n60 = Note.fromMIDI(60)
        XCTAssertEqual(n60.pitchClass, .c)
        XCTAssertEqual(n60.octave, 4)
        XCTAssertEqual(n60.name, "C4")

        let n69 = Note(pitchClass: .a, octave: 4)
        XCTAssertEqual(n69.midiNumber, 69)
        XCTAssertEqual(n69.name, "A4")

        let maxClamped = Note(pitchClass: .c, octave: 20)
        XCTAssertEqual(maxClamped.midiNumber, 127)

        let minClamped = Note(pitchClass: .c, octave: -5)
        XCTAssertEqual(minClamped.midiNumber, 0)
    }

    func testNoteFrequency() {
        let a4 = Note.a4
        XCTAssertEqual(a4.frequency, 440.0, accuracy: 0.001)

        let a5 = Note.fromMIDI(81)
        XCTAssertEqual(a5.frequency, 880.0, accuracy: 0.001)

        let a3 = Note.fromMIDI(57)
        XCTAssertEqual(a3.frequency, 220.0, accuracy: 0.001)

        let c4 = Note.middleC
        XCTAssertEqual(c4.frequency, 261.625, accuracy: 0.01)
    }

    func testNoteTransposition() {
        let c4 = Note.middleC
        let g4 = c4.transposed(by: 7)
        XCTAssertEqual(g4.midiNumber, 67)
        XCTAssertEqual(g4.pitchClass, .g)
        XCTAssertTrue(c4 < g4)

        let maxNote = Note.fromMIDI(127).transposed(by: 5)
        XCTAssertEqual(maxNote.midiNumber, 127)
    }

    // MARK: - Scale & Mode Tests
    func testAllScaleTypes() {
        for type in ScaleType.allCases {
            let scale = Scale(root: .c, type: type)
            XCTAssertFalse(scale.pitchClasses.isEmpty)
            XCTAssertEqual(scale.pitchClasses.first, .c)
            XCTAssertTrue(scale.contains(PitchClass.c))
            XCTAssertTrue(scale.contains(Note.middleC))
            XCTAssertEqual(scale.noteCount, type.intervals.count)
        }
    }

    func testDiatonicScales() {
        let cMajor = Scale.cMajor
        let cMajorPcs: [PitchClass] = [.c, .d, .e, .f, .g, .a, .b]
        XCTAssertEqual(cMajor.pitchClasses, cMajorPcs)
        XCTAssertEqual(cMajor.name, "C Major (Ionian)")
        XCTAssertEqual(cMajor.degree(of: .g), 5)
        XCTAssertNil(cMajor.degree(of: .cSharp))

        let aMinor = Scale.aMinor
        let aMinorPcs: [PitchClass] = [.a, .b, .c, .d, .e, .f, .g]
        XCTAssertEqual(aMinor.pitchClasses, aMinorPcs)
        XCTAssertEqual(aMinor.name, "A Natural Minor (Aeolian)")
    }

    func testScaleNotesStayOrderedAndInRange() {
        let notes = Scale.cMajor.notes(fromOctave: 3, toOctave: 4)
        XCTAssertFalse(notes.isEmpty)
        XCTAssertEqual(notes, notes.sorted())
        XCTAssertTrue(notes.allSatisfy { $0.midiNumber <= 127 })
        XCTAssertTrue(notes.allSatisfy { Scale.cMajor.contains($0) })
    }

    // MARK: - Chord & Voicing Tests
    func testChordQualitiesAndSymbols() {
        XCTAssertEqual(Chord(root: .c, quality: .major).symbol, "C")
        XCTAssertEqual(Chord(root: .c, quality: .minor).symbol, "Cm")
        XCTAssertEqual(Chord(root: .c, quality: .major7).symbol, "Cmaj7")
        XCTAssertEqual(Chord(root: .c, quality: .dominant7).symbol, "C7")
        XCTAssertEqual(Chord(root: .c, quality: .major9).symbol, "Cmaj9")
        XCTAssertEqual(Chord(root: .c, quality: .dominant13).symbol, "C13")
    }

    func testChordInversions() {
        let cMaj = Chord(root: .c, quality: .major, inversion: 0)
        let rootNotes = cMaj.voicedNotes(baseOctave: 3)
        XCTAssertEqual(rootNotes.map { $0.midiNumber }, [48, 52, 55])

        var firstInv = cMaj
        firstInv.inversion = 1
        let firstInvNotes = firstInv.voicedNotes(baseOctave: 3)
        XCTAssertEqual(firstInvNotes.map { $0.midiNumber }, [52, 55, 60])

        var secondInv = cMaj
        secondInv.inversion = 2
        let secondInvNotes = secondInv.voicedNotes(baseOctave: 3)
        XCTAssertEqual(secondInvNotes.map { $0.midiNumber }, [55, 60, 64])
    }

    func testExtendedChordVoicingsPreserveCompoundIntervals() {
        let cMaj7 = Chord(root: .c, quality: .major7).voicedNotes(baseOctave: 3)
        XCTAssertEqual(cMaj7.count, 4)
        XCTAssertEqual(cMaj7.map { $0.midiNumber }, [48, 52, 55, 59])

        let cAdd9 = Chord(root: .c, quality: .add9).voicedNotes(baseOctave: 3)
        XCTAssertEqual(cAdd9.map { $0.midiNumber }, [48, 52, 55, 62])

        let c13 = Chord(root: .c, quality: .dominant13).voicedNotes(baseOctave: 3)
        XCTAssertEqual(c13.count, 6)
        XCTAssertEqual(c13.last?.midiNumber, 69)
    }

    func testVoiceLeadingKeepsStablePlayableRegister() {
        let progression = [
            Chord(root: .d, quality: .minor),
            Chord(root: .c, quality: .major),
            Chord(root: .e, quality: .diminished),
            Chord(root: .f, quality: .major),
            Chord(root: .a, quality: .minor),
            Chord(root: .g, quality: .minor)
        ]
        var voicing = ChordVoicing.strummed(chord: progression[0], strings: 6, baseOctave: 3)

        for _ in 0..<16 {
            for chord in progression {
                voicing = ChordVoicing.voiceLed(
                    chord: chord,
                    from: voicing,
                    baseOctave: 3,
                    voiceCount: 6
                )
                XCTAssertEqual(voicing.notes.count, 6)
                XCTAssertTrue(voicing.notes.allSatisfy { (36...84).contains($0.midiNote) })
            }
        }

        XCTAssertLessThanOrEqual(voicing.notes.last?.midiNote ?? 127, 84)
        XCTAssertGreaterThanOrEqual(voicing.notes.first?.midiNote ?? 0, 36)
    }

    // MARK: - PerformanceEvent & Transport Tests
    func testPerformanceEventCodable() throws {
        let events: [PerformanceEvent] = [
            .noteOn(channel: 1, note: 60, velocity: 100),
            .noteOff(channel: 1, note: 60),
            .pitchBend(channel: 1, value: 4096),
            .polyPressure(channel: 1, note: 60, pressure: 80),
            .channelPressure(channel: 1, pressure: 90),
            .controlChange(channel: 1, controller: 74, value: 64),
            .timbreCC74(channel: 1, value: 100),
            .allNotesOff(channel: 1)
        ]

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for event in events {
            let data = try encoder.encode(event)
            let decoded = try decoder.decode(PerformanceEvent.self, from: data)
            XCTAssertNotNil(decoded)
        }
    }

    func testTransportStateArithmetic() {
        var transport = TransportState(bpm: 120.0, timeSignatureNumerator: 4, timeSignatureDenominator: 4)
        XCTAssertEqual(transport.currentBar, 1)
        XCTAssertEqual(transport.currentBeat, 1.0, accuracy: 0.001)

        transport.currentTick = 960
        XCTAssertEqual(transport.currentBar, 1)
        XCTAssertEqual(transport.currentBeat, 2.0, accuracy: 0.001)

        transport.currentTick = 3840
        XCTAssertEqual(transport.currentBar, 2)
        XCTAssertEqual(transport.currentBeat, 1.0, accuracy: 0.001)

        transport.currentTick = 9600
        XCTAssertEqual(transport.currentBar, 3)
        XCTAssertEqual(transport.currentBeat, 3.0, accuracy: 0.001)
    }
}
