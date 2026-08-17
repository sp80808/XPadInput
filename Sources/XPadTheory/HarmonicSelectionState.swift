import Foundation

/// Radial meaning of left-stick travel on the harmonic wheel.
public enum HarmonicRadialRegion: String, Sendable, Equatable {
    case rest
    case ordinary
    case risk
}

/// One evaluation of left-stick harmonic selection.
public struct HarmonicSelectionSnapshot: Sendable, Equatable {
    public var sectorIndex: Int
    public var region: HarmonicRadialRegion
    public var didCommitSector: Bool
    public var didEnterRisk: Bool

    public init(
        sectorIndex: Int,
        region: HarmonicRadialRegion,
        didCommitSector: Bool,
        didEnterRisk: Bool
    ) {
        self.sectorIndex = sectorIndex
        self.region = region
        self.didCommitSector = didCommitSector
        self.didEnterRisk = didEnterRisk
    }
}

/// Stateful harmonic-wheel selection with angular hysteresis, a sticky rest zone,
/// and a deliberate outer risk band.
///
/// Angle convention matches PLAY: `atan2(y, x)` with Y up, index 0 at north
/// (`π/2`), increasing clockwise. Visual selection must use `committedIndex`,
/// never the raw instantaneous sector.
public struct HarmonicSelectionState: Sendable, Equatable {
    public var sectorCount: Int
    public var committedIndex: Int
    public var region: HarmonicRadialRegion

    public var restEnterRadius: Double
    public var restExitRadius: Double
    public var riskEnterRadius: Double
    public var riskExitRadius: Double
    /// Extra angular width, as a fraction of one sector, added to the committed slice.
    public var hysteresisFraction: Double

    public init(
        sectorCount: Int = 7,
        committedIndex: Int = 0,
        region: HarmonicRadialRegion = .rest,
        restEnterRadius: Double = 0.28,
        restExitRadius: Double = 0.34,
        riskEnterRadius: Double = 0.82,
        riskExitRadius: Double = 0.72,
        hysteresisFraction: Double = 0.18
    ) {
        self.sectorCount = max(1, sectorCount)
        self.committedIndex = Self.clampIndex(committedIndex, count: self.sectorCount)
        self.region = region
        self.restEnterRadius = restEnterRadius
        self.restExitRadius = max(restEnterRadius, restExitRadius)
        self.riskEnterRadius = riskEnterRadius
        self.riskExitRadius = min(riskEnterRadius, riskExitRadius)
        self.hysteresisFraction = max(0, min(0.45, hysteresisFraction))
    }

    public mutating func resize(sectorCount: Int) {
        self.sectorCount = max(1, sectorCount)
        committedIndex = Self.clampIndex(committedIndex, count: self.sectorCount)
    }

    public mutating func commit(index: Int) {
        committedIndex = Self.clampIndex(index, count: sectorCount)
    }

    public mutating func reset(index: Int = 0) {
        committedIndex = Self.clampIndex(index, count: sectorCount)
        region = .rest
    }

    public mutating func evaluate(angle: Double, radius: Double) -> HarmonicSelectionSnapshot {
        let previousIndex = committedIndex
        let previousRegion = region
        let clampedRadius = radius.isFinite ? max(0, min(1, radius)) : 0

        region = updatedRegion(radius: clampedRadius)

        if region == .rest {
            return HarmonicSelectionSnapshot(
                sectorIndex: committedIndex,
                region: region,
                didCommitSector: false,
                didEnterRisk: false
            )
        }

        let raw = Self.rawIndex(angle: angle, sectorCount: sectorCount)
        if !isInsideCommittedBand(angle: angle) {
            committedIndex = raw
        }

        return HarmonicSelectionSnapshot(
            sectorIndex: committedIndex,
            region: region,
            didCommitSector: committedIndex != previousIndex,
            didEnterRisk: region == .risk && previousRegion != .risk
        )
    }

    /// PLAY stick angle whose sector centre is `index` (north = 0, clockwise).
    public static func stickAngle(forIndex index: Int, sectorCount: Int) -> Double {
        let count = max(1, sectorCount)
        let slice = (2.0 * .pi) / Double(count)
        return .pi / 2.0 - Double(clampIndex(index, count: count)) * slice
    }

    public static func rawIndex(angle: Double, sectorCount: Int) -> Int {
        let count = max(1, sectorCount)
        var normalised = -(angle - .pi / 2.0)
        normalised = wrap2pi(normalised)
        let slice = (2.0 * .pi) / Double(count)
        let centred = wrap2pi(normalised + slice / 2.0)
        return Int(centred / slice) % count
    }

    private mutating func updatedRegion(radius: Double) -> HarmonicRadialRegion {
        switch region {
        case .rest:
            if radius >= restExitRadius {
                return radius >= riskEnterRadius ? .risk : .ordinary
            }
            return .rest
        case .ordinary:
            if radius < restEnterRadius { return .rest }
            if radius >= riskEnterRadius { return .risk }
            return .ordinary
        case .risk:
            if radius < restEnterRadius { return .rest }
            if radius <= riskExitRadius { return .ordinary }
            return .risk
        }
    }

    private func isInsideCommittedBand(angle: Double) -> Bool {
        let slice = (2.0 * .pi) / Double(sectorCount)
        let margin = slice * hysteresisFraction
        var normalised = wrap2pi(-(angle - .pi / 2.0))
        let center = Double(committedIndex) * slice
        var delta = normalised - center
        if delta > .pi { delta -= 2.0 * .pi }
        if delta < -.pi { delta += 2.0 * .pi }
        return abs(delta) <= (slice / 2.0 + margin)
    }

    private static func clampIndex(_ index: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        let mod = index % count
        return mod < 0 ? mod + count : mod
    }

    private static func wrap2pi(_ value: Double) -> Double {
        var x = value.truncatingRemainder(dividingBy: 2.0 * .pi)
        if x < 0 { x += 2.0 * .pi }
        return x
    }
}
