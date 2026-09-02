import XCTest
@testable import XPadController

final class SemanticMusicalActionTests: XCTestCase {
    func testEverySemanticActionHasExpectedCategoryAndCompatibility() {
        let expectations: [String: (String, String)] = [
            "Primary Excitation (Strum / Pluck)": ("Excitation & Strum", "Analog Axis, Trigger or Stick"),
            "Secondary Excitation (Duo Drums / Percussion)": ("Excitation & Strum", "Momentary Face / Shoulder Button"),
            "Pitch Expression (Bend / Vibrato / Slide)": ("Continuous Expression", "Analog Axis, Trigger or Stick"),
            "Pressure Expression (Dynamic Swell / Aftertouch)": ("Continuous Expression", "Analog Axis, Trigger or Stick"),
            "Damping Expression (Palm Mute / Decay Cut)": ("Continuous Expression", "Analog Axis, Trigger or Stick"),
            "Timbre Expression (Filter Sweep / Brightness)": ("Continuous Expression", "Analog Axis, Trigger or Stick"),
            "Motion Tilt Expression (6-Axis IMU Modulation)": ("Continuous Expression", "Analog Axis, Trigger or Stick"),
            "Harmonic Wheel 2D (Polar Sector & Risk)": ("Harmony & Navigation", "2D Continuous Thumbstick"),
            "Octave Shift Up": ("Harmony & Navigation", "Digital Button or D-Pad Direction"),
            "Octave Shift Down": ("Harmony & Navigation", "Digital Button or D-Pad Direction"),
            "Next Inversion / Open Voicing": ("Harmony & Navigation", "Digital Button or D-Pad Direction"),
            "Previous Inversion / Close Voicing": ("Harmony & Navigation", "Digital Button or D-Pad Direction"),
            "Technique Modifier (Hammer / Pull / Slide Hold)": ("Articulation & Modes", "Momentary Face / Shoulder Button"),
            "Sustain Latch (Pedal Hold / Toggle)": ("Articulation & Modes", "Button or Toggle Latch"),
            "Lead Solo Mode Toggle": ("Articulation & Modes", "Button or Toggle Latch"),
            "Duo Performance Mode Toggle": ("Articulation & Modes", "Button or Toggle Latch"),
            "Chord Root / Degree 1 Voice": ("Individual Voices", "Momentary Face / Shoulder Button"),
            "Chord Third / Degree 3 Voice": ("Individual Voices", "Momentary Face / Shoulder Button"),
            "Chord Fifth / Degree 5 Voice": ("Individual Voices", "Momentary Face / Shoulder Button"),
            "Chord Seventh / Degree 7 Voice": ("Individual Voices", "Momentary Face / Shoulder Button"),
            "MIDI Panic (All Notes Off)": ("System & Utility", "Button or Toggle Latch"),
            "Metronome Audio Click Toggle": ("System & Utility", "Button or Toggle Latch")
        ]

        XCTAssertEqual(expectations.count, SemanticMusicalAction.allCases.count)
        for action in SemanticMusicalAction.allCases {
            let expectation = expectations[action.rawValue]
            XCTAssertNotNil(expectation, "Missing table mapping for \(action)")
            XCTAssertFalse(action.displayName.isEmpty)
            XCTAssertFalse(action.description.isEmpty)
            XCTAssertEqual(action.category.rawValue, expectation?.0)
            XCTAssertEqual(action.compatibilityType.rawValue, expectation?.1)
        }
    }

    func testPhysicalControlContinuityAndPolarity() {
        XCTAssertTrue(PhysicalControlInput.leftTrigger.isContinuous)
        XCTAssertFalse(PhysicalControlInput.leftTrigger.isBipolar)
        XCTAssertTrue(PhysicalControlInput.rightTrigger.isContinuous)
        XCTAssertFalse(PhysicalControlInput.rightTrigger.isBipolar)

        for input in [
            PhysicalControlInput.leftStick2D,
            .rightStickX,
            .motionYaw,
            .touchpad2D
        ] {
            XCTAssertTrue(input.isContinuous)
            XCTAssertTrue(input.isBipolar)
        }

        for input in [
            PhysicalControlInput.buttonSouth,
            .leftShoulder,
            .dpadUp
        ] {
            XCTAssertFalse(input.isContinuous)
            XCTAssertFalse(input.isBipolar)
        }
    }

    func testPhysicalControlFamiliesAxesAndGlyphs() {
        XCTAssertEqual(PhysicalControlInput.leftStick2D.hardwareFamily, .leftStick)
        XCTAssertEqual(PhysicalControlInput.leftStickX.hardwareFamily, .leftStick)
        XCTAssertEqual(PhysicalControlInput.motionPitch.hardwareFamily, .motion)
        XCTAssertEqual(PhysicalControlInput.touchpad2D.hardwareFamily, .touchpad)

        XCTAssertEqual(PhysicalControlInput.leftStick2D.stickAxis, .radial)
        XCTAssertEqual(PhysicalControlInput.leftStickX.stickAxis, .x)
        XCTAssertEqual(PhysicalControlInput.leftStickY.stickAxis, .y)
        XCTAssertNil(PhysicalControlInput.leftTrigger.stickAxis)

        let faceGlyphs: Set<String> = [
            PhysicalControlInput.buttonSouth.defaultGlyphKey.rawValue,
            PhysicalControlInput.buttonEast.defaultGlyphKey.rawValue,
            PhysicalControlInput.buttonWest.defaultGlyphKey.rawValue,
            PhysicalControlInput.buttonNorth.defaultGlyphKey.rawValue
        ]
        XCTAssertEqual(faceGlyphs.count, 4)
    }

    func testPhysicalControlOverlapRules() {
        XCTAssertTrue(PhysicalControlInput.leftStickX.overlapsHardware(with: .leftStickX))
        XCTAssertTrue(PhysicalControlInput.unassigned.overlapsHardware(with: .unassigned))
        XCTAssertFalse(PhysicalControlInput.unassigned.overlapsHardware(with: .buttonSouth))
        XCTAssertTrue(PhysicalControlInput.leftStick2D.overlapsHardware(with: .leftStickX))
        XCTAssertTrue(PhysicalControlInput.leftStickY.overlapsHardware(with: .leftStick2D))
        XCTAssertFalse(PhysicalControlInput.leftStickX.overlapsHardware(with: .leftStickY))
        XCTAssertFalse(PhysicalControlInput.motionPitch.overlapsHardware(with: .motionRoll))
        XCTAssertTrue(PhysicalControlInput.buttonSouth.overlapsHardware(with: .buttonSouth))
        XCTAssertFalse(PhysicalControlInput.buttonSouth.overlapsHardware(with: .buttonEast))
    }

    func testOrthogonalStickPairsOnlyMatchSameStickAxes() {
        XCTAssertTrue(PhysicalControlInput.leftStickX.isOrthogonalStickPair(with: .leftStickY))
        XCTAssertTrue(PhysicalControlInput.rightStickY.isOrthogonalStickPair(with: .rightStickX))
        XCTAssertFalse(PhysicalControlInput.leftStick2D.isOrthogonalStickPair(with: .leftStickX))
        XCTAssertFalse(PhysicalControlInput.leftStickX.isOrthogonalStickPair(with: .rightStickY))
        XCTAssertFalse(PhysicalControlInput.leftStickX.isOrthogonalStickPair(with: .leftStickX))
    }

    func testUnavailableReasonUsesControllerCapabilities() {
        XCTAssertNil(PhysicalControlInput.motionPitch.unavailableReason(given: .dualSense))
        XCTAssertEqual(PhysicalControlInput.motionPitch.unavailableReason(given: .xbox), "motion IMU")
        XCTAssertNil(PhysicalControlInput.motionPitch.unavailableReason(given: .switchPro))

        XCTAssertNil(PhysicalControlInput.touchpad2D.unavailableReason(given: .dualSense))
        XCTAssertEqual(PhysicalControlInput.touchpad2D.unavailableReason(given: .xbox), "touchpad")
        XCTAssertEqual(PhysicalControlInput.buttonCenter.unavailableReason(given: .switchPro), "touchpad")

        XCTAssertNil(PhysicalControlInput.leftStickClick.unavailableReason(given: .xbox))
        XCTAssertEqual(
            PhysicalControlInput.leftStickClick.unavailableReason(given: ControllerCapabilityProfile()),
            "stick clicks"
        )

        XCTAssertNil(PhysicalControlInput.leftTrigger.unavailableReason(given: .dualSense))
        XCTAssertNil(PhysicalControlInput.leftTrigger.unavailableReason(given: .xbox))
        XCTAssertEqual(PhysicalControlInput.leftTrigger.unavailableReason(given: .switchPro), "analog triggers")
        XCTAssertNil(PhysicalControlInput.buttonSouth.unavailableReason(given: .switchPro))
    }
}
