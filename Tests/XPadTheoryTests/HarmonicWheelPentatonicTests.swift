import XCTest
@testable import XPadCore
@testable import XPadTheory

/// Regression coverage for issue #52.
///
/// The crash itself (unconditional `pcs[5]` indexing in the tension layer) was
/// resolved upstream when that layer became heptatonic-degree-keyed; these
/// tests pin that behaviour against regressions. The half-diminished roman
/// numeral glyph fix (`viiø7`, not `vii°7`) ships alongside them.
final class HarmonicWheelPentatonicTests: XCTestCase {

    func testSubHeptatonicScalesConstructWithoutCrashing() {
        // Pentatonics have 5 pitch classes and blues has 6; every layer of the
        // wheel must build through ordinary public API without trapping.
        XCTAssertNotNil(HarmonicWheel(scale: .pentatonicMajor))
        XCTAssertNotNil(HarmonicWheel(scale: .pentatonicMinor))
        XCTAssertNotNil(HarmonicWheel(scale: .blues))
    }

    func testHeptatonicScalesStillConstruct() {
        XCTAssertNotNil(HarmonicWheel(scale: .cMajor))
        XCTAssertNotNil(HarmonicWheel(scale: .aMinor))
    }

    func testHalfDiminishedColourRomanUsesSlashOGlyph() {
        let wheel = HarmonicWheel(scale: .cMajor)
        let vii = wheel.sectorsByLayer[.colour]?
            .first(where: { $0.chord.quality == .halfDiminished7 })

        XCTAssertNotNil(vii, "C major colour layer must contain the half-diminished vii chord")
        XCTAssertEqual(vii?.romanNumeral, "viiø7",
                       "half-diminished chords must render with the ø glyph, not °")
    }

    func testDominantSeventhColourRomanKeepsPlainGlyph() {
        let wheel = HarmonicWheel(scale: .cMajor)
        let v = wheel.sectorsByLayer[.colour]?
            .first(where: { $0.chord.quality == .dominant7 })

        XCTAssertNotNil(v)
        XCTAssertEqual(v?.romanNumeral, "V7")
    }
}
