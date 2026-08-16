import Foundation
import CoreMIDI
import XPadCore

/// Standards-aligned MIDI Clip File (M2-116-U v1.0) / SMF2 binary encoder & parser.
///
/// Encodes Universal MIDI Packet (UMP) event sequences preserving native 16-bit
/// velocity, 32-bit pitch bend, and 32-bit per-note articulation without flattening.
public enum SMF2Exporter {
    public static let headerMagic: [UInt8] = [0x53, 0x4D, 0x46, 0x32] // "SMF2"
    public static let trackMagic: [UInt8] = [0x4D, 0x32, 0x54, 0x52]  // "M2TR"
    public static let defaultPPQN: UInt16 = 960

    /// Encodes a list of recorded note events into standard MIDI Clip File / SMF2 binary format.
    public static func export(
        events: [RecordedNoteEvent],
        channel: UInt8 = 0,
        ppqn: UInt16 = defaultPPQN
    ) -> Data {
        var allEvents: [TimedUMPEvent] = []

        for noteEvent in events {
            let startTick = noteEvent.startTick
            let endTick = startTick + noteEvent.durationTicks

            let vel16 = MIDI2UMPEncoder.scale7To16(noteEvent.velocity)

            // 64-bit Note On UMP
            let noteOnWord0: UInt32 = (0x4 << 28)
                | (0x00 << 24) // Group 0
                | (0x90 << 16) // Status 0x90 = Note On
                | (UInt32(channel & 0x0F) << 16)
                | (UInt32(noteEvent.note & 0x7F) << 8)
            let noteOnWord1: UInt32 = UInt32(vel16) << 16
            allEvents.append(TimedUMPEvent(tick: startTick, words: [noteOnWord0, noteOnWord1]))

            // 64-bit Note Off UMP
            let noteOffWord0: UInt32 = (0x4 << 28)
                | (0x00 << 24)
                | (0x80 << 16) // Status 0x80 = Note Off
                | (UInt32(channel & 0x0F) << 16)
                | (UInt32(noteEvent.note & 0x7F) << 8)
            let noteOffWord1: UInt32 = 0
            allEvents.append(TimedUMPEvent(tick: endTick, words: [noteOffWord0, noteOffWord1]))
        }

        // Sort events chronologically
        allEvents.sort { $0.tick < $1.tick }

        return encodeStream(events: allEvents, ppqn: ppqn)
    }

    /// Encodes a list of Timed UMP events into the standard binary SMF2 file structure.
    public static func encodeStream(
        events: [TimedUMPEvent],
        ppqn: UInt16 = defaultPPQN
    ) -> Data {
        var fileData = Data()

        // 1. File Header Chunk ('SMF2')
        fileData.append(contentsOf: headerMagic)
        fileData.append(UInt32(8).bigEndianData) // Header length = 8 bytes
        fileData.append(UInt16(1).bigEndianData) // Format version = 1 (Single Clip)
        fileData.append(ppqn.bigEndianData)      // PPQN division (960)
        fileData.append(UInt16(1).bigEndianData) // Number of tracks = 1
        fileData.append(UInt16(0).bigEndianData) // Reserved / flags

        // 2. Track Data Chunk ('M2TR')
        var trackPayload = Data()
        var lastTick: UInt64 = 0

        for event in events {
            let deltaTicks = event.tick > lastTick ? (event.tick - lastTick) : 0
            lastTick = event.tick

            // Emit Delta-Clock UMP (Type 0x0, Status 0x2) if time elapsed
            if deltaTicks > 0 {
                var remainingTicks = deltaTicks
                while remainingTicks > 0 {
                    let chunkTicks = min(UInt64(0x00FF_FFFF), remainingTicks)
                    let deltaWord: UInt32 = (0x0 << 28) | (0x2 << 24) | UInt32(chunkTicks & 0x00FF_FFFF)
                    trackPayload.append(deltaWord.bigEndianData)
                    remainingTicks -= chunkTicks
                }
            }

            // Emit Message UMP words
            for word in event.words {
                trackPayload.append(word.bigEndianData)
            }
        }

        // End of Sequence (Type 0x0 Utility NOOP 0x00000000)
        let endWord: UInt32 = 0x0000_0000
        trackPayload.append(endWord.bigEndianData)

        // Write Track Chunk Header and Payload
        fileData.append(contentsOf: trackMagic)
        fileData.append(UInt32(trackPayload.count).bigEndianData)
        fileData.append(trackPayload)

        return fileData
    }
}

// MARK: - SMF2 Parser & Round-Trip Validator

public struct ParsedSMF2Clip {
    public let formatVersion: UInt16
    public let ppqn: UInt16
    public let trackCount: UInt16
    public let events: [TimedUMPEvent]
}

public enum SMF2Parser {
    public enum ParseError: Error {
        case invalidHeaderMagic
        case invalidTrackMagic
        case fileTooShort
        case malformedPayload
    }

    public static func parse(data: Data) throws -> ParsedSMF2Clip {
        guard data.count >= 24 else { throw ParseError.fileTooShort }

        // Read SMF2 Header
        let headerMagic = Array(data[0..<4])
        guard headerMagic == SMF2Exporter.headerMagic else {
            throw ParseError.invalidHeaderMagic
        }

        let formatVersion = data.readUInt16(at: 8)
        let ppqn = data.readUInt16(at: 10)
        let trackCount = data.readUInt16(at: 12)

        // Read M2TR Track Header
        let trackMagic = Array(data[16..<20])
        guard trackMagic == SMF2Exporter.trackMagic else {
            throw ParseError.invalidTrackMagic
        }

        let trackLength = Int(data.readUInt32(at: 20))
        guard data.count >= 24 + trackLength else {
            throw ParseError.malformedPayload
        }

        var offset = 24
        let endOffset = 24 + trackLength
        var currentTick: UInt64 = 0
        var parsedEvents: [TimedUMPEvent] = []

        while offset + 4 <= endOffset {
            let word0 = data.readUInt32(at: offset)
            let messageType = (word0 >> 28) & 0x0F
            offset += 4

            if messageType == 0x0 {
                // Utility Message
                let status = (word0 >> 24) & 0x0F
                if status == 0x2 {
                    // Delta Clock
                    let delta = UInt64(word0 & 0x00FF_FFFF)
                    currentTick += delta
                }
            } else if messageType == 0x4 {
                // MIDI 2.0 Channel Voice (64-bit / 2 words)
                guard offset + 4 <= endOffset else { break }
                let word1 = data.readUInt32(at: offset)
                offset += 4
                parsedEvents.append(TimedUMPEvent(tick: currentTick, words: [word0, word1]))
            } else if messageType == 0x2 {
                // MIDI 1.0 Channel Voice in UMP (32-bit / 1 word)
                parsedEvents.append(TimedUMPEvent(tick: currentTick, words: [word0]))
            }
        }

        return ParsedSMF2Clip(
            formatVersion: formatVersion,
            ppqn: ppqn,
            trackCount: trackCount,
            events: parsedEvents
        )
    }
}

// MARK: - Data Byte Helpers

public struct TimedUMPEvent: Equatable, Sendable {
    public let tick: UInt64
    public let words: [UInt32]

    public init(tick: UInt64, words: [UInt32]) {
        self.tick = tick
        self.words = words
    }
}

private extension UInt16 {
    var bigEndianData: Data {
        var be = self.bigEndian
        return Data(bytes: &be, count: 2)
    }
}

private extension UInt32 {
    var bigEndianData: Data {
        var be = self.bigEndian
        return Data(bytes: &be, count: 4)
    }
}

private extension Data {
    func readUInt16(at offset: Int) -> UInt16 {
        let sub = self[offset..<(offset + 2)]
        return sub.withUnsafeBytes { $0.load(as: UInt16.self).bigEndian }
    }

    func readUInt32(at offset: Int) -> UInt32 {
        let sub = self[offset..<(offset + 4)]
        return sub.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
    }
}
