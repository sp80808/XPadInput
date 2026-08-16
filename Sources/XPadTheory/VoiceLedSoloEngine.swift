import Foundation
import XPadCore

// MARK: - Voice-Led Solo Models

public enum SoloPolarQuadrant: String, Sendable, Codable, CaseIterable {
    case northGuideTones = "Guide Tones & Extensions (North)"
    case southBassAnchors = "Bass & Root Anchors (South)"
    case eastDiatonicScale = "Ascending Scale Runs (East)"
    case westEnclosures = "Chromatic Enclosures & Blue Notes (West)"
}

public enum SoloArticulationMode: String, Sendable, Codable {
    case sustain
    case staccato
    case graceNote
    case bluesFlourish
    case screamingBend
}

public struct SoloTargetResolution: Sendable, Equatable {
    public var targetNote: Note
    public var roleLabel: String
    public var isChordTone: Bool
    public var isGuideTone: Bool
    public var isPassingTone: Bool
    public var isBlueNote: Bool
    public var velocity: UInt8
    public var octaveShift: Int
    public var pitchBendSemitones: Double
    public var articulation: SoloArticulationMode
    public var theoryExplanation: String
    public var approachPath: [Note]

    public init(
        targetNote: Note,
        roleLabel: String,
        isChordTone: Bool = true,
        isGuideTone: Bool = false,
        isPassingTone: Bool = false,
        isBlueNote: Bool = false,
        velocity: UInt8 = 100,
        octaveShift: Int = 0,
        pitchBendSemitones: Double = 0.0,
        articulation: SoloArticulationMode = .sustain,
        theoryExplanation: String = "",
        approachPath: [Note] = []
    ) {
        self.targetNote = targetNote
        self.roleLabel = roleLabel
        self.isChordTone = isChordTone
        self.isGuideTone = isGuideTone
        self.isPassingTone = isPassingTone
        self.isBlueNote = isBlueNote
        self.velocity = velocity
        self.octaveShift = octaveShift
        self.pitchBendSemitones = pitchBendSemitones
        self.articulation = articulation
        self.theoryExplanation = theoryExplanation
        self.approachPath = approachPath
    }
}

// MARK: - Voice-Led Solo Engine

public struct VoiceLedSoloEngine: Sendable {
    public init() {}

    /// Evaluates polar right stick coordinates relative to active musical context and returns the optimal melodic pitch.
    public func evaluateStick(
        stickX: Double,
        stickY: Double,
        radius: Double,
        angle: Double,
        velocity: Double,
        context: MusicalContext,
        previousTarget: Note? = nil
    ) -> SoloTargetResolution {
        guard radius > 0.08 else {
            let fallback = previousTarget ?? Note(pitchClass: context.chord?.root ?? context.key, octave: context.registerOctave)
            return SoloTargetResolution(
                targetNote: fallback,
                roleLabel: "Center Neutral",
                isChordTone: true,
                velocity: 0,
                theoryExplanation: "Neutral center deadzone"
            )
        }

        let quadrant = polarQuadrant(for: angle)
        let noteVelocity = UInt8(max(45, min(127, 50.0 + radius * 77.0)))
        let registerOctave = calculateOctave(radius: radius, baseOctave: context.registerOctave)
        let activeChord = context.chord ?? Chord(root: context.key, quality: .major)

        switch quadrant {
        case .northGuideTones:
            return resolveGuideTones(
                stickY: stickY,
                radius: radius,
                velocity: noteVelocity,
                octave: registerOctave,
                chord: activeChord,
                context: context,
                prev: previousTarget
            )

        case .southBassAnchors:
            return resolveBassAnchors(
                stickY: stickY,
                radius: radius,
                velocity: noteVelocity,
                octave: max(2, registerOctave - 1),
                chord: activeChord,
                context: context
            )

        case .eastDiatonicScale:
            return resolveDiatonicRuns(
                stickX: stickX,
                radius: radius,
                velocity: noteVelocity,
                octave: registerOctave,
                chord: activeChord,
                context: context,
                prev: previousTarget
            )

        case .westEnclosures:
            return resolveEnclosuresAndBlues(
                stickX: stickX,
                radius: radius,
                velocity: noteVelocity,
                octave: registerOctave,
                chord: activeChord,
                context: context,
                prev: previousTarget
            )
        }
    }

    /// Resolves optimal voice leading when the underlying chord changes during a sustained solo line.
    public func resolveChordTransition(
        from previousNote: Note,
        oldChord: Chord,
        newChord: Chord,
        context: MusicalContext
    ) -> SoloTargetResolution {
        let newTones = newChord.pitchClasses
        let guideTones: [PitchClass] = [
            newChord.pitchClass(for: .third),
            newChord.pitchClass(for: .seventh)
        ]

        // Find nearest guide tone first (3rd or 7th)
        var bestTone = newTones.first ?? newChord.root
        var bestDistance = Int.max

        for gt in guideTones {
            let rawDist = abs(previousNote.pitchClass.semitones(to: gt))
            let dist = min(rawDist, 12 - rawDist)
            if dist < bestDistance {
                bestDistance = dist
                bestTone = gt
            }
        }

        // Target note voiced closest to previous note
        let target = nearestNote(of: bestTone, to: previousNote)
        let isGuide = guideTones.contains(bestTone)

        let roleLabel: String
        if bestTone == newChord.root {
            roleLabel = "Root (\(bestTone.displayName))"
        } else if bestTone == newChord.pitchClass(for: .third) {
            roleLabel = "3rd Guide Tone (\(bestTone.displayName))"
        } else if bestTone == newChord.pitchClass(for: .seventh) {
            roleLabel = "7th Guide Tone (\(bestTone.displayName))"
        } else if bestTone == newChord.pitchClass(for: .fifth) {
            roleLabel = "5th Anchor (\(bestTone.displayName))"
        } else {
            roleLabel = "Target (\(bestTone.displayName))"
        }

        return SoloTargetResolution(
            targetNote: target,
            roleLabel: roleLabel,
            isChordTone: true,
            isGuideTone: isGuide,
            velocity: 95,
            articulation: .sustain,
            theoryExplanation: "Voice-led resolution: \(previousNote.pitchClass.displayName) → \(bestTone.displayName) on \(newChord.displayName)"
        )
    }

    // MARK: - Internal Quadrant Resolvers

    private func resolveGuideTones(
        stickY: Double,
        radius: Double,
        velocity: UInt8,
        octave: Int,
        chord: Chord,
        context: MusicalContext,
        prev: Note?
    ) -> SoloTargetResolution {
        // High North prioritizes 7ths, 9ths, and 3rds (guide tones)
        let third = chord.pitchClass(for: .third)
        let seventh = chord.pitchClass(for: .seventh)
        let fifth = chord.pitchClass(for: .fifth)

        let selectedTone: PitchClass
        let roleName: String

        if radius > 0.75 {
            // Extension or 7th
            selectedTone = seventh
            roleName = "7th Guide Tone (\(seventh.displayName))"
        } else if radius > 0.45 {
            // 3rd
            selectedTone = third
            roleName = "3rd Guide Tone (\(third.displayName))"
        } else {
            // 5th
            selectedTone = fifth
            roleName = "5th Harmonic Anchor (\(fifth.displayName))"
        }

        var target = Note(pitchClass: selectedTone, octave: octave)
        if let prev {
            target = nearestNote(of: selectedTone, to: prev)
        }

        let isScreaming = radius > 0.93
        let bend = isScreaming ? 2.0 : 0.0

        return SoloTargetResolution(
            targetNote: target,
            roleLabel: roleName,
            isChordTone: true,
            isGuideTone: true,
            velocity: isScreaming ? 127 : velocity,
            pitchBendSemitones: bend,
            articulation: isScreaming ? .screamingBend : .sustain,
            theoryExplanation: "Guide-tone target locked to \(chord.displayName)"
        )
    }

    private func resolveBassAnchors(
        stickY: Double,
        radius: Double,
        velocity: UInt8,
        octave: Int,
        chord: Chord,
        context: MusicalContext
    ) -> SoloTargetResolution {
        let root = chord.root
        let fifth = chord.pitchClass(for: .fifth)
        let tone = radius > 0.65 ? fifth : root
        let target = Note(pitchClass: tone, octave: octave)

        return SoloTargetResolution(
            targetNote: target,
            roleLabel: tone == root ? "Root Anchor (\(root.displayName))" : "5th Low Anchor (\(fifth.displayName))",
            isChordTone: true,
            velocity: velocity,
            theoryExplanation: "Bass grounding tone on \(chord.displayName)"
        )
    }

    private func resolveDiatonicRuns(
        stickX: Double,
        radius: Double,
        velocity: UInt8,
        octave: Int,
        chord: Chord,
        context: MusicalContext,
        prev: Note?
    ) -> SoloTargetResolution {
        let scaleTones = context.scaleTones
        guard !scaleTones.isEmpty else {
            return SoloTargetResolution(targetNote: Note(pitchClass: chord.root, octave: octave), roleLabel: "Root")
        }

        // Stepped scale degree selection based on radius
        let index = Int(floor(radius * Double(scaleTones.count))) % scaleTones.count
        let tone = scaleTones[index]
        let isChord = context.isChordTone(tone)

        var target = Note(pitchClass: tone, octave: octave)
        if let prev {
            target = nearestNote(of: tone, to: prev)
        }

        return SoloTargetResolution(
            targetNote: target,
            roleLabel: isChord ? "Chord Tone (\(tone.displayName))" : "Scale Passing Tone (\(tone.displayName))",
            isChordTone: isChord,
            isPassingTone: !isChord,
            velocity: velocity,
            theoryExplanation: "Diatonic run locked to \(context.key.displayName) \(context.scale.type.rawValue)"
        )
    }

    private func resolveEnclosuresAndBlues(
        stickX: Double,
        radius: Double,
        velocity: UInt8,
        octave: Int,
        chord: Chord,
        context: MusicalContext,
        prev: Note?
    ) -> SoloTargetResolution {
        let targetChordTone = chord.pitchClass(for: .third)
        let anchor = Note(pitchClass: targetChordTone, octave: octave)

        // Chromatic lower approach: target - 1 semitone
        let lowerApproach = anchor.transposed(by: -1)
        // Blue note: root + 6 semitones (flatted 5th)
        let blueNote = Note(pitchClass: chord.root.transposed(by: 6), octave: octave)

        if radius > 0.70 {
            // Blues flat-5 note
            return SoloTargetResolution(
                targetNote: blueNote,
                roleLabel: "♭5 Blue Note (\(blueNote.pitchClass.displayName))",
                isChordTone: false,
                isPassingTone: true,
                isBlueNote: true,
                velocity: velocity,
                articulation: .bluesFlourish,
                theoryExplanation: "Blues tension against \(chord.displayName)",
                approachPath: [blueNote, anchor]
            )
        } else {
            // Chromatic approach enclosure
            return SoloTargetResolution(
                targetNote: anchor,
                roleLabel: "Chromatic Approach → \(targetChordTone.displayName)",
                isChordTone: true,
                isGuideTone: true,
                isPassingTone: true,
                velocity: velocity,
                articulation: .graceNote,
                theoryExplanation: "Half-step enclosure resolving to 3rd",
                approachPath: [lowerApproach, anchor]
            )
        }
    }

    // MARK: - Helpers

    public func polarQuadrant(for angle: Double) -> SoloPolarQuadrant {
        // angle: -PI ... +PI (0 is East/Right, PI/2 is North/Up)
        if angle >= 0.25 * .pi && angle <= 0.75 * .pi {
            return .northGuideTones
        } else if angle >= -0.75 * .pi && angle <= -0.25 * .pi {
            return .southBassAnchors
        } else if angle > -0.25 * .pi && angle < 0.25 * .pi {
            return .eastDiatonicScale
        } else {
            return .westEnclosures
        }
    }

    private func calculateOctave(radius: Double, baseOctave: Int) -> Int {
        if radius > 0.85 {
            return baseOctave + 1
        } else if radius < 0.35 {
            return max(2, baseOctave - 1)
        }
        return baseOctave
    }

    private func nearestNote(of pitchClass: PitchClass, to reference: Note) -> Note {
        let refMidi = Int(reference.midiNote)
        var bestMidi = refMidi
        var bestDist = Int.max

        for midi in 36...96 where midi % 12 == pitchClass.rawValue {
            let dist = abs(midi - refMidi)
            if dist < bestDist {
                bestDist = dist
                bestMidi = midi
            }
        }
        return Note.fromMIDI(UInt8(bestMidi))
    }
}
