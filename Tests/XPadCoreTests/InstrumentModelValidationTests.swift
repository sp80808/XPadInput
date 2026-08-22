import Foundation
import XCTest
@testable import XPadCore

final class InstrumentModelValidationTests: XCTestCase {
    func testProfileSanitizesInvalidRanges() {
        let profile = InstrumentProfile(
            id: "invalid",
            family: .genericMPE,
            name: "Invalid",
            polyphonyMode: .mpe,
            preferredPitchBendRange: .nan,
            supportsPitchBend: true
        )

        XCTAssertEqual(profile.preferredPitchBendRange, 0.0)
        XCTAssertFalse(profile.supportsPitchBend)
        XCTAssertTrue(profile.supports(.normal))
    }

    func testSemanticCurvesClampAndPreserveDirection() {
        XCTAssertEqual(PitchBendCurve.linear.apply(2.0), 1.0)
        XCTAssertEqual(PitchBendCurve.precision.apply(-0.5), -0.25, accuracy: 0.000_001)
        XCTAssertEqual(PressureCurve.linear.apply(-1.0), 0.0)
        XCTAssertEqual(PressureCurve.expressive.apply(0.5), 0.5, accuracy: 0.000_001)
    }

    func testPerformanceLaneRegistersUseInstrumentDefaultsAndClampShifts() {
        let guitar = PerformanceLaneRegisters.defaults(for: .guitar)
        let bass = PerformanceLaneRegisters.defaults(for: .bass)

        XCTAssertEqual(guitar.strumOctave, 3)
        XCTAssertEqual(guitar.faceButtonOctave, 3)
        XCTAssertEqual(bass.strumOctave, 2)
        XCTAssertEqual(bass.faceButtonOctave, 2)
        var shifted = guitar
        shifted.shiftBoth(by: 10)
        XCTAssertEqual(shifted.strumOctave, 5)
        XCTAssertEqual(shifted.faceButtonOctave, 5)
        shifted.shiftBoth(by: -10)
        XCTAssertEqual(shifted.strumOctave, 2)
        XCTAssertEqual(shifted.faceButtonOctave, 2)
        shifted.shiftBoth(by: .max)
        XCTAssertEqual(shifted.strumOctave, 5)
        XCTAssertEqual(shifted.faceButtonOctave, 5)
        shifted.shiftBoth(by: .min)
        XCTAssertEqual(shifted.strumOctave, 2)
        XCTAssertEqual(shifted.faceButtonOctave, 2)
    }

    func testPerformanceLaneRegisterMemoryRecallsEachInstrumentProfile() {
        var memory = PerformanceLaneRegisterMemory()
        var guitar = memory.settings(for: .guitar)
        guitar.setStrumOctave(5)
        guitar.setFaceButtonOctave(4)
        memory.remember(guitar, for: .guitar)

        XCTAssertEqual(memory.settings(for: .bass), PerformanceLaneRegisters(strumOctave: 2, faceButtonOctave: 2))
        XCTAssertEqual(memory.settings(for: .guitar), PerformanceLaneRegisters(strumOctave: 5, faceButtonOctave: 4))
    }

    func testStrumRegisterAnchorsChordVoicingWithoutChangingFaceRegister() {
        let chord = Chord(root: .d, quality: .minor)
        var registers = PerformanceLaneRegisters(strumOctave: 2, faceButtonOctave: 4)
        let lowVoicing = ChordVoicing.strummed(
            chord: chord,
            strings: 4,
            baseOctave: registers.strumOctave
        )

        registers.setStrumOctave(5)
        let highVoicing = ChordVoicing.strummed(
            chord: chord,
            strings: 4,
            baseOctave: registers.strumOctave
        )

        XCTAssertEqual(lowVoicing.bassNote, Note(pitchClass: .d, octave: 2))
        XCTAssertEqual(highVoicing.bassNote, Note(pitchClass: .d, octave: 5))
        XCTAssertEqual(registers.faceButtonOctave, 4)
    }

    func testPerformanceEventNormalizesExpressionAndRoundTrips() throws {
        let event = InstrumentPerformanceEvent(
            note: Note(pitchClass: .e, octave: 4),
            targetNote: Note(pitchClass: .fSharp, octave: 4),
            technique: .bend,
            velocity: 72,
            pressure: 1.4,
            pitchOffset: 2.0,
            timbre: -0.2,
            damping: 0.3,
            role: .third,
            timestamp: -1.0
        )

        XCTAssertEqual(event.pressure, 1.0)
        XCTAssertEqual(event.timbre, 0.0)
        XCTAssertEqual(event.pitchOffsetSemitones, 2.0)
        XCTAssertEqual(event.timestamp, 0.0)
        XCTAssertEqual(event.expression.midiPressure, 127)

        let data = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(InstrumentPerformanceEvent.self, from: data)
        XCTAssertEqual(decoded, event)
    }
}
