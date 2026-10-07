import Foundation

/// Reasons a Scala (`.scl`) scale file can be rejected.
public enum ScalaTuningError: Error, Equatable, Sendable, CustomStringConvertible {
    /// The file ended before the description and note-count lines.
    case missingNoteCount
    /// The note-count line is not a positive integer.
    case invalidNoteCount(String)
    /// The file declared more pitch lines than it contains.
    case pitchCountMismatch(expected: Int, found: Int)
    /// A pitch line is neither a cents value nor a positive ratio.
    case invalidPitch(String)
    /// The scale has no degrees, or its period is not a positive interval.
    case invalidScale

    public var description: String {
        switch self {
        case .missingNoteCount:
            "Scala file has no note-count line."
        case .invalidNoteCount(let text):
            "Scala note count is not a positive integer: '\(text)'."
        case .pitchCountMismatch(let expected, let found):
            "Scala file declares \(expected) pitches but contains \(found)."
        case .invalidPitch(let text):
            "Scala pitch is neither cents nor a ratio: '\(text)'."
        case .invalidScale:
            "Scala scale needs at least one degree and a period above 0 cents."
        }
    }
}

/// A microtonal scale imported from the Scala (`.scl`) file format.
///
/// A Scala scale lists the cents of each degree above an implicit `1/1`; the
/// last entry is the period (normally the octave, 1200 cents) after which the
/// pattern repeats. The scale is anchored on a MIDI root note that keeps its
/// 12-TET pitch, and each other note is the root plus the scale's cents.
public struct ScalaTuning: Equatable, Sendable {
    public let name: String
    /// Cents of each degree above `1/1`, ending with the period.
    public let degreeCents: [Double]

    public init(name: String = "", degreeCents: [Double]) throws {
        guard let period = degreeCents.last,
              degreeCents.allSatisfy({ $0.isFinite }),
              period > 0
        else {
            throw ScalaTuningError.invalidScale
        }
        self.name = name
        self.degreeCents = degreeCents
    }

    /// Size of the repeating interval in cents.
    public var periodCents: Double { degreeCents[degreeCents.count - 1] }

    /// Number of scale degrees per period.
    public var notesPerPeriod: Int { degreeCents.count }

    /// Whether the period is a pure octave (1200 cents).
    public var isOctaveRepeating: Bool { abs(periodCents - 1200.0) < 0.001 }

    // MARK: - Mapping

    /// Cents above the root for a signed number of scale steps (keys) from the root.
    public func cents(atStep step: Int) -> Double {
        let count = degreeCents.count
        var period = step / count
        var degree = step % count
        if degree < 0 {
            degree += count
            period -= 1
        }
        let withinPeriod = degree == 0 ? 0.0 : degreeCents[degree - 1]
        return Double(period) * periodCents + withinPeriod
    }

    /// Offset in cents of a MIDI note from its 12-TET pitch.
    ///
    /// Keys map one-to-one onto scale steps starting at `rootNote`, so a scale
    /// with seven degrees repeats every seven keys. `rootNote` keeps its 12-TET pitch.
    public func centsOffset(forMIDINote note: UInt8, rootNote: UInt8 = 60) -> Double {
        let step = Int(note) - Int(rootNote)
        return cents(atStep: step) - Double(step) * 100.0
    }

    /// Offset in fractional semitones of a MIDI note from its 12-TET pitch.
    public func semitoneOffset(forMIDINote note: UInt8, rootNote: UInt8 = 60) -> Double {
        centsOffset(forMIDINote: note, rootNote: rootNote) / 100.0
    }

    // MARK: - Parsing

    /// Parses the text of a `.scl` file.
    ///
    /// Lines starting with `!` are comments. The first other line is the
    /// description (possibly empty), then the note count, then one pitch per
    /// line: a value containing `.` is cents, anything else is a ratio `n/d`
    /// (or an integer `n`). Text after the first whitespace on a pitch line is ignored.
    public static func parse(_ text: String) throws -> ScalaTuning {
        var source = text
        if source.hasPrefix("\u{FEFF}") {
            source.removeFirst()
        }
        source = source
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        var lines = source
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.hasPrefix("!") }
            .makeIterator()

        // The description may be blank, so it is the first non-comment line as-is.
        let name = lines.next() ?? ""

        // Blank lines carry no meaning after the description.
        var content = IteratorSequence(lines).filter { !$0.isEmpty }.makeIterator()

        guard let countLine = content.next() else {
            throw ScalaTuningError.missingNoteCount
        }
        let countToken = countLine.split(whereSeparator: { $0 == " " || $0 == "\t" }).first.map(String.init) ?? ""
        guard let count = Int(countToken), count > 0 else {
            throw ScalaTuningError.invalidNoteCount(countLine)
        }

        var degrees: [Double] = []
        degrees.reserveCapacity(count)
        while degrees.count < count, let line = content.next() {
            guard let cents = parsePitch(line) else {
                throw ScalaTuningError.invalidPitch(line)
            }
            degrees.append(cents)
        }
        guard degrees.count == count else {
            throw ScalaTuningError.pitchCountMismatch(expected: count, found: degrees.count)
        }

        return try ScalaTuning(name: name, degreeCents: degrees)
    }

    /// Converts one pitch line into cents, or `nil` when it is malformed.
    static func parsePitch(_ line: String) -> Double? {
        guard let token = line.split(whereSeparator: { $0 == " " || $0 == "\t" }).first else {
            return nil
        }
        if token.contains(".") {
            guard let cents = Double(token), cents.isFinite else { return nil }
            return cents
        }

        let parts = token.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count <= 2,
              let numerator = Int(parts[0]), numerator > 0
        else {
            return nil
        }
        var denominator = 1
        if parts.count == 2 {
            guard let parsed = Int(parts[1]), parsed > 0 else { return nil }
            denominator = parsed
        }
        return 1200.0 * log2(Double(numerator) / Double(denominator))
    }
}
