import XCTest
@testable import XPadCore

final class MIDITuningStandardTests: XCTestCase {

    // MARK: - Frequency data

    func testEqualTemperedNoteEncodesWholeSemitone() {
        XCTAssertEqual(MIDITuningStandard.frequencyData(forMIDINote: 60, deviationCents: 0), [60, 0, 0])
        XCTAssertEqual(MIDITuningStandard.frequencyData(forMIDINote: 0, deviationCents: 0), [0, 0, 0])
    }

    func testFractionIsFourteenBitsOfASemitone() {
        // +50 cents is half a semitone: 0.5 * 16384 = 8192 -> 0x40, 0x00.
        XCTAssertEqual(MIDITuningStandard.frequencyData(forMIDINote: 69, deviationCents: 50), [69, 64, 0])
        // +0.5 cents is 0.005 of a semitone: 81.92 -> 82 -> MSB 0, LSB 82.
        XCTAssertEqual(MIDITuningStandard.frequencyData(forMIDINote: 60, deviationCents: 0.5), [60, 0, 82])
    }

    func testNegativeDeviationStaysInsideTheLowerSemitone() {
        XCTAssertEqual(MIDITuningStandard.frequencyData(forMIDINote: 60, deviationCents: -25), [59, 96, 0])
        XCTAssertEqual(
            MIDITuningStandard.frequencyData(forMIDINote: 0, deviationCents: -50),
            [0, 0, 0],
            "deviation below note 0 clamps to note 0"
        )
    }

    func testFrequencyDataNeverEmitsTheReservedNoChangeWord() {
        for cents in stride(from: -200.0, through: 13_000.0, by: 3.7) {
            XCTAssertNotEqual(
                MIDITuningStandard.frequencyData(centsAboveNoteZero: cents),
                MIDITuningStandard.noChange
            )
        }
        XCTAssertEqual(MIDITuningStandard.frequencyData(centsAboveNoteZero: 99_999), [127, 0, 0])
        XCTAssertEqual(MIDITuningStandard.frequencyData(centsAboveNoteZero: .nan), MIDITuningStandard.noChange)
    }

    func testFractionCarryRollsIntoTheNextSemitone() {
        // 99.999 cents rounds the 14-bit fraction up to a full semitone.
        let word = MIDITuningStandard.frequencyData(forMIDINote: 60, deviationCents: 99.999)
        XCTAssertEqual(word, [61, 0, 0])
    }

    // MARK: - Names and channel masks

    func testTuningNameIsSixteenSevenBitBytes() {
        XCTAssertEqual(MIDITuningStandard.nameBytes("XPI"), Array("XPI".utf8) + Array(repeating: 0x20, count: 13))
        XCTAssertEqual(MIDITuningStandard.nameBytes("0123456789ABCDEFGH").count, 16)
        XCTAssertEqual(MIDITuningStandard.nameBytes(""), Array(repeating: 0x20, count: 16))
        XCTAssertEqual(MIDITuningStandard.nameBytes("é")[0], 0x3F, "non-ASCII becomes '?'")
        XCTAssertEqual(MIDITuningStandard.nameBytes("é").last, 0x20, "and the name is still padded")
    }

    func testChannelMaskRoundTrips() {
        let mask = MIDITuningChannelMask(channels: [1, 7, 8, 14, 15, 16])
        XCTAssertEqual(mask.channels, [1, 7, 8, 14, 15, 16])
        XCTAssertEqual(MIDITuningChannelMask.all.channels.count, 16)
        XCTAssertEqual(MIDITuningChannelMask.single(3).channels, [3])
        XCTAssertEqual(MIDITuningChannelMask(channels: [99]).channels, [])
    }

    // MARK: - Bulk dump

    func testBulkDumpShapeAndChecksum() {
        let deviations = [Double](repeating: 0, count: 128)
        let message = MIDITuningStandard.bulkDump(name: "12-TET", deviationsCents: deviations, program: 2)

        XCTAssertEqual(message.count, 408)
        XCTAssertEqual(Array(message.prefix(5)), [0xF0, 0x7E, 0x7F, 0x08, 0x01])
        XCTAssertEqual(message[5], 2, "tuning program number")
        XCTAssertEqual(Array(message[6..<22]).count, 16, "tuning name")
        XCTAssertEqual(message.last, 0xF7)

        let body = Array(message[1..<(message.count - 2)])
        let checksum = body.reduce(UInt8(0)) { $0 ^ $1 }
        XCTAssertEqual(message[message.count - 2], checksum)
    }

    func testBulkDumpCarriesPerNoteTuning() {
        var deviations = [Double](repeating: 0, count: 128)
        deviations[61] = -13.7 // pure major third down from A
        let message = MIDITuningStandard.bulkDump(name: "JI", deviationsCents: deviations)

        // 6 header/name bytes + 3 bytes per note.
        let first = 22
        XCTAssertEqual(Array(message[first..<(first + 3)]), [0, 0, 0])
        XCTAssertEqual(Array(message[(first + 3 * 61)..<(first + 3 * 61 + 3)]), [60, 110, 59])
        XCTAssertEqual(Array(message[(first + 3 * 62)..<(first + 3 * 62 + 3)]), [62, 0, 0])
    }

    func testBulkDumpToleratesShortDeviationTable() {
        let message = MIDITuningStandard.bulkDump(name: "Short", deviationsCents: [0, 10])
        XCTAssertEqual(message.count, 408, "missing notes default to 12-TET")
        XCTAssertEqual(Array(message.prefix(5)), [0xF0, 0x7E, 0x7F, 0x08, 0x01])
    }

    func testBulkDumpRequest() {
        XCTAssertEqual(
            MIDITuningStandard.bulkDumpRequest(program: 16, deviceID: 1),
            [0xF0, 0x7E, 0x01, 0x08, 0x00, 0x10, 0xF7]
        )
    }

    // MARK: - Single note tuning change

    func testSingleNoteChangeSkipsUnchangedNotes() {
        var deviations = [Double](repeating: 0, count: 128)
        deviations[60] = -13.686 // 5-limit major third
        deviations[64] = 2.0

        let message = MIDITuningStandard.singleNoteTuningChange(deviationsCents: deviations)
        XCTAssertEqual(Array(message.prefix(7)), [0xF0, 0x7F, 0x7F, 0x08, 0x02, 0x00, 0x02])
        XCTAssertEqual(message.count, 7 + 2 * 4 + 1)
        XCTAssertEqual(message[7], 60, "first changed note")
        XCTAssertEqual(message[11], 64, "second changed note")
    }

    func testSingleNoteChangeIsEmptyForEqualTemperament() {
        let message = MIDITuningStandard.singleNoteTuningChange(
            deviationsCents: [Double](repeating: 0, count: 128)
        )
        XCTAssertTrue(message.isEmpty, "a 12-TET request should not spray 128 empty entries")
    }

    func testSingleNoteChangeRespectsTheSevenBitCount() {
        let message = MIDITuningStandard.singleNoteTuningChange(
            deviationsCents: [Double]((0..<128).map { Double($0) }),
            minimumDeviationCents: 0
        )
        XCTAssertEqual(message[6], 127, "ll is a 7-bit count")
        XCTAssertEqual(message.count, 7 + 127 * 4 + 1)
    }

    // MARK: - Scale/octave tuning

    func testScaleOctaveOneByteCentresOnSixtyFour() {
        let message = MIDITuningStandard.scaleOctaveTuning1Byte(deviationsCents: [Double](repeating: 0, count: 12))
        XCTAssertEqual(Array(message.prefix(5)), [0xF0, 0x7F, 0x7F, 0x08, 0x08])
        XCTAssertEqual(Array(message[5..<8]), [0x03, 0x7F, 0x7F], "all channels")
        XCTAssertEqual(Array(message[8..<20]), [UInt8](repeating: 0x40, count: 12))
        XCTAssertEqual(message.count, 21)
        XCTAssertEqual(message.last, 0xF7)
    }

    func testScaleOctaveOneByteClampsAndRounds() {
        var deviations = [Double](repeating: 0, count: 12)
        deviations[1] = -13.686
        deviations[3] = 200
        let message = MIDITuningStandard.scaleOctaveTuning1Byte(deviationsCents: deviations, channels: .single(5))
        XCTAssertEqual(Array(message[5..<8]), MIDITuningChannelMask.single(5).bytes)
        XCTAssertEqual(message[8], 0x40)
        XCTAssertEqual(message[9], 0x40 - 9, "-13.686 cents rounds to -9 one-byte steps")
        XCTAssertEqual(message[11], 0x7F, "values above +63 cents clamp")
    }

    func testScaleOctaveTwoByteHasFourteenBitResolution() {
        var deviations = [Double](repeating: 0, count: 12)
        deviations[4] = -13.686
        let message = MIDITuningStandard.scaleOctaveTuning2Byte(deviationsCents: deviations)
        XCTAssertEqual(Array(message.prefix(5)), [0xF0, 0x7F, 0x7F, 0x08, 0x09])
        XCTAssertEqual(message.count, 33)
        XCTAssertEqual(Array(message[8..<10]), [0x40, 0x00], "0 cents is 8192")
        // -13.686 cents -> 8192 - 1121 = 7071 -> 0x37 0x1F
        XCTAssertEqual(Array(message[16..<18]), [0x37, 0x1F])
        XCTAssertEqual(message.last, 0xF7)
    }

    func testEveryMessageIsSevenBitSafeAndFramed() {
        let deviations = [Double]((0..<128).map { Double($0 % 17) - 8 })
        let messages: [[UInt8]] = [
            MIDITuningStandard.bulkDump(name: "Sweep", deviationsCents: deviations),
            MIDITuningStandard.singleNoteTuningChange(deviationsCents: deviations),
            MIDITuningStandard.scaleOctaveTuning1Byte(deviationsCents: Array(deviations.prefix(12))),
            MIDITuningStandard.scaleOctaveTuning2Byte(deviationsCents: Array(deviations.prefix(12)))
        ]

        for message in messages {
            XCTAssertEqual(message.first, 0xF0)
            XCTAssertEqual(message.last, 0xF7)
            for byte in message.dropFirst().dropLast() {
                XCTAssertLessThan(byte, 0x80, "SysEx data must be 7-bit clean")
            }
        }
    }
}
