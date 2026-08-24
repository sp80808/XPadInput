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
        var trackEvents: [(tick: UInt64, bytes: [UInt8])] = []

        for event in events {
            trackEvents.append((tick: event.startTick, bytes: [0x90, event.note, event.velocity]))
            trackEvents.append((tick: event.startTick + event.durationTicks, bytes: [0x80, event.note, 0]))
        }

        return encodeTrack(events: trackEvents, bpm: bpm, ppqn: ppqn)
    }

    /// Translates recorded techniques into SMF with pitch bend, pressure, and CC74.
    public func encodeTechniques(
        events: [RecordedTechniqueEvent],
        bpm: Double = 120.0,
        ppqn: UInt16 = 960,
        bendRange: Double = 48.0,
        mpe: Bool = true
    ) -> Data {
        var trackEvents: [(tick: UInt64, bytes: [UInt8])] = []
        let rangeMSB = UInt8(Int(bendRange.rounded()).clamped(to: 0...127))

        // Pitch-bend sensitivity RPN on the zone/master channel so importers know the range.
        trackEvents.append((0, [0xB0, 101, 0]))
        trackEvents.append((0, [0xB0, 100, 0]))
        trackEvents.append((0, [0xB0, 6, rangeMSB]))
        trackEvents.append((0, [0xB0, 38, 0]))

        for item in events {
            let channel: UInt8 = mpe ? UInt8((Int(item.event.note.midiNote) % 14) + 1) : 0
            let duration = item.durationTicks > 0 ? item.durationTicks : 240
            let note = item.event.note.midiNote

            trackEvents.append((item.tick, [0x90 | channel, note, item.event.velocity]))
            trackEvents.append((item.tick + duration, [0x80 | channel, note, 0]))

            if abs(item.event.pitchOffset) > 0.01 {
                let bend = PitchBendCodec.value(semitones: item.event.pitchOffset, range: bendRange)
                trackEvents.append((item.tick, [
                    0xE0 | channel,
                    UInt8(bend & 0x7F),
                    UInt8((bend >> 7) & 0x7F)
                ]))
                trackEvents.append((item.tick + duration, [0xE0 | channel, 0x00, 0x40]))
            }
            if item.event.pressure > 0.02 {
                let p = UInt8(min(127, Int((item.event.pressure * 127).rounded())))
                trackEvents.append((item.tick, [0xD0 | channel, p]))
            }
            if abs(item.event.timbre - 0.5) > 0.05 {
                let t = UInt8(min(127, Int((item.event.timbre * 127).rounded())))
                trackEvents.append((item.tick, [0xB0 | channel, 74, t]))
            }
        }

        return encodeTrack(events: trackEvents, bpm: bpm, ppqn: ppqn)
    }

    private func encodeTrack(
        events: [(tick: UInt64, bytes: [UInt8])],
        bpm: Double,
        ppqn: UInt16
    ) -> Data {
        var midiData = Data()

        midiData.append(contentsOf: [0x4D, 0x54, 0x68, 0x64]) // "MThd"
        midiData.append(contentsOf: UInt32(6).bigEndianBytes)
        midiData.append(contentsOf: UInt16(0).bigEndianBytes) // Format 0
        midiData.append(contentsOf: UInt16(1).bigEndianBytes) // 1 Track
        midiData.append(contentsOf: ppqn.bigEndianBytes)

        let usPerQuarter = UInt32(60_000_000.0 / max(20.0, bpm))
        let tempoBytes: [UInt8] = [
            0xFF, 0x51, 0x03,
            UInt8((usPerQuarter >> 16) & 0xFF),
            UInt8((usPerQuarter >> 8) & 0xFF),
            UInt8(usPerQuarter & 0xFF)
        ]
        var indexedEvents: [(order: Int, tick: UInt64, bytes: [UInt8])] = [
            (order: 0, tick: 0, bytes: tempoBytes)
        ]
        for (idx, event) in events.enumerated() {
            indexedEvents.append((order: idx + 1, tick: event.tick, bytes: event.bytes))
        }
        indexedEvents.sort { lhs, rhs in
            if lhs.tick != rhs.tick {
                return lhs.tick < rhs.tick
            }
            return lhs.order < rhs.order
        }

        var trackData = Data()
        var lastTick: UInt64 = 0
        for item in indexedEvents {
            let delta = item.tick >= lastTick ? item.tick - lastTick : 0
            lastTick = item.tick
            trackData.append(contentsOf: encodeVariableLength(delta))
            trackData.append(contentsOf: item.bytes)
        }

        trackData.append(contentsOf: encodeVariableLength(0))
        trackData.append(contentsOf: [0xFF, 0x2F, 0x00])

        midiData.append(contentsOf: [0x4D, 0x54, 0x72, 0x6B]) // "MTrk"
        midiData.append(contentsOf: UInt32(trackData.count).bigEndianBytes)
        midiData.append(trackData)
        return midiData
    }

    public func encodeVariableLength(_ value: UInt64) -> [UInt8] {
        var v = min(value, 0x0FFFFFFF)
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
