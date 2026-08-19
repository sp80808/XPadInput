import XCTest
@testable import XPadCore
@testable import XPadTheory
@testable import XPadMIDI

final class MIDITests: XCTestCase {

    // MARK: - Virtual Port Tests
    func testVirtualPorts() {
        XCTAssertEqual(VirtualPort.allCases.count, 6)
        XCTAssertEqual(VirtualPort.main.rawValue, "XPI Main")
        XCTAssertEqual(VirtualPort.chords.rawValue, "XPI Chords")
        XCTAssertEqual(VirtualPort.melody.rawValue, "XPI Melody")
        XCTAssertEqual(VirtualPort.bass.rawValue, "XPI Bass")
        XCTAssertEqual(VirtualPort.drums.rawValue, "XPI Drums")
        XCTAssertEqual(VirtualPort.mpe.rawValue, "XPI Expression (MPE)")
    }

    // MARK: - MIDIManager Lifecycle & Event Dispatching
    func testMIDIManagerDispatching() {
        let midi = MIDIManager.shared

        midi.sendNoteOn(port: .main, channel: 0, note: 60, velocity: 100)
        midi.sendPitchBend(port: .main, channel: 0, semitoneOffset: 2.0, bendRangeSemitones: 48.0)
        midi.sendPitchBend(port: .main, channel: 0, semitoneOffset: -2.0, bendRangeSemitones: 48.0)
        midi.sendPolyPressure(port: .main, channel: 0, note: 60, pressure: 80)
        midi.sendCC(port: .main, channel: 0, controller: 1, value: 64)
        midi.sendTimbreCC74(port: .mpe, channel: 1, value: 90)
        midi.sendNoteOff(port: .main, channel: 0, note: 60)

        midi.panic()
    }

    func testRepeatedNoteOnClosesPreviousVoiceDeterministically() {
        let midi = MIDIEngine()
        midi.clearMessageLog()

        midi.sendNoteOn(port: .main, channel: 0, note: 60, velocity: 90)
        midi.sendNoteOn(port: .main, channel: 0, note: 60, velocity: 100)

        XCTAssertEqual(
            midi.sentMessages.map(\.bytes),
            [
                [0x90, 60, 90],
                [0x80, 60, 0],
                [0x90, 60, 100]
            ]
        )
        XCTAssertEqual(midi.activeNoteCount, 1)

        midi.sendNoteOff(port: .main, channel: 0, note: 60)
        XCTAssertEqual(midi.activeNoteCount, 0)
        XCTAssertEqual(midi.sentMessages.last?.bytes, [0x80, 60, 0])
    }

    func testZeroVelocityNoteOnUsesCanonicalNoteOffPath() {
        let midi = MIDIEngine()
        midi.sendNoteOn(port: .melody, channel: 3, note: 72, velocity: 80)
        midi.clearMessageLog()

        midi.sendNoteOn(port: .melody, channel: 3, note: 72, velocity: 0)

        XCTAssertEqual(midi.sentMessages, [
            MIDIMessageRecord(port: .melody, bytes: [0x83, 72, 0])
        ])
        XCTAssertEqual(midi.activeNoteCount, 0)
    }

    func testOutOfRangeMIDIDataClampsInsteadOfWrapping() {
        let midi = MIDIEngine()
        midi.clearMessageLog()

        midi.sendNoteOn(port: .main, channel: 255, note: 255, velocity: 255)
        midi.sendCC(
            port: .main,
            channel: 255,
            controller: 255,
            value: 255
        )

        XCTAssertEqual(midi.sentMessages.map(\.bytes), [
            [0x9F, 127, 127],
            [0xBF, 127, 127]
        ])
    }

    func testAllNotesOffIsScopedAndNeutralizesDAWChannel() {
        let midi = MIDIEngine()
        midi.sendNoteOn(port: .drums, channel: 9, note: 36, velocity: 110)
        midi.sendNoteOn(port: .drums, channel: 9, note: 38, velocity: 105)
        midi.sendNoteOn(port: .main, channel: 0, note: 60, velocity: 95)
        midi.clearMessageLog()

        midi.sendAllNotesOff(port: .drums, channel: 9)

        let messages = midi.sentMessages
        XCTAssertEqual(Array(messages.prefix(2)).map(\.bytes), [
            [0x89, 36, 0],
            [0x89, 38, 0]
        ])
        XCTAssertTrue(messages.contains { $0.bytes == [0xE9, 0, 0x40] })
        XCTAssertTrue(messages.contains { $0.bytes == [0xB9, 64, 0] })
        XCTAssertTrue(messages.contains { $0.bytes == [0xB9, 66, 0] })
        XCTAssertTrue(messages.contains { $0.bytes == [0xB9, 121, 0] })
        XCTAssertTrue(messages.contains { $0.bytes == [0xB9, 123, 0] })
        XCTAssertTrue(messages.contains { $0.bytes == [0xB9, 120, 0] })
        XCTAssertEqual(midi.activeNoteCount, 1)

        midi.sendNoteOff(port: .main, channel: 0, note: 60)
        XCTAssertEqual(midi.activeNoteCount, 0)
    }

    func testPerformanceEventDispatchUsesSignedPitchBendAndPortRouting() {
        let midi = MIDIEngine()
        midi.clearMessageLog()

        midi.send(
            [
                PerformanceEvent.pitchBend(channel: 2, value: 0),
                .noteOn(channel: 2, note: 64, velocity: 96),
                .noteOff(channel: 2, note: 64)
            ],
            to: .mpe
        )

        XCTAssertEqual(midi.sentMessages, [
            MIDIMessageRecord(port: .mpe, bytes: [0xE2, 0, 0x40]),
            MIDIMessageRecord(port: .mpe, bytes: [0x92, 64, 96]),
            MIDIMessageRecord(port: .mpe, bytes: [0x82, 64, 0])
        ])
        XCTAssertEqual(midi.activeNoteCount, 0)
    }

    func testPanicClearsRunningNotesAndCriticalControllers() {
        let midi = MIDIEngine()
        midi.sendNoteOn(port: .chords, channel: 0, note: 60, velocity: 90)
        midi.sendNoteOn(port: .mpe, channel: 1, note: 67, velocity: 100)
        midi.clearMessageLog()

        midi.panic()

        XCTAssertEqual(midi.activeNoteCount, 0)
        XCTAssertTrue(midi.lastSentNotes.isEmpty)
        XCTAssertTrue(midi.sentMessages.contains {
            $0.port == .chords && $0.bytes == [0x80, 60, 0]
        })
        XCTAssertTrue(midi.sentMessages.contains {
            $0.port == .mpe && $0.bytes == [0x81, 67, 0]
        })
        XCTAssertTrue(midi.sentMessages.contains {
            $0.port == .mpe && $0.bytes == [0xB1, 64, 0]
        })
        XCTAssertTrue(midi.sentMessages.contains {
            $0.port == .mpe && $0.bytes == [0xB1, 123, 0]
        })
        XCTAssertTrue(midi.sentMessages.contains {
            $0.port == .mpe && $0.bytes == [0xB1, 120, 0]
        })
    }

    func testMessageLogRingKeepsNewestMessagesInDeliveryOrder() {
        let midi = MIDIEngine()
        midi.clearMessageLog()

        for index in 0..<2_052 {
            midi.sendCC(
                port: .main,
                channel: 0,
                controller: UInt8((index >> 7) & 0x7F),
                value: UInt8(index & 0x7F)
            )
        }

        let messages = midi.sentMessages
        XCTAssertEqual(messages.count, 2_048)
        XCTAssertEqual(messages.first?.bytes, [0xB0, 0, 4])
        XCTAssertEqual(messages.last?.bytes, [0xB0, 16, 3])
    }

    func testDisposalWithoutLiveEndpointsSkipsSyntheticPanicTraffic() {
        let midi = MIDIEngine()
        midi.sendNoteOn(port: .mpe, channel: 1, note: 60, velocity: 100)
        midi.clearMessageLog()

        midi.prepareForVirtualSourceDisposal()

        XCTAssertTrue(midi.sentMessages.isEmpty)
        XCTAssertEqual(midi.activeNoteCount, 0)
        XCTAssertTrue(midi.lastSentNotes.isEmpty)
    }

    // MARK: - MPEManager Tests
    func testMPEManagerMultiVoiceAllocation() {
        let mpe = MPEManager(midiManager: MIDIManager.shared)

        mpe.sendMPEZoneConfiguration()

        let chordNotes: [UInt8] = [60, 64, 67, 71]

        for (index, note) in chordNotes.enumerated() {
            mpe.noteOn(note: note, velocity: UInt8(90 + index * 5))
            mpe.setPitchBend(for: note, semitones: Double(index) * 0.5)
            mpe.setPressure(for: note, pressure: UInt8(60 + index * 10))
            mpe.setTimbre(for: note, value: UInt8(40 + index * 20))
        }

        mpe.noteOff(note: 60)
        mpe.stopAllNotes()
    }

    func testMPEZoneLayoutAdvertisesHostMemberCount() {
        let midi = MIDIEngine()
        let mpe = MPEManager(midiEngine: midi)
        midi.clearMessageLog()

        mpe.applyZoneLayout(.lowerFifteen, sendConfiguration: true)
        XCTAssertEqual(mpe.currentZoneLayout.memberCount, 15)
        XCTAssertTrue(
            midi.sentMessages.contains { $0.port == .mpe && $0.bytes == [0xB0, 6, 15] },
            "Lower-zone MCM must declare 15 member channels for Logic/Live/Bitwig."
        )

        midi.clearMessageLog()
        mpe.applyZoneLayout(.upperFifteen, sendConfiguration: true)
        XCTAssertTrue(
            midi.sentMessages.contains { $0.port == .mpe && $0.bytes == [0xBF, 6, 15] },
            "Upper-zone MCM is sent on master MIDI channel 16."
        )
        mpe.noteOn(note: 61, velocity: 100)
        XCTAssertEqual(mpe.activeVoice(for: 61)?.channel, 14)
    }

    func testMPEPitchBendLifecycleAndChannelIsolation() {
        let midi = MIDIEngine()
        let mpe = MPEManager(midiEngine: midi, bendRangeSemitones: 2)
        midi.clearMessageLog()

        mpe.noteOn(note: 60, velocity: 100)
        XCTAssertEqual(mpe.activeVoice(for: 60)?.channel, 1)

        let attack = midi.sentMessages
        XCTAssertEqual(attack.first?.port, .mpe)
        XCTAssertEqual(attack.first?.bytes, [0xE1, 0x00, 0x40])
        XCTAssertEqual(attack.last?.bytes, [0x91, 60, 100])

        mpe.noteOn(note: 64, velocity: 90)
        XCTAssertEqual(mpe.activeVoice(for: 64)?.channel, 2)

        midi.clearMessageLog()
        mpe.setPitchBend(for: 60, semitones: 2)
        XCTAssertEqual(midi.sentMessages.last?.bytes, [0xE1, 0x7F, 0x7F])
        XCTAssertEqual(mpe.activeVoice(for: 60)?.currentPitchBend, 2)

        mpe.setPitchBend(for: 60, semitones: 0)
        XCTAssertEqual(midi.sentMessages.last?.bytes, [0xE1, 0x00, 0x40])

        midi.clearMessageLog()
        mpe.noteOff(note: 60)
        XCTAssertEqual(midi.sentMessages.first?.bytes, [0x81, 60, 0])
        XCTAssertTrue(midi.sentMessages.contains { $0.bytes == [0xE1, 0x00, 0x40] })
        XCTAssertNil(mpe.activeVoice(for: 60))
        XCTAssertEqual(mpe.activeVoiceCount, 1)
    }

    func testMPEVoiceStealReleasesAndResetsBeforeChannelReuse() {
        let midi = MIDIEngine()
        let mpe = MPEManager(midiEngine: midi)
        for note: UInt8 in 60..<74 {
            mpe.noteOn(note: note, velocity: 90)
        }
        XCTAssertEqual(mpe.activeVoiceCount, 14)
        XCTAssertEqual(mpe.voice(for: 60)?.channel, 1)

        midi.clearMessageLog()
        mpe.noteOn(note: 74, velocity: 101)

        XCTAssertNil(mpe.voice(for: 60))
        XCTAssertEqual(mpe.voice(for: 74)?.channel, 1)
        XCTAssertEqual(mpe.activeVoiceCount, 14)
        XCTAssertEqual(midi.sentMessages.map(\.bytes), [
            [0x81, 60, 0],
            [0xE1, 0, 0x40],
            [0xD1, 0],
            [0xB1, 74, 64],
            [0x91, 74, 101]
        ])
    }

    func testRepeatedMPEAttackReusesChannelWithoutStealingPolyphony() {
        let midi = MIDIEngine()
        let mpe = MPEManager(midiEngine: midi)
        for note: UInt8 in 60..<74 {
            mpe.noteOn(note: note, velocity: 90)
        }
        let originalChannel = mpe.voice(for: 70)?.channel
        XCTAssertEqual(mpe.activeVoiceCount, 14)

        midi.clearMessageLog()
        mpe.noteOn(note: 70, velocity: 105)

        XCTAssertEqual(mpe.activeVoiceCount, 14)
        XCTAssertEqual(mpe.voice(for: 70)?.channel, originalChannel)
        XCTAssertNotNil(mpe.voice(for: 60))
        XCTAssertEqual(midi.sentMessages.map(\.bytes), [
            [0x8B, 70, 0],
            [0xEB, 0, 0x40],
            [0xDB, 0],
            [0xBB, 74, 64],
            [0x9B, 70, 105]
        ])
    }

    func testMPEExpressionCoalescesUnchangedWireValues() {
        let midi = MIDIEngine()
        let mpe = MPEManager(midiEngine: midi, bendRangeSemitones: 48)
        mpe.noteOn(note: 60, velocity: 100)
        midi.clearMessageLog()

        // The mandatory neutral reset happened before Note On; matching first
        // input frames do not need to repeat it.
        mpe.setPitchBend(for: 60, semitones: 0)
        mpe.setPressure(for: 60, pressure: 0)
        mpe.setTimbre(for: 60, value: 64)
        XCTAssertTrue(midi.sentMessages.isEmpty)

        mpe.setPitchBend(for: 60, semitones: 1)
        mpe.setPressure(for: 60, pressure: 80)
        mpe.setTimbre(for: 60, value: 90)
        XCTAssertEqual(midi.sentMessages.count, 3)

        for _ in 0..<32 {
            mpe.setPitchBend(for: 60, semitones: 1)
            mpe.setPressure(for: 60, pressure: 80)
            mpe.setTimbre(for: 60, value: 90)
        }
        // A sub-resolution bend change maps to the same MIDI 14-bit value.
        XCTAssertEqual(
            MIDIEngine.pitchBendValue(semitoneOffset: 1, bendRangeSemitones: 48),
            MIDIEngine.pitchBendValue(semitoneOffset: 1.0001, bendRangeSemitones: 48)
        )
        mpe.setPitchBend(for: 60, semitones: 1.0001)

        XCTAssertEqual(midi.sentMessages.count, 3)
    }

    func testMPEStopAllResetsAllocatorAndChannelState() {
        let midi = MIDIEngine()
        let mpe = MPEManager(midiEngine: midi)
        mpe.noteOn(note: 60, velocity: 90)
        mpe.noteOn(note: 64, velocity: 90)

        midi.clearMessageLog()
        mpe.stopAllNotes()
        XCTAssertEqual(mpe.activeVoiceCount, 0)
        XCTAssertEqual(midi.activeNoteCount, 0)
        XCTAssertTrue(midi.sentMessages.contains { $0.bytes == [0xB1, 123, 0] })
        XCTAssertTrue(midi.sentMessages.contains { $0.bytes == [0xB2, 123, 0] })

        midi.clearMessageLog()
        mpe.noteOn(note: 67, velocity: 92)
        XCTAssertEqual(mpe.voice(for: 67)?.channel, 1)
        XCTAssertEqual(midi.sentMessages.last?.bytes, [0x91, 67, 92])
    }

    func testIdlePhraseNoteOnDoesNotDumpMPEZone() {
        let midi = MIDIEngine()
        let mpe = MPEManager(midiEngine: midi, bendRangeSemitones: 48)
        mpe.sendMPEZoneConfiguration()
        midi.clearMessageLog()

        mpe.noteOn(note: 60, velocity: 90)

        XCTAssertFalse(
            midi.sentMessages.contains { $0.port == .mpe && $0.bytes == [0xB0, 101, 0] },
            "Attack must not re-send the 14-channel zone dump; that belongs on virtual MIDI enable."
        )
        XCTAssertEqual(midi.sentMessages.first?.bytes, [0xE1, 0x00, 0x40])
        XCTAssertEqual(midi.sentMessages.last?.bytes, [0x91, 60, 90])

        mpe.noteOff(note: 60)
        midi.clearMessageLog()
        mpe.noteOn(note: 64, velocity: 88)
        XCTAssertFalse(midi.sentMessages.contains { $0.bytes == [0xB0, 101, 0] })
        XCTAssertEqual(midi.sentMessages.last?.bytes, [0x92, 64, 88])
    }

    func testPitchBendCodecEndpoints() {
        XCTAssertEqual(MIDIEngine.pitchBendValue(semitoneOffset: -2, bendRangeSemitones: 2), 0)
        XCTAssertEqual(MIDIEngine.pitchBendValue(semitoneOffset: 0, bendRangeSemitones: 2), 8192)
        XCTAssertEqual(MIDIEngine.pitchBendValue(semitoneOffset: 2, bendRangeSemitones: 2), 16_383)
    }

    // MARK: - SMFExporter (Standard MIDI File) Tests
    func testSMFExporterBinaryStructure() {
        let exporter = SMFExporter()

        let events: [RecordedNoteEvent] = [
            RecordedNoteEvent(note: 60, velocity: 100, startTick: 0, durationTicks: 480),
            RecordedNoteEvent(note: 64, velocity: 110, startTick: 480, durationTicks: 480),
            RecordedNoteEvent(note: 67, velocity: 95, startTick: 960, durationTicks: 960)
        ]

        let data = exporter.encode(events: events, bpm: 120.0, ppqn: 480)

        XCTAssertFalse(data.isEmpty)
        XCTAssertTrue(data.count > 30)

        // 1. Validate "MThd" header chunk (bytes 0..3)
        let mthdHeader = Array(data[0..<4])
        XCTAssertEqual(mthdHeader, [0x4D, 0x54, 0x68, 0x64])

        // 2. Validate header length = 6 (bytes 4..7)
        let headerLength = Array(data[4..<8])
        XCTAssertEqual(headerLength, [0x00, 0x00, 0x00, 0x06])

        // 3. Validate format = 0 (bytes 8..9)
        let format = Array(data[8..<10])
        XCTAssertEqual(format, [0x00, 0x00])

        // 4. Validate tracks = 1 (bytes 10..11)
        let tracks = Array(data[10..<12])
        XCTAssertEqual(tracks, [0x00, 0x01])

        // 5. Validate PPQN = 480 (0x01E0) (bytes 12..13)
        let division = Array(data[12..<14])
        XCTAssertEqual(division, [0x01, 0xE0])

        // 6. Validate "MTrk" track chunk header
        let mtrkHeader = Array(data[14..<18])
        XCTAssertEqual(mtrkHeader, [0x4D, 0x54, 0x72, 0x6B])

        // 7. Validate End of Track Meta Event (FF 2F 00) at tail
        let tail = Array(data.suffix(3))
        XCTAssertEqual(tail, [0xFF, 0x2F, 0x00])
    }

    func testSMFExporterEmptyEvents() {
        let exporter = SMFExporter()
        let data = exporter.encode(events: [], bpm: 140.0, ppqn: 960)
        XCTAssertFalse(data.isEmpty)
        XCTAssertTrue(data.count >= 22)
    }
}
