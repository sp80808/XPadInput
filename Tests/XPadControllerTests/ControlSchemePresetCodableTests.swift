import Foundation
import XCTest
@testable import XPadController

final class ControlSchemePresetCodableTests: XCTestCase {
    func testStickFeelPresetDecodesLegacyVerboseValues() throws {
        let legacyPrecise = Data(#"\"Precise (High resolution at center for vibrato & fine bends)\""#.utf8)
        let legacyBalanced = Data(#"\"Balanced (Natural linear response)\""#.utf8)
        let legacyResponsive = Data(#"\"Responsive (Immediate output from small thumb movements)\""#.utf8)

        XCTAssertEqual(try JSONDecoder().decode(StickFeelPreset.self, from: legacyPrecise), .precise)
        XCTAssertEqual(try JSONDecoder().decode(StickFeelPreset.self, from: legacyBalanced), .balanced)
        XCTAssertEqual(try JSONDecoder().decode(StickFeelPreset.self, from: legacyResponsive), .responsive)
    }

    func testTriggerFeelPresetDecodesLegacyVerboseValues() throws {
        let legacySoft = Data(#"\"Soft (Light initial pull with rapid engagement)\""#.utf8)
        let legacyLinear = Data(#"\"Linear (Proportional travel with predictable swell)\""#.utf8)
        let legacyFirm = Data(#"\"Firm (Deep travel threshold for heavy expressive pressure)\""#.utf8)

        XCTAssertEqual(try JSONDecoder().decode(TriggerFeelPreset.self, from: legacySoft), .soft)
        XCTAssertEqual(try JSONDecoder().decode(TriggerFeelPreset.self, from: legacyLinear), .linear)
        XCTAssertEqual(try JSONDecoder().decode(TriggerFeelPreset.self, from: legacyFirm), .firm)
    }

    func testPresetEncodingUsesCompactWidthSafeLabels() throws {
        let stickData = try JSONEncoder().encode(StickFeelPreset.balanced)
        let triggerData = try JSONEncoder().encode(TriggerFeelPreset.linear)

        XCTAssertEqual(String(data: stickData, encoding: .utf8), "\"Balanced\"")
        XCTAssertEqual(String(data: triggerData, encoding: .utf8), "\"Linear\"")
    }

    func testPresetRawValuesRemainCompactForSegmentedControls() {
        XCTAssertEqual(StickFeelPreset.allCases.map(\.rawValue), ["Precise", "Balanced", "Responsive"])
        XCTAssertEqual(TriggerFeelPreset.allCases.map(\.rawValue), ["Soft", "Linear", "Firm"])
    }
}
