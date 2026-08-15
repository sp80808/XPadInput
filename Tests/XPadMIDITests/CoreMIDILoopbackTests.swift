import XCTest
import CoreMIDI
@testable import XPadMIDI

final class CoreMIDILoopbackTests: XCTestCase {
    private final class ReceivedEvent: @unchecked Sendable {
        private let lock = NSLock()
        private var storedProtocol: MIDIProtocolID?
        private var storedWords: [UInt32] = []

        func recordIfEmpty(protocolID: MIDIProtocolID, words: [UInt32]) -> Bool {
            lock.lock()
            defer { lock.unlock() }
            guard storedWords.isEmpty else { return false }
            storedProtocol = protocolID
            storedWords = words
            return true
        }

        var snapshot: (MIDIProtocolID?, [UInt32]) {
            lock.lock()
            defer { lock.unlock() }
            return (storedProtocol, storedWords)
        }
    }

    func testMIDI2VirtualSourceDeliversNativeHighResolutionPitchThroughCoreMIDI() throws {
        let midi = MIDIEngine()
        midi.transportProtocol = .midi2
        midi.virtualMIDIEnabled = true
        defer { midi.virtualMIDIEnabled = false }

        guard let source = source(named: VirtualPort.main.rawValue) else {
            XCTFail("CoreMIDI did not expose the XPI Main virtual source")
            return
        }

        var receiverClient: MIDIClientRef = 0
        var inputPort: MIDIPortRef = 0
        let received = ReceivedEvent()
        let expectation = expectation(description: "Receive MIDI 2 UMP from XPI Main")

        XCTAssertEqual(
            MIDIClientCreateWithBlock("XPI MIDI2 Loopback Tests" as CFString, &receiverClient) { _ in },
            noErr
        )
        guard receiverClient != 0 else { return }
        defer { MIDIClientDispose(receiverClient) }

        let createPortStatus = MIDIInputPortCreateWithProtocol(
            receiverClient,
            "XPI MIDI2 Test Input" as CFString,
            ._2_0,
            &inputPort
        ) { eventList, _ in
            guard eventList.pointee.numPackets > 0 else { return }
            let packet = eventList.pointee.packet
            let wordCount = Int(packet.wordCount)
            guard wordCount > 0 else { return }

            let words: [UInt32] = withUnsafePointer(to: packet.words) { tuplePointer in
                tuplePointer.withMemoryRebound(to: UInt32.self, capacity: 64) { wordPointer in
                    Array(UnsafeBufferPointer(start: wordPointer, count: min(64, wordCount)))
                }
            }

            if received.recordIfEmpty(protocolID: eventList.pointee.protocol, words: words) {
                expectation.fulfill()
            }
        }

        XCTAssertEqual(createPortStatus, noErr)
        guard inputPort != 0 else { return }
        defer {
            MIDIPortDisconnectSource(inputPort, source)
            MIDIPortDispose(inputPort)
        }

        XCTAssertEqual(MIDIPortConnectSource(inputPort, source, nil), noErr)

        let semitoneOffset = 0.0002
        let bendRange = 48.0
        let expectedPitch = MIDI2UMPEncoder.pitchBend32(
            semitoneOffset: semitoneOffset,
            bendRangeSemitones: bendRange
        )

        midi.sendPitchBend(
            port: .main,
            channel: 2,
            semitoneOffset: semitoneOffset,
            bendRangeSemitones: bendRange
        )

        wait(for: [expectation], timeout: 2.0)

        let snapshot = received.snapshot
        XCTAssertEqual(snapshot.0, ._2_0)
        XCTAssertGreaterThanOrEqual(snapshot.1.count, 2)
        guard snapshot.1.count >= 2 else { return }

        // UMP type 0x4 = MIDI 2.0 Channel Voice; low nibble of status byte is channel 2.
        XCTAssertEqual(snapshot.1[0] >> 28, 0x4)
        XCTAssertEqual((snapshot.1[0] >> 16) & 0xFF, 0xE2)
        XCTAssertEqual(snapshot.1[1], expectedPitch)
        XCTAssertGreaterThan(expectedPitch, MIDI2UMPEncoder.pitchBendCentre)
    }

    private func source(named expectedName: String) -> MIDIEndpointRef? {
        let count = MIDIGetNumberOfSources()
        guard count > 0 else { return nil }

        for index in 0..<count {
            let endpoint = MIDIGetSource(index)
            guard endpoint != 0 else { continue }

            var unmanagedName: Unmanaged<CFString>?
            let status = MIDIObjectGetStringProperty(
                endpoint,
                kMIDIPropertyName,
                &unmanagedName
            )
            guard status == noErr, let unmanagedName else { continue }

            let name = unmanagedName.takeRetainedValue() as String
            if name == expectedName {
                return endpoint
            }
        }

        return nil
    }
}
