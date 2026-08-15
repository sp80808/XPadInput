import Foundation
import XPadCore

public enum VoiceLeadingStrategy: String, CaseIterable, Identifiable, Codable, Sendable {
    case smooth = "Smooth (Minimal Motion)"
    case pianoSATB = "Piano (SATB Voice Leading)"
    case bassAnchored = "Bass Anchored"
    case cinematic = "Cinematic (Open Spread)"
    case parallel = "Parallel"

    public var id: String { rawValue }
}

public struct VoiceLeadingEngine: Sendable {
    public init() {}

    /// Given a previous chord voicing and a target next chord, returns the optimized voicing of the target chord.
    public func optimizeTransition(
        from previousVoicing: [Note],
        to targetChord: Chord,
        strategy: VoiceLeadingStrategy = .smooth,
        baseOctave: Int = 3
    ) -> [Note] {
        if previousVoicing.isEmpty || strategy == .parallel {
            return targetChord.voicedNotes(baseOctave: baseOctave)
        }

        // Generate all possible inversions and base octave permutations for the target chord
        var candidateVoicings: [[Note]] = []
        for octave in [baseOctave - 1, baseOctave, baseOctave + 1] {
            for inv in Inversion.allCases {
                var c = targetChord
                c.inversion = inv
                let notes = c.voicedNotes(baseOctave: octave)
                if !notes.isEmpty {
                    candidateVoicings.append(notes)
                }
            }
        }

        // Score each candidate voicing against previousVoicing
        var bestVoicing = targetChord.voicedNotes(baseOctave: baseOctave)
        var lowestScore = Double.greatestFiniteMagnitude

        let prevMidi = previousVoicing.map { Double($0.midiNumber) }

        for candidate in candidateVoicings {
            let candMidi = candidate.map { Double($0.midiNumber) }
            let score = calculateCost(from: prevMidi, to: candMidi, strategy: strategy)
            if score < lowestScore {
                lowestScore = score
                bestVoicing = candidate
            }
        }

        return bestVoicing
    }

    private func calculateCost(
        from prev: [Double],
        to cand: [Double],
        strategy: VoiceLeadingStrategy
    ) -> Double {
        var cost: Double = 0.0

        // 1. Voice displacement cost
        let minCount = min(prev.count, cand.count)
        for i in 0..<minCount {
            let diff = abs(cand[i] - prev[i])
            cost += diff * diff // Quadratic penalty for large leaps in a single voice
        }

        // 2. Extra/fewer voices penalty
        let countDiff = abs(Double(cand.count - prev.count))
        cost += countDiff * 15.0

        // 3. Register penalty (prefer middle octave C3..C5 / MIDI 48..72)
        for note in cand {
            if note < 40 { cost += (40 - note) * 4.0 }
            if note > 84 { cost += (note - 84) * 4.0 }
        }

        // 4. Strategy-specific adjustments
        switch strategy {
        case .smooth:
            break // Pure displacement minimization
        case .bassAnchored:
            // High priority on bass note stability or step motion
            if let prevBass = prev.first, let candBass = cand.first {
                let bassLeap = abs(candBass - prevBass)
                if bassLeap > 7 { cost += bassLeap * 5.0 }
            }
        case .pianoSATB:
            // Avoid extreme voice crossings
            for i in 0..<(cand.count - 1) {
                if cand[i] >= cand[i+1] { cost += 50.0 }
            }
        case .cinematic:
            // Reward wider pitch spread (distance between bass and soprano)
            if let bass = cand.first, let soprano = cand.last {
                let spread = soprano - bass
                if spread < 18 { cost += (18 - spread) * 3.0 }
            }
        case .parallel:
            break
        }

        return cost
    }
}
