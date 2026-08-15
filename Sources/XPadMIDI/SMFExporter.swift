import Foundation
import XPadCore

public struct RecordedNoteEvent: Codable, Sendable {
    public let note: UInt8
    public let velocity: UInt8
    public let startTick: UInt64
    public let durationTicks: UInt64

    public init(note: UInt8, velocity: UInt8, startTick: UInt64, durationTicks: UInt64) {
        self.note = note
        self.velocity = velocity
        self.startTick = startTick
        self.durationTicks = durationTicks
    }
}

public struct SMFExporter: Sendable {
    public init() {}

    /// Encodes note events into Standard MIDI File Type 0 (Single Track) binary data.
    public func encode(events: [RecordedNoteEvent], bpm: Double = 120.0, ppqn: UInt16 = 480) -> Data {
        var midiData = Data()

        // 1. Header Chunk: "MThd", length = 6, format = 0, tracks = 1, division = ppqn
        midiData.append(contentsOf: [0x4D, 0x54, 0x68, 0x64]) // "MThd"
        midiData.append(contentsOf: UInt32(6).bigEndianBytes)
        midiData.append(contentsOf: UInt16(0).bigEndianBytes) // Format 0
        midiData.append(contentsOf: UInt16(1).bigEndianBytes) // 1 Track
        midiData.append(contentsOf: ppqn.bigEndianBytes)

        // 2. Build Track Events
        var trackEvents: [(tick: UInt64, bytes: [UInt8])] = []

        // Set Tempo Meta Event (Microseconds per quarter note = 60,000,000 / BPM)
        let usPerQuarter = UInt32(60_000_000.0 / max(20.0, bpm))
        let tempoBytes: [UInt8] = [
            0xFF, 0x51, 0x03,
            UInt8((usPerQuarter >> 16) & 0xFF),
            UInt8((usPerQuarter >> 8) & 0xFF),
            UInt8(usPerQuarter & 0xFF)
        ]
        trackEvents.append((tick: 0, bytes: tempoBytes))

        for event in events {
            // Note On
            trackEvents.append((tick: event.startTick, bytes: [0x90, event.note, event.velocity]))
            // Note Off
            trackEvents.append((tick: event.startTick + event.durationTicks, bytes: [0x80, event.note, 0]))
        }

        // Sort chronologically
        trackEvents.sort { $0.tick < $1.tick }

        // Encode with delta-times
        var trackData = Data()
        var lastTick: UInt64 = 0

        for item in trackEvents {
            let delta = item.tick >= lastTick ? item.tick - lastTick : 0
            lastTick = item.tick
            trackData.append(contentsOf: encodeVariableLength(delta))
            trackData.append(contentsOf: item.bytes)
        }

        // End of Track Meta Event
        trackData.append(contentsOf: encodeVariableLength(0))
        trackData.append(contentsOf: [0xFF, 0x2F, 0x00])

        // 3. Track Chunk: "MTrk", length, data
        midiData.append(contentsOf: [0x4D, 0x54, 0x72, 0x6B]) // "MTrk"
        midiData.append(contentsOf: UInt32(trackData.count).bigEndianBytes)
        midiData.append(trackData)

        return midiData
    }

    private func encodeVariableLength(_ value: UInt64) -> [UInt8] {
        var v = value
        var buffer: [UInt8] = [UInt8(v & 0x7F)]
        while (v >> 7) > 0 {
            v >>= 7
            buffer.insert(UInt8((v & 0x7F) | 0x80), at: 0)
        }
        return buffer
    }
}

private extension FixedWidthInteger {
    var bigEndianBytes: [UInt8] {
        var be = self.bigEndian
        return withUnsafeBytes(of: &be) { Array($0) }
    }
}
