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

    func testPitchBendScalingPreservesMinimumCentreAndMaximum() {
        XCTAssertEqual(MIDI2UMPEncoder.scale14BitPitchBendTo32(0), 0)
        XCTAssertEqual(
            MIDI2UMPEncoder.scale14BitPitchBendTo32(8_192),
            0x8000_0000
        )
        XCTAssertEqual(
            MIDI2UMPEncoder.scale14BitPitchBendTo32(16_383),
            UInt32.max
        )
    }

    func testMIDI2EncoderProducesChannelVoice2Messages() {
        let noteOn = MIDI2UMPEncoder.message(from: [0x92, 64, 100])
        let control = MIDI2UMPEncoder.message(from: [0xB1, 74, 90])
        let bend = MIDI2UMPEncoder.message(from: [0xE3, 0x00, 0x40])

        XCTAssertNotNil(noteOn)
        XCTAssertNotNil(control)
        XCTAssertNotNil(bend)

        // UMP message type 0x4 is MIDI 2.0 Channel Voice.
        XCTAssertEqual(noteOn!.word0 >> 28, 0x4)
        XCTAssertEqual(control!.word0 >> 28, 0x4)
        XCTAssertEqual(bend!.word0 >> 28, 0x4)
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
}
