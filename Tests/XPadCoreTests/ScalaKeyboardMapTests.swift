import XCTest
@testable import XPadCore

final class ScalaKeyboardMapTests: XCTestCase {
    private let middleC = 261.6255653005986

    private func ptolemaic() throws -> ScalaTuning {
        try ScalaTuning.parse("Ptolemaic\n 7\n 9/8\n 5/4\n 4/3\n 3/2\n 5/3\n 15/8\n 2/1\n")
    }

    func testParsesHeaderEntriesAndComments() throws {
        let text = """
        ! test.kbm
        3
        ! first and last
        0
        127
        60
        60
        261.6255653006
        4
        0
        2
        x
        """
        let map = try ScalaKeyboardMap.parse(text)
        XCTAssertEqual(map.mapSize, 3)
        XCTAssertEqual(map.middleNote, 60)
        XCTAssertEqual(map.referenceFrequency, 261.6255653006, accuracy: 1e-9)
        XCTAssertEqual(map.formalOctaveDegree, 4)
        XCTAssertEqual(map.entries, [0, 2, nil])
    }

    func testPatternRepeatsAndSkipsUnmappedKeys() throws {
        let map = ScalaKeyboardMap(
            referenceNote: 60,
            referenceFrequency: middleC,
            formalOctaveDegree: 4,
            entries: [0, 2, nil]
        )
        XCTAssertEqual(map.scaleDegree(forMIDINote: 60), 0)
        XCTAssertEqual(map.scaleDegree(forMIDINote: 61), 2)
        XCTAssertNil(map.scaleDegree(forMIDINote: 62))
        XCTAssertEqual(map.scaleDegree(forMIDINote: 63), 4)
        XCTAssertEqual(map.scaleDegree(forMIDINote: 64), 6)
        XCTAssertNil(map.scaleDegree(forMIDINote: 59))
        XCTAssertEqual(map.scaleDegree(forMIDINote: 58), -2)
        XCTAssertEqual(map.scaleDegree(forMIDINote: 57), -4)
    }

    func testNotesOutsideRangeAreUnmapped() {
        let map = ScalaKeyboardMap(firstNote: 48, lastNote: 72)
        XCTAssertNil(map.scaleDegree(forMIDINote: 47))
        XCTAssertEqual(map.scaleDegree(forMIDINote: 48), -12)
        XCTAssertNil(map.scaleDegree(forMIDINote: 73))
    }

    func testStandardMapKeepsTwelveToneEqualTemperament() throws {
        let twelveTET = try ScalaTuning(degreeCents: (1...12).map { Double($0) * 100.0 })
        for note in UInt8(0)...UInt8(127) {
            let offset = try XCTUnwrap(twelveTET.centsOffset(forMIDINote: note, map: .standard))
            XCTAssertEqual(offset, 0.0, accuracy: 1e-6)
        }
    }

    func testReferenceFrequencyAnchorsTheScale() throws {
        let tuning = try ptolemaic()
        let map = ScalaKeyboardMap(referenceNote: 60, referenceFrequency: middleC)
        XCTAssertEqual(try XCTUnwrap(tuning.centsOffset(forMIDINote: 60, map: map)), 0.0, accuracy: 1e-6)
        // 5/4 above middle C is 386.314 cents against 200 in 12-TET.
        XCTAssertEqual(try XCTUnwrap(tuning.centsOffset(forMIDINote: 62, map: map)), 186.3137, accuracy: 1e-3)
        XCTAssertEqual(try XCTUnwrap(tuning.semitoneOffset(forMIDINote: 67, map: map)), 5.0, accuracy: 1e-6)
    }

    func testStandardMapAnchorsA440NotMiddleC() throws {
        // Degree 9 of the 7-note scale is 1200 + 386.314 cents above degree 0,
        // so with A4 pinned at 440 Hz middle C lands 686.314 cents flat of 12-TET.
        let offset = try XCTUnwrap(ptolemaic().centsOffset(forMIDINote: 60, map: .standard))
        XCTAssertEqual(offset, -686.3137, accuracy: 1e-3)
    }

    func testUnmappedKeysHaveNoOffset() throws {
        let map = ScalaKeyboardMap(referenceNote: 60, referenceFrequency: middleC, formalOctaveDegree: 4, entries: [0, 2, nil])
        XCTAssertNil(try ptolemaic().centsOffset(forMIDINote: 62, map: map))
    }

    func testExtremeHandBuiltMapsDoNotTrap() throws {
        let map = ScalaKeyboardMap(formalOctaveDegree: Int.max, entries: [Int.max])
        _ = map.scaleDegree(forMIDINote: 127)
        // An absurd degree gives a non-finite pitch, which is reported as "no offset".
        let farAway = ScalaKeyboardMap(referenceNote: 60, entries: [0, 1_000_000_000])
        XCTAssertNil(try ptolemaic().centsOffset(forMIDINote: 61, map: farAway))
    }

    func testRejectsMalformedFiles() {
        XCTAssertThrowsError(try ScalaKeyboardMap.parse("0\n0\n127\n60")) {
            XCTAssertEqual($0 as? ScalaKeyboardMapError, .missingField("reference note"))
        }
        XCTAssertThrowsError(try ScalaKeyboardMap.parse("0\n0\n127\n60\n69\n0\n12")) {
            XCTAssertEqual($0 as? ScalaKeyboardMapError, .invalidField(name: "reference frequency", text: "0"))
        }
        XCTAssertThrowsError(try ScalaKeyboardMap.parse("0\n100\n50\n60\n69\n440\n12")) {
            XCTAssertEqual($0 as? ScalaKeyboardMapError, .invalidField(name: "last note", text: "50"))
        }
        XCTAssertThrowsError(try ScalaKeyboardMap.parse("3\n0\n127\n60\n60\n261.6\n7\n0\n1")) {
            XCTAssertEqual($0 as? ScalaKeyboardMapError, .entryCountMismatch(expected: 3, found: 2))
        }
        XCTAssertThrowsError(try ScalaKeyboardMap.parse("2\n0\n127\n60\n60\n261.6\n7\nx\n1")) {
            XCTAssertEqual($0 as? ScalaKeyboardMapError, .unmappedReferenceNote)
        }
        XCTAssertThrowsError(try ScalaKeyboardMap.parse("1\n0\n127\n60\n60\n261.6\n7\n9223372036854775807")) {
            XCTAssertEqual($0 as? ScalaKeyboardMapError, .invalidField(name: "mapping entry", text: "9223372036854775807"))
        }
        XCTAssertThrowsError(try ScalaKeyboardMap.parse("1\n0\n127\n60\n60\n261.6\n0\n0")) {
            XCTAssertEqual($0 as? ScalaKeyboardMapError, .invalidField(name: "formal octave degree", text: "0"))
        }
    }
}
