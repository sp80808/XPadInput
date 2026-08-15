import Foundation

/// Represents a musical scale/mode with its interval pattern.
struct Scale: Hashable, Codable, Sendable, Identifiable {
    let id: String
    let name: String
    let intervals: [Int] // Semitone offsets from root
    
    /// Generate pitch classes for this scale with a given root
    func pitchClasses(root: PitchClass) -> [PitchClass] {
        intervals.map { root.transposed(by: $0) }
    }
    
    /// Generate concrete notes for this scale in a given octave range
    func notes(root: PitchClass, fromOctave: Int = 3, toOctave: Int = 5) -> [Note] {
        var result: [Note] = []
        for octave in fromOctave...toOctave {
            for interval in intervals {
                let pc = root.transposed(by: interval)
                let note = Note(pitchClass: pc, octave: octave)
                if note.midiNote <= 127 {
                    result.append(note)
                }
            }
        }
        return result.sorted()
    }
    
    /// Check if a pitch class belongs to this scale
    func contains(_ pitchClass: PitchClass, root: PitchClass) -> Bool {
        pitchClasses(root: root).contains(pitchClass)
    }
    
    /// Degree of a pitch class in this scale (1-based, nil if not in scale)
    func degree(of pitchClass: PitchClass, root: PitchClass) -> Int? {
        let pcs = pitchClasses(root: root)
        guard let idx = pcs.firstIndex(of: pitchClass) else { return nil }
        return idx + 1
    }
    
    /// The number of notes in the scale
    var noteCount: Int { intervals.count }
    
    // MARK: - Common Scales
    
    static let major = Scale(
        id: "major",
        name: "Major (Ionian)",
        intervals: [0, 2, 4, 5, 7, 9, 11]
    )
    
    static let naturalMinor = Scale(
        id: "natural_minor",
        name: "Natural Minor (Aeolian)",
        intervals: [0, 2, 3, 5, 7, 8, 10]
    )
    
    static let harmonicMinor = Scale(
        id: "harmonic_minor",
        name: "Harmonic Minor",
        intervals: [0, 2, 3, 5, 7, 8, 11]
    )
    
    static let melodicMinor = Scale(
        id: "melodic_minor",
        name: "Melodic Minor",
        intervals: [0, 2, 3, 5, 7, 9, 11]
    )
    
    static let dorian = Scale(
        id: "dorian",
        name: "Dorian",
        intervals: [0, 2, 3, 5, 7, 9, 10]
    )
    
    static let phrygian = Scale(
        id: "phrygian",
        name: "Phrygian",
        intervals: [0, 1, 3, 5, 7, 8, 10]
    )
    
    static let lydian = Scale(
        id: "lydian",
        name: "Lydian",
        intervals: [0, 2, 4, 6, 7, 9, 11]
    )
    
    static let mixolydian = Scale(
        id: "mixolydian",
        name: "Mixolydian",
        intervals: [0, 2, 4, 5, 7, 9, 10]
    )
    
    static let locrian = Scale(
        id: "locrian",
        name: "Locrian",
        intervals: [0, 1, 3, 5, 6, 8, 10]
    )
    
    static let pentatonicMajor = Scale(
        id: "pentatonic_major",
        name: "Major Pentatonic",
        intervals: [0, 2, 4, 7, 9]
    )
    
    static let pentatonicMinor = Scale(
        id: "pentatonic_minor",
        name: "Minor Pentatonic",
        intervals: [0, 3, 5, 7, 10]
    )
    
    static let blues = Scale(
        id: "blues",
        name: "Blues",
        intervals: [0, 3, 5, 6, 7, 10]
    )
    
    static let chromatic = Scale(
        id: "chromatic",
        name: "Chromatic",
        intervals: Array(0...11)
    )
    
    /// All available scales for UI display
    static let allScales: [Scale] = [
        .major, .naturalMinor, .harmonicMinor, .melodicMinor,
        .dorian, .phrygian, .lydian, .mixolydian, .locrian,
        .pentatonicMajor, .pentatonicMinor, .blues, .chromatic
    ]
}
