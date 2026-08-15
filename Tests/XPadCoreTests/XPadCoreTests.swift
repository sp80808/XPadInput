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
        XCTAssertEqual(Interval.unison.semitones, 0)
        XCTAssertEqual(Interval.unison.shortName, "P1")
        XCTAssertEqual(Interval.minorSecond.semitones, 1)
        XCTAssertEqual(Interval.minorSecond.shortName, "m2")
        XCTAssertEqual(Interval.majorSecond.semitones, 2)
        XCTAssertEqual(Interval.majorSecond.shortName, "M2")
        XCTAssertEqual(Interval.minorThird.semitones, 3)
        XCTAssertEqual(Interval.minorThird.shortName, "m3")
        XCTAssertEqual(Interval.majorThird.semitones, 4)
        XCTAssertEqual(Interval.majorThird.shortName, "M3")
        XCTAssertEqual(Interval.perfectFourth.semitones, 5)
        XCTAssertEqual(Interval.perfectFourth.shortName, "P4")
        XCTAssertEqual(Interval.tritone.semitones, 6)
        XCTAssertEqual(Interval.tritone.shortName, "TT")
        XCTAssertEqual(Interval.perfectFifth.semitones, 7)
        XCTAssertEqual(Interval.perfectFifth.shortName, "P5")
        XCTAssertEqual(Interval.minorSixth.semitones, 8)
        XCTAssertEqual(Interval.minorSixth.shortName, "m6")
        XCTAssertEqual(Interval.majorSixth.semitones, 9)
        XCTAssertEqual(Interval.majorSixth.shortName, "M6")
        XCTAssertEqual(Interval.minorSeventh.semitones, 10)
        XCTAssertEqual(Interval.minorSeventh.shortName, "m7")
        XCTAssertEqual(Interval.majorSeventh.semitones, 11)
        XCTAssertEqual(Interval.majorSeventh.shortName, "M7")
        XCTAssertEqual(Interval.octave.semitones, 12)
        XCTAssertEqual(Interval.octave.shortName, "P8")
        XCTAssertEqual(Interval.minorNinth.semitones, 13)
        XCTAssertEqual(Interval.minorNinth.shortName, "m9")
        XCTAssertEqual(Interval.majorNinth.semitones, 14)
        XCTAssertEqual(Interval.majorNinth.shortName, "M9")
        XCTAssertEqual(Interval.perfectEleventh.semitones, 17)
        XCTAssertEqual(Interval.perfectEleventh.shortName, "P11")
        XCTAssertEqual(Interval.augmentedEleventh.semitones, 18)
        XCTAssertEqual(Interval.augmentedEleventh.shortName, "♯11")
        XCTAssertEqual(Interval.majorThirteenth.semitones, 21)
        XCTAssertEqual(Interval.majorThirteenth.shortName, "M13")

        let custom = Interval(semitones: 15)
        XCTAssertEqual(custom.shortName, "15st")
        XCTAssertTrue(Interval.majorThird < Interval.perfectFifth)
    }

    // MARK: - Note Tests
    func testNoteInitialization() {
        let n60 = Note(midiNumber: 60)
        XCTAssertEqual(n60.pitchClass, .c)
        XCTAssertEqual(n60.octave, 4)
        XCTAssertEqual(n60.name, "C4")

        let n69 = Note(pitchClass: .a, octave: 4)
        XCTAssertEqual(n69.midiNumber, 69)
        XCTAssertEqual(n69.name, "A4")

        let clamped = Note(midiNumber: 200)
        XCTAssertEqual(clamped.midiNumber, 127)

        let minClamped = Note(pitchClass: .c, octave: -5)
        XCTAssertEqual(minClamped.midiNumber, 0)
    }

    func testNoteFrequency() {
        let a4 = Note(midiNumber: 69)
        XCTAssertEqual(a4.frequency, 440.0, accuracy: 0.001)

        let a5 = Note(midiNumber: 81)
        XCTAssertEqual(a5.frequency, 880.0, accuracy: 0.001)

        let a3 = Note(midiNumber: 57)
        XCTAssertEqual(a3.frequency, 220.0, accuracy: 0.001)

        let c4 = Note(midiNumber: 60)
        XCTAssertEqual(c4.frequency, 261.625, accuracy: 0.01)
    }

    func testNoteTransposition() {
        let c4 = Note.c4
        let g4 = c4.transposed(by: 7)
        XCTAssertEqual(g4.midiNumber, 67)
        XCTAssertEqual(g4.pitchClass, .g)
        XCTAssertTrue(c4 < g4)

        let maxNote = Note(midiNumber: 127).transposed(by: 5)
        XCTAssertEqual(maxNote.midiNumber, 127)
    }

    // MARK: - Scale & Mode Tests
    func testAllScaleTypes() {
        for type in ScaleType.allCases {
            let scale = Scale(root: .c, type: type)
            XCTAssertFalse(scale.pitchClasses.isEmpty)
            XCTAssertEqual(scale.pitchClasses.first, .c)
            XCTAssertTrue(scale.contains(PitchClass.c))
            XCTAssertTrue(scale.contains(Note.c4))
        }
    }

    func testDiatonicScales() {
        let cMajor = Scale.cMajor
        let cMajorPcs: [PitchClass] = [.c, .d, .e, .f, .g, .a, .b]
        XCTAssertEqual(cMajor.pitchClasses, cMajorPcs)
        XCTAssertEqual(cMajor.name, "C Major (Ionian)")

        let aMinor = Scale.aMinor
        let aMinorPcs: [PitchClass] = [.a, .b, .c, .d, .e, .f, .g]
        XCTAssertEqual(aMinor.pitchClasses, aMinorPcs)
        XCTAssertEqual(aMinor.name, "A Natural Minor (Aeolian)")
    }

    func testSnapToScale() {
        let cMajor = Scale.cMajor
        XCTAssertEqual(cMajor.snapToScale(.c), .c)
        XCTAssertEqual(cMajor.snapToScale(.e), .e)
        let snappedCSharp = cMajor.snapToScale(.cSharp)
        XCTAssertTrue(snappedCSharp == .c || snappedCSharp == .d)
        let snappedGSharp = cMajor.snapToScale(.gSharp)
        XCTAssertTrue(snappedGSharp == .g || snappedGSharp == .a)
    }

    // MARK: - Chord & Voicing Tests
    func testChordQualitiesAndSymbols() {
        let cMaj = Chord(root: .c, quality: .major)
        XCTAssertEqual(cMaj.symbol, "C")

        let cMin = Chord(root: .c, quality: .minor)
        XCTAssertEqual(cMin.symbol, "Cm")

        let cMaj7 = Chord(root: .c, quality: .major7)
        XCTAssertEqual(cMaj7.symbol, "Cmaj7")

        let cDom7 = Chord(root: .c, quality: .dominant7)
        XCTAssertEqual(cDom7.symbol, "C7")

        let cSlashG = Chord(root: .c, quality: .major, bassNote: .g)
        XCTAssertEqual(cSlashG.symbol, "C/G")

        let customChord = Chord(root: .c, quality: .major, customName: "Special C")
        XCTAssertEqual(customChord.symbol, "Special C")
    }

    func testChordInversions() {
        let cMaj = Chord(root: .c, quality: .major, inversion: .root)
        let rootNotes = cMaj.voicedNotes(baseOctave: 3)
        XCTAssertEqual(rootNotes.map { $0.midiNumber }, [48, 52, 55])

        var firstInv = cMaj
        firstInv.inversion = .first
        let firstInvNotes = firstInv.voicedNotes(baseOctave: 3)
        XCTAssertEqual(firstInvNotes.map { $0.midiNumber }, [52, 55, 60])

        var secondInv = cMaj
        secondInv.inversion = .second
        let secondInvNotes = secondInv.voicedNotes(baseOctave: 3)
        XCTAssertEqual(secondInvNotes.map { $0.midiNumber }, [55, 60, 64])
    }

    func testChordVoicingStyles() {
        let cMaj7 = Chord(root: .c, quality: .major7)

        let closeVoicing = cMaj7.voicedNotes(baseOctave: 3)
        XCTAssertEqual(closeVoicing.count, 4)

        var drop2 = cMaj7
        drop2.voicingStyle = .drop2
        let drop2Voicing = drop2.voicedNotes(baseOctave: 3)
        XCTAssertEqual(drop2Voicing.count, 4)

        var openSpread = cMaj7
        openSpread.voicingStyle = .openSpread
        let openSpreadVoicing = openSpread.voicedNotes(baseOctave: 3)
        XCTAssertEqual(openSpreadVoicing.count, 4)

        var guitarAcoustic = cMaj7
        guitarAcoustic.voicingStyle = .guitarAcoustic
        let guitarVoicing = guitarAcoustic.voicedNotes(baseOctave: 3)
        XCTAssertEqual(guitarVoicing.count, 5)

        var shellJazz = cMaj7
        shellJazz.voicingStyle = .shellJazz
        let shellVoicing = shellJazz.voicedNotes(baseOctave: 3)
        XCTAssertEqual(shellVoicing.count, 3)
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
