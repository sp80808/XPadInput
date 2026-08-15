import Foundation

/// Which layer of harmonic richness the wheel exposes.
enum WheelLayer: String, CaseIterable, Identifiable, Codable, Sendable {
    case diatonic   = "Diatonic"
    case colour     = "Colour / Extensions"
    case borrowed   = "Modal Interchange"
    case tension    = "Tension & Secondary"
    case mediant    = "Chromatic Mediants"

    var id: String { rawValue }

    var shortName: String {
        switch self {
        case .diatonic: return "DIA"
        case .colour:   return "COL"
        case .borrowed: return "BOR"
        case .tension:  return "TEN"
        case .mediant:  return "MED"
        }
    }
}

/// One slice of the harmonic wheel.
struct WheelSector: Identifiable, Codable, Sendable, Hashable {
    let id: Int
    let angle: Double           // centre angle in radians
    let chord: Chord
    let romanNumeral: String
    let label: String
    let layer: WheelLayer
    let harmonicFunction: String

    static func == (lhs: WheelSector, rhs: WheelSector) -> Bool {
        lhs.id == rhs.id && lhs.layer == rhs.layer
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(layer)
    }
}

/// Generates all sectors for each wheel layer given a root key and scale.
struct HarmonicWheel: Sendable {

    let rootKey: PitchClass
    let scale: Scale
    let sectorsByLayer: [WheelLayer: [WheelSector]]

    init(root: PitchClass, scale: Scale) {
        self.rootKey = root
        self.scale = scale

        let pcs = scale.pitchClasses(root: root)
        let isMajor = (scale.id == "major")
        var dict: [WheelLayer: [WheelSector]] = [:]

        // ── 1. DIATONIC ──────────────────────────────────────────────
        let majorDeg: [(ChordQuality, String, String)] = [
            (.major,      "I",    "Tonic"),
            (.minor,      "ii",   "Subdominant"),
            (.minor,      "iii",  "Mediant"),
            (.major,      "IV",   "Subdominant"),
            (.major,      "V",    "Dominant"),
            (.minor,      "vi",   "Submediant"),
            (.diminished, "vii°", "Leading Tone"),
        ]
        let minorDeg: [(ChordQuality, String, String)] = [
            (.minor,      "i",    "Tonic"),
            (.diminished, "ii°",  "Subdominant"),
            (.major,      "III",  "Mediant"),
            (.minor,      "iv",   "Subdominant"),
            (.minor,      "v",    "Dominant"),
            (.major,      "VI",   "Submediant"),
            (.major,      "VII",  "Subtonic"),
        ]
        let deg = isMajor ? majorDeg : minorDeg
        let n = min(pcs.count, deg.count)

        dict[.diatonic] = (0..<n).map { i in
            let angle = sectorAngle(index: i, of: n)
            let (q, rn, fn) = deg[i]
            let chord = Chord(root: pcs[i], quality: q)
            return WheelSector(
                id: i, angle: angle, chord: chord,
                romanNumeral: rn,
                label: chord.displayName,
                layer: .diatonic,
                harmonicFunction: fn
            )
        }

        // ── 2. COLOUR (7ths on diatonic roots) ───────────────────────
        let col7Major: [ChordQuality] = [.major7, .minor7, .minor7, .major7, .dominant7, .minor7, .halfDiminished7]
        let col7Minor: [ChordQuality] = [.minor7, .halfDiminished7, .major7, .minor7, .minor7, .major7, .dominant7]
        let colQ = isMajor ? col7Major : col7Minor

        dict[.colour] = (0..<n).map { i in
            let angle = sectorAngle(index: i, of: n)
            let chord = Chord(root: pcs[i], quality: colQ[i])
            return WheelSector(
                id: 100 + i, angle: angle, chord: chord,
                romanNumeral: deg[i].1 + colQ[i].symbol,
                label: chord.displayName,
                layer: .colour,
                harmonicFunction: "Colour / 7th"
            )
        }

        // ── 3. BORROWED (Modal Interchange) ──────────────────────────
        let borrowedSpecs: [(Int, ChordQuality, String)] = isMajor ? [
            (3,  .major, "♭III"),
            (5,  .minor, "iv"),
            (7,  .minor, "v"),
            (8,  .major, "♭VI"),
            (10, .major, "♭VII"),
            (1,  .major, "♭II (Neapolitan)"),
        ] : [
            (0,  .major, "I (Picardy)"),
            (2,  .minor, "ii"),
            (5,  .major, "IV (Dorian)"),
            (7,  .major, "V (Harmonic)"),
            (1,  .major, "♭II (Neapolitan)"),
            (11, .diminished, "vii° (Harmonic)"),
        ]

        dict[.borrowed] = borrowedSpecs.enumerated().map { (i, spec) in
            let angle = sectorAngle(index: i, of: borrowedSpecs.count)
            let chord = Chord(root: root.transposed(by: spec.0), quality: spec.1)
            return WheelSector(
                id: 200 + i, angle: angle, chord: chord,
                romanNumeral: spec.2,
                label: chord.displayName,
                layer: .borrowed,
                harmonicFunction: "Modal Interchange"
            )
        }

        // ── 4. TENSION & SECONDARY DOMINANTS ─────────────────────────
        let secDom: [(Int, String, String)] = [
            (7,  "V7",     "Dominant"),
            (pcs.count > 1 ? pcs[1].rawValue + 7 - root.rawValue : 9, "V7/ii",  "Sec. Dom → ii"),
            (pcs.count > 3 ? pcs[3].rawValue + 7 - root.rawValue : 0, "V7/IV",  "Sec. Dom → IV"),
            (pcs.count > 4 ? pcs[4].rawValue + 7 - root.rawValue : 2, "V7/V",   "Sec. Dom → V"),
            (pcs.count > 5 ? pcs[5].rawValue + 7 - root.rawValue : 4, "V7/vi",  "Sec. Dom → vi"),
            (1,  "subV7",  "Tritone Substitution"),
        ]

        dict[.tension] = secDom.enumerated().map { (i, spec) in
            let angle = sectorAngle(index: i, of: secDom.count)
            let chord = Chord(root: root.transposed(by: ((spec.0 % 12) + 12) % 12), quality: .dominant7)
            return WheelSector(
                id: 300 + i, angle: angle, chord: chord,
                romanNumeral: spec.1,
                label: chord.displayName,
                layer: .tension,
                harmonicFunction: spec.2
            )
        }

        // ── 5. CHROMATIC MEDIANTS ────────────────────────────────────
        let meds: [(Int, String)] = [
            (3,  "♭III Mediant"),
            (4,  "III Mediant"),
            (8,  "♭VI Submediant"),
            (9,  "VI Submediant"),
            (6,  "♯IV Polar"),
            (11, "VII Mediant"),
        ]
        dict[.mediant] = meds.enumerated().map { (i, spec) in
            let angle = sectorAngle(index: i, of: meds.count)
            let chord = Chord(root: root.transposed(by: spec.0), quality: .major)
            return WheelSector(
                id: 400 + i, angle: angle, chord: chord,
                romanNumeral: spec.1,
                label: chord.displayName,
                layer: .mediant,
                harmonicFunction: "Chromatic Mediant"
            )
        }

        self.sectorsByLayer = dict
    }

    /// Selects the sector closest to a given analog stick angle for the active layer.
    func sector(forAngle stickAngle: Double, layer: WheelLayer = .diatonic) -> WheelSector? {
        guard let sectors = sectorsByLayer[layer], !sectors.isEmpty else { return nil }

        var norm = stickAngle
        while norm < 0       { norm += 2.0 * .pi }
        while norm >= 2 * .pi { norm -= 2.0 * .pi }

        let span = (2.0 * .pi) / Double(sectors.count)
        let half = span / 2.0

        for sector in sectors {
            var sa = sector.angle + (.pi / 2.0)   // sectors start at top
            while sa < 0       { sa += 2.0 * .pi }
            while sa >= 2 * .pi { sa -= 2.0 * .pi }

            var diff = abs(norm - sa)
            if diff > .pi { diff = 2.0 * .pi - diff }
            if diff <= half { return sector }
        }
        return sectors.first
    }

    // ── Helpers ──────────────────────────────────────────────────────

    /// Distributes sectors evenly around the circle, starting at top (–π/2).
    private func sectorAngle(index: Int, of total: Int) -> Double {
        (Double(index) / Double(total)) * 2.0 * .pi - (.pi / 2.0)
    }
}
