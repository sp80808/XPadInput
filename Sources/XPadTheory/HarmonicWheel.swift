import Foundation
import XPadCore

public enum WheelLayer: String, CaseIterable, Identifiable, Codable, Sendable {
    case diatonic = "Diatonic"
    case colour = "Colour / Extensions"
    case borrowed = "Modal Interchange"
    case tension = "Tension & Secondary"
    case mediant = "Chromatic Mediants"

    public var id: String { rawValue }
}

public struct WheelSector: Identifiable, Codable, Sendable {
    public let id: Int
    public let angle: Double // Radians 0..<2*PI
    public let chord: Chord
    public let romanNumeral: String
    public let label: String
    public let layer: WheelLayer
    public let harmonicFunction: String

    public init(
        id: Int,
        angle: Double,
        chord: Chord,
        romanNumeral: String,
        label: String,
        layer: WheelLayer,
        harmonicFunction: String
    ) {
        self.id = id
        self.angle = angle
        self.chord = chord
        self.romanNumeral = romanNumeral
        self.label = label
        self.layer = layer
        self.harmonicFunction = harmonicFunction
    }
}

public struct HarmonicWheel: Codable, Sendable {
    public let scale: Scale
    public let sectorsByLayer: [WheelLayer: [WheelSector]]

    public init(scale: Scale = .cMajor) {
        self.scale = scale
        var dict: [WheelLayer: [WheelSector]] = [:]

        // 1. DIATONIC LAYER
        var diatonicSectors: [WheelSector] = []
        let pcs = scale.pitchClasses
        let isMinor = scale.type == .naturalMinor || scale.type == .harmonicMinor || scale.type == .melodicMinor

        let diatonicQualitiesMajor: [(ChordQuality, String, String)] = [
            (.major, "I", "Tonic"),
            (.minor, "ii", "Subdominant"),
            (.minor, "iii", "Tonic (Mediant)"),
            (.major, "IV", "Subdominant"),
            (.major, "V", "Dominant"),
            (.minor, "vi", "Tonic (Submediant)"),
            (.diminished, "vii°", "Leading Tone")
        ]

        let diatonicQualitiesMinor: [(ChordQuality, String, String)] = [
            (.minor, "i", "Tonic"),
            (.diminished, "ii°", "Subdominant"),
            (.major, "III", "Tonic (Mediant)"),
            (.minor, "iv", "Subdominant"),
            (.minor, "v", "Dominant"),
            (.major, "VI", "Submediant"),
            (.major, "VII", "Subtonic")
        ]

        let qualities = isMinor ? diatonicQualitiesMinor : diatonicQualitiesMajor
        let count = min(pcs.count, qualities.count)

        for i in 0..<count {
            let angle = (Double(i) / Double(count)) * 2.0 * .pi - (.pi / 2.0)
            let chordRoot = pcs[i]
            let (quality, roman, fn) = qualities[i]
            let chord = Chord(root: chordRoot, quality: quality)
            diatonicSectors.append(WheelSector(
                id: i,
                angle: angle,
                chord: chord,
                romanNumeral: roman,
                label: chord.symbol,
                layer: .diatonic,
                harmonicFunction: fn
            ))
        }
        dict[.diatonic] = diatonicSectors

        // 2. COLOUR LAYER (Rich 7ths, 9ths, sus chords on diatonic roots)
        var colourSectors: [WheelSector] = []
        let colourQualities: [ChordQuality] = isMinor ?
            [.minor7, .halfDiminished, .major7, .minor7, .dominant7, .major7, .dominant7] :
            [.major7, .minor7, .minor7, .major7, .dominant7, .minor7, .halfDiminished]

        for i in 0..<count {
            let angle = (Double(i) / Double(count)) * 2.0 * .pi - (.pi / 2.0)
            let chordRoot = pcs[i]
            let quality = colourQualities[i % colourQualities.count]
            let chord = Chord(root: chordRoot, quality: quality)
            let roman = qualities[i].1 + (quality == .major7 ? "maj7" : "7")
            colourSectors.append(WheelSector(
                id: i + 100,
                angle: angle,
                chord: chord,
                romanNumeral: roman,
                label: chord.symbol,
                layer: .colour,
                harmonicFunction: "Colour / 7th"
            ))
        }
        dict[.colour] = colourSectors

        // 3. BORROWED LAYER (Modal Interchange)
        var borrowedSectors: [WheelSector] = []
        let parallelRoot = scale.root
        let borrowedSpecs: [(PitchClass, ChordQuality, String)] = isMinor ? [
            (parallelRoot, .major, "I (Picardy)"),
            (parallelRoot.transposed(by: 2), .minor, "ii"),
            (parallelRoot.transposed(by: 5), .major, "IV (Dorian)"),
            (parallelRoot.transposed(by: 7), .major, "V (Harmonic/Major)"),
            (parallelRoot.transposed(by: 1), .major, "♭II (Neapolitan)"),
            (parallelRoot.transposed(by: 11), .diminished, "vii° (Harmonic)")
        ] : [
            (parallelRoot.transposed(by: 3), .major, "♭III"),
            (parallelRoot.transposed(by: 5), .minor, "iv"),
            (parallelRoot.transposed(by: 7), .minor, "v"),
            (parallelRoot.transposed(by: 8), .major, "♭VI"),
            (parallelRoot.transposed(by: 10), .major, "♭VII"),
            (parallelRoot.transposed(by: 1), .major, "♭II (Neapolitan)")
        ]

        for (i, spec) in borrowedSpecs.enumerated() {
            let angle = (Double(i) / Double(borrowedSpecs.count)) * 2.0 * .pi - (.pi / 2.0)
            let chord = Chord(root: spec.0, quality: spec.1)
            borrowedSectors.append(WheelSector(
                id: i + 200,
                angle: angle,
                chord: chord,
                romanNumeral: spec.2,
                label: chord.symbol,
                layer: .borrowed,
                harmonicFunction: "Modal Interchange"
            ))
        }
        dict[.borrowed] = borrowedSectors

        // 4. TENSION & SECONDARY DOMINANTS
        var tensionSectors: [WheelSector] = []
        let secondaryDominants: [(PitchClass, ChordQuality, String, String)] = [
            (pcs[0].transposed(by: 7), .dominant7, "V7", "Dominant"),
            (pcs[1].transposed(by: 7), .dominant7, "V7/ii", "Secondary Dominant to ii"),
            (pcs[3].transposed(by: 7), .dominant7, "V7/IV", "Secondary Dominant to IV"),
            (pcs[4].transposed(by: 7), .dominant7, "V7/V", "Secondary Dominant to V"),
            (pcs[5].transposed(by: 7), .dominant7, "V7/vi", "Secondary Dominant to vi"),
            (pcs[0].transposed(by: 1), .dominant7, "subV7", "Tritone Substitution")
        ]

        for (i, spec) in secondaryDominants.enumerated() {
            let angle = (Double(i) / Double(secondaryDominants.count)) * 2.0 * .pi - (.pi / 2.0)
            let chord = Chord(root: spec.0, quality: spec.1)
            tensionSectors.append(WheelSector(
                id: i + 300,
                angle: angle,
                chord: chord,
                romanNumeral: spec.2,
                label: chord.symbol,
                layer: .tension,
                harmonicFunction: spec.3
            ))
        }
        dict[.tension] = tensionSectors

        // 5. CHROMATIC MEDIANTS
        var mediantSectors: [WheelSector] = []
        let mediants: [(PitchClass, ChordQuality, String)] = [
            (scale.root.transposed(by: 3), .major, "♭III Chromatic Mediant"),
            (scale.root.transposed(by: 4), .major, "III Chromatic Mediant"),
            (scale.root.transposed(by: 8), .major, "♭VI Chromatic Submediant"),
            (scale.root.transposed(by: 9), .major, "VI Chromatic Submediant"),
            (scale.root.transposed(by: 6), .major, "♯IV Polar Mediant"),
            (scale.root.transposed(by: 11), .major, "VII Chromatic Mediant")
        ]

        for (i, spec) in mediants.enumerated() {
            let angle = (Double(i) / Double(mediants.count)) * 2.0 * .pi - (.pi / 2.0)
            let chord = Chord(root: spec.0, quality: spec.1)
            mediantSectors.append(WheelSector(
                id: i + 400,
                angle: angle,
                chord: chord,
                romanNumeral: spec.2,
                label: chord.symbol,
                layer: .mediant,
                harmonicFunction: "Neo-Riemannian / Mediant"
            ))
        }
        dict[.mediant] = mediantSectors

        self.sectorsByLayer = dict
    }

    /// Selects sector corresponding to a given analog stick angle (-pi to +pi) and current layer.
    public func sector(forAngle stickAngle: Double, layer: WheelLayer = .diatonic) -> WheelSector? {
        guard let sectors = sectorsByLayer[layer], !sectors.isEmpty else { return nil }

        // Normalize angle to [0, 2*pi)
        var norm = stickAngle
        while norm < 0 { norm += 2.0 * .pi }
        while norm >= 2.0 * .pi { norm -= 2.0 * .pi }

        let sectorSpan = (2.0 * .pi) / Double(sectors.count)
        let halfSpan = sectorSpan / 2.0

        for sector in sectors {
            var sAngle = sector.angle
            while sAngle < 0 { sAngle += 2.0 * .pi }
            while sAngle >= 2.0 * .pi { sAngle -= 2.0 * .pi }

            var diff = abs(norm - sAngle)
            if diff > .pi { diff = 2.0 * .pi - diff }
            if diff <= halfSpan {
                return sector
            }
        }

        return sectors.first
    }
}
