import Foundation
import XPadCore

/// Calculates per-voice pitch bend offsets for polyphonic chord voicings,
/// ensuring chords bend in diatonic and consonant harmony within the active musical key.
public struct HarmonicChordBender: Sendable {
    public init() {}

    /// Computes pitch bend offsets (in semitones) for each active note.
    /// - Parameters:
    ///   - notes: The sounding notes in the chord / cluster.
    ///   - leadBendSemitones: The primary pitch bend in semitones (from stick / pitch engine).
    ///   - context: The current musical context (key, scale, chord, pitchAssist, chromaticMode).
    ///   - bendRangeSemitones: Pitch bend range.
    /// - Returns: A dictionary mapping MIDI note numbers to their respective semitone bend offsets.
    public func bends(
        for notes: [Note],
        leadBendSemitones: Double,
        context: MusicalContext,
        bendRangeSemitones: Double = 48.0
    ) -> [UInt8: Double] {
        guard !notes.isEmpty else { return [:] }
        guard abs(leadBendSemitones) > 0.0001 else {
            var result: [UInt8: Double] = [:]
            for note in notes {
                result[note.midiNote] = 0.0
            }
            return result
        }

        // Chromatic mode or Pitch Assist off uses parallel pitch bend across all voices
        if context.chromaticMode || context.pitchAssist == .off || notes.count <= 1 {
            var result: [UInt8: Double] = [:]
            for note in notes {
                result[note.midiNote] = leadBendSemitones
            }
            return result
        }

        // In-key diatonic chord bending
        return calculateDiatonicChordBends(
            notes: notes,
            leadBendSemitones: leadBendSemitones,
            context: context,
            bendRangeSemitones: bendRangeSemitones
        )
    }

    /// Evaluates diatonic scale-step trajectories for each voice in the chord.
    private func calculateDiatonicChordBends(
        notes: [Note],
        leadBendSemitones: Double,
        context: MusicalContext,
        bendRangeSemitones: Double
    ) -> [UInt8: Double] {
        // Choose reference note: lowest note (bass / root anchor)
        guard let referenceNote = notes.min() else { return [:] }
        let isAscending = leadBendSemitones > 0
        let absBend = abs(leadBendSemitones)

        // Build diatonic scale steps above or below for the reference note
        let refSteps = scaleStepLadder(from: referenceNote, ascending: isAscending, context: context, maxSteps: 8)
        guard refSteps.count >= 2 else {
            var result: [UInt8: Double] = [:]
            for note in notes { result[note.midiNote] = leadBendSemitones }
            return result
        }

        // Determine step index and fractional progress t based on reference note's semitone delta
        let (stepIndex, fraction) = findStepProgress(
            targetOffset: absBend,
            refLadder: refSteps.map { Double($0.midiNote - referenceNote.midiNote).magnitude }
        )

        var result: [UInt8: Double] = [:]
        for note in notes {
            let voiceLadder = scaleStepLadder(from: note, ascending: isAscending, context: context, maxSteps: 8)
            let voiceOffset: Double
            if voiceLadder.count > stepIndex + 1 {
                let lowerOffset = Double(voiceLadder[stepIndex].midiNote) - Double(note.midiNote)
                let upperOffset = Double(voiceLadder[stepIndex + 1].midiNote) - Double(note.midiNote)
                let interpolated = lowerOffset + (upperOffset - lowerOffset) * fraction
                voiceOffset = interpolated
            } else if let last = voiceLadder.last {
                voiceOffset = Double(last.midiNote) - Double(note.midiNote)
            } else {
                voiceOffset = leadBendSemitones
            }

            // Apply magnetic attraction if assist is enabled
            let assisted = applyAssistAttraction(
                rawOffset: voiceOffset,
                voiceLadder: voiceLadder,
                sourceNote: note,
                context: context
            )
            result[note.midiNote] = min(bendRangeSemitones, max(-bendRangeSemitones, assisted))
        }

        return result
    }

    /// Builds a ladder of diatonic scale degrees starting at sourceNote (index 0 = sourceNote).
    private func scaleStepLadder(
        from sourceNote: Note,
        ascending: Bool,
        context: MusicalContext,
        maxSteps: Int
    ) -> [Note] {
        var ladder: [Note] = [sourceNote]
        let scalePcs = context.scaleTones
        guard !scalePcs.isEmpty else { return ladder }

        var current = sourceNote
        for _ in 1...maxSteps {
            var nextNote: Note?
            for semitone in 1...12 {
                let candidate = current.transposed(by: ascending ? semitone : -semitone)
                if scalePcs.contains(candidate.pitchClass) {
                    nextNote = candidate
                    break
                }
            }
            if let next = nextNote {
                ladder.append(next)
                current = next
            } else {
                break
            }
        }
        return ladder
    }

    /// Determines the step index k and interpolation fraction t in [0, 1].
    private func findStepProgress(
        targetOffset: Double,
        refLadder: [Double]
    ) -> (stepIndex: Int, fraction: Double) {
        guard refLadder.count >= 2 else { return (0, 0.0) }

        for k in 0..<(refLadder.count - 1) {
            let low = refLadder[k]
            let high = refLadder[k + 1]
            if targetOffset >= low && targetOffset <= high {
                let range = high - low
                let fraction = range > 0.001 ? (targetOffset - low) / range : 0.0
                return (k, fraction)
            }
        }

        if let last = refLadder.last, targetOffset > last {
            return (refLadder.count - 2, 1.0)
        }
        return (0, 0.0)
    }

    /// Magnetically pulls voice bend towards exact in-key scale degrees when assist is active.
    private func applyAssistAttraction(
        rawOffset: Double,
        voiceLadder: [Note],
        sourceNote: Note,
        context: MusicalContext
    ) -> Double {
        guard context.pitchAssist != .off else { return rawOffset }
        let strength = context.pitchAssist.attractionStrength
        guard strength > 0 else { return rawOffset }

        let targetOffsets = voiceLadder.map { Double($0.midiNote) - Double(sourceNote.midiNote) }
        guard let nearest = targetOffsets.min(by: { abs($0 - rawOffset) < abs($1 - rawOffset) }) else {
            return rawOffset
        }

        let captureRadius = context.pitchAssist == .strong ? 0.65 : 0.35
        let dist = abs(rawOffset - nearest)
        guard dist <= captureRadius else { return rawOffset }

        let proximity = 1.0 - (dist / captureRadius)
        let eased = proximity * proximity * (3.0 - 2.0 * proximity)
        return rawOffset + (nearest - rawOffset) * eased * strength
    }

    /// Computes the harmonic consonance score of a collection of notes (0.0 to 1.0).
    public func consonanceScore(for notes: [Note]) -> Double {
        guard notes.count >= 2 else { return 1.0 }
        var totalConsonance = 0.0
        var pairCount = 0

        for i in 0..<notes.count {
            for j in (i + 1)..<notes.count {
                let semitones = abs(Int(notes[i].midiNote) - Int(notes[j].midiNote)) % 12
                let interval = Interval(semitones: semitones)
                totalConsonance += interval.consonance
                pairCount += 1
            }
        }

        return pairCount > 0 ? totalConsonance / Double(pairCount) : 1.0
    }
}
