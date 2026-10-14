import Foundation

/// Channel mask used by the MTS scale/octave tuning messages.
///
/// The mask spans three 7-bit bytes: channels 1–7 in the low byte, 8–14 in the
/// middle byte, and 15–16 in the first two bits of the high byte.
public struct MIDITuningChannelMask: Sendable, Equatable {
    /// Bits 0–1 address channels 15 and 16.
    public let byte1: UInt8
    /// Bits 0–6 address channels 8–14.
    public let byte2: UInt8
    /// Bits 0–6 address channels 1–7.
    public let byte3: UInt8

    public init(byte1: UInt8, byte2: UInt8, byte3: UInt8) {
        self.byte1 = byte1 & 0x03
        self.byte2 = byte2 & 0x7F
        self.byte3 = byte3 & 0x7F
    }

    /// Builds a mask from 1-based MIDI channel numbers, ignoring anything outside 1...16.
    public init(channels: [UInt8]) {
        var low: UInt8 = 0
        var middle: UInt8 = 0
        var high: UInt8 = 0
        for channel in channels {
            switch channel {
            case 1...7: low |= UInt8(1 << (channel - 1))
            case 8...14: middle |= UInt8(1 << (channel - 8))
            case 15: high |= 0x01
            case 16: high |= 0x02
            default: break
            }
        }
        self.init(byte1: high, byte2: middle, byte3: low)
    }

    /// Every channel (1–16).
    public static let all = MIDITuningChannelMask(byte1: 0x03, byte2: 0x7F, byte3: 0x7F)

    /// A single channel.
    public static func single(_ channel: UInt8) -> MIDITuningChannelMask {
        MIDITuningChannelMask(channels: [channel])
    }

    public var bytes: [UInt8] { [byte1, byte2, byte3] }

    /// 1-based channel numbers addressed by this mask.
    public var channels: [UInt8] {
        var result: [UInt8] = []
        for bit in 0..<7 where byte3 & UInt8(1 << bit) != 0 { result.append(UInt8(bit + 1)) }
        for bit in 0..<7 where byte2 & UInt8(1 << bit) != 0 { result.append(UInt8(bit + 8)) }
        if byte1 & 0x01 != 0 { result.append(15) }
        if byte1 & 0x02 != 0 { result.append(16) }
        return result
    }
}

/// Encoder for the MIDI Tuning Standard (MTS) universal SysEx messages.
///
/// XPI already retunes its own oscillator per note. MTS goes one step further
/// and hands the *destination's* oscillator a tuning table, so hardware synths,
/// samplers, and soft synths stay in tune with XPI — including non-octave
/// scales such as Wendy Carlos Alpha that pitch bend alone cannot express.
///
/// Reference: MIDI 1.0 Universal System Exclusive, sub-ID#1 `08`.
public enum MIDITuningStandard {
    /// Universal Non-Real Time SysEx ID (`7E`).
    public static let nonRealTimeID: UInt8 = 0x7E
    /// Universal Real Time SysEx ID (`7F`).
    public static let realTimeID: UInt8 = 0x7F
    /// Sub-ID#1 shared by every MIDI Tuning message.
    public static let tuningSubID: UInt8 = 0x08
    /// Device ID addressing every device (`7F`).
    public static let broadcastDeviceID: UInt8 = 0x7F

    /// Frequency of MIDI note 0 (C-1) in 12-TET, in hertz.
    public static let noteZeroFrequency: Double = 8.175_798_915_643_077
    /// Fraction steps per semitone in the 3-byte frequency word (14-bit).
    public static let fractionStepsPerSemitone: Double = 16_384
    /// Cents represented by one step of the 14-bit fraction (~0.0061 cents).
    public static let centsPerFractionStep: Double = 100 / fractionStepsPerSemitone
    /// Reserved word meaning "leave this note's tuning unchanged".
    public static let noChange: [UInt8] = [0x7F, 0x7F, 0x7F]
    /// Tuning name length in bytes.
    public static let nameByteCount = 16
    /// Highest MIDI note number.
    public static let highestNote: UInt8 = 127

    // MARK: - Frequency data

    /// Encodes an absolute pitch, in cents above MIDI note 0, as MTS `xx yy zz`.
    ///
    /// `xx` is the semitone below the pitch, and `yy`/`zz` are the 14-bit
    /// fraction of that semitone (MSB first).
    public static func frequencyData(centsAboveNoteZero cents: Double) -> [UInt8] {
        guard cents.isFinite else { return noChange }
        let clamped = cents.clamped(to: 0...Double(highestNote) * 100)
        let semitoneValue = clamped / 100
        var semitone = Int(floor(semitoneValue))
        var fraction = Int(((semitoneValue - Double(semitone)) * fractionStepsPerSemitone).rounded())
        if fraction >= Int(fractionStepsPerSemitone) {
            semitone += 1
            fraction = 0
        }
        semitone = min(semitone, Int(highestNote))
        let fractionMSB = UInt8((fraction >> 7) & 0x7F)
        let fractionLSB = UInt8(fraction & 0x7F)
        let word: [UInt8] = [UInt8(semitone), fractionMSB, fractionLSB]
        // `7F 7F 7F` is reserved for "no change", so nudge to the last legal pitch.
        if word == noChange {
            return [0x7F, 0x7F, 0x7E]
        }
        return word
    }

    /// Encodes a MIDI note retuned by `deviationCents` away from 12-TET.
    public static func frequencyData(forMIDINote note: UInt8, deviationCents: Double) -> [UInt8] {
        frequencyData(centsAboveNoteZero: Double(note) * 100 + deviationCents)
    }

    // MARK: - Messages

    /// Bulk Tuning Dump (`F0 7E id 08 01 tt <name> [xx yy zz]×128 <checksum> F7`).
    ///
    /// - Parameters:
    ///   - deviationsCents: Per-note deviation from 12-TET. Missing notes keep 12-TET.
    ///   - program: Tuning program number, 0–127.
    public static func bulkDump(
        name: String,
        deviationsCents: [Double],
        program: UInt8 = 0,
        deviceID: UInt8 = broadcastDeviceID
    ) -> [UInt8] {
        var message: [UInt8] = [
            nonRealTimeID,
            deviceID & 0x7F,
            tuningSubID,
            0x01,
            program & 0x7F
        ]
        message.append(contentsOf: nameBytes(name))

        for note in 0...Int(highestNote) {
            let deviation = note < deviationsCents.count ? deviationsCents[note] : 0
            message.append(contentsOf: frequencyData(forMIDINote: UInt8(note), deviationCents: deviation))
        }

        // MTS checksums the message body excluding the SysEx header and EOX.
        let checksum = message.reduce(UInt8(0)) { $0 ^ $1 }
        return [0xF0] + message + [checksum, 0xF7]
    }

    /// Bulk Tuning Dump Request (`F0 7E id 08 00 tt F7`).
    public static func bulkDumpRequest(program: UInt8 = 0, deviceID: UInt8 = broadcastDeviceID) -> [UInt8] {
        [0xF0, nonRealTimeID, deviceID & 0x7F, tuningSubID, 0x00, program & 0x7F, 0xF7]
    }

    /// Single Note Tuning Change (`F0 7F id 08 02 tt ll [kk xx yy zz]… F7`).
    ///
    /// Retunes individual notes while they sound, which is how a dynamic
    /// temperament (just intonation, Hermode) reaches an external instrument.
    /// Notes with no meaningful deviation are omitted to keep messages small.
    public static func singleNoteTuningChange(
        deviationsCents: [Double],
        program: UInt8 = 0,
        deviceID: UInt8 = broadcastDeviceID,
        minimumDeviationCents: Double = 0.1
    ) -> [UInt8] {
        var entries: [UInt8] = []
        var changed = 0

        for note in 0...Int(highestNote) {
            let deviation = note < deviationsCents.count ? deviationsCents[note] : 0
            guard deviation.isFinite, abs(deviation) >= abs(minimumDeviationCents) else { continue }
            entries.append(UInt8(note))
            entries.append(contentsOf: frequencyData(forMIDINote: UInt8(note), deviationCents: deviation))
            changed += 1
            if changed == 127 { break } // `ll` is a 7-bit count
        }

        guard changed > 0 else { return [] }
        return [
            0xF0,
            realTimeID,
            deviceID & 0x7F,
            tuningSubID,
            0x02,
            program & 0x7F,
            UInt8(changed)
        ] + entries + [0xF7]
    }

    /// Scale/Octave Tuning, 1-byte form (`F0 7F id 08 08 ff gg hh [ss]×12 F7`).
    ///
    /// Twelve deviations, one per scale degree, applied to every octave — the
    /// lightest way to put a 12-note temperament onto a channel.
    public static func scaleOctaveTuning1Byte(
        deviationsCents: [Double],
        channels: MIDITuningChannelMask = .all,
        deviceID: UInt8 = broadcastDeviceID
    ) -> [UInt8] {
        var message: [UInt8] = [0xF0, realTimeID, deviceID & 0x7F, tuningSubID, 0x08]
        message.append(contentsOf: channels.bytes)
        for degree in 0..<12 {
            let cents = degree < deviationsCents.count ? deviationsCents[degree] : 0
            // 0x00 = -64 cents, 0x40 = 0 cents, 0x7F = +63 cents.
            let value = Int((cents * 64.0 / 100.0).rounded()) + 64
            message.append(UInt8(value.clamped(to: 0...127)))
        }
        message.append(0xF7)
        return message
    }

    /// Scale/Octave Tuning, 2-byte form (`F0 7F id 08 09 ff gg hh [ss tt]×12 F7`).
    ///
    /// Same idea as the 1-byte form with 14-bit resolution (±100 cents).
    public static func scaleOctaveTuning2Byte(
        deviationsCents: [Double],
        channels: MIDITuningChannelMask = .all,
        deviceID: UInt8 = broadcastDeviceID
    ) -> [UInt8] {
        var message: [UInt8] = [0xF0, realTimeID, deviceID & 0x7F, tuningSubID, 0x09]
        message.append(contentsOf: channels.bytes)
        for degree in 0..<12 {
            let cents = degree < deviationsCents.count ? deviationsCents[degree] : 0
            // 14-bit deviation around 8192, covering ±100 cents.
            let raw = Int((cents * 8192.0 / 100.0).rounded()) + 8192
            let value = raw.clamped(to: 0...16_383)
            message.append(UInt8((value >> 7) & 0x7F))
            message.append(UInt8(value & 0x7F))
        }
        message.append(0xF7)
        return message
    }

    // MARK: - Helpers

    /// Truncates or pads a tuning name to 16 seven-bit ASCII bytes.
    public static func nameBytes(_ name: String) -> [UInt8] {
        var bytes: [UInt8] = []
        for scalar in name.unicodeScalars {
            let value = scalar.value
            if value >= 0x20, value <= 0x7E {
                bytes.append(UInt8(value))
            } else if value <= 0x7F {
                bytes.append(UInt8(value))
            } else {
                bytes.append(UInt8(ascii: "?"))
            }
            if bytes.count == nameByteCount { break }
        }
        while bytes.count < nameByteCount {
            bytes.append(UInt8(ascii: " "))
        }
        return bytes
    }
}
