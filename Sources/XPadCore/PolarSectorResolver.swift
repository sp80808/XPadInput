import Foundation

/// Maps an analog stick angle onto one of `sectorCount` equal radial sectors.
///
/// The harmonic wheel, the active-progression selector, and the Rhythm Compass
/// all describe "point the stick at the musical idea you want" with the same
/// geometry. Keeping that geometry in one deterministic place means a thumb
/// position that highlights a sector on screen always selects the chord that
/// sector promises.
///
/// The convention is:
/// - sector `0` is centred on "up" (`+y`, `π/2` radians);
/// - indices advance clockwise: up → right → down → left;
/// - each boundary owns a narrow neutral band, outside which `nil` is returned
///   so resting analog jitter cannot flicker between neighbouring sectors.
public enum PolarSectorResolver {
    /// Fraction of a sector, on each side of a boundary, treated as neutral.
    public static let defaultEdgeInset: Double = 0.14

    /// Rotates a raw stick angle so "up" reads as `0` and angles increase clockwise.
    public static func wheelAngle(forStickAngle angle: Double) -> Double {
        guard angle.isFinite else { return 0 }
        var normalised = -(angle - .pi / 2)
        normalised = normalised.truncatingRemainder(dividingBy: 2 * .pi)
        if normalised < 0 { normalised += 2 * .pi }
        return normalised
    }

    /// Zero-based sector index for a stick angle, or `nil` inside a neutral band.
    ///
    /// - Parameters:
    ///   - angle: Stick angle in radians as reported by `ProcessedStickState.angle`.
    ///   - sectorCount: Number of equal sectors around the centre. Must be positive.
    ///   - edgeInset: Fraction of a sector kept neutral on each side of a boundary.
    public static func sectorIndex(
        angle: Double,
        sectorCount: Int,
        edgeInset: Double = defaultEdgeInset
    ) -> Int? {
        guard sectorCount > 0, angle.isFinite else { return nil }
        guard let slot = slot(angle: angle, sectorCount: sectorCount, edgeInset: edgeInset) else {
            return nil
        }
        return slot.index
    }

    /// Radial slot for a stick angle, including how far into the sector it sits.
    ///
    /// `positionWithinSector` runs 0...1 from the leading boundary to the trailing
    /// one, which lets callers scale musical risk by how deliberately the player
    /// aimed inside a sector instead of resting on its edge.
    public static func slot(
        angle: Double,
        sectorCount: Int,
        edgeInset: Double = defaultEdgeInset
    ) -> (index: Int, positionWithinSector: Double)? {
        guard sectorCount > 0, angle.isFinite else { return nil }
        let inset = edgeInset.clamped(to: 0...0.5)
        let sliceAngle = (2 * Double.pi) / Double(sectorCount)
        let rotated = wheelAngle(forStickAngle: angle)
        let centred = (rotated + sliceAngle / 2).truncatingRemainder(dividingBy: 2 * Double.pi)
        let slicePosition = centred / sliceAngle
        let index = Int(slicePosition) % sectorCount
        let positionWithinSector = slicePosition - floor(slicePosition)
        guard positionWithinSector > inset, positionWithinSector < 1 - inset else { return nil }
        return (index, positionWithinSector)
    }

    /// Signed shortest angular distance between two stick angles, in radians.
    ///
    /// Useful for hysteresis decisions such as "has the thumb actually moved to a
    /// new sector" without treating the `±π` wrap as a full-circle jump.
    public static func shortestAngularDistance(from angle: Double, to other: Double) -> Double {
        guard angle.isFinite, other.isFinite else { return 0 }
        var delta = (other - angle).truncatingRemainder(dividingBy: 2 * Double.pi)
        if delta > .pi { delta -= 2 * .pi }
        if delta < -.pi { delta += 2 * .pi }
        return delta
    }
}
