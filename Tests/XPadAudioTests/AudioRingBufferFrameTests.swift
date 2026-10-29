import XCTest
@testable import XPadAudio

/// Frame-alignment regressions for the public ring-buffer API.
final class AudioRingBufferFrameTests: XCTestCase {
    func testPlanarReadKeepsLeftAndRightInTheSameFrameWindow() {
        let buffer = AudioRingBuffer(channels: 2, capacityFrames: 256)
        let left: [Float] = [0.1, 0.2, 0.3, 0.4]
        let right: [Float] = [0.6, 0.7, 0.8, 0.9]

        left.withUnsafeBufferPointer { leftInput in
            right.withUnsafeBufferPointer { rightInput in
                XCTAssertEqual(
                    buffer.writeStereo(
                        left: leftInput.baseAddress!,
                        right: rightInput.baseAddress!,
                        frameCount: left.count
                    ),
                    4
                )
            }
        }

        var actualLeft = [Float](repeating: -1, count: 4)
        var actualRight = [Float](repeating: -1, count: 4)
        actualLeft.withUnsafeMutableBufferPointer { leftOutput in
            actualRight.withUnsafeMutableBufferPointer { rightOutput in
                XCTAssertEqual(
                    buffer.readStereo(
                        left: leftOutput.baseAddress!,
                        right: rightOutput.baseAddress!,
                        frameCount: 4
                    ),
                    4
                )
            }
        }

        XCTAssertEqual(actualLeft, left)
        XCTAssertEqual(actualRight, right)
        XCTAssertEqual(buffer.availableReadFrames, 0)
    }

    func testPlanarReadPadsBothChannelsWhenUnderrun() {
        let buffer = AudioRingBuffer(channels: 2, capacityFrames: 256)
        let input: [Float] = [1, 3, 2, 4] // L1, R1, L2, R2
        input.withUnsafeBufferPointer {
            XCTAssertEqual(buffer.writeInterleaved(from: $0.baseAddress!, frameCount: 2), 2)
        }

        var left = [Float](repeating: -99, count: 5)
        var right = [Float](repeating: -99, count: 5)
        left.withUnsafeMutableBufferPointer { leftOutput in
            right.withUnsafeMutableBufferPointer { rightOutput in
                XCTAssertEqual(
                    buffer.readStereo(
                        left: leftOutput.baseAddress!,
                        right: rightOutput.baseAddress!,
                        frameCount: 5
                    ),
                    2
                )
            }
        }

        XCTAssertEqual(left, [1, 2, 0, 0, 0])
        XCTAssertEqual(right, [3, 4, 0, 0, 0])
        XCTAssertEqual(buffer.underrunCount, 3)
    }

    func testMonoSourceMirrorsOptionalSecondDestination() {
        let buffer = AudioRingBuffer(channels: 1, capacityFrames: 256)
        let mono: [Float] = [0.25, -0.5, 0.75]
        mono.withUnsafeBufferPointer {
            XCTAssertEqual(buffer.writeInterleaved(from: $0.baseAddress!, frameCount: 3), 3)
        }

        var left = [Float](repeating: 0, count: 3)
        var right = [Float](repeating: 0, count: 3)
        left.withUnsafeMutableBufferPointer { leftOutput in
            right.withUnsafeMutableBufferPointer { rightOutput in
                XCTAssertEqual(
                    buffer.readStereo(
                        left: leftOutput.baseAddress!,
                        right: rightOutput.baseAddress!,
                        frameCount: 3
                    ),
                    3
                )
            }
        }
        XCTAssertEqual(left, mono)
        XCTAssertEqual(right, mono)
    }

    func testPlanarReadWorksAfterWrapAroundAndRepeatedResets() {
        let buffer = AudioRingBuffer(channels: 2, capacityFrames: 256)
        let filler = [Float](repeating: 0.5, count: 250 * 2)
        filler.withUnsafeBufferPointer {
            XCTAssertEqual(buffer.writeInterleaved(from: $0.baseAddress!, frameCount: 250), 250)
        }

        var consumed = [Float](repeating: 0, count: 250 * 2)
        consumed.withUnsafeMutableBufferPointer {
            XCTAssertEqual(buffer.readInterleaved(into: $0.baseAddress!, frameCount: 250), 250)
        }

        let wrapped: [Float] = [1, 11, 2, 12, 3, 13, 4, 14, 5, 15, 6, 16]
        wrapped.withUnsafeBufferPointer {
            XCTAssertEqual(buffer.writeInterleaved(from: $0.baseAddress!, frameCount: 6), 6)
        }

        var left = [Float](repeating: 0, count: 6)
        var right = [Float](repeating: 0, count: 6)
        left.withUnsafeMutableBufferPointer { leftOutput in
            right.withUnsafeMutableBufferPointer { rightOutput in
                XCTAssertEqual(
                    buffer.readStereo(
                        left: leftOutput.baseAddress!,
                        right: rightOutput.baseAddress!,
                        frameCount: 6
                    ),
                    6
                )
            }
        }
        XCTAssertEqual(left, [1, 2, 3, 4, 5, 6])
        XCTAssertEqual(right, [11, 12, 13, 14, 15, 16])

        for _ in 0..<3 {
            wrapped.withUnsafeBufferPointer {
                XCTAssertEqual(buffer.writeInterleaved(from: $0.baseAddress!, frameCount: 6), 6)
            }
            buffer.reset()
            XCTAssertEqual(buffer.availableReadFrames, 0)
            XCTAssertEqual(buffer.underrunCount, 0)
            XCTAssertEqual(buffer.overrunCount, 0)
            var silence = [Float](repeating: -1, count: 12)
            silence.withUnsafeMutableBufferPointer {
                XCTAssertEqual(buffer.readInterleaved(into: $0.baseAddress!, frameCount: 6), 0)
            }
            XCTAssertEqual(silence, [Float](repeating: 0, count: 12))
        }
    }
}
