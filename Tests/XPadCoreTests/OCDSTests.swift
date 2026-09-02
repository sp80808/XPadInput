import XCTest
@testable import XPadCore

final class OCDSTests: XCTestCase {
    func testEncodeDecodeRoundTripUsesPrettySortedJSON() throws {
        let manager = OCDSManager()
        let original = makeProfile()

        let json = try manager.encodeToJSON(original)
        let decoded = try manager.decodeFromJSON(json)

        XCTAssertEqual(decoded, original)
        XCTAssertTrue(json.hasPrefix("{\n"))
        XCTAssertTrue(json.contains("\n  \"hapticProfile\""))
        XCTAssertLessThan(json.range(of: "\"hapticProfile\"")!.lowerBound, json.range(of: "\"metadata\"")!.lowerBound)
        XCTAssertLessThan(json.range(of: "\"metadata\"")!.lowerBound, json.range(of: "\"schemaVersion\"")!.lowerBound)
    }

    func testValidationRejectsUnsupportedVersionAndMissingFields() {
        let manager = OCDSManager()

        assertValidationError(
            manager,
            profile: makeProfile(schemaVersion: "2.0.0"),
            expected: .unsupportedSchemaVersion("2.0.0")
        )
        assertValidationError(
            manager,
            profile: makeProfile(metadata: OCDSMetadata(id: " \t", name: "Valid")),
            expected: .missingRequiredField("metadata.id")
        )
        assertValidationError(
            manager,
            profile: makeProfile(metadata: OCDSMetadata(id: "valid", name: " \t")),
            expected: .missingRequiredField("metadata.name")
        )
    }

    func testValidationRejectsBindingAndTriggerRanges() {
        let manager = OCDSManager()

        for deadzone in [-0.01, 1.01] {
            let binding = OCDSInputBinding(source: .leftStick, target: .soloLead, deadzone: deadzone)
            assertValidationError(
                manager,
                profile: makeProfile(inputBindings: [binding]),
                expected: .outOfRange("deadzone for left_stick")
            )
        }

        let insensitive = OCDSInputBinding(source: .leftStick, target: .soloLead, sensitivity: 0)
        assertValidationError(
            manager,
            profile: makeProfile(inputBindings: [insensitive]),
            expected: .outOfRange("sensitivity for left_stick")
        )

        let triggerFactories: [(String, (Double) -> OCDSAdaptiveTriggerSpec)] = [
            ("trigger startPosition", { OCDSAdaptiveTriggerSpec(trigger: .leftTrigger, startPosition: $0) }),
            ("trigger endPosition", { OCDSAdaptiveTriggerSpec(trigger: .leftTrigger, endPosition: $0) }),
            ("trigger resistiveStrength", { OCDSAdaptiveTriggerSpec(trigger: .leftTrigger, resistiveStrength: $0) })
        ]
        for (field, makeTrigger) in triggerFactories {
            for value in [-0.01, 1.01] {
                assertValidationError(
                    manager,
                    profile: makeProfile(triggerConfigs: [makeTrigger(value)]),
                    expected: .outOfRange(field)
                )
            }
        }
    }

    func testDecodeRejectsInvalidJSONAndInvalidDecodedProfile() throws {
        let manager = OCDSManager()

        XCTAssertThrowsError(try manager.decodeFromJSON("{not valid json"))

        let invalidProfile = try manager.encodeToJSON(makeProfile(schemaVersion: "2.0.0"))
        XCTAssertThrowsError(try manager.decodeFromJSON(invalidProfile)) { error in
            guard case .unsupportedSchemaVersion("2.0.0") = error as? OCDSValidationError else {
                return XCTFail("Expected validation after decoding, got \(error)")
            }
        }
    }

    func testBundledProfilesValidateAndExposeExpectedCapabilities() throws {
        let manager = OCDSManager()

        XCTAssertEqual(manager.bundledProfiles.count, 13)
        for (key, profile) in manager.bundledProfiles {
            XCTAssertEqual(key, profile.metadata.id)
            XCTAssertNoThrow(try manager.validate(profile))
        }

        let dualSense = try XCTUnwrap(manager.profile(for: "sony_dualsense_mpe"))
        XCTAssertTrue(dualSense.hardwareSpec.hasAdaptiveTriggers)
        XCTAssertTrue(dualSense.hardwareSpec.hasMotionIMU)
        XCTAssertEqual(
            Set(dualSense.inputBindings.map { "\($0.source.rawValue):\($0.target.rawValue)" }),
            Set([
                "left_stick:harmonic_layer_select",
                "right_stick:solo_lead",
                "left_trigger:palm_mute",
                "right_trigger:pressure",
                "button_a:chord_tone_root",
                "button_x:chord_tone_third",
                "button_y:chord_tone_fifth",
                "button_b:chord_tone_seventh",
                "gyro_pitch:vibrato"
            ])
        )

        let guitarHero = try XCTUnwrap(manager.profile(for: "guitar_hero_fretboard"))
        XCTAssertTrue(guitarHero.hardwareSpec.hasFrets)
    }

    func testCustomProfilesOverrideLookupAndIncreaseAllProfiles() throws {
        let manager = OCDSManager()
        let bundled = try XCTUnwrap(manager.profile(for: "sony_dualsense_mpe"))
        var custom = bundled
        custom.metadata.name = "Custom DualSense"

        try manager.registerCustomProfile(custom)

        XCTAssertEqual(manager.profile(for: custom.id)?.metadata.name, "Custom DualSense")
        XCTAssertEqual(manager.allProfiles.count, manager.bundledProfiles.count + 1)
        XCTAssertEqual(manager.customProfiles[custom.id], custom)
    }

    func testInvalidCustomProfileIsNotRegistered() {
        let manager = OCDSManager()
        let invalid = makeProfile(metadata: OCDSMetadata(id: "", name: "Invalid"))

        XCTAssertThrowsError(try manager.registerCustomProfile(invalid))
        XCTAssertNil(manager.customProfiles[invalid.id])
    }

    func testModelDefaultsAndStableIdentifiers() {
        let metadata = OCDSMetadata(id: "id", name: "Name")
        XCTAssertEqual(metadata.author, "XPI Community")
        XCTAssertEqual(metadata.version, "1.0.0")
        XCTAssertEqual(metadata.category, "Standard Gamepad")
        XCTAssertNil(metadata.targetVendor)
        XCTAssertNil(metadata.targetProductID)
        XCTAssertEqual(metadata.tags, [])

        let profile = OCDSProfile(metadata: metadata, hardwareSpec: OCDSHardwareSpec())
        XCTAssertEqual(profile.id, "id")
        XCTAssertEqual(profile.schemaVersion, "1.0.0")
        XCTAssertEqual(profile.inputBindings, [])
        XCTAssertEqual(profile.triggerConfigs, [])

        let binding = OCDSInputBinding(source: .leftStick, target: .soloLead)
        XCTAssertEqual(binding.id, "left_stick_solo_lead")

        let trigger = OCDSAdaptiveTriggerSpec(trigger: .rightTrigger)
        XCTAssertEqual(trigger.id, "right_trigger")
        XCTAssertEqual(trigger.mode, "guitar_string")
        XCTAssertEqual(trigger.startPosition, 0)
        XCTAssertEqual(trigger.endPosition, 1)
        XCTAssertEqual(trigger.resistiveStrength, 0.6)
    }

    func testOnDiskEnumRawValuesRemainStable() {
        let sources: [OCDSSourceElement: String] = [
            .leftStick: "left_stick",
            .buttonA: "button_a",
            .gyroYaw: "gyro_yaw",
            .fret5: "fret_5",
            .strumDown: "strum_down"
        ]
        for (source, rawValue) in sources {
            XCTAssertEqual(source.rawValue, rawValue)
        }

        let targets: [OCDSTargetFunction: String] = [
            .pitchBend: "pitch_bend",
            .chordTone3: "chord_tone_third",
            .harmonicLayerSelect: "harmonic_layer_select",
            .ghostNote: "ghost_note"
        ]
        for (target, rawValue) in targets {
            XCTAssertEqual(target.rawValue, rawValue)
        }
    }

    func testValidationErrorDescriptionsIdentifyTheirContext() {
        let errors: [(OCDSValidationError, String)] = [
            (.invalidEncoding, "Invalid"),
            (.unsupportedSchemaVersion("2.0.0"), "2.0.0"),
            (.missingRequiredField("metadata.id"), "metadata.id"),
            (.outOfRange("deadzone for left_stick"), "deadzone")
        ]

        for (error, expectedText) in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertTrue(error.errorDescription!.localizedCaseInsensitiveContains(expectedText))
        }
    }

    private func makeProfile(
        schemaVersion: String = "1.0.0",
        metadata: OCDSMetadata = OCDSMetadata(id: "test_profile", name: "Test Profile"),
        inputBindings: [OCDSInputBinding] = [],
        triggerConfigs: [OCDSAdaptiveTriggerSpec] = []
    ) -> OCDSProfile {
        OCDSProfile(
            schemaVersion: schemaVersion,
            metadata: metadata,
            hardwareSpec: OCDSHardwareSpec(),
            inputBindings: inputBindings,
            triggerConfigs: triggerConfigs
        )
    }

    private func assertValidationError(
        _ manager: OCDSManager,
        profile: OCDSProfile,
        expected: OCDSValidationError
    ) {
        XCTAssertThrowsError(try manager.validate(profile)) { error in
            guard let actual = error as? OCDSValidationError else {
                return XCTFail("Expected OCDSValidationError, got \(error)")
            }
            switch (actual, expected) {
            case let (.unsupportedSchemaVersion(actual), .unsupportedSchemaVersion(expected)),
                 let (.missingRequiredField(actual), .missingRequiredField(expected)),
                 let (.outOfRange(actual), .outOfRange(expected)):
                XCTAssertEqual(actual, expected)
            default:
                XCTFail("Expected \(expected), got \(actual)")
            }
        }
    }
}
