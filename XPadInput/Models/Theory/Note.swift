import Foundation

/// A concrete musical note with pitch class and octave.
/// MIDI note number = (octave + 1) * 12 + pitchClass.rawValue
struct Note: Hashable, Codable, Sendable, Comparable {
    let pitchClass: PitchClass
    let octave: Int
    
    /// MIDI note number (0-127)
    var midiNote: UInt8 {
        let value = (octave + 1) * 12 + pitchClass.rawValue
        return UInt8(max(0, min(127, value)))
    }
    
    /// Frequency in Hz (A4 = 440Hz)
    var frequency: Double {
        440.0 * pow(2.0, (Double(midiNote) - 69.0) / 12.0)
    }
    
    /// Display name
    var displayName: String {
        "\(pitchClass.displayName)\(octave)"
    }
    
    /// Create from MIDI note number
    static func fromMIDI(_ noteNumber: UInt8) -> Note {
        let pc = PitchClass(rawValue: Int(noteNumber) % 12)!
        let oct = Int(noteNumber) / 12 - 1
        return Note(pitchClass: pc, octave: oct)
    }
    
    /// Transpose by semitones
    func transposed(by semitones: Int) -> Note {
        let newMidi = Int(midiNote) + semitones
        let clamped = max(0, min(127, newMidi))
        return Note.fromMIDI(UInt8(clamped))
    }
    
    /// Interval to another note in semitones
    func semitones(to other: Note) -> Int {
        Int(other.midiNote) - Int(midiNote)
    }
    
    static func < (lhs: Note, rhs: Note) -> Bool {
        lhs.midiNote < rhs.midiNote
    }
    
    // Common reference notes
    static let middleC = Note(pitchClass: .c, octave: 4)
    static let a4 = Note(pitchClass: .a, octave: 4)
}
