import XCTest
@testable import XPadMIDI

final class MIDI2ExpressionResolutionTests: XCTestCase {
    func testMIDI2MPEPressureRetainsChangesBelowSevenBitResolution() {
        let midi = MIDIEngine()
        midi.transportProtocol = .midi2
        let mpe = MPEManager(midiEngine: midi)

        mpe.noteOn(note: 60, velocity: 100)
        midi.clearMessageLog()

        let first = 0.5001
        let second = 0.5002
        XCTAssertEqual(midi7(first), midi7(second))

        mpe.setPressure(for: 60, normalizedPressure: first)
        mpe.setPressure(for: 60, normalizedPressure: second)

        XCTAssertEqual(midi.sentMessages.map(\.bytes), [
            [0xD1, 64],
            [0xD1, 64]
        ])
        XCTAssertEqual(mpe.voice(for: 60)?.currentPressure, 64)
        XCTAssertEqual(mpe.voice(for: 60)?.currentPressureNormalized, second)
        XCTAssertEqual(
            mpe.voice(for: 60)?.currentMIDI2PressureValue,
            MIDI2UMPEncoder.scaleNormalizedTo32(second)
        )
        XCTAssertGreaterThan(
            MIDI2UMPEncoder.scaleNormalizedTo32(second),
            MIDI2UMPEncoder.scaleNormalizedTo32(first)
        )
    }

    func testMIDI1MPEPressureSuppressesChangesWithSameSevenBitValue() {
        let midi = MIDIEngine()
        midi.transportProtocol = .midi1
        let mpe = MPEManager(midiEngine: midi)

        mpe.noteOn(note: 60, velocity: 100)
        midi.clearMessageLog()

        mpe.setPressure(for: 60, normalizedPressure: 0.5001)
        mpe.setPressure(for: 60, normalizedPressure: 0.5002)

        XCTAssertEqual(midi.sentMessages.map(\.bytes), [[0xD1, 64]])
        XCTAssertEqual(mpe.voice(for: 60)?.currentPressure, 64)
        XCTAssertEqual(mpe.voice(for: 60)?.currentPressureNormalized, 0.5002)
    }

    func testMIDI2MPETimbreRetainsChangesBelowSevenBitResolution() {
        let midi = MIDIEngine()
        midi.transportProtocol = .midi2
        let mpe = MPEManager(midiEngine: midi)

        mpe.noteOn(note: 60, velocity: 100)
        midi.clearMessageLog()

        let first = 0.5117
        let second = 0.5118
        XCTAssertEqual(midi7(first), 65)
        XCTAssertEqual(midi7(second), 65)

        mpe.setTimbre(for: 60, normalizedValue: first)
        mpe.setTimbre(for: 60, normalizedValue: second)

        XCTAssertEqual(midi.sentMessages.map(\.bytes), [
            [0xB1, 74, 65],
            [0xB1, 74, 65]
        ])
        XCTAssertEqual(mpe.voice(for: 60)?.currentTimbre, 65)
        XCTAssertEqual(mpe.voice(for: 60)?.currentTimbreNormalized, second)
        XCTAssertEqual(
            mpe.voice(for: 60)?.currentMIDI2TimbreValue,
            MIDI2UMPEncoder.scaleNormalizedTo32(second)
        )
    }

    func testMIDI1MPETimbreSuppressesChangesWithSameSevenBitValue() {
        let midi = MIDIEngine()
        midi.transportProtocol = .midi1
        let mpe = MPEManager(midiEngine: midi)

        mpe.noteOn(note: 60, velocity: 100)
        midi.clearMessageLog()

        mpe.setTimbre(for: 60, normalizedValue: 0.5117)
        mpe.setTimbre(for: 60, normalizedValue: 0.5118)

        XCTAssertEqual(midi.sentMessages.map(\.bytes), [[0xB1, 74, 65]])
        XCTAssertEqual(mpe.voice(for: 60)?.currentTimbre, 65)
        XCTAssertEqual(mpe.voice(for: 60)?.currentTimbreNormalized, 0.5118)
    }

    func testPolyPressureUsesSameProtocolAwareHighResolutionState() {
        let midi = MIDIEngine()
        midi.transportProtocol = .midi2
        let mpe = MPEManager(midiEngine: midi)

        mpe.noteOn(note: 72, velocity: 90)
        midi.clearMessageLog()

        mpe.setPolyPressure(for: 72, normalizedPressure: 0.2501)
        mpe.setPolyPressure(for: 72, normalizedPressure: 0.2502)

        XCTAssertEqual(midi.sentMessages.count, 2)
        XCTAssertTrue(midi.sentMessages.allSatisfy { $0.bytes[0] == 0xA1 && $0.bytes[1] == 72 })
        XCTAssertEqual(
            mpe.voice(for: 72)?.currentMIDI2PressureValue,
            MIDI2UMPEncoder.scaleNormalizedTo32(0.2502)
        )
    }

    func testNonFiniteNormalizedExpressionFailsSafe() {
        let midi = MIDIEngine()
        midi.transportProtocol = .midi2
        let mpe = MPEManager(midiEngine: midi)

        mpe.noteOn(note: 60, velocity: 100)
        midi.clearMessageLog()

        mpe.setPressure(for: 60, normalizedPressure: .nan)
        mpe.setTimbre(for: 60, normalizedValue: .infinity)

        XCTAssertEqual(mpe.voice(for: 60)?.currentPressureNormalized, 0)
        XCTAssertEqual(mpe.voice(for: 60)?.currentTimbreNormalized, 0)
        XCTAssertEqual(mpe.voice(for: 60)?.currentMIDI2PressureValue, 0)
        XCTAssertEqual(mpe.voice(for: 60)?.currentMIDI2TimbreValue, 0)
        XCTAssertTrue(midi.sentMessages.contains { $0.bytes == [0xB1, 74, 0] })
    }

    private func midi7(_ normalized: Double) -> UInt8 {
        UInt8((min(1, max(0, normalized)) * 127.0).rounded())
    }
}
