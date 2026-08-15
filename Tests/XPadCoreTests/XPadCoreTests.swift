import Testing
import Foundation
@testable import XPadCore

@Suite("Core Music & Data Model Tests")
struct XPadCoreTests {

    // MARK: - PitchClass Tests
    @Test("PitchClass enum cases and raw values")
    func testPitchClassRawValues() {
        #expect(PitchClass.allCases.count == 12)
        #expect(PitchClass.c.rawValue == 0)
        #expect(PitchClass.cSharp.rawValue == 1)
        #expect(PitchClass.d.rawValue == 2)
        #expect(PitchClass.dSharp.rawValue == 3)
        #expect(PitchClass.e.rawValue == 4)
        #expect(PitchClass.f.rawValue == 5)
        #expect(PitchClass.fSharp.rawValue == 6)
        #expect(PitchClass.g.rawValue == 7)
        #expect(PitchClass.gSharp.rawValue == 8)
        #expect(PitchClass.a.rawValue == 9)
        #expect(PitchClass.aSharp.rawValue == 10)
        #expect(PitchClass.b.rawValue == 11)
    }

    @Test("PitchClass naming properties")
    func testPitchClassNaming() {
        #expect(PitchClass.c.sharpName == "C")
        #expect(PitchClass.c.flatName == "C")
        #expect(PitchClass.cSharp.sharpName == "C♯")
        #expect(PitchClass.cSharp.flatName == "D♭")
        #expect(PitchClass.cSharp.standardName == "D♭") // Standard prefers flats for accidentals
        #expect(PitchClass.fSharp.sharpName == "F♯")
        #expect(PitchClass.fSharp.flatName == "G♭")
        #expect(PitchClass.aSharp.standardName == "B♭")
        #expect(PitchClass.e.standardName == "E")
    }

    @Test("PitchClass transposition across octave boundaries")
    func testPitchClassTransposition() {
        #expect(PitchClass.c.transposed(by: 0) == .c)
        #expect(PitchClass.c.transposed(by: 12) == .c)
        #expect(PitchClass.c.transposed(by: 24) == .c)
        #expect(PitchClass.c.transposed(by: -12) == .c)
        #expect(PitchClass.c.transposed(by: 4) == .e)
        #expect(PitchClass.c.transposed(by: 7) == .g)
        #expect(PitchClass.c.transposed(by: -1) == .b)
        #expect(PitchClass.c.transposed(by: -13) == .b)
        #expect(PitchClass.b.transposed(by: 1) == .c)
        #expect(PitchClass.b.transposed(by: 2) == .cSharp)
    }

    @Test("PitchClass upward semitone distance")
    func testPitchClassSemitonesDistance() {
        #expect(PitchClass.c.semitones(to: .c) == 0)
        #expect(PitchClass.c.semitones(to: .g) == 7)
        #expect(PitchClass.g.semitones(to: .c) == 5)
        #expect(PitchClass.b.semitones(to: .c) == 1)
        #expect(PitchClass.c.semitones(to: .b) == 11)
    }

    @Test("PitchClass Circle of Fifths indices")
    func testCircleOfFifthsIndices() {
        let expectedCoF: [PitchClass: Int] = [
            .c: 0, .g: 1, .d: 2, .a: 3, .e: 4, .b: 5,
            .fSharp: 6, .cSharp: 7, .gSharp: 8, .dSharp: 9, .aSharp: 10, .f: 11
        ]
        for (pc, index) in expectedCoF {
            #expect(pc.circleOfFifthsIndex == index)
        }
    }

    @Test("PitchClass Comparable conformance")
    func testPitchClassComparable() {
        #expect(PitchClass.c < PitchClass.d)
        #expect(PitchClass.d < PitchClass.e)
        #expect(PitchClass.aSharp < PitchClass.b)
    }

    // MARK: - Interval Tests
    @Test("Interval constants and short names")
    func testIntervalConstants() {
        #expect(Interval.unison.semitones == 0)
        #expect(Interval.unison.shortName == "P1")
        #expect(Interval.minorSecond.semitones == 1)
        #expect(Interval.minorSecond.shortName == "m2")
        #expect(Interval.majorSecond.semitones == 2)
        #expect(Interval.majorSecond.shortName == "M2")
        #expect(Interval.minorThird.semitones == 3)
        #expect(Interval.minorThird.shortName == "m3")
        #expect(Interval.majorThird.semitones == 4)
        #expect(Interval.majorThird.shortName == "M3")
        #expect(Interval.perfectFourth.semitones == 5)
        #expect(Interval.perfectFourth.shortName == "P4")
        #expect(Interval.tritone.semitones == 6)
        #expect(Interval.tritone.shortName == "TT")
        #expect(Interval.perfectFifth.semitones == 7)
        #expect(Interval.perfectFifth.shortName == "P5")
        #expect(Interval.minorSixth.semitones == 8)
        #expect(Interval.minorSixth.shortName == "m6")
        #expect(Interval.majorSixth.semitones == 9)
        #expect(Interval.majorSixth.shortName == "M6")
        #expect(Interval.minorSeventh.semitones == 10)
        #expect(Interval.minorSeventh.shortName == "m7")
        #expect(Interval.majorSeventh.semitones == 11)
        #expect(Interval.majorSeventh.shortName == "M7")
        #expect(Interval.octave.semitones == 12)
        #expect(Interval.octave.shortName == "P8")
        #expect(Interval.minorNinth.semitones == 13)
        #expect(Interval.minorNinth.shortName == "m9")
        #expect(Interval.majorNinth.semitones == 14)
        #expect(Interval.majorNinth.shortName == "M9")
        #expect(Interval.perfectEleventh.semitones == 17)
        #expect(Interval.perfectEleventh.shortName == "P11")
        #expect(Interval.augmentedEleventh.semitones == 18)
        #expect(Interval.augmentedEleventh.shortName == "♯11")
        #expect(Interval.majorThirteenth.semitones == 21)
        #expect(Interval.majorThirteenth.shortName == "M13")

        let custom = Interval(semitones: 15)
        #expect(custom.shortName == "15st")
        #expect(Interval.majorThird < Interval.perfectFifth)
    }

    // MARK: - Note Tests
    @Test("Note initialization from MIDI and PitchClass+Octave")
    func testNoteInitialization() {
        let n60 = Note(midiNumber: 60)
        #expect(n60.pitchClass == .c)
        #expect(n60.octave == 4)
        #expect(n60.name == "C4")

        let n69 = Note(pitchClass: .a, octave: 4)
        #expect(n69.midiNumber == 69)
        #expect(n69.name == "A4")

        let clamped = Note(midiNumber: 200)
        #expect(clamped.midiNumber == 127)

        let minClamped = Note(pitchClass: .c, octave: -5)
        #expect(minClamped.midiNumber == 0)
    }

    @Test("Note frequency calculations")
    func testNoteFrequency() {
        let a4 = Note(midiNumber: 69)
        #expect(abs(a4.frequency - 440.0) < 0.001)

        let a5 = Note(midiNumber: 81)
        #expect(abs(a5.frequency - 880.0) < 0.001)

        let a3 = Note(midiNumber: 57)
        #expect(abs(a3.frequency - 220.0) < 0.001)

        let c4 = Note(midiNumber: 60)
        #expect(abs(c4.frequency - 261.625) < 0.01)
    }

    @Test("Note transposition and comparability")
    func testNoteTransposition() {
        let c4 = Note.c4
        let g4 = c4.transposed(by: 7)
        #expect(g4.midiNumber == 67)
        #expect(g4.pitchClass == .g)
        #expect(c4 < g4)

        let maxNote = Note(midiNumber: 127).transposed(by: 5)
        #expect(maxNote.midiNumber == 127)
    }

    // MARK: - Scale & Mode Tests
    @Test("Scale construction for all modes")
    func testAllScaleTypes() {
        for type in ScaleType.allCases {
            let scale = Scale(root: .c, type: type)
            #expect(!scale.pitchClasses.isEmpty)
            #expect(scale.pitchClasses.first == .c)
            #expect(scale.contains(PitchClass.c))
            #expect(scale.contains(Note.c4))
        }
    }

    @Test("Diatonic major and natural minor scale pitch classes")
    func testDiatonicScales() {
        let cMajor = Scale.cMajor
        let cMajorPcs: [PitchClass] = [.c, .d, .e, .f, .g, .a, .b]
        #expect(cMajor.pitchClasses == cMajorPcs)
        #expect(cMajor.name == "C Major (Ionian)")

        let aMinor = Scale.aMinor
        let aMinorPcs: [PitchClass] = [.a, .b, .c, .d, .e, .f, .g]
        #expect(aMinor.pitchClasses == aMinorPcs)
        #expect(aMinor.name == "A Natural Minor (Aeolian)")
    }

    @Test("Scale quantization (snapToScale)")
    func testSnapToScale() {
        let cMajor = Scale.cMajor
        #expect(cMajor.snapToScale(.c) == .c)
        #expect(cMajor.snapToScale(.e) == .e)
        // C# should snap to C or D (both distance 1)
        let snappedCSharp = cMajor.snapToScale(.cSharp)
        #expect(snappedCSharp == .c || snappedCSharp == .d)
        // G# should snap to G or A
        let snappedGSharp = cMajor.snapToScale(.gSharp)
        #expect(snappedGSharp == .g || snappedGSharp == .a)
    }

    // MARK: - Chord & Voicing Tests
    @Test("Chord qualities and symbol generation")
    func testChordQualitiesAndSymbols() {
        let cMaj = Chord(root: .c, quality: .major)
        #expect(cMaj.symbol == "C")

        let cMin = Chord(root: .c, quality: .minor)
        #expect(cMin.symbol == "Cm")

        let cMaj7 = Chord(root: .c, quality: .major7)
        #expect(cMaj7.symbol == "Cmaj7")

        let cDom7 = Chord(root: .c, quality: .dominant7)
        #expect(cDom7.symbol == "C7")

        let cSlashG = Chord(root: .c, quality: .major, bassNote: .g)
        #expect(cSlashG.symbol == "C/G")

        let customChord = Chord(root: .c, quality: .major, customName: "Special C")
        #expect(customChord.symbol == "Special C")
    }

    @Test("Chord inversions note calculation")
    func testChordInversions() {
        let cMaj = Chord(root: .c, quality: .major, inversion: .root)
        let rootNotes = cMaj.voicedNotes(baseOctave: 3)
        #expect(rootNotes.map { $0.midiNumber } == [48, 52, 55]) // C3, E3, G3

        var firstInv = cMaj
        firstInv.inversion = .first
        let firstInvNotes = firstInv.voicedNotes(baseOctave: 3)
        #expect(firstInvNotes.map { $0.midiNumber } == [52, 55, 60]) // E3, G3, C4

        var secondInv = cMaj
        secondInv.inversion = .second
        let secondInvNotes = secondInv.voicedNotes(baseOctave: 3)
        #expect(secondInvNotes.map { $0.midiNumber } == [55, 60, 64]) // G3, C4, E4
    }

    @Test("Chord voicing styles")
    func testChordVoicingStyles() {
        let cMaj7 = Chord(root: .c, quality: .major7)

        let closeVoicing = cMaj7.voicedNotes(baseOctave: 3)
        #expect(closeVoicing.count == 4)

        var drop2 = cMaj7
        drop2.voicingStyle = .drop2
        let drop2Voicing = drop2.voicedNotes(baseOctave: 3)
        #expect(drop2Voicing.count == 4)

        var openSpread = cMaj7
        openSpread.voicingStyle = .openSpread
        let openSpreadVoicing = openSpread.voicedNotes(baseOctave: 3)
        #expect(openSpreadVoicing.count == 4)

        var guitarAcoustic = cMaj7
        guitarAcoustic.voicingStyle = .guitarAcoustic
        let guitarVoicing = guitarAcoustic.voicedNotes(baseOctave: 3)
        #expect(guitarVoicing.count == 5)

        var shellJazz = cMaj7
        shellJazz.voicingStyle = .shellJazz
        let shellVoicing = shellJazz.voicedNotes(baseOctave: 3)
        #expect(shellVoicing.count == 3) // Root, 3rd, 7th
    }

    // MARK: - PerformanceEvent & Transport Tests
    @Test("PerformanceEvent Codable encoding & decoding")
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
            #expect(decoded != nil)
        }
    }

    @Test("TransportState bar and beat arithmetic")
    func testTransportStateArithmetic() {
        var transport = TransportState(bpm: 120.0, timeSignatureNumerator: 4, timeSignatureDenominator: 4)
        #expect(transport.currentBar == 1)
        #expect(abs(transport.currentBeat - 1.0) < 0.001)

        // Advance by 1 beat (960 ticks)
        transport.currentTick = 960
        #expect(transport.currentBar == 1)
        #expect(abs(transport.currentBeat - 2.0) < 0.001)

        // Advance to bar 2 beat 1 (3840 ticks)
        transport.currentTick = 3840
        #expect(transport.currentBar == 2)
        #expect(abs(transport.currentBeat - 1.0) < 0.001)

        // Advance to bar 3 beat 3 (3840 * 2 + 1920 = 9600 ticks)
        transport.currentTick = 9600
        #expect(transport.currentBar == 3)
        #expect(abs(transport.currentBeat - 3.0) < 0.001)
    }
}
