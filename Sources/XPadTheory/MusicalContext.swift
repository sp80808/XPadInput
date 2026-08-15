import Foundation
import XPadCore

/// Snapshot of the harmonic and melodic situation used to interpret techniques.
public struct MusicalContext: Sendable, Equatable {
    public var key: PitchClass
    public var scale: Scale
    public var chord: Chord?
    public var previousNote: Note?
    public var currentNote: Note?
    public var chromaticMode: Bool
    public var pitchAssist: PitchAssistMode
    public var registerOctave: Int

    public init(
        key: PitchClass,
        scale: Scale,
        chord: Chord? = nil,
        previousNote: Note? = nil,
        currentNote: Note? = nil,
        chromaticMode: Bool = false,
        pitchAssist: PitchAssistMode = .light,
        registerOctave: Int = 4
    ) {
        self.key = key
        self.scale = scale
        self.chord = chord
        self.previousNote = previousNote
        self.currentNote = currentNote
        self.chromaticMode = chromaticMode
        self.pitchAssist = pitchAssist
        self.registerOctave = registerOctave
    }

    public var activeChordTones: [PitchClass] {
        chord?.pitchClasses ?? []
    }

    public var scaleTones: [PitchClass] {
        scale.pitchClasses(root: key)
    }

    public var intervalTravelled: Int? {
        guard let previousNote, let currentNote else { return nil }
        return previousNote.semitones(to: currentNote)
    }

    public var melodicDirection: Int {
        guard let interval = intervalTravelled else { return 0 }
        if interval > 0 { return 1 }
        if interval < 0 { return -1 }
        return 0
    }

    public var bassRelationship: PitchClass? {
        chord?.root
    }

    public func isChordTone(_ pitchClass: PitchClass) -> Bool {
        activeChordTones.contains(pitchClass)
    }

    public func isScaleTone(_ pitchClass: PitchClass) -> Bool {
        scaleTones.contains(pitchClass)
    }

    public func neighbouringScaleDegrees(from note: Note) -> (below: Note?, above: Note?) {
        let tones = scaleTones
        guard !tones.isEmpty else { return (nil, nil) }
        var below: Note?
        var above: Note?
        for offset in 1...12 {
            let up = note.transposed(by: offset)
            if above == nil && tones.contains(up.pitchClass) {
                above = up
            }
            let down = note.transposed(by: -offset)
            if below == nil && tones.contains(down.pitchClass) {
                below = down
            }
            if below != nil && above != nil { break }
        }
        return (below, above)
    }

    public func chordFunctionLabel() -> String? {
        guard let chord else { return nil }
        return chord.romanNumeral(in: key, scale: scale)
    }
}

/// A musically useful pitch destination for a bend/slide, ranked but never mandatory.
public struct PitchTarget: Sendable, Equatable, Identifiable {
    public var semitones: Double
    public var note: Note
    public var isChordTone: Bool
    public var isScaleTone: Bool
    public var score: Double
    public var roleLabel: String

    public var id: String { "\(note.midiNote)_\(semitones)" }

    public var displayLabel: String {
        let sign = semitones >= 0 ? "+" : ""
        let rounded = semitones.rounded()
        if abs(semitones - rounded) < 0.05 {
            return "\(sign)\(Int(rounded)) → \(note.pitchClass.displayName)"
        }
        return String(format: "%@%.1f → %@", sign, semitones, note.pitchClass.displayName)
    }

    public var theoryLabel: String {
        "Bend \(displayLabel)\(isChordTone ? " · chord" : isScaleTone ? " · scale" : "")"
    }
}

/// Ranks contextual pitch destinations for bends, slides, and hammer-ons.
/// Does not forbid out-of-scale notes — chromatic mode disables ranking bias.
public struct ContextualPitchTargeter: Sendable {
    public init() {}

    public func bendTargets(
        from note: Note,
        rangeSemitones: Double,
        context: MusicalContext,
        allowDownward: Bool
    ) -> [PitchTarget] {
        let maxUp = max(0.5, rangeSemitones)
        let maxDown = allowDownward ? max(0.5, rangeSemitones) : 0
        var candidates: [PitchTarget] = []

        // Stylistic guitar/bass intervals always offered inside the instrument range.
        let stylistic: [Double] = [1, 2, 3]
        for st in stylistic where st <= maxUp + 0.01 {
            candidates.append(makeTarget(from: note, semitones: st, context: context, stylisticBonus: 8))
        }
        if allowDownward {
            for st in stylistic where st <= maxDown + 0.01 {
                candidates.append(makeTarget(from: note, semitones: -st, context: context, stylisticBonus: 4))
            }
        }

        // Next scale / chord tones within range.
        if !context.chromaticMode {
            for offset in 1...Int(maxUp.rounded(.up)) {
                let dest = note.transposed(by: offset)
                if context.isChordTone(dest.pitchClass) || context.isScaleTone(dest.pitchClass) {
                    candidates.append(makeTarget(from: note, semitones: Double(offset), context: context, stylisticBonus: 0))
                }
            }
            if allowDownward {
                for offset in 1...Int(maxDown.rounded(.up)) {
                    let dest = note.transposed(by: -offset)
                    if context.isChordTone(dest.pitchClass) || context.isScaleTone(dest.pitchClass) {
                        candidates.append(makeTarget(from: note, semitones: Double(-offset), context: context, stylisticBonus: 0))
                    }
                }
            }
        }

        var unique: [PitchTarget] = []
        for candidate in candidates {
            if let idx = unique.firstIndex(where: { abs($0.semitones - candidate.semitones) < 0.05 }) {
                if candidate.score > unique[idx].score {
                    unique[idx] = candidate
                }
            } else {
                unique.append(candidate)
            }
        }

        return unique.sorted { $0.score > $1.score }
    }

    public func slideTarget(from note: Note, direction: Int, context: MusicalContext) -> Note {
        let neighbours = context.neighbouringScaleDegrees(from: note)
        if direction >= 0 {
            if let chord = context.chord {
                let chordUp = nextChordTone(from: note, chord: chord, direction: 1)
                if let chordUp { return chordUp }
            }
            return neighbours.above ?? note.transposed(by: 2)
        } else {
            if let chord = context.chord {
                let chordDown = nextChordTone(from: note, chord: chord, direction: -1)
                if let chordDown { return chordDown }
            }
            return neighbours.below ?? note.transposed(by: -2)
        }
    }

    public func hammerOnTarget(from note: Note, context: MusicalContext) -> Note? {
        if let chord = context.chord, let next = nextChordTone(from: note, chord: chord, direction: 1) {
            return next
        }
        return context.neighbouringScaleDegrees(from: note).above
    }

    public func pullOffTarget(from note: Note, context: MusicalContext) -> Note? {
        if let chord = context.chord, let next = nextChordTone(from: note, chord: chord, direction: -1) {
            return next
        }
        return context.neighbouringScaleDegrees(from: note).below
    }

    public func note(for role: ChordToneRole, chord: Chord, previous: Note?, baseOctave: Int) -> Note {
        let pc = chord.pitchClass(for: role)
        let anchor = Note(pitchClass: pc, octave: baseOctave)
        let reference = previous ?? anchor
        let anchorMIDI = Int(anchor.midiNote)
        let referenceMIDI = Int(reference.midiNote)
        var best = anchor
        var bestScore = Double.greatestFiniteMagnitude

        // Nearest-note motion is balanced against a stable register anchor. This
        // preserves smooth melodic movement without accumulating octave drift.
        for midi in 36...84 where midi % 12 == pc.rawValue {
            let movement = abs(midi - referenceMIDI)
            let registerPull = abs(midi - anchorMIDI)
            let score = Double(movement) + Double(registerPull) * 0.8
            if score < bestScore {
                bestScore = score
                best = Note.fromMIDI(UInt8(midi))
            }
        }
        return best
    }

    public func roleLabel(for note: Note, chord: Chord?) -> String? {
        guard let chord else { return nil }
        if note.pitchClass == chord.pitchClass(for: .root) { return "1" }
        if note.pitchClass == chord.pitchClass(for: .third) { return chord.quality.intervals.contains(3) ? "♭3" : "3" }
        if note.pitchClass == chord.pitchClass(for: .fifth) { return "5" }
        if note.pitchClass == chord.pitchClass(for: .seventh) {
            return chord.quality.intervals.contains(11) ? "7" : "♭7"
        }
        return nil
    }

    private func nextChordTone(from note: Note, chord: Chord, direction: Int) -> Note? {
        let pcs = chord.pitchClasses
        guard !pcs.isEmpty else { return nil }
        for offset in 1...12 {
            let candidate = note.transposed(by: offset * direction)
            if pcs.contains(candidate.pitchClass) {
                return candidate
            }
        }
        return nil
    }

    private func makeTarget(from note: Note, semitones: Double, context: MusicalContext, stylisticBonus: Double) -> PitchTarget {
        let dest = note.transposed(by: Int(semitones.rounded()))
        let chordTone = context.isChordTone(dest.pitchClass)
        let scaleTone = context.isScaleTone(dest.pitchClass)
        var score = stylisticBonus
        if context.chromaticMode {
            score += 1
        } else {
            if chordTone { score += 20 }
            if scaleTone { score += 10 }
            if dest.pitchClass == context.chord?.pitchClass(for: .fifth) { score += 4 }
            if dest.pitchClass == context.chord?.pitchClass(for: .third) { score += 3 }
        }
        // Prefer the physical range of a typical guitar bend (1–2 st).
        if abs(semitones) <= 2 { score += 3 }
        let role = roleLabel(for: dest, chord: context.chord) ?? dest.pitchClass.displayName
        return PitchTarget(
            semitones: semitones,
            note: dest,
            isChordTone: chordTone,
            isScaleTone: scaleTone,
            score: score,
            roleLabel: role
        )
    }
}
