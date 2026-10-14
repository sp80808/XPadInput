import Foundation
import XPadCore
import XPadTheory

/// A decision the co-pilot wants the backing band to take on the next bar.
public struct CoPilotDirective: Equatable, Sendable {
    /// What to do.
    public enum Kind: Equatable, Sendable {
        /// Leave the arrangement alone.
        case hold
        /// Give the player space by muting a role.
        case dropOut(TrackType)
        /// Bring a role back in.
        case addLayer(TrackType)
        /// Play a drum fill into the next bar.
        case drumFill(intensity: Double)
        /// Push the whole arrangement up a level (denser, louder).
        case lift(intensity: Double)
        /// The player has been circling the same harmony; write a new one.
        case regenerate(styleName: String)
    }

    public let kind: Kind
    /// Human-readable why, shown in the UI so the co-pilot never feels random.
    public let reason: String
    /// Bar the decision was taken on.
    public let bar: Int

    public init(kind: Kind, reason: String, bar: Int) {
        self.kind = kind
        self.reason = reason
        self.bar = bar
    }

    public static func hold(bar: Int) -> CoPilotDirective {
        CoPilotDirective(kind: .hold, reason: "Laying back", bar: bar)
    }

    /// Should the host act on this directive?
    public var isActionable: Bool {
        kind != .hold
    }
}

/// Rule-based jam co-pilot: a session musician's instincts, not a neural net.
///
/// The co-pilot watches what the player is doing — how hard they are playing,
/// which roles are already sounding, how long they have stayed on one
/// progression — and decides what the backing should do next. Every rule is
/// musical and explainable, and every decision is reproducible from a seed, so
/// the same performance always gets the same arrangement.
///
/// The engine is deliberately pure: it returns a `CoPilotDirective` and lets
/// the host decide how to realise it (mute a track, insert a fill clip, write a
/// new progression with `StyleMorphEngine`).
public struct JamCoPilot: Sendable {
    /// Bars between decisions. Eight bars is one conventional section.
    public var sectionLengthBars: Int
    /// Never thin the arrangement below this many sounding roles.
    public var minimumLayers: Int
    /// Never stack more than this many roles.
    public var maximumLayers: Int
    /// Play a fill this many bars before a section ends.
    public var fillEverySection: Bool

    /// Roles in the order a band usually builds them.
    public static let buildOrder: [TrackType] = [.drums, .bass, .chords, .melody, .gesture]

    public init(
        sectionLengthBars: Int = 8,
        minimumLayers: Int = 1,
        maximumLayers: Int = 4,
        fillEverySection: Bool = true
    ) {
        self.sectionLengthBars = max(1, sectionLengthBars)
        self.minimumLayers = max(1, minimumLayers)
        self.maximumLayers = max(self.minimumLayers, maximumLayers)
        self.fillEverySection = fillEverySection
    }

    /// Next 0-based bar index at which the arrangement may change.
    public func nextSectionBoundary(after bar: Int) -> Int {
        ((bar / sectionLengthBars) + 1) * sectionLengthBars
    }

    /// How far through the current section `bar` is, `0...1`.
    public func sectionProgress(at bar: Int) -> Double {
        let position = bar % sectionLengthBars
        return Double(position) / Double(sectionLengthBars)
    }

    /// Decides what the backing should do when the transport enters `bar`.
    ///
    /// - Parameters:
    ///   - bar: 0-based bar inside the current scene.
    ///   - energy: Player intensity, `0...1` (velocity and playing density).
    ///   - activeLayers: Roles currently sounding.
    ///   - availableLayers: Roles that have material to play.
    ///   - sameProgressionBars: How long the player has stayed on this harmony.
    ///   - styleName: Name of the style the co-pilot may regenerate into.
    ///   - seed: Seed for reproducible tie-breaking.
    public func directive(
        bar: Int,
        energy: Double,
        activeLayers: [TrackType],
        availableLayers: [TrackType],
        sameProgressionBars: Int = 0,
        styleName: String = "Jam Co-Pilot",
        seed: UInt64 = 0
    ) -> CoPilotDirective {
        let energy = energy.normalizedUnit
        var random = DeterministicRandom(seed: seed &+ UInt64(bitPattern: Int64(bar)) &* 0x9E37_79B9)

        // A fill belongs in the last bar of a section, so the downbeat lands on
        // the new section rather than in the middle of one.
        if fillEverySection,
           sectionLengthBars > 1,
           (bar % sectionLengthBars) == sectionLengthBars - 1 {
            return CoPilotDirective(
                kind: .drumFill(intensity: energy),
                reason: "Turning the section around",
                bar: bar
            )
        }

        // Decisions land on section boundaries.
        guard bar > 0, bar % sectionLengthBars == 0 else {
            return .hold(bar: bar)
        }

        // Staying on one progression for two whole sections is a rut, so write
        // something new in the current style instead of looping forever.
        if sameProgressionBars >= sectionLengthBars * 2, energy < 0.8 {
            return CoPilotDirective(
                kind: .regenerate(styleName: styleName),
                reason: "Two sections on the same chords — new harmony",
                bar: bar
            )
        }

        let layers = Set(activeLayers)
        let playable = JamCoPilot.buildOrder.filter { availableLayers.contains($0) }
        let missing = playable.filter { !layers.contains($0) }

        // Quiet playing + a thick arrangement: clear space for the player.
        if energy < 0.35, layers.count > minimumLayers {
            if let victim = layers.intersection([.melody, .gesture, .chords]).max(by: { $0.rawValue < $1.rawValue }) {
                return CoPilotDirective(
                    kind: .dropOut(victim),
                    reason: "You are playing softly — dropping \(victim.rawValue.lowercased())",
                    bar: bar
                )
            }
        }

        // Loud playing with room to grow: build the arrangement up.
        if energy > 0.62, layers.count < maximumLayers, let next = missing.first {
            return CoPilotDirective(
                kind: .addLayer(next),
                reason: "You are pushing — bringing in \(next.rawValue.lowercased())",
                bar: bar
            )
        }

        // Otherwise keep it interesting: every other section lifts, whatever
        // the player does, so the arrangement breathes.
        let sectionIndex = bar / sectionLengthBars
        if sectionIndex % 2 == 0, energy > 0.4, random.chance(0.6) {
            return CoPilotDirective(
                kind: .lift(intensity: min(1.0, energy + 0.15)),
                reason: "Opening up the section",
                bar: bar
            )
        }

        return .hold(bar: bar)
    }
}
