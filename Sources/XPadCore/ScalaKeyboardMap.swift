import Foundation

/// Reasons a Scala keyboard mapping (`.kbm`) file can be rejected.
public enum ScalaKeyboardMapError: Error, Equatable, Sendable, CustomStringConvertible {
    /// The file ended before this header field.
    case missingField(String)
    /// A header field or mapping entry has an unusable value.
    case invalidField(name: String, text: String)
    /// Fewer mapping entries than the declared map size.
    case entryCountMismatch(expected: Int, found: Int)
    /// The reference note has no scale degree, so no frequency can be anchored.
    case unmappedReferenceNote

    public var description: String {
        switch self {
        case .missingField(let name):
            "Keyboard map is missing its \(name)."
        case .invalidField(let name, let text):
            "Keyboard map \(name) is not valid: '\(text)'."
        case .entryCountMismatch(let expected, let found):
            "Keyboard map declares \(expected) entries but contains \(found)."
        case .unmappedReferenceNote:
            "Keyboard map reference note is not mapped to a scale degree."
        }
    }
}

/// A keyboard mapping from the Scala `.kbm` format: which scale degree each
/// MIDI key plays, and which frequency anchors the scale.
///
/// A pattern of `entries` repeats up the keyboard from `middleNote`; each
/// entry is a scale degree (or `nil` for an unmapped key). After one pattern
/// the degrees advance by `formalOctaveDegree`. With no entries the mapping is
/// linear: the key `middleNote + n` plays scale degree `n`.
public struct ScalaKeyboardMap: Equatable, Sendable {
    public let firstNote: Int
    public let lastNote: Int
    public let middleNote: Int
    public let referenceNote: Int
    public let referenceFrequency: Double
    public let formalOctaveDegree: Int
    public let entries: [Int?]

    public init(
        firstNote: Int = 0,
        lastNote: Int = 127,
        middleNote: Int = 60,
        referenceNote: Int = 69,
        referenceFrequency: Double = 440.0,
        formalOctaveDegree: Int = 12,
        entries: [Int?] = []
    ) {
        self.firstNote = firstNote
        self.lastNote = lastNote
        self.middleNote = middleNote
        self.referenceNote = referenceNote
        self.referenceFrequency = referenceFrequency
        self.formalOctaveDegree = formalOctaveDegree
        self.entries = entries
    }

    /// The Scala default: linear mapping, middle C on degree 0, A4 at 440 Hz.
    public static let standard = ScalaKeyboardMap()

    /// Number of entries in the repeating pattern (0 for a linear mapping).
    public var mapSize: Int { entries.count }

    /// The scale degree a key plays, or `nil` when the key is outside
    /// `firstNote...lastNote` or is marked unmapped.
    public func scaleDegree(forMIDINote note: Int) -> Int? {
        guard note >= firstNote, note <= lastNote else { return nil }
        return degree(ofKey: note)
    }

    /// The scale degree of the reference note, or `nil` when it is unmapped.
    public var referenceDegree: Int? { degree(ofKey: referenceNote) }

    private func degree(ofKey key: Int) -> Int? {
        let offset = key - middleNote
        let size = entries.count
        if size == 0 { return offset }

        var patternRepeat = offset / size
        var index = offset % size
        if index < 0 {
            index += size
            patternRepeat -= 1
        }
        guard let entry = entries[index] else { return nil }
        // Wrapping arithmetic: hand-built maps with extreme values must not trap.
        return patternRepeat &* formalOctaveDegree &+ entry
    }

    // MARK: - Parsing

    /// Sanity bound on a mapped scale degree in a file; real maps stay in the low hundreds.
    private static let degreeLimit = -100_000...100_000

    private static let fieldNames = [
        "map size", "first note", "last note", "middle note",
        "reference note", "reference frequency", "formal octave degree"
    ]

    /// Parses the text of a `.kbm` file.
    ///
    /// Lines starting with `!` are comments. Seven header values follow, one
    /// per line (map size, first note, last note, middle note, reference note,
    /// reference frequency in Hz, formal octave degree), then one line per map
    /// entry: a scale degree, or `x` for an unmapped key.
    public static func parse(_ text: String) throws -> ScalaKeyboardMap {
        var source = text
        if source.hasPrefix("\u{FEFF}") {
            source.removeFirst()
        }
        let tokens: [String] = source
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("!") }
            .compactMap { line in
                line.split(whereSeparator: { $0 == " " || $0 == "\t" }).first.map(String.init)
            }

        func integer(_ field: Int, in range: ClosedRange<Int>) throws -> Int {
            let name = fieldNames[field]
            guard field < tokens.count else { throw ScalaKeyboardMapError.missingField(name) }
            guard let value = Int(tokens[field]), range.contains(value) else {
                throw ScalaKeyboardMapError.invalidField(name: name, text: tokens[field])
            }
            return value
        }

        let mapSize = try integer(0, in: 0...1_024)
        let firstNote = try integer(1, in: 0...127)
        let lastNote = try integer(2, in: 0...127)
        let middleNote = try integer(3, in: 0...127)
        let referenceNote = try integer(4, in: 0...127)

        guard lastNote >= firstNote else {
            throw ScalaKeyboardMapError.invalidField(name: fieldNames[2], text: tokens[2])
        }

        guard 5 < tokens.count else { throw ScalaKeyboardMapError.missingField(fieldNames[5]) }
        guard let frequency = Double(tokens[5]), frequency.isFinite, frequency > 0 else {
            throw ScalaKeyboardMapError.invalidField(name: fieldNames[5], text: tokens[5])
        }

        // A repeating pattern needs a positive stride; a linear map ignores it.
        let formalOctaveDegree = try integer(6, in: mapSize == 0 ? 0...10_000 : 1...10_000)

        let entryTokens = tokens.dropFirst(7)
        guard entryTokens.count >= mapSize else {
            throw ScalaKeyboardMapError.entryCountMismatch(expected: mapSize, found: entryTokens.count)
        }
        var entries: [Int?] = []
        entries.reserveCapacity(mapSize)
        for token in entryTokens.prefix(mapSize) {
            if token == "x" || token == "X" {
                entries.append(nil)
            } else if let degree = Int(token), Self.degreeLimit.contains(degree) {
                entries.append(degree)
            } else {
                throw ScalaKeyboardMapError.invalidField(name: "mapping entry", text: token)
            }
        }

        let map = ScalaKeyboardMap(
            firstNote: firstNote,
            lastNote: lastNote,
            middleNote: middleNote,
            referenceNote: referenceNote,
            referenceFrequency: frequency,
            formalOctaveDegree: formalOctaveDegree,
            entries: entries
        )
        guard map.referenceDegree != nil else {
            throw ScalaKeyboardMapError.unmappedReferenceNote
        }
        return map
    }
}

extension ScalaTuning {
    /// Offset in cents of a MIDI note from its 12-TET pitch, with the scale
    /// laid out by a keyboard map.
    ///
    /// The map's reference note sounds at its reference frequency and every
    /// other key is placed relative to it by the scale. Returns `nil` for keys
    /// the map leaves unmapped or outside its note range, which keep 12-TET.
    public func centsOffset(forMIDINote note: UInt8, map: ScalaKeyboardMap) -> Double? {
        guard let degree = map.scaleDegree(forMIDINote: Int(note)),
              let referenceDegree = map.referenceDegree
        else {
            return nil
        }
        let centsAboveReference = cents(atStep: degree) - cents(atStep: referenceDegree)
        let frequency = map.referenceFrequency * pow(2.0, centsAboveReference / 1200.0)
        let equalTemperamentFrequency = 440.0 * pow(2.0, (Double(note) - 69.0) / 12.0)
        let offset = 1200.0 * log2(frequency / equalTemperamentFrequency)
        return offset.isFinite ? offset : nil
    }

    /// Offset in fractional semitones; see ``centsOffset(forMIDINote:map:)``.
    public func semitoneOffset(forMIDINote note: UInt8, map: ScalaKeyboardMap) -> Double? {
        centsOffset(forMIDINote: note, map: map).map { $0 / 100.0 }
    }
}
