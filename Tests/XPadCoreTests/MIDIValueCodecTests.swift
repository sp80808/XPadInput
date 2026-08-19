import XCTest
@testable import XPadCore

final class MIDIValueCodecTests: XCTestCase {
    func testMIDI7ClampsAndRounds() {
        XCTAssertEqual(MIDIValueCodec.midi7(0), 0)
        XCTAssertEqual(MIDIValueCodec.midi7(1), 127)
        XCTAssertEqual(MIDIValueCodec.midi7(0.5), 64)
        XCTAssertEqual(MIDIValueCodec.midi7(-3), 0)
        XCTAssertEqual(MIDIValueCodec.midi7(9), 127)
        XCTAssertEqual(MIDIValueCodec.midi7(.nan), 0)
    }

    func testSymmetricPitchBendIsCentredAndBounded() {
        XCTAssertEqual(MIDIValueCodec.pitchBend14(semitones: 0, range: 48), 8_192)
        XCTAssertEqual(MIDIValueCodec.pitchBend14(semitones: 48, range: 48), 16_383)
        XCTAssertEqual(MIDIValueCodec.pitchBend14(semitones: -48, range: 48), 0)
        XCTAssertEqual(MIDIValueCodec.pitchBend14(semitones: 96, range: 48), 16_383)
        XCTAssertEqual(MIDIValueCodec.pitchBend14(semitones: 12, range: 0), 8_192)
        XCTAssertEqual(MIDIValueCodec.pitchBend14(semitones: .nan, range: 48), 8_192)
    }

    func testAsymmetricPitchBendStopsShortOfMaximumUpwards() {
        XCTAssertEqual(MIDIValueCodec.asymmetricPitchBend14(semitones: 0, range: 48), 8_192)
        XCTAssertEqual(MIDIValueCodec.asymmetricPitchBend14(semitones: 48, range: 48), 16_383)
        XCTAssertEqual(MIDIValueCodec.asymmetricPitchBend14(semitones: -48, range: 48), 0)
        XCTAssertEqual(MIDIValueCodec.asymmetricPitchBend14(semitones: 24, range: 48), 12_288)
    }

    func testPitchBendRoundTripsToSemitones() {
        for semitones in [-12.0, -3.5, 0.0, 1.25, 7.0] {
            let encoded = MIDIValueCodec.pitchBend14(semitones: semitones, range: 24)
            let decoded = MIDIValueCodec.semitones(fromPitchBend14: encoded, range: 24)
            XCTAssertEqual(decoded, semitones, accuracy: 0.01)
        }
    }

    func testSignedPitchBendConversionClamps() {
        XCTAssertEqual(MIDIValueCodec.unsignedPitchBend14(signed: 0), 8_192)
        XCTAssertEqual(MIDIValueCodec.unsignedPitchBend14(signed: -8_192), 0)
        XCTAssertEqual(MIDIValueCodec.unsignedPitchBend14(signed: 8_191), 16_383)
    }
}

final class ScalarMathTests: XCTestCase {
    func testClampedRestrictsToRange() {
        XCTAssertEqual(5.clamped(to: 0...3), 3)
        XCTAssertEqual((-2).clamped(to: 0...3), 0)
        XCTAssertEqual(2.clamped(to: 0...3), 2)
    }

    func testNormalizedUnitAndBipolarRejectNonFiniteInput() {
        XCTAssertEqual(1.5.normalizedUnit, 1)
        XCTAssertEqual((-0.5).normalizedUnit, 0)
        XCTAssertEqual(Double.infinity.normalizedUnit, 0)
        XCTAssertEqual((-4.0).normalizedBipolar, -1)
        XCTAssertEqual(Float.nan.normalizedBipolar, 0)
    }
}
