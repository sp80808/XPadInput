import Foundation

/// A concrete musical note with pitch class and octave.
public struct Note: Hashable, Codable, Sendable, Comparable {
    public let pitchClass: PitchClass
    public let octave: Int
    
    public init(pitchClass: PitchClass, octave: Int) {
        self.pitchClass = pitchClass
        self.octave = octave
    }
    
    /// MIDI note number (0-127)
    public var midiNote: UInt8 {
        let value = (octave + 1) * 12 + pitchClass.rawValue
        return UInt8(max(0, min(127, value)))
    }
    
    /// Frequency in Hz (A4 = 440Hz)
    public var frequency: Double {
        440.0 * pow(2.0, (Double(midiNote) - 69.0) / 12.0)
    }
    
    /// Display name
    public var displayName: String {
        "\(pitchClass.displayName)\(octave)"
    }
    
    /// Create from MIDI note number
    public static func fromMIDI(_ noteNumber: UInt8) -> Note {
        let pc = PitchClass(rawValue: Int(noteNumber) % 12)!
        let oct = Int(noteNumber) / 12 - 1
        return Note(pitchClass: pc, octave: oct)
    }
    
    /// Transpose by semitones
    public func transposed(by semitones: Int) -> Note {
        let newMidi = Int(midiNote) + semitones
        let clamped = max(0, min(127, newMidi))
        return Note.fromMIDI(UInt8(clamped))
    }
    
    /// Interval to another note in semitones
    public func semitones(to other: Note) -> Int {
        Int(other.midiNote) - Int(midiNote)
    }
    
    public static func < (lhs: Note, rhs: Note) -> Bool {
        lhs.midiNote < rhs.midiNote
    }
    
    // Common reference notes
    public static let middleC = Note(pitchClass: .c, octave: 4)
    public static let a4 = Note(pitchClass: .a, octave: 4)
}
