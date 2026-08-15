import Foundation
import XCTest
@testable import XPadCore
@testable import XPadAudio

final class XPadAudioTests: XCTestCase {
    func testAudioEngineInit() {
        let engine = AudioEngine.shared
        XCTAssertNotNil(engine)
    }
}
