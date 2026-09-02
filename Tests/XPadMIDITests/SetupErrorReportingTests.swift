import XCTest
@testable import XPadMIDI

final class SetupErrorReportingTests: XCTestCase {
    func testSetupErrorDescriptionReflectsEndpointCreation() {
        let midi = MIDIEngine()
        XCTAssertNil(midi.setupErrorDescription, "Client creation alone reports no setup error")

        midi.virtualMIDIEnabled = true
        defer { midi.virtualMIDIEnabled = false }

        if let description = midi.setupErrorDescription {
            XCTAssertFalse(description.isEmpty, "A setup failure carries a human-readable description")
        } else {
            XCTAssertEqual(
                midi.availableVirtualPorts,
                Set(VirtualPort.allCases),
                "No setup error means every virtual source was created"
            )
        }
    }
}
