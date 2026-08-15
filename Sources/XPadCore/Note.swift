import Foundation

/// Represents a concrete musical pitch with an octave and exact MIDI note number.
public struct Note: Identifiable, Hashable, Codable, Sendable, Comparable {
    public let midiNumber: UInt8

    public var id: UInt8 { midiNumber }

    public init(midiNumber: UInt8) {
        self.midiNumber = min(127, midiNumber)
    }

    public init(pitchClass: PitchClass, octave: Int) {
        let midi = (octave + 1) * 12 + pitchClass.rawValue
        self.midiNumber = UInt8(clamping: max(0, min(127, midi)))
    }

    public var pitchClass: PitchClass {
        PitchClass(rawValue: Int(midiNumber) % 12)!
    }

    public var octave: Int {
        (Int(midiNumber) / 12) - 1
    }

    public var name: String {
        "\(pitchClass.standardName)\(octave)"
    }

    /// Equal temperament frequency in Hz (A4 = 440 Hz = MIDI 69).
    public var frequency: Double {
        440.0 * pow(2.0, (Double(midiNumber) - 69.0) / 12.0)
    }

    public func transposed(by semitones: Int) -> Note {
        let newMidi = Int(midiNumber) + semitones
        return Note(midiNumber: UInt8(clamping: max(0, min(127, newMidi))))
    }

    public static func < (lhs: Note, rhs: Note) -> Bool {
        lhs.midiNumber < rhs.midiNumber
    }

    // Common standard notes
    public static let c4 = Note(midiNumber: 60)
    public static let a4 = Note(midiNumber: 69)
}
