import Foundation

/// A specific voicing of a chord - concrete note assignment.
public struct ChordVoicing: Hashable, Codable, Sendable {
    public let chord: Chord
    public let notes: [Note]
    
    public init(chord: Chord, notes: [Note]) {
        self.chord = chord
        self.notes = notes
    }
    
    /// Total interval span in semitones
    public var span: Int {
        guard let lowest = notes.min(), let highest = notes.max() else { return 0 }
        return lowest.semitones(to: highest)
    }
    
    /// The bass note
    public var bassNote: Note? { notes.min() }
    
    /// Create a close-position voicing
    public static func closePosition(chord: Chord, baseOctave: Int = 3) -> ChordVoicing {
        return ChordVoicing(chord: chord, notes: chord.voiced(baseOctave: baseOctave))
    }
    
    /// Create a smooth voicing without allowing repeated chord changes to drift
    /// indefinitely through octaves. The fixed-register baseline also preserves
    /// the requested voice count, so repeated strums do not collapse from six
    /// voices to a triad and then re-expand later.
    public static func voiceLed(
        chord: Chord,
        from previous: ChordVoicing,
        baseOctave: Int = 3,
        voiceCount: Int? = nil,
        playableRegister: ClosedRange<UInt8> = 36...84
    ) -> ChordVoicing {
        let count = max(chord.pitchClasses.count, voiceCount ?? previous.notes.count)
        let baseline = strummed(chord: chord, strings: count, baseOctave: baseOctave).notes
        guard !baseline.isEmpty else { return ChordVoicing(chord: chord, notes: []) }

        let previousNotes = previous.notes
        let lower = Int(playableRegister.lowerBound)
        let upper = Int(playableRegister.upperBound)
        var newNotes: [Note] = []
        newNotes.reserveCapacity(count)

        for index in 0..<count {
            let baselineNote = baseline[min(index, baseline.count - 1)]
            let previousNote = previousNotes.isEmpty
                ? baselineNote
                : previousNotes[min(index, previousNotes.count - 1)]
            let previousMIDI = Int(previousNote.midiNote)
            let baselineMIDI = Int(baselineNote.midiNote)
            let pitchClassValue = baselineNote.pitchClass.rawValue

            var bestMIDI = max(lower, min(upper, baselineMIDI))
            var bestScore = Double.greatestFiniteMagnitude

            for midi in lower...upper where midi % 12 == pitchClassValue {
                let movement = abs(midi - previousMIDI)
                let registerPull = abs(midi - baselineMIDI)
                let crossingPenalty: Int
                if let prior = newNotes.last, midi <= Int(prior.midiNote) {
                    crossingPenalty = 18
                } else {
                    crossingPenalty = 0
                }
                let score = Double(movement) + Double(registerPull) * 0.45 + Double(crossingPenalty)
                if score < bestScore {
                    bestScore = score
                    bestMIDI = midi
                }
            }

            newNotes.append(Note.fromMIDI(UInt8(bestMIDI)))
        }

        return ChordVoicing(chord: chord, notes: newNotes.sorted())
    }
    
    /// Create a strummed voicing with a specific number of strings
    public static func strummed(chord: Chord, strings: Int = 6, baseOctave: Int = 3) -> ChordVoicing {
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
