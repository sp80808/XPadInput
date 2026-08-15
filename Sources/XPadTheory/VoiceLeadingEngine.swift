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
            return targetChord.voiced(baseOctave: baseOctave)
        }

        // Generate all possible inversions and base octave permutations for the target chord
        var candidateVoicings: [[Note]] = []
        for octave in [baseOctave - 1, baseOctave, baseOctave + 1] {
            for inv in 0..<max(1, targetChord.quality.intervals.count) {
                var c = targetChord
                c.inversion = inv
                let notes = c.voiced(baseOctave: octave)
                if !notes.isEmpty {
                    candidateVoicings.append(notes)
                }
            }
        }

        var bestVoicing = targetChord.voiced(baseOctave: baseOctave)
        var lowestScore = Double.greatestFiniteMagnitude

        let prevMidi = previousVoicing.map { Double($0.midiNote) }

        for candidate in candidateVoicings {
            let candMidi = candidate.map { Double($0.midiNote) }
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

        let minCount = min(prev.count, cand.count)
        for i in 0..<minCount {
            let diff = abs(cand[i] - prev[i])
            cost += diff * diff
        }

        let countDiff = abs(Double(cand.count - prev.count))
        cost += countDiff * 15.0

        for note in cand {
            if note < 40 { cost += (40 - note) * 4.0 }
            if note > 84 { cost += (note - 84) * 4.0 }
        }

        switch strategy {
        case .smooth:
            break
        case .bassAnchored:
            if let prevBass = prev.first, let candBass = cand.first {
                let bassLeap = abs(candBass - prevBass)
                if bassLeap > 7 { cost += bassLeap * 5.0 }
            }
        case .pianoSATB:
            for i in 0..<(cand.count - 1) {
                if cand[i] >= cand[i+1] { cost += 50.0 }
            }
        case .cinematic:
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
