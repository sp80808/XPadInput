import Foundation
import XPadCore

/// A measurable harmonic fingerprint of a musical style.
///
/// Instead of shipping a fixed list of "genre progressions", XPI describes each
/// style as a point in a small feature space. That makes two things possible:
/// styles can be *interpolated* (morph a Neo-Soul vamp continuously into a
/// Synthwave loop), and generated progressions can be explained in terms of the
/// same numbers the UI displays.
///
/// Every axis is normalised to `0...1` except `chordsPerBar`, which is measured
/// in chords per 4/4 bar (`0.25` = one chord every four bars, `2` = two chords
/// per bar) — the axis that mostly determines whether harmony feels like a pad
/// bed, a ballad, or a groove.
public struct HarmonicStyleDNA: Codable, Sendable, Equatable {
    /// Human-readable style name, used for generated progression titles.
    public var name: String

    /// Emphasis on each mode-relative degree, `I` through `vii`. Index
    /// `0` is always the tonic, so a style can be transposed freely.
    public var degreeWeights: [Double]

    /// `0` = major-leaning, `1` = minor-leaning. Used when the caller does not
    /// supply a scale of their own.
    public var minorLean: Double

    /// `0` = bare triads, `1` = 9ths, 11ths, 13ths and altered colours.
    public var extensionRichness: Double

    /// `0` = triads stay triads, `1` = pad-like `sus2`/`sus4`/`add9` colour.
    public var suspendedColour: Double

    /// Rate at which modal interchange chords replace functional ones.
    public var borrowing: Double

    /// Rate at which a `V7/x` is inserted to pull into the following chord.
    public var secondaryDominantRate: Double

    /// Rate at which a dominant is replaced by its tritone substitute.
    public var tritoneSubstitutionRate: Double

    /// Rate at which a chord is re-rooted by a chromatic third (plane).
    public var mediantShiftRate: Double

    /// Chords per 4/4 bar.
    public var chordsPerBar: Double

    /// `0` = looping motion that avoids the tonic, `1` = strong `ii–V–I` pull.
    public var cadenceStrength: Double

    public init(
        name: String,
        degreeWeights: [Double],
        minorLean: Double,
        extensionRichness: Double,
        suspendedColour: Double = 0,
        borrowing: Double,
        secondaryDominantRate: Double,
        tritoneSubstitutionRate: Double = 0,
        mediantShiftRate: Double = 0,
        chordsPerBar: Double,
        cadenceStrength: Double
    ) {
        self.name = name
        self.degreeWeights = degreeWeights
        self.minorLean = minorLean
        self.extensionRichness = extensionRichness
        self.suspendedColour = suspendedColour
        self.borrowing = borrowing
        self.secondaryDominantRate = secondaryDominantRate
        self.tritoneSubstitutionRate = tritoneSubstitutionRate
        self.mediantShiftRate = mediantShiftRate
        self.chordsPerBar = chordsPerBar
        self.cadenceStrength = cadenceStrength
    }

    /// Number of degrees a style describes; every built-in style uses seven.
    public static let degreeCount = 7

    /// Clamps every axis into range and normalises `degreeWeights` to sum to 1.
    public func normalised() -> HarmonicStyleDNA {
        var copy = self

        let weights = degreeWeights.prefix(HarmonicStyleDNA.degreeCount).map {
            $0.isFinite && $0 > 0 ? $0 : 0
        }
        var padded = Array(weights)
        while padded.count < HarmonicStyleDNA.degreeCount { padded.append(0) }
        let total = padded.reduce(0, +)
        copy.degreeWeights = total > 0
            ? padded.map { $0 / total }
            : Array(repeating: 1.0 / Double(HarmonicStyleDNA.degreeCount), count: HarmonicStyleDNA.degreeCount)

        copy.minorLean = minorLean.normalizedUnit
        copy.extensionRichness = extensionRichness.normalizedUnit
        copy.suspendedColour = suspendedColour.normalizedUnit
        copy.borrowing = borrowing.normalizedUnit
        copy.secondaryDominantRate = secondaryDominantRate.normalizedUnit
        copy.tritoneSubstitutionRate = tritoneSubstitutionRate.normalizedUnit
        copy.mediantShiftRate = mediantShiftRate.normalizedUnit
        copy.cadenceStrength = cadenceStrength.normalizedUnit
        copy.chordsPerBar = chordsPerBar.isFinite ? chordsPerBar.clamped(to: 0.25...4) : 1
        return copy
    }

    /// Scale a caller should use when they want this style's home mode.
    public var preferredScaleType: ScaleType {
        minorLean >= 0.5 ? .naturalMinor : .major
    }

    /// Weight on a degree, wrapping by octave for scales that are not heptatonic.
    public func weight(forDegree degree: Int) -> Double {
        guard !degreeWeights.isEmpty else { return 0 }
        let count = degreeWeights.count
        var index = degree % count
        if index < 0 { index += count }
        return degreeWeights[index]
    }

    /// Linear interpolation between two styles.
    ///
    /// - Parameter amount: `0` returns `start`, `1` returns `end`, and values in
    ///   between blend every axis — including the degree weights, so a half-way
    ///   blend really does land half-way between the two harmonic dialects.
    public static func blend(
        _ start: HarmonicStyleDNA,
        _ end: HarmonicStyleDNA,
        amount: Double
    ) -> HarmonicStyleDNA {
        let t = amount.normalizedUnit
        let a = start.normalised()
        let b = end.normalised()

        var weights: [Double] = []
        for index in 0..<degreeCount {
            let blended = a.degreeWeights[index] * (1 - t) + b.degreeWeights[index] * t
            weights.append(blended)
        }

        func mix(_ lhs: Double, _ rhs: Double) -> Double {
            lhs * (1 - t) + rhs * t
        }

        var name: String
        if t <= 0 {
            name = a.name
        } else if t >= 1 {
            name = b.name
        } else {
            name = "\(a.name) → \(b.name) \(Int((t * 100).rounded()))%"
        }

        return HarmonicStyleDNA(
            name: name,
            degreeWeights: weights,
            minorLean: mix(a.minorLean, b.minorLean),
            extensionRichness: mix(a.extensionRichness, b.extensionRichness),
            suspendedColour: mix(a.suspendedColour, b.suspendedColour),
            borrowing: mix(a.borrowing, b.borrowing),
            secondaryDominantRate: mix(a.secondaryDominantRate, b.secondaryDominantRate),
            tritoneSubstitutionRate: mix(a.tritoneSubstitutionRate, b.tritoneSubstitutionRate),
            mediantShiftRate: mix(a.mediantShiftRate, b.mediantShiftRate),
            chordsPerBar: mix(a.chordsPerBar, b.chordsPerBar),
            cadenceStrength: mix(a.cadenceStrength, b.cadenceStrength)
        ).normalised()
    }
}

/// Built-in harmonic dialects.
///
/// The numbers are not invented: each style encodes the moves that define it in
/// practice — pop's `I–V–vi–IV` loop, synthwave's non-resolving
/// `i–♭VI–♭III–♭VII` with sus/add9 pads, neo-soul's extended `ii9–V13–Imaj9`
/// with modal interchange, cinematic trailer's slow ♭VI–♭VII–i modal swells,
/// and so on. See `docs/guides/style-morphing.md` for the sources behind them.
public enum HarmonicStyleLibrary {
    /// Degree order for every style below: I, ii, iii, IV, V, vi, vii.
    public static let popRoyalRoad = HarmonicStyleDNA(
        name: "Pop / Royal Road",
        degreeWeights: [1.0, 0.45, 0.25, 1.05, 0.95, 1.15, 0.2],
        minorLean: 0.15,
        extensionRichness: 0.25,
        suspendedColour: 0.1,
        borrowing: 0.08,
        secondaryDominantRate: 0.1,
        chordsPerBar: 1,
        cadenceStrength: 0.75
    )

    public static let neoSoul = HarmonicStyleDNA(
        name: "Neo-Soul",
        degreeWeights: [0.9, 1.1, 0.6, 0.85, 0.95, 1.0, 0.35],
        minorLean: 0.55,
        extensionRichness: 0.9,
        suspendedColour: 0.35,
        borrowing: 0.45,
        secondaryDominantRate: 0.3,
        tritoneSubstitutionRate: 0.15,
        mediantShiftRate: 0.2,
        chordsPerBar: 2,
        cadenceStrength: 0.55
    )

    public static let synthwave = HarmonicStyleDNA(
        name: "Synthwave",
        degreeWeights: [1.0, 0.35, 0.55, 0.5, 0.4, 0.95, 0.85],
        minorLean: 0.85,
        extensionRichness: 0.6,
        suspendedColour: 0.7,
        borrowing: 0.3,
        secondaryDominantRate: 0.08,
        mediantShiftRate: 0.12,
        chordsPerBar: 1,
        cadenceStrength: 0.35
    )

    public static let cinematicTrailer = HarmonicStyleDNA(
        name: "Cinematic Trailer",
        degreeWeights: [1.0, 0.2, 0.3, 0.55, 0.5, 0.9, 0.6],
        minorLean: 0.9,
        extensionRichness: 0.45,
        suspendedColour: 0.6,
        borrowing: 0.5,
        secondaryDominantRate: 0.05,
        mediantShiftRate: 0.35,
        chordsPerBar: 0.5,
        cadenceStrength: 0.3
    )

    public static let lofiHipHop = HarmonicStyleDNA(
        name: "Lo-Fi Hip-Hop",
        degreeWeights: [0.95, 0.95, 0.55, 0.8, 0.85, 0.9, 0.3],
        minorLean: 0.5,
        extensionRichness: 0.8,
        suspendedColour: 0.25,
        borrowing: 0.35,
        secondaryDominantRate: 0.2,
        tritoneSubstitutionRate: 0.1,
        mediantShiftRate: 0.1,
        chordsPerBar: 1.5,
        cadenceStrength: 0.6
    )

    public static let gospelSoul = HarmonicStyleDNA(
        name: "Gospel / Soul",
        degreeWeights: [1.0, 0.8, 0.5, 1.0, 1.05, 0.85, 0.25],
        minorLean: 0.3,
        extensionRichness: 0.75,
        suspendedColour: 0.2,
        borrowing: 0.5,
        secondaryDominantRate: 0.45,
        tritoneSubstitutionRate: 0.2,
        mediantShiftRate: 0.15,
        chordsPerBar: 2,
        cadenceStrength: 0.8
    )

    public static let deepHouse = HarmonicStyleDNA(
        name: "Deep House",
        degreeWeights: [1.0, 0.9, 0.35, 0.7, 0.6, 0.75, 0.2],
        minorLean: 0.6,
        extensionRichness: 0.65,
        suspendedColour: 0.45,
        borrowing: 0.3,
        secondaryDominantRate: 0.1,
        chordsPerBar: 2,
        cadenceStrength: 0.35
    )

    public static let ambientModal = HarmonicStyleDNA(
        name: "Ambient Modal",
        degreeWeights: [1.0, 0.4, 0.4, 0.7, 0.35, 0.6, 0.25],
        minorLean: 0.45,
        extensionRichness: 0.7,
        suspendedColour: 0.85,
        borrowing: 0.25,
        secondaryDominantRate: 0.02,
        mediantShiftRate: 0.2,
        chordsPerBar: 0.5,
        cadenceStrength: 0.15
    )

    public static let jazzStandard = HarmonicStyleDNA(
        name: "Jazz Standard",
        degreeWeights: [0.95, 1.15, 0.7, 0.75, 1.0, 0.85, 0.35),
        minorLean: 0.35,
        extensionRichness: 0.85,
        suspendedColour: 0.15,
        borrowing: 0.4,
        secondaryDominantRate: 0.55,
        tritoneSubstitutionRate: 0.35,
        mediantShiftRate: 0.1,
        chordsPerBar: 2,
        cadenceStrength: 0.85
    )

    public static let liquidDrumAndBass = HarmonicStyleDNA(
        name: "Liquid Drum & Bass",
        degreeWeights: [0.95, 0.9, 0.45, 0.75, 0.7, 0.85, 0.3],
        minorLean: 0.7,
        extensionRichness: 0.8,
        suspendedColour: 0.3,
        borrowing: 0.35,
        secondaryDominantRate: 0.2,
        tritoneSubstitutionRate: 0.1,
        mediantShiftRate: 0.15,
        chordsPerBar: 1.5,
        cadenceStrength: 0.5
    )

    /// Every built-in style, in a friendly display order.
    public static let all: [HarmonicStyleDNA] = [
        popRoyalRoad,
        neoSoul,
        synthwave,
        cinematicTrailer,
        lofiHipHop,
        gospelSoul,
        deepHouse,
        ambientModal,
        jazzStandard,
        liquidDrumAndBass
    ]

    /// Case-insensitive lookup by `name`.
    public static func style(named name: String) -> HarmonicStyleDNA? {
        let needle = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return all.first { $0.name.lowercased() == needle }
    }
}
