import Foundation

/// A specific voicing of a chord - concrete note assignment.
struct ChordVoicing: Hashable, Codable, Sendable {
    let chord: Chord
    let notes: [Note]
    
    /// Total interval span in semitones
    var span: Int {
        guard let lowest = notes.min(), let highest = notes.max() else { return 0 }
        return lowest.semitones(to: highest)
    }
    
    /// The bass note
    var bassNote: Note? { notes.min() }
    
    /// Create a close-position voicing
    static func closePosition(chord: Chord, baseOctave: Int = 3) -> ChordVoicing {
        return ChordVoicing(chord: chord, notes: chord.voiced(baseOctave: baseOctave))
    }
    
    /// Create a voicing optimised for smooth voice leading from a previous voicing
    static func voiceLed(chord: Chord, from previous: ChordVoicing) -> ChordVoicing {
        let targetPCs = chord.pitchClasses
        var newNotes: [Note] = []
        let prevNotes = previous.notes
        
        for (i, targetPC) in targetPCs.enumerated() {
            if i < prevNotes.count {
                // Find nearest octave placement of this pitch class to the previous note
                let prevNote = prevNotes[i]
                let prevMidi = Int(prevNote.midiNote)
                
                var bestNote = Note(pitchClass: targetPC, octave: prevNote.octave)
                var bestDist = abs(Int(bestNote.midiNote) - prevMidi)
                
                for octaveShift in [-1, 1] {
                    let candidate = Note(pitchClass: targetPC, octave: prevNote.octave + octaveShift)
                    let dist = abs(Int(candidate.midiNote) - prevMidi)
                    if dist < bestDist {
                        bestNote = candidate
                        bestDist = dist
                    }
                }
                
                newNotes.append(bestNote)
            } else {
                // Extra voices: place near the highest previous note
                let refOctave = prevNotes.last?.octave ?? 4
                newNotes.append(Note(pitchClass: targetPC, octave: refOctave))
            }
        }
        
        return ChordVoicing(chord: chord, notes: newNotes.sorted())
    }
    
    /// Create a strummed voicing with a specific number of strings
    static func strummed(chord: Chord, strings: Int = 6, baseOctave: Int = 3) -> ChordVoicing {
        let pcs = chord.pitchClasses
        var notes: [Note] = []
        
        // Start with bass note
        notes.append(Note(pitchClass: chord.root, octave: baseOctave))
        
        // Fill remaining strings cycling through chord tones
        var currentOctave = baseOctave
        for i in 1..<strings {
            let pc = pcs[i % pcs.count]
            
            // Move up octave when we've gone through all pitch classes
            if i >= pcs.count {
                currentOctave = baseOctave + (i / pcs.count)
            }
            
            let note = Note(pitchClass: pc, octave: min(currentOctave + 1, 6))
            if notes.last.map({ note.midiNote > $0.midiNote }) ?? true {
                notes.append(note)
            } else {
                notes.append(Note(pitchClass: pc, octave: min(currentOctave + 2, 6)))
            }
        }
        
        return ChordVoicing(chord: chord, notes: notes.sorted())
    }
}
