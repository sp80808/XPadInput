import XCTest
@testable import XPadCore

final class ScalaTuningTests: XCTestCase {
    private let ptolemaic = """
    ! ptolemy.scl
    !
    Ptolemy's intense diatonic scale
     7
    !
     9/8
     5/4
     4/3
     3/2
     5/3
     15/8
     2/1
    """

    func testParsesRatiosAndPeriod() throws {
        let tuning = try ScalaTuning.parse(ptolemaic)
        XCTAssertEqual(tuning.name, "Ptolemy's intense diatonic scale")
        XCTAssertEqual(tuning.notesPerPeriod, 7)
        XCTAssertEqual(tuning.periodCents, 1200.0, accuracy: 1e-9)
        XCTAssertTrue(tuning.isOctaveRepeating)
        XCTAssertEqual(tuning.degreeCents[1], 386.3137, accuracy: 1e-3)
    }

    func testMapsKeysOntoScaleStepsAroundRoot() throws {
        let tuning = try ScalaTuning.parse(ptolemaic)
        // Root keeps its 12-TET pitch.
        XCTAssertEqual(tuning.centsOffset(forMIDINote: 60), 0.0, accuracy: 1e-9)
        // Step 2 is 5/4 = 386.314 cents, against 200 cents in 12-TET.
        XCTAssertEqual(tuning.semitoneOffset(forMIDINote: 62), 1.86314, accuracy: 1e-4)
        // Step 7 is the period: 1200 vs 700 cents.
        XCTAssertEqual(tuning.centsOffset(forMIDINote: 67), 500.0, accuracy: 1e-9)
        // Step -1 is 15/8 an octave down: -111.731 vs -100 cents.
        XCTAssertEqual(tuning.centsOffset(forMIDINote: 59), -11.731, accuracy: 1e-3)
        // Step -7 is exactly one period down.
        XCTAssertEqual(tuning.cents(atStep: -7), -1200.0, accuracy: 1e-9)
    }

    func testCentsEntriesAndTrailingTextAreAccepted() throws {
        let text = "! a.scl\r\n\r\n3\r\n 100.0 first\r\n 250.5\tsecond\r\n 3/1\r\n"
        let tuning = try ScalaTuning.parse(text)
        XCTAssertEqual(tuning.name, "")
        XCTAssertEqual(tuning.degreeCents[0], 100.0, accuracy: 1e-9)
        XCTAssertEqual(tuning.degreeCents[1], 250.5, accuracy: 1e-9)
        XCTAssertEqual(tuning.periodCents, 1901.955, accuracy: 1e-3)
        XCTAssertFalse(tuning.isOctaveRepeating)
    }

    func testEqualTemperamentHasNoOffsets() throws {
        let degrees = (1...12).map { Double($0) * 100.0 }
        let tuning = try ScalaTuning(name: "12-TET", degreeCents: degrees)
        for note in UInt8(0)...UInt8(127) {
            XCTAssertEqual(tuning.centsOffset(forMIDINote: note), 0.0, accuracy: 1e-9)
        }
    }

    func testRejectsMalformedFiles() {
        XCTAssertThrowsError(try ScalaTuning.parse("! only a comment")) {
            XCTAssertEqual($0 as? ScalaTuningError, .missingNoteCount)
        }
        XCTAssertThrowsError(try ScalaTuning.parse("desc\nseven\n1/1")) {
            XCTAssertEqual($0 as? ScalaTuningError, .invalidNoteCount("seven"))
        }
        XCTAssertThrowsError(try ScalaTuning.parse("desc\n0\n")) {
            XCTAssertEqual($0 as? ScalaTuningError, .invalidNoteCount("0"))
        }
        XCTAssertThrowsError(try ScalaTuning.parse("desc\n3\n9/8\n2/1")) {
            XCTAssertEqual($0 as? ScalaTuningError, .pitchCountMismatch(expected: 3, found: 2))
        }
        XCTAssertThrowsError(try ScalaTuning.parse("desc\n1\n3/0")) {
            XCTAssertEqual($0 as? ScalaTuningError, .invalidPitch("3/0"))
        }
        XCTAssertThrowsError(try ScalaTuning.parse("desc\n1\n-3/2")) {
            XCTAssertEqual($0 as? ScalaTuningError, .invalidPitch("-3/2"))
        }
        XCTAssertThrowsError(try ScalaTuning.parse("desc\n1\n-50.0")) {
            XCTAssertEqual($0 as? ScalaTuningError, .invalidScale)
        }
    }

    func testInitRejectsEmptyOrNonPositivePeriod() {
        XCTAssertThrowsError(try ScalaTuning(degreeCents: []))
        XCTAssertThrowsError(try ScalaTuning(degreeCents: [100, 0]))
        XCTAssertThrowsError(try ScalaTuning(degreeCents: [.nan]))
    }
}
