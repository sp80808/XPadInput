import Foundation
import XPadCore
import XPadMIDI

/// Generates drum fills for the end of a section.
///
/// A fill is the drummer's way of saying "here comes the next section", so the
/// generator only ever writes into the last beat(s) of a bar and always leaves
/// the final sixteenth empty — the downbeat belongs to the new section.
public enum DrumFillGenerator {
    /// General MIDI drum notes, matching `BuiltInDrumSound`.
    public static let kick: UInt8 = 36
    public static let snare: UInt8 = 38
    public static let closedHat: UInt8 = 42
    public static let openHat: UInt8 = 46

    /// One drum hit inside a fill.
    public struct Hit: Equatable, Sendable {
        /// MIDI note number.
        public let note: UInt8
        public let velocity: UInt8
        /// Ticks from the start of the pattern.
        public let tickOffset: UInt64

        public init(note: UInt8, velocity: UInt8, tickOffset: UInt64) {
            self.note = note
            self.velocity = velocity
            self.tickOffset = tickOffset
        }
    }

    /// A hit at a beat position measured backwards from the end of the pattern.
    private struct Stroke {
        let beatsBeforeEnd: Double
        let note: UInt8
        let velocity: UInt8
    }

    /// Builds a fill for a pattern `beats` long, ending on a downbeat.
    ///
    /// - Parameters:
    ///   - intensity: `0...1`. Quiet playing gets a two-note pickup; loud
    ///     playing gets a sixteenth-note run across two beats.
    ///   - beats: Length of the pattern in quarter notes (a bar of 4/4 is 4).
    ///   - seed: Reproducible velocity humanisation.
    public static func fill(intensity: Double = 0.5, beats: Double = 4, seed: UInt64 = 0) -> [Hit] {
        guard beats > 0, beats.isFinite else { return [] }
        let level = intensity.normalizedUnit
        let strokes = strokes(for: level, patternBeats: beats)
        let patternTicks = SequencerGrid.ticks(forBeats: beats)
        var random = DeterministicRandom(seed: seed)

        let hits = strokes.map { stroke -> Hit in
            let position = max(0, beats - stroke.beatsBeforeEnd)
            let tick = SequencerGrid.ticks(forBeats: position)
            let jitter = Int(random.nextDouble(in: -6, 6).rounded())
            let velocity = (Int(stroke.velocity) + jitter).clamped(to: 1...127)
            return Hit(
                note: stroke.note,
                velocity: UInt8(velocity),
                tickOffset: min(tick, patternTicks == 0 ? 0 : patternTicks - 1)
            )
        }

        return hits.sorted { $0.tickOffset < $1.tickOffset }
    }

    /// Wraps `fill(intensity:beats:seed:)` in a clip for the drums track.
    public static func clip(
        intensity: Double = 0.5,
        beats: Double = 4,
        seed: UInt64 = 0,
        name: String = "Fill",
        startTick: UInt64 = 0,
        velocityScale: Double = 1.0
    ) -> SequencerClip {
        let scale = velocityScale.clamped(to: 0.1...1.0)
        let notes = fill(intensity: intensity, beats: beats, seed: seed).map { hit in
            RecordedNoteEvent(
                note: hit.note,
                velocity: UInt8((Double(hit.velocity) * scale).rounded().clamped(to: 1...127)),
                startTick: hit.tickOffset,
                durationTicks: 120
            )
        }
        return SequencerClip(
            name: name,
            startTick: startTick,
            durationTicks: SequencerGrid.ticks(forBeats: beats),
            notes: notes
        )
    }

    // MARK: - Patterns

    private static func strokes(for intensity: Double, patternBeats: Double) -> [Stroke] {
        // The run always ends on the last sixteenth before the downbeat so the
        // fill pushes into the next section instead of sitting on top of it.
        let pickup: [Stroke] = [
            Stroke(beatsBeforeEnd: 0.5, note: snare, velocity: 104),
            Stroke(beatsBeforeEnd: 0.25, note: closedHat, velocity: 72)
        ]

        switch intensity {
        case ..<0.34:
            return pickup.filter { $0.beatsBeforeEnd <= patternBeats }

        case ..<0.67:
            let run: [Stroke] = [
                Stroke(beatsBeforeEnd: 1.5, note: kick, velocity: 98),
                Stroke(beatsBeforeEnd: 1.0, note: snare, velocity: 92),
                Stroke(beatsBeforeEnd: 0.75, note: closedHat, velocity: 76),
                Stroke(beatsBeforeEnd: 0.5, note: snare, velocity: 106),
                Stroke(beatsBeforeEnd: 0.25, note: closedHat, velocity: 80)
            ]
            return run.filter { $0.beatsBeforeEnd <= patternBeats }

        default:
            let sixteenths: [Double] = [2.0, 1.75, 1.5, 1.25, 1.0, 0.75, 0.5, 0.25]
            var run: [Stroke] = []
            for (index, beatsBeforeEnd) in sixteenths.enumerated() {
                // Accents on the quarter and the final sixteenth, ghost notes between.
                let isAccent = beatsBeforeEnd == 1.0 || beatsBeforeEnd == 0.25
                let note: UInt8 = isAccent ? snare : (index % 2 == 0 ? snare : kick)
                let velocity: UInt8 = isAccent ? 112 : 72
                run.append(Stroke(beatsBeforeEnd: beatsBeforeEnd, note: note, velocity: velocity))
            }
            run.append(Stroke(beatsBeforeEnd: 2.0, note: openHat, velocity: 88))
            return run.filter { $0.beatsBeforeEnd <= patternBeats }
        }
    }
}
