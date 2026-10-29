import XCTest
import AudioToolbox
import AVFoundation
import XPadAudio

final class AUv3NoteOwnershipTests: XCTestCase {
    func testMIDIProcessorKeepsOverlappingChannelsIndependentAndPairsRepeatedNotes() throws {
        let processor = try XPadAUMIDIFX(
            componentDescription: XPadPluginRegistrar.midiFXComponentDescription
        )
        var emitted: [[UInt8]] = []
        processor.midiOutputEventBlock = { _, _, length, data in
            emitted.append(Array(UnsafeBufferPointer(start: data, count: length)))
            return noErr
        }
        try processor.allocateRenderResources()
        defer { processor.deallocateRenderResources() }

        let render = processor.internalRenderBlock
        func send(_ status: UInt8, note: UInt8 = 60, velocity: UInt8 = 100) {
            var flags: AudioUnitRenderActionFlags = []
            var timestamp = AudioTimeStamp()
            timestamp.mSampleTime = 0
            timestamp.mFlags = .sampleTimeValid
            var event = AURenderEvent()
            event.head.eventType = .MIDI
            event.head.eventSampleTime = 0
            event.MIDI.data = (status, note, velocity)
            event.MIDI.length = 3
            var audioBuffers = AudioBufferList()
            let result = withUnsafePointer(to: &event) {
                render(&flags, &timestamp, 64, 0, &audioBuffers, $0, nil)
            }
            XCTAssertEqual(result, noErr)
        }

        // The same input pitch is held on MIDI channels 1 and 2.
        send(0x90)
        let notesOnChannel1 = emitted.map { $0[1] }
        XCTAssertFalse(notesOnChannel1.isEmpty)
        XCTAssertTrue(emitted.allSatisfy { $0[0] == 0x90 })

        let channel2Start = emitted.count
        send(0x91)
        let notesOnChannel2 = Array(emitted.dropFirst(channel2Start)).map { $0[1] }
        XCTAssertFalse(notesOnChannel2.isEmpty)
        XCTAssertTrue(emitted.dropFirst(channel2Start).allSatisfy { $0[0] == 0x91 })

        // An unrelated channel must not release either of the held notes.
        let unrelatedStart = emitted.count
        send(0x82, velocity: 0)
        XCTAssertEqual(emitted.count, unrelatedStart)

        let channel1OffStart = emitted.count
        send(0x80, velocity: 0)
        let channel1Off = Array(emitted.dropFirst(channel1OffStart))
        XCTAssertEqual(channel1Off.map { $0[1] }, notesOnChannel1)
        XCTAssertTrue(channel1Off.allSatisfy { $0[0] == 0x80 })

        let channel2OffStart = emitted.count
        send(0x81, velocity: 0)
        let channel2Off = Array(emitted.dropFirst(channel2OffStart))
        XCTAssertEqual(channel2Off.map { $0[1] }, notesOnChannel2)
        XCTAssertTrue(channel2Off.allSatisfy { $0[0] == 0x81 })

        // Retriggering the same pitch on one channel must retain both voicings.
        let firstStart = emitted.count
        send(0x90)
        let firstVoicing = Array(emitted.dropFirst(firstStart)).map { $0[1] }
        let secondStart = emitted.count
        send(0x90, velocity: 110)
        let secondVoicing = Array(emitted.dropFirst(secondStart)).map { $0[1] }

        let firstReleaseStart = emitted.count
        send(0x90, velocity: 0) // MIDI 1 zero-velocity note-on is note-off.
        let firstRelease = Array(emitted.dropFirst(firstReleaseStart))
        XCTAssertEqual(firstRelease.map { $0[1] }, secondVoicing)
        XCTAssertTrue(firstRelease.allSatisfy { $0[0] == 0x80 })

        let secondReleaseStart = emitted.count
        send(0x80, velocity: 0)
        let secondRelease = Array(emitted.dropFirst(secondReleaseStart))
        XCTAssertEqual(secondRelease.map { $0[1] }, firstVoicing)
        XCTAssertTrue(secondRelease.allSatisfy { $0[0] == 0x80 })

        let noExtraReleaseStart = emitted.count
        send(0x80, velocity: 0)
        XCTAssertEqual(emitted.count, noExtraReleaseStart)
    }
}
