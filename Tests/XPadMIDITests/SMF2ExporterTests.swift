import XCTest
@testable import XPadMIDI

final class SMF2ExporterTests: XCTestCase {
    func testHeaderUsesSMF2LayoutAndDefaultPPQN() throws {
        let data = SMF2Exporter.export(events: [])

        XCTAssertEqual(Array(data[0..<4]), Array("SMF2".utf8))
        XCTAssertEqual(readUInt32(data, at: 4), 8)
        XCTAssertEqual(readUInt16(data, at: 8), 1)
        XCTAssertEqual(readUInt16(data, at: 10), 960)
        XCTAssertEqual(readUInt16(data, at: 12), 1)
        XCTAssertEqual(Array(data[16..<20]), Array("M2TR".utf8))
        XCTAssertEqual(readUInt32(data, at: 20), UInt32(data.count - 24))
    }

    func testHeaderPreservesCustomPPQN() {
        let data = SMF2Exporter.export(events: [], ppqn: 480)
        XCTAssertEqual(readUInt16(data, at: 10), 480)
    }

    func testExportEncodesSortedMIDI2NoteOnAndNoteOffEvents() throws {
        let event = RecordedNoteEvent(note: 64, velocity: 100, startTick: 20, durationTicks: 30)
        let parsed = try SMF2Parser.parse(data: SMF2Exporter.export(events: [event], channel: 3))

        XCTAssertEqual(parsed.events.count, 2)
        XCTAssertEqual(parsed.events.map(\.tick), [20, 50])

        let noteOn = parsed.events[0].words
        XCTAssertEqual(noteOn[0] >> 28, 0x4)
        XCTAssertEqual((noteOn[0] >> 16) & 0xFF, 0x93)
        XCTAssertEqual((noteOn[0] >> 8) & 0x7F, 64)
        XCTAssertEqual(noteOn[1], UInt32(MIDI2UMPEncoder.scale7To16(100)) << 16)

        let noteOff = parsed.events[1].words
        XCTAssertEqual(noteOff[0] >> 28, 0x4)
        XCTAssertEqual((noteOff[0] >> 16) & 0xFF, 0x83)
        XCTAssertEqual((noteOff[0] >> 8) & 0x7F, 64)
        XCTAssertEqual(noteOff[1], 0)

        let sorted = SMF2Exporter.export(events: [
            RecordedNoteEvent(note: 60, velocity: 1, startTick: 100, durationTicks: 1),
            RecordedNoteEvent(note: 61, velocity: 1, startTick: 10, durationTicks: 1)
        ])
        let sortedParsed = try SMF2Parser.parse(data: sorted)
        XCTAssertEqual(sortedParsed.events.map(\.tick), [10, 11, 100, 101])
    }

    func testRoundTripPreservesMetadataEventsAndSimultaneousTicks() throws {
        let events = [
            TimedUMPEvent(tick: 0, words: [0x40123456, 0xABCDEF01]),
            TimedUMPEvent(tick: 0, words: [0x40223344, 0x10203040]),
            TimedUMPEvent(tick: 480, words: [0x40334455, 0x50607080])
        ]

        let parsed = try SMF2Parser.parse(data: SMF2Exporter.encodeStream(events: events, ppqn: 720))
        XCTAssertEqual(parsed.formatVersion, 1)
        XCTAssertEqual(parsed.ppqn, 720)
        XCTAssertEqual(parsed.trackCount, 1)
        XCTAssertEqual(parsed.events, events)
    }

    func testLargeDeltaIsSplitAndReparsedAtSameAbsoluteTick() throws {
        let largeTick = UInt64(0x00FF_FFFF) + 123
        let events = [
            TimedUMPEvent(tick: 0, words: [0x40112233, 0x44556677]),
            TimedUMPEvent(tick: largeTick, words: [0x408899AA, 0xBBCCDDEE])
        ]
        let data = SMF2Exporter.encodeStream(events: events)
        let payload = Array(data[24...])
        let deltaClockWords = stride(from: 0, to: payload.count, by: 4).filter {
            let word = readUInt32(Data(payload), at: $0)
            return (word >> 28) == 0 && ((word >> 24) & 0x0F) == 2
        }

        XCTAssertGreaterThanOrEqual(deltaClockWords.count, 2)
        XCTAssertEqual(try SMF2Parser.parse(data: data).events, events)
    }

    func testParserReportsMalformedFiles() {
        XCTAssertThrowsError(try SMF2Parser.parse(data: Data([0, 1, 2]))) { error in
            XCTAssertTrue(error is SMF2Parser.ParseError)
            guard case .fileTooShort = error as? SMF2Parser.ParseError else {
                return XCTFail("Expected fileTooShort")
            }
        }

        var badHeader = SMF2Exporter.export(events: [])
        badHeader[0] = 0
        XCTAssertThrowsError(try SMF2Parser.parse(data: badHeader)) { error in
            guard case .invalidHeaderMagic = error as? SMF2Parser.ParseError else {
                return XCTFail("Expected invalidHeaderMagic")
            }
        }

        var badTrack = SMF2Exporter.export(events: [])
        badTrack[16] = 0
        XCTAssertThrowsError(try SMF2Parser.parse(data: badTrack)) { error in
            guard case .invalidTrackMagic = error as? SMF2Parser.ParseError else {
                return XCTFail("Expected invalidTrackMagic")
            }
        }

        var badLength = SMF2Exporter.export(events: [])
        badLength[23] = 0xFF
        XCTAssertThrowsError(try SMF2Parser.parse(data: badLength)) { error in
            guard case .malformedPayload = error as? SMF2Parser.ParseError else {
                return XCTFail("Expected malformedPayload")
            }
        }
    }

    func testEmptyEventListIsParsableWithNoEvents() throws {
        let parsed = try SMF2Parser.parse(data: SMF2Exporter.encodeStream(events: []))
        XCTAssertEqual(parsed.events, [])
        XCTAssertEqual(parsed.trackCount, 1)
    }

    private func readUInt16(_ data: Data, at offset: Int) -> UInt16 {
        UInt16(data[offset]) << 8 | UInt16(data[offset + 1])
    }

    private func readUInt32(_ data: Data, at offset: Int) -> UInt32 {
        UInt32(data[offset]) << 24
            | UInt32(data[offset + 1]) << 16
            | UInt32(data[offset + 2]) << 8
            | UInt32(data[offset + 3])
    }
}
