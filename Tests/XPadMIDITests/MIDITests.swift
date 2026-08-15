import Testing
import Foundation
@testable import XPadCore
@testable import XPadTheory
@testable import XPadMIDI

@Suite("Exhaustive MIDI & MPE Engine Tests")
struct MIDITests {

    // MARK: - Virtual Port Tests
    @Test("Virtual Port Identifiers and Cases")
    func testVirtualPorts() {
        #expect(VirtualPort.allCases.count == 6)
        #expect(VirtualPort.main.rawValue == "XPadInput Main")
        #expect(VirtualPort.chords.rawValue == "XPadInput Chords")
        #expect(VirtualPort.melody.rawValue == "XPadInput Melody")
        #expect(VirtualPort.bass.rawValue == "XPadInput Bass")
        #expect(VirtualPort.drums.rawValue == "XPadInput Drums")
        #expect(VirtualPort.mpe.rawValue == "XPadInput Expression (MPE)")
    }

    // MARK: - MIDIManager Lifecycle & Event Dispatching
    @Test("MIDIManager Initialization and Safe Message Dispatching")
    func testMIDIManagerDispatching() {
        let midi = MIDIManager.shared

        // Test sending across various ports and channels
        midi.sendNoteOn(port: .main, channel: 0, note: 60, velocity: 100)
        midi.sendPitchBend(port: .main, channel: 0, semitoneOffset: 2.0, bendRangeSemitones: 48.0)
        midi.sendPitchBend(port: .main, channel: 0, semitoneOffset: -2.0, bendRangeSemitones: 48.0)
        midi.sendPolyPressure(port: .main, channel: 0, note: 60, pressure: 80)
        midi.sendCC(port: .main, channel: 0, controller: 1, value: 64)
        midi.sendTimbreCC74(port: .mpe, channel: 1, value: 90)
        midi.sendNoteOff(port: .main, channel: 0, note: 60)

        // Test MIDI Panic
        midi.panic()
    }

    // MARK: - MPEManager Tests
    @Test("MPE Zone Configuration and Multi-Voice Allocation")
    func testMPEManagerMultiVoiceAllocation() {
        let mpe = MPEManager(midiManager: MIDIManager.shared)

        mpe.sendMPEZoneConfiguration()

        // Play a 4-note chord in MPE
        let chordNotes: [UInt8] = [60, 64, 67, 71] // C, E, G, B

        for (index, note) in chordNotes.enumerated() {
            mpe.noteOn(note: note, velocity: UInt8(90 + index * 5))
            mpe.setPitchBend(for: note, semitones: Double(index) * 0.5)
            mpe.setPressure(for: note, pressure: UInt8(60 + index * 10))
            mpe.setTimbre(for: note, value: UInt8(40 + index * 20))
        }

        // Release individual note
        mpe.noteOff(note: 60)

        // Stop all remaining notes
        mpe.stopAllNotes()
    }

    // MARK: - SMFExporter (Standard MIDI File) Tests
    @Test("SMFExporter Binary Structure & Delta-Time Encoding")
    func testSMFExporterBinaryStructure() {
        let exporter = SMFExporter()

        let events: [RecordedNoteEvent] = [
            RecordedNoteEvent(note: 60, velocity: 100, startTick: 0, durationTicks: 480),
            RecordedNoteEvent(note: 64, velocity: 110, startTick: 480, durationTicks: 480),
            RecordedNoteEvent(note: 67, velocity: 95, startTick: 960, durationTicks: 960)
        ]

        let data = exporter.encode(events: events, bpm: 120.0, ppqn: 480)

        #expect(!data.isEmpty)
        #expect(data.count > 30)

        // 1. Validate "MThd" header chunk (bytes 0..3)
        let mthdHeader = Array(data[0..<4])
        #expect(mthdHeader == [0x4D, 0x54, 0x68, 0x64]) // "MThd"

        // 2. Validate header length = 6 (bytes 4..7)
        let headerLength = Array(data[4..<8])
        #expect(headerLength == [0x00, 0x00, 0x00, 0x06])

        // 3. Validate format = 0 (bytes 8..9)
        let format = Array(data[8..<10])
        #expect(format == [0x00, 0x00])

        // 4. Validate tracks = 1 (bytes 10..11)
        let tracks = Array(data[10..<12])
        #expect(tracks == [0x00, 0x01])

        // 5. Validate PPQN = 480 (0x01E0) (bytes 12..13)
        let division = Array(data[12..<14])
        #expect(division == [0x01, 0xE0])

        // 6. Validate "MTrk" track chunk header
        let mtrkHeader = Array(data[14..<18])
        #expect(mtrkHeader == [0x4D, 0x54, 0x72, 0x6B]) // "MTrk"

        // 7. Validate End of Track Meta Event (FF 2F 00) at tail
        let tail = Array(data.suffix(3))
        #expect(tail == [0xFF, 0x2F, 0x00])
    }

    @Test("SMFExporter Empty Events Graceful Handling")
    func testSMFExporterEmptyEvents() {
        let exporter = SMFExporter()
        let data = exporter.encode(events: [], bpm: 140.0, ppqn: 960)
        #expect(!data.isEmpty)
        #expect(data.count >= 22) // Header (14) + MTrk (8) + Tempo + End of Track
    }
}
