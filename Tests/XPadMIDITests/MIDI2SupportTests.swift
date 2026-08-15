import XCTest
import CoreMIDI
@testable import XPadMIDI

final class MIDI2SupportTests: XCTestCase {
    func testMIDI1RemainsDefaultTransport() {
        let midi = MIDIEngine()
        XCTAssertEqual(midi.transportProtocol, .midi1)
        XCTAssertEqual(MIDITransportProtocol.midi1.coreMIDIProtocol, ._1_0)
        XCTAssertEqual(MIDITransportProtocol.midi2.coreMIDIProtocol, ._2_0)
    }

    func testSevenBitScalingPreservesEndpoints() {
        XCTAssertEqual(MIDI2UMPEncoder.scale7To16(0), 0)
        XCTAssertEqual(MIDI2UMPEncoder.scale7To16(127), UInt16.max)
        XCTAssertEqual(MIDI2UMPEncoder.scale7To32(0), 0)
        XCTAssertEqual(MIDI2UMPEncoder.scale7To32(127), UInt32.max)

        XCTAssertLessThan(
            MIDI2UMPEncoder.scale7To32(63),
            MIDI2UMPEncoder.scale7To32(64)
        )
    }

    func testNormalizedScalingPreservesRangeWithoutSevenBitRoundTrip() {
        XCTAssertEqual(MIDI2UMPEncoder.scaleNormalizedTo16(0), 0)
        XCTAssertEqual(MIDI2UMPEncoder.scaleNormalizedTo16(1), UInt16.max)
        XCTAssertEqual(MIDI2UMPEncoder.scaleNormalizedTo32(0), 0)
        XCTAssertEqual(MIDI2UMPEncoder.scaleNormalizedTo32(1), UInt32.max)
        XCTAssertEqual(
            MIDI2UMPEncoder.scaleNormalizedTo32(0.5),
            MIDI2UMPEncoder.pitchBendCentre
        )
        XCTAssertEqual(MIDI2UMPEncoder.scaleNormalizedTo32(.nan), 0)
        XCTAssertEqual(MIDI2UMPEncoder.scaleNormalizedTo32(-1), 0)
        XCTAssertEqual(MIDI2UMPEncoder.scaleNormalizedTo32(2), UInt32.max)
    }

    func testPitchBendScalingPreservesMinimumCentreAndMaximum() {
        XCTAssertEqual(MIDI2UMPEncoder.scale14BitPitchBendTo32(0), 0)
        XCTAssertEqual(
            MIDI2UMPEncoder.scale14BitPitchBendTo32(8_192),
            MIDI2UMPEncoder.pitchBendCentre
        )
        XCTAssertEqual(
            MIDI2UMPEncoder.scale14BitPitchBendTo32(16_383),
            UInt32.max
        )

        XCTAssertEqual(
            MIDI2UMPEncoder.pitchBend32(semitoneOffset: -48, bendRangeSemitones: 48),
            0
        )
        XCTAssertEqual(
            MIDI2UMPEncoder.pitchBend32(semitoneOffset: 0, bendRangeSemitones: 48),
            MIDI2UMPEncoder.pitchBendCentre
        )
        XCTAssertEqual(
            MIDI2UMPEncoder.pitchBend32(semitoneOffset: 48, bendRangeSemitones: 48),
            UInt32.max
        )
        XCTAssertEqual(
            MIDI2UMPEncoder.pitchBend32(semitoneOffset: .nan, bendRangeSemitones: 48),
            MIDI2UMPEncoder.pitchBendCentre
        )
    }

    func testNativeMIDI2PitchRetainsMotionBelowMIDI1Resolution() {
        let firstOffset = 0.0001
        let secondOffset = 0.0002
        let range = 48.0

        // Both gestures collapse to the same MIDI 1 14-bit value.
        XCTAssertEqual(
            MIDIEngine.pitchBendValue(
                semitoneOffset: firstOffset,
                bendRangeSemitones: range
            ),
            8_192
        )
        XCTAssertEqual(
            MIDIEngine.pitchBendValue(
                semitoneOffset: secondOffset,
                bendRangeSemitones: range
            ),
            8_192
        )

        // MIDI 2 retains them as distinct 32-bit values.
        let firstMIDI2 = MIDI2UMPEncoder.pitchBend32(
            semitoneOffset: firstOffset,
            bendRangeSemitones: range
        )
        let secondMIDI2 = MIDI2UMPEncoder.pitchBend32(
            semitoneOffset: secondOffset,
            bendRangeSemitones: range
        )
        XCTAssertGreaterThan(firstMIDI2, MIDI2UMPEncoder.pitchBendCentre)
        XCTAssertGreaterThan(secondMIDI2, firstMIDI2)

        let message = MIDI2UMPEncoder.pitchBendMessage(
            channel: 2,
            semitoneOffset: secondOffset,
            bendRangeSemitones: range
        )
        XCTAssertEqual(message.word1, secondMIDI2)
    }

    func testMIDI2EncoderProducesChannelVoice2Messages() {
        let noteOn = MIDI2UMPEncoder.message(from: [0x92, 64, 100])
        let control = MIDI2UMPEncoder.message(from: [0xB1, 74, 90])
        let bend = MIDI2UMPEncoder.message(from: [0xE3, 0x00, 0x40])
        let hiResPressure = MIDI2UMPEncoder.channelPressureMessage(
            channel: 1,
            normalizedPressure: 0.501
        )

        XCTAssertNotNil(noteOn)
        XCTAssertNotNil(control)
        XCTAssertNotNil(bend)

        // UMP message type 0x4 is MIDI 2.0 Channel Voice.
        XCTAssertEqual(noteOn!.word0 >> 28, 0x4)
        XCTAssertEqual(control!.word0 >> 28, 0x4)
        XCTAssertEqual(bend!.word0 >> 28, 0x4)
        XCTAssertEqual(hiResPressure.word0 >> 28, 0x4)
        XCTAssertEqual(
            hiResPressure.word1,
            MIDI2UMPEncoder.scaleNormalizedTo32(0.501)
        )
    }

    func testMIDI2EncoderRejectsMalformedOrUnsupportedMessages() {
        XCTAssertNil(MIDI2UMPEncoder.message(from: []))
        XCTAssertNil(MIDI2UMPEncoder.message(from: [0x90, 60]))
        XCTAssertNil(MIDI2UMPEncoder.message(from: [0xC0, 10]))
        XCTAssertNil(MIDI2UMPEncoder.message(from: [0xF8, 0]))
    }

    func testChangingTransportWhileDisabledDoesNotEmitCleanupTraffic() {
        let midi = MIDIEngine()
        midi.clearMessageLog()

        midi.transportProtocol = .midi2

        XCTAssertEqual(midi.transportProtocol, .midi2)
        XCTAssertTrue(midi.sentMessages.isEmpty)
        XCTAssertEqual(midi.activeNoteCount, 0)
    }

    func testSemanticMessageLogIsStableAcrossTransportSelection() {
        let midi = MIDIEngine()
        midi.transportProtocol = .midi2
        midi.clearMessageLog()

        midi.sendNoteOn(port: .main, channel: 2, note: 64, velocity: 100)
        midi.sendPitchBend(port: .main, channel: 2, value: 8_192)
        midi.sendNoteOff(port: .main, channel: 2, note: 64)

        XCTAssertEqual(midi.sentMessages.map(\.bytes), [
            [0x92, 64, 100],
            [0xE2, 0, 0x40],
            [0x82, 64, 0]
        ])
    }

    func testMPEMIDI2DoesNotSuppressSubFourteenBitBendChanges() {
        let midi = MIDIEngine()
        midi.transportProtocol = .midi2
        let mpe = MPEManager(midiEngine: midi, bendRangeSemitones: 48)

        mpe.noteOn(note: 60, velocity: 100)
        midi.clearMessageLog()

        mpe.setPitchBend(for: 60, semitones: 0.0001)
        mpe.setPitchBend(for: 60, semitones: 0.0002)

        // The stable diagnostic view is still 14-bit shaped, so both records
        // appear centred even though the MIDI 2 wire values are distinct.
        XCTAssertEqual(midi.sentMessages.map(\.bytes), [
            [0xE1, 0, 0x40],
            [0xE1, 0, 0x40]
        ])
        XCTAssertEqual(
            mpe.voice(for: 60)?.currentMIDI2PitchBendValue,
            MIDI2UMPEncoder.pitchBend32(
                semitoneOffset: 0.0002,
                bendRangeSemitones: 48
            )
        )
    }

    func testMPEMIDI1StillSuppressesChangesThatQuantizeToSameWireValue() {
        let midi = MIDIEngine()
        midi.transportProtocol = .midi1
        let mpe = MPEManager(midiEngine: midi, bendRangeSemitones: 48)

        mpe.noteOn(note: 60, velocity: 100)
        midi.clearMessageLog()

        mpe.setPitchBend(for: 60, semitones: 0.0001)
        mpe.setPitchBend(for: 60, semitones: 0.0002)

        XCTAssertTrue(midi.sentMessages.isEmpty)
    }
}
