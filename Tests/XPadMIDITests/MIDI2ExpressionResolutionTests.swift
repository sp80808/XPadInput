import XCTest
@testable import XPadMIDI
import XPadCore

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

    func testLiveExpressionDispatchPreservesMIDI2MPEPressureBelowSevenBits() {
        let midi = MIDIEngine()
        midi.transportProtocol = .midi2
        let mpe = MPEManager(midiEngine: midi)
        mpe.noteOn(note: 60, velocity: 100)
        midi.clearMessageLog()

        let first = 0.5001
        let second = 0.5002
        XCTAssertEqual(midi7(first), midi7(second))

        LiveExpressionDispatch.sendPressure(
            mpe: mpe,
            midi: midi,
            destination: .genericMPE,
            preferredPressureMode: .mpePressure,
            note: 60,
            ports: [.melody],
            normalizedPressure: first
        )
        LiveExpressionDispatch.sendPressure(
            mpe: mpe,
            midi: midi,
            destination: .genericMPE,
            preferredPressureMode: .mpePressure,
            note: 60,
            ports: [.melody],
            normalizedPressure: second
        )

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

    func testLiveExpressionDispatchPreservesMIDI2MPETimbreBelowSevenBits() {
        let midi = MIDIEngine()
        midi.transportProtocol = .midi2
        let mpe = MPEManager(midiEngine: midi)
        mpe.noteOn(note: 60, velocity: 100)
        midi.clearMessageLog()

        let first = 0.5117
        let second = 0.5118
        XCTAssertEqual(midi7(first), midi7(second))

        LiveExpressionDispatch.sendTimbre(
            mpe: mpe,
            midi: midi,
            destination: .genericMPE,
            note: 60,
            ports: [.melody],
            normalizedTimbre: first
        )
        LiveExpressionDispatch.sendTimbre(
            mpe: mpe,
            midi: midi,
            destination: .genericMPE,
            note: 60,
            ports: [.melody],
            normalizedTimbre: second
        )

        XCTAssertEqual(mpe.voice(for: 60)?.currentTimbreNormalized, second)
        XCTAssertEqual(
            mpe.voice(for: 60)?.currentMIDI2TimbreValue,
            MIDI2UMPEncoder.scaleNormalizedTo32(second)
        )
    }

    func testLiveExpressionDispatchConventionalPathUsesNormalizedChannelPressure() {
        let midi = MIDIEngine()
        midi.transportProtocol = .midi2
        let mpe = MPEManager(midiEngine: midi)
        midi.clearMessageLog()

        let first = 0.5001
        let second = 0.5002
        XCTAssertEqual(midi7(first), midi7(second))

        LiveExpressionDispatch.sendPressure(
            mpe: mpe,
            midi: midi,
            destination: .genericMIDI,
            preferredPressureMode: .channelPressure,
            note: 60,
            ports: [.melody],
            normalizedPressure: first
        )
        LiveExpressionDispatch.sendPressure(
            mpe: mpe,
            midi: midi,
            destination: .genericMIDI,
            preferredPressureMode: .channelPressure,
            note: 60,
            ports: [.melody],
            normalizedPressure: second
        )

        XCTAssertEqual(midi.sentMessages.map(\.bytes), [
            [0xD0, 64],
            [0xD0, 64]
        ])
        XCTAssertEqual(midi.sentMessages.map(\.port), [.melody, .melody])
        XCTAssertGreaterThan(
            MIDI2UMPEncoder.scaleNormalizedTo32(second),
            MIDI2UMPEncoder.scaleNormalizedTo32(first)
        )
    }

    func testQuantizedUInt8CallerWouldCollapseSubSevenBitPressure() {
        let first = 0.5001
        let second = 0.5002
        let quantizedFirst = UInt8(min(127, Int((first * 127.0).rounded())))
        let quantizedSecond = UInt8(min(127, Int((second * 127.0).rounded())))

        XCTAssertEqual(quantizedFirst, quantizedSecond)
        XCTAssertNotEqual(
            MIDI2UMPEncoder.scaleNormalizedTo32(first),
            MIDI2UMPEncoder.scaleNormalizedTo32(second)
        )
    }

    private func midi7(_ normalized: Double) -> UInt8 {
        UInt8((min(1, max(0, normalized)) * 127.0).rounded())
    }
}
