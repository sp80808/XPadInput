import Foundation

/// Independent musical registers for the two note-producing gamepad lanes.
///
/// The values are deliberately pure domain state so defaults, clamping, and
/// per-instrument recall can be verified without starting audio or MIDI.
public struct PerformanceLaneRegisters: Codable, Equatable, Sendable {
    public static let supportedOctaves = 2...5

    public private(set) var strumOctave: Int
    public private(set) var faceButtonOctave: Int

    public init(strumOctave: Int, faceButtonOctave: Int) {
        self.strumOctave = Self.clampedOctave(strumOctave)
        self.faceButtonOctave = Self.clampedOctave(faceButtonOctave)
    }

    public static func defaults(for family: InstrumentFamily) -> Self {
        let octave = family == .bass ? 2 : 3
        return Self(strumOctave: octave, faceButtonOctave: octave)
    }

    public mutating func setStrumOctave(_ octave: Int) {
        strumOctave = Self.clampedOctave(octave)
    }

    public mutating func setFaceButtonOctave(_ octave: Int) {
        faceButtonOctave = Self.clampedOctave(octave)
    }

    public mutating func shiftBoth(by octaveDelta: Int) {
        strumOctave = Self.shiftedOctave(strumOctave, by: octaveDelta)
        faceButtonOctave = Self.shiftedOctave(faceButtonOctave, by: octaveDelta)
    }

    public static func clampedOctave(_ octave: Int) -> Int {
        min(supportedOctaves.upperBound, max(supportedOctaves.lowerBound, octave))
    }

    private static func shiftedOctave(_ octave: Int, by octaveDelta: Int) -> Int {
        let (shifted, overflowed) = octave.addingReportingOverflow(octaveDelta)
        if overflowed {
            return octaveDelta > 0 ? supportedOctaves.upperBound : supportedOctaves.lowerBound
        }
        return clampedOctave(shifted)
    }
}

/// Session-scoped recall keyed by the stable instrument profile identifier.
public struct PerformanceLaneRegisterMemory: Codable, Equatable, Sendable {
    private var valuesByInstrumentID: [String: PerformanceLaneRegisters]

    public init(valuesByInstrumentID: [String: PerformanceLaneRegisters] = [:]) {
        self.valuesByInstrumentID = valuesByInstrumentID
    }

    public mutating func settings(for profile: InstrumentProfile) -> PerformanceLaneRegisters {
        if let remembered = valuesByInstrumentID[profile.id] {
            return remembered
        }

        let defaults = PerformanceLaneRegisters.defaults(for: profile.family)
        valuesByInstrumentID[profile.id] = defaults
        return defaults
    }

    public mutating func remember(
        _ settings: PerformanceLaneRegisters,
        for profile: InstrumentProfile
    ) {
        valuesByInstrumentID[profile.id] = settings
    }
}
