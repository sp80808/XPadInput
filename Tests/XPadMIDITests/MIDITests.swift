import XCTest
@testable import XPadCore
@testable import XPadTheory
@testable import XPadMIDI

final class MIDITests: XCTestCase {

    // MARK: - Virtual Port Tests
    func testVirtualPorts() {
        XCTAssertEqual(VirtualPort.allCases.count, 6)
        XCTAssertEqual(VirtualPort.main.rawValue, "XPadInput Main")
        XCTAssertEqual(VirtualPort.chords.rawValue, "XPadInput Chords")
        XCTAssertEqual(VirtualPort.melody.rawValue, "XPadInput Melody")
        XCTAssertEqual(VirtualPort.bass.rawValue, "XPadInput Bass")
        XCTAssertEqual(VirtualPort.drums.rawValue, "XPadInput Drums")
        XCTAssertEqual(VirtualPort.mpe.rawValue, "XPadInput Expression (MPE)")
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
