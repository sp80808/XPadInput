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

/// One scale tone mapped onto a heptatonic functional degree when possible.
/// Non-7-note scales skip missing degrees instead of shifting I–vii onto the first N tones.
private struct WheelDegreeSpec: Sendable {
    let pitchClass: PitchClass
    /// 0...6 when this tone is a diatonic degree of the parallel major/minor.
    let heptatonicIndex: Int?
    let quality: ChordQuality
    let roman: String
    let harmonicFunction: String
}

private enum WheelDegreeBuilder {
    static let majorQualities: [(ChordQuality, String, String)] = [
        (.major, "I", "Tonic"),
        (.minor, "ii", "Subdominant"),
        (.minor, "iii", "Tonic (Mediant)"),
        (.major, "IV", "Subdominant"),
        (.major, "V", "Dominant"),
        (.minor, "vi", "Tonic (Submediant)"),
        (.diminished, "vii°", "Leading Tone")
    ]

    static let minorQualities: [(ChordQuality, String, String)] = [
        (.minor, "i", "Tonic"),
        (.diminished, "ii°", "Subdominant"),
        (.major, "III", "Tonic (Mediant)"),
        (.minor, "iv", "Subdominant"),
        (.minor, "v", "Dominant"),
        (.major, "VI", "Submediant"),
        (.major, "VII", "Subtonic")
    ]

    static let colourMajor: [ChordQuality] = [
        .major7, .minor7, .minor7, .major7, .dominant7, .minor7, .halfDiminished7
    ]

    static let colourMinor: [ChordQuality] = [
        .minor7, .halfDiminished7, .major7, .minor7, .dominant7, .major7, .dominant7
    ]

    static let majorIntervals = [0, 2, 4, 5, 7, 9, 11]
    static let minorIntervals = [0, 2, 3, 5, 7, 8, 10]
    static let chromaticRomans = ["I", "♭II", "II", "♭III", "III", "IV", "♭V", "V", "♭VI", "VI", "♭VII", "VII"]

    static func specs(for scale: Scale) -> [WheelDegreeSpec] {
        let pcs = scale.pitchClasses
        guard !pcs.isEmpty else { return [] }

        let isMinor = scale.type.isMinor
        let qualities = isMinor ? minorQualities : majorQualities
        let heptatonicIntervals = isMinor ? minorIntervals : majorIntervals

        // Heptatonic: keep the functional I–vii tables (including modal scales).
        if pcs.count == 7 {
            return zip(pcs, qualities).enumerated().map { index, pair in
                WheelDegreeSpec(
                    pitchClass: pair.0,
                    heptatonicIndex: index,
                    quality: pair.1.0,
                    roman: pair.1.1,
                    harmonicFunction: pair.1.2
                )
            }
        }

        if scale.type == .chromatic || pcs.count >= 12 {
            return pcs.map { pc in
                let interval = scale.root.interval(to: pc)
                return WheelDegreeSpec(
                    pitchClass: pc,
                    heptatonicIndex: heptatonicIntervals.firstIndex(of: interval),
                    quality: .major,
                    roman: chromaticRomans[interval],
                    harmonicFunction: "Chromatic"
                )
            }
        }

        return pcs.map { pc in
            let interval = scale.root.interval(to: pc)
            if let index = heptatonicIntervals.firstIndex(of: interval) {
                let quality = qualities[index]
                return WheelDegreeSpec(
                    pitchClass: pc,
                    heptatonicIndex: index,
                    quality: quality.0,
                    roman: quality.1,
                    harmonicFunction: quality.2
                )
            }
            // Blues ♭5 / other non-diatonic scale tones.
            if interval == 6 {
                return WheelDegreeSpec(
                    pitchClass: pc,
                    heptatonicIndex: nil,
                    quality: .diminished,
                    roman: "♭V°",
                    harmonicFunction: "Blue note"
                )
            }
            return WheelDegreeSpec(
                pitchClass: pc,
                heptatonicIndex: nil,
                quality: .major,
                roman: chromaticRomans[interval],
                harmonicFunction: "Scale tone"
            )
        }
    }

    static func colourQuality(for spec: WheelDegreeSpec, isMinor: Bool) -> ChordQuality {
        let palette = isMinor ? colourMinor : colourMajor
        if let index = spec.heptatonicIndex {
            return palette[index]
        }
        switch spec.quality {
        case .diminished: return .halfDiminished7
        case .minor: return .minor7
        default: return .dominant7
        }
    }
}

public struct HarmonicWheel: Codable, Sendable {
    public let scale: Scale
    public let sectorsByLayer: [WheelLayer: [WheelSector]]

    public init(scale: Scale = .cMajor) {
        self.scale = scale
        var dict: [WheelLayer: [WheelSector]] = [:]

        let degreeSpecs = WheelDegreeBuilder.specs(for: scale)
        let isMinor = scale.type.isMinor

        // 1. DIATONIC LAYER
        dict[.diatonic] = sectors(
            from: degreeSpecs,
            layer: .diatonic,
            idBase: 0,
            chord: { Chord(root: $0.pitchClass, quality: $0.quality) },
            roman: { $0.roman },
            function: { $0.harmonicFunction }
        )

        // 2. COLOUR LAYER (Rich 7ths, 9ths, sus chords on diatonic roots)
        dict[.colour] = sectors(
            from: degreeSpecs,
            layer: .colour,
            idBase: 100,
            chord: { spec in
                Chord(
                    root: spec.pitchClass,
                    quality: WheelDegreeBuilder.colourQuality(for: spec, isMinor: isMinor)
                )
            },
            roman: { spec in
                let quality = WheelDegreeBuilder.colourQuality(for: spec, isMinor: isMinor)
                switch quality {
                case .major7:
                    return spec.roman + "maj7"
                case .halfDiminished7:
                    // "vii°" carries the fully-diminished glyph; a half-diminished
                    // chord must use the ø glyph instead (e.g. "viiø7"). Refs #52.
                    let base = spec.roman.hasSuffix("°") ? String(spec.roman.dropLast()) : spec.roman
                    return base + "ø7"
                default:
                    return spec.roman + "7"
                }
            },
            function: { _ in "Colour / 7th" }
        )

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
            let chord = Chord(root: spec.0, quality: spec.1)
            borrowedSectors.append(WheelSector(
                id: i + 200,
                angle: wheelAngle(index: i, count: borrowedSpecs.count),
                chord: chord,
                romanNumeral: spec.2,
                label: chord.symbol,
                layer: .borrowed,
                harmonicFunction: "Modal Interchange"
            ))
        }
        dict[.borrowed] = borrowedSectors

        // 4. TENSION & SECONDARY DOMINANTS — keyed by heptatonic degree, never by raw array index.
        var tensionSectors: [WheelSector] = []
        var secondaryDominants: [(PitchClass, ChordQuality, String, String)] = []
        func degree(_ heptatonicIndex: Int) -> PitchClass? {
            degreeSpecs.first(where: { $0.heptatonicIndex == heptatonicIndex })?.pitchClass
        }
        if let tonic = degree(0) {
            secondaryDominants.append((tonic.transposed(by: 7), .dominant7, "V7", "Dominant"))
        }
        if let supertonic = degree(1) {
            secondaryDominants.append((supertonic.transposed(by: 7), .dominant7, "V7/ii", "Secondary Dominant to ii"))
        }
        if let subdominant = degree(3) {
            secondaryDominants.append((subdominant.transposed(by: 7), .dominant7, "V7/IV", "Secondary Dominant to IV"))
        }
        if let dominant = degree(4) {
            secondaryDominants.append((dominant.transposed(by: 7), .dominant7, "V7/V", "Secondary Dominant to V"))
        }
        if let submediant = degree(5) {
            secondaryDominants.append((submediant.transposed(by: 7), .dominant7, "V7/vi", "Secondary Dominant to vi"))
        }
        if let tonic = degree(0) {
            secondaryDominants.append((tonic.transposed(by: 1), .dominant7, "subV7", "Tritone Substitution"))
        }

        for (i, spec) in secondaryDominants.enumerated() {
            let chord = Chord(root: spec.0, quality: spec.1)
            tensionSectors.append(WheelSector(
                id: i + 300,
                angle: wheelAngle(index: i, count: secondaryDominants.count),
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
            let chord = Chord(root: spec.0, quality: spec.1)
            mediantSectors.append(WheelSector(
                id: i + 400,
                angle: wheelAngle(index: i, count: mediants.count),
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

private func wheelAngle(index: Int, count: Int) -> Double {
    guard count > 0 else { return -.pi / 2.0 }
    return (Double(index) / Double(count)) * 2.0 * .pi - (.pi / 2.0)
}

private func sectors(
    from specs: [WheelDegreeSpec],
    layer: WheelLayer,
    idBase: Int,
    chord: (WheelDegreeSpec) -> Chord,
    roman: (WheelDegreeSpec) -> String,
    function: (WheelDegreeSpec) -> String
) -> [WheelSector] {
    let count = specs.count
    return specs.enumerated().map { index, spec in
        let built = chord(spec)
        return WheelSector(
            id: index + idBase,
            angle: wheelAngle(index: index, count: count),
            chord: built,
            romanNumeral: roman(spec),
            label: built.symbol,
            layer: layer,
            harmonicFunction: function(spec)
        )
    }
}
