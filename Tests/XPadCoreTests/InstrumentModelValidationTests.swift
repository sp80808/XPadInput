import Foundation
import XCTest
@testable import XPadCore

final class InstrumentModelValidationTests: XCTestCase {
    func testProfileSanitizesInvalidRanges() {
        let profile = InstrumentProfile(
            id: "invalid",
            family: .genericMPE,
            name: "Invalid",
            polyphonyMode: .mpe,
            preferredPitchBendRange: .nan,
            supportsPitchBend: true
        )

        XCTAssertEqual(profile.preferredPitchBendRange, 0.0)
        XCTAssertFalse(profile.supportsPitchBend)
        XCTAssertTrue(profile.supports(.normal))
    }

    func testSemanticCurvesClampAndPreserveDirection() {
        XCTAssertEqual(PitchBendCurve.linear.apply(2.0), 1.0)
        XCTAssertEqual(PitchBendCurve.precision.apply(-0.5), -0.25, accuracy: 0.000_001)
        XCTAssertEqual(PressureCurve.linear.apply(-1.0), 0.0)
        XCTAssertEqual(PressureCurve.expressive.apply(0.5), 0.5, accuracy: 0.000_001)
    }

    func testPerformanceEventNormalizesExpressionAndRoundTrips() throws {
        let event = InstrumentPerformanceEvent(
            note: Note(pitchClass: .e, octave: 4),
            targetNote: Note(pitchClass: .fSharp, octave: 4),
            technique: .bend,
            velocity: 72,
            pressure: 1.4,
            pitchOffset: 2.0,
            timbre: -0.2,
            damping: 0.3,
            role: .third,
            timestamp: -1.0
        )

        XCTAssertEqual(event.pressure, 1.0)
        XCTAssertEqual(event.timbre, 0.0)
        XCTAssertEqual(event.pitchOffsetSemitones, 2.0)
        XCTAssertEqual(event.timestamp, 0.0)
        XCTAssertEqual(event.expression.midiPressure, 127)

        let data = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(InstrumentPerformanceEvent.self, from: data)
        XCTAssertEqual(decoded, event)
    }
}
