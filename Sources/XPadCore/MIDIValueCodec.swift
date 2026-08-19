import Foundation

/// Conversions between musical/normalized quantities and MIDI 1.0 wire values.
///
/// Every producer of MIDI bytes in the workspace (`XPadMIDI`, `XPadController`,
/// `XPadAudio`) shares these definitions so a bend or a timbre value cannot
/// drift between the internal synth, the virtual endpoints, and file export.
public enum MIDIValueCodec {
    /// Centre of the 14-bit pitch-bend range.
    public static let pitchBendCentre14: UInt16 = 8_192
    /// Highest legal 14-bit pitch-bend value.
    public static let pitchBendMaximum14: UInt16 = 16_383

    /// Converts a `0...1` value into a 7-bit controller value.
    public static func midi7(_ normalizedValue: Double) -> UInt8 {
        UInt8((normalizedValue.normalizedUnit * 127.0).rounded())
    }

    /// Converts a signed bend in semitones into a symmetric 14-bit bend value,
    /// where the full range maps to an equal number of steps either side of centre.
    public static func pitchBend14(semitones: Double, range: Double) -> UInt16 {
        guard range.isFinite, range > 0 else { return pitchBendCentre14 }
        let normalized = (semitones / range).normalizedBipolar
        let raw = (8_192.0 + normalized * 8_192.0).rounded()
        return UInt16(raw.clamped(to: 0...Double(pitchBendMaximum14)))
    }

    /// Converts a signed bend in semitones into a 14-bit bend value whose upward
    /// half stops at 16383, matching hosts that treat 16383 as maximum bend.
    public static func asymmetricPitchBend14(semitones: Double, range: Double) -> UInt16 {
        guard range.isFinite, range > 0 else { return pitchBendCentre14 }
        let normalized = (semitones / range).normalizedBipolar
        let span = normalized >= 0 ? 8_191.0 : 8_192.0
        return UInt16((8_192.0 + normalized * span).rounded())
    }

    /// Inverse of ``pitchBend14(semitones:range:)``.
    public static func semitones(fromPitchBend14 value: UInt16, range: Double) -> Double {
        (Double(value) - 8_192.0) / 8_192.0 * range
    }

    /// Converts a signed `-8192...8191` bend into an unsigned 14-bit wire value.
    public static func unsignedPitchBend14(signed value: Int16) -> UInt16 {
        UInt16((Int(value) + 8_192).clamped(to: 0...Int(pitchBendMaximum14)))
    }
}
