import Foundation
import XPadCore
import XPadTheory
import XPadMIDI

/// Writes basslines that follow a progression's chords.
///
/// The generator only ever plays notes that belong to the chord under it
/// (root, third, fifth, octave) or a chromatic approach into the next chord, so
/// the result is playable by construction. Feel is a musical choice, not a
/// random one: house pumps octaves, jazz walks, neo-soul anticipates the beat.
public enum BasslineGenerator {
    /// How the line moves.
    public enum Feel: String, CaseIterable, Identifiable, Sendable {
        /// Quarter-note roots with the occasional fifth. Pop, rock, singer-songwriter.
        case rootNotes = "Root Notes"
        /// Root, third, fifth, then a chromatic approach into the next chord. Jazz.
        case walking = "Walking"
        /// Eighth-note root/octave alternation with accents on the beat. House, disco.
        case octavePulse = "Octave Pulse"
        /// Sparse hits that anticipate the chord change. Neo-soul, gospel, funk.
        case syncopated = "Syncopated"
        /// Long sustained roots with an octave lift. Ambient, cinematic.
        case drone = "Drone Octaves"

        public var id: String { rawValue }
    }

    /// MIDI note of C2, the default register for basslines.
    public static let defaultBaseNote: UInt8 = 36

    /// MIDI note for a pitch class in a given octave, where C4 is 60.
    public static func note(for pitchClass: PitchClass, octave: Int) -> UInt8 {
        let octave = octave.clamped(to: 0...7)
        let note = 12 * (octave + 1) + Int(pitchClass.rawValue)
        return UInt8(note.clamped(to: 0...127))
    }

    /// Generates a bassline for a whole progression.
    ///
    /// - Parameters:
    ///   - progression: Harmony to follow. Block durations drive the rhythm.
    ///   - feel: How the line moves.
    ///   - octave: Register of the chord roots (2 is the low bass octave).
    ///   - seed: Reproducible velocity humanisation and note choices.
    public static func generate(
        progression: Progression,
        feel: Feel = .rootNotes,
        octave: Int = 2,
        seed: UInt64 = 0
    ) -> [RecordedNoteEvent] {
        guard !progression.blocks.isEmpty else { return [] }
        var random = DeterministicRandom(seed: seed)
        var events: [RecordedNoteEvent] = []
        var cursor: UInt64 = 0

        for (index, block) in progression.blocks.enumerated() {
            let blockTicks = max(SequencerGrid.ticksPerBeat, SequencerGrid.ticks(forBeats: block.durationBeats))
            let root = note(for: block.chord.root, octave: octave)
            let nextRoot: UInt8? = index + 1 < progression.blocks.count
                ? note(for: progression.blocks[index + 1].chord.root, octave: octave)
                : nil

            let hits = strokes(
                feel: feel,
                chord: block.chord,
                root: root,
                nextRoot: nextRoot,
                blockTicks: blockTicks,
                random: &random
            )

            for hit in hits {
                let jitter = Int(random.nextDouble(in: -5, 5).rounded())
                events.append(
                    RecordedNoteEvent(
                        note: hit.note,
                        velocity: UInt8((Int(hit.velocity) + jitter).clamped(to: 1...127)),
                        startTick: cursor + hit.tickOffset,
                        durationTicks: min(hit.durationTicks, blockTicks)
                    )
                )
            }
            cursor += blockTicks
        }

        return events.sorted { $0.startTick < $1.startTick }
    }

    /// Wraps `generate(progression:feel:octave:seed:)` in a clip for the bass track.
    public static func clip(
        progression: Progression,
        feel: Feel = .rootNotes,
        octave: Int = 2,
        seed: UInt64 = 0,
        name: String? = nil
    ) -> SequencerClip {
        let events = generate(progression: progression, feel: feel, octave: octave, seed: seed)
        let lengthTicks = progression.blocks.reduce(UInt64(0)) { total, block in
            total + max(SequencerGrid.ticksPerBeat, SequencerGrid.ticks(forBeats: block.durationBeats))
        }
        return SequencerClip(
            name: name ?? "Bass \(progression.root.standardName)",
            startTick: 0,
            durationTicks: max(SequencerGrid.ticksPerBar, lengthTicks),
            notes: events
        )
    }

    /// Chooses a feel that suits a style name from `HarmonicStyleLibrary`.
    public static func feel(forStyleName name: String) -> Feel {
        let lower = name.lowercased()
        if lower.contains("jazz") { return .walking }
        if lower.contains("neo-soul") || lower.contains("gospel") || lower.contains("funk") { return .syncopated }
        if lower.contains("house") || lower.contains("synthwave") || lower.contains("liquid") || lower.contains("disco") {
            return .octavePulse
        }
        if lower.contains("ambient") || lower.contains("cinematic") || lower.contains("drone") { return .drone }
        return .rootNotes
    }

    // MARK: - Patterns

    private struct Stroke {
        let tickOffset: UInt64
        let note: UInt8
        let velocity: UInt8
        let durationTicks: UInt64
    }

    private static func strokes(
        feel: Feel,
        chord: Chord,
        root: UInt8,
        nextRoot: UInt8?,
        blockTicks: UInt64,
        random: inout DeterministicRandom
    ) -> [Stroke] {
        let intervals = chord.quality.intervals
        let third = UInt8((Int(root) + max(1, intervals.count > 1 ? intervals[1] : 4)).clamped(to: 0...127))
        let fifth = UInt8((Int(root) + (intervals.count > 2 ? intervals[2] : 7)).clamped(to: 0...127))
        let octave = UInt8((Int(root) + 12).clamped(to: 0...127))
        let gap: UInt64 = 80
        let sounding = max(1, blockTicks - gap)

        func tick(_ beats: Double) -> UInt64 {
            min(SequencerGrid.ticks(forBeats: beats), blockTicks - 1)
        }

        switch feel {
        case .rootNotes:
            var strokes = [
                Stroke(tickOffset: tick(0), note: root, velocity: 98, durationTicks: SequencerGrid.ticks(forBeats: 0.9)),
                Stroke(tickOffset: tick(1), note: root, velocity: 88, durationTicks: SequencerGrid.ticks(forBeats: 0.9))
            ]
            // A fifth on beat three gives the line somewhere to go without
            // turning every bar into the same four notes.
            let beatThreeNote = random.chance(0.45) ? fifth : root
            strokes.append(Stroke(tickOffset: tick(2), note: beatThreeNote, velocity: 92, durationTicks: SequencerGrid.ticks(forBeats: 0.9)))
            if blockTicks >= SequencerGrid.ticksPerBar {
                strokes.append(Stroke(tickOffset: tick(3), note: root, velocity: 86, durationTicks: SequencerGrid.ticks(forBeats: 0.9)))
            }
            return strokes.filter { $0.tickOffset < blockTicks }

        case .walking:
            // Root, third, fifth, then a chromatic approach into the next root.
            let approach: UInt8
            if let nextRoot, nextRoot > root {
                approach = nextRoot - 1
            } else if let nextRoot {
                approach = nextRoot + 1
            } else {
                approach = fifth
            }
            var strokes: [Stroke] = []
            let beats: [Double] = [0, 1, 2, 3]
            let notes: [UInt8] = [root, third, fifth, approach]
            for (index, beat) in beats.enumerated() {
                let offset = tick(beat)
                guard offset < blockTicks else { continue }
                strokes.append(
                    Stroke(
                        tickOffset: offset,
                        note: notes[index],
                        velocity: 94,
                        durationTicks: SequencerGrid.ticks(forBeats: 0.85)
                    )
                )
            }
            return strokes

        case .octavePulse:
            // Eighth notes, accenting the beat, root below the octave above.
            var strokes: [Stroke] = []
            let eighths = Int((Double(blockTicks) / Double(SequencerGrid.ticksPerBeat) * 2).rounded(.down))
            for step in 0..<max(0, eighths) {
                let offset = UInt64(step) * (SequencerGrid.ticksPerBeat / 2)
                guard offset < blockTicks else { break }
                let isBeat = step % 2 == 0
                strokes.append(
                    Stroke(
                        tickOffset: offset,
                        note: isBeat ? root : octave,
                        velocity: isBeat ? 104 : 82,
                        durationTicks: SequencerGrid.ticksPerBeat / 2 - gap
                    )
                )
            }
            return strokes

        case .syncopated:
            // Hits that lean into the chord change rather than sitting on it.
            var strokes = [
                Stroke(tickOffset: tick(0), note: root, velocity: 102, durationTicks: SequencerGrid.ticks(forBeats: 1.2)),
                Stroke(tickOffset: tick(1.5), note: root, velocity: 82, durationTicks: SequencerGrid.ticks(forBeats: 0.35))
            ]
            if blockTicks >= SequencerGrid.ticksPerBar {
                strokes.append(Stroke(tickOffset: tick(2), note: fifth, velocity: 92, durationTicks: SequencerGrid.ticks(forBeats: 0.9)))
            }
            if let nextRoot, nextRoot != root {
                strokes.append(
                    Stroke(
                        tickOffset: tick(Double(blockTicks) / Double(SequencerGrid.ticksPerBeat) - 0.5),
                        note: nextRoot,
                        velocity: 96,
                        durationTicks: SequencerGrid.ticks(forBeats: 0.4)
                    )
                )
            }
            return strokes.filter { $0.tickOffset < blockTicks }

        case .drone:
            var strokes = [
                Stroke(tickOffset: 0, note: root, velocity: 84, durationTicks: sounding)
            ]
            if blockTicks >= SequencerGrid.ticksPerBar * 2 {
                strokes.append(Stroke(tickOffset: blockTicks / 2, note: octave, velocity: 72, durationTicks: blockTicks / 2 - gap))
            }
            return strokes
        }
    }
}
