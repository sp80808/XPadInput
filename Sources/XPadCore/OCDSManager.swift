import Foundation

/// Repository and validation engine for Open Controller Definition Standard (OCDS) profiles.
public final class OCDSManager: @unchecked Sendable {
    public static let shared = OCDSManager()

    public private(set) var bundledProfiles: [String: OCDSProfile] = [:]
    public private(set) var customProfiles: [String: OCDSProfile] = [:]

    public init() {
        loadBundledProfiles()
    }

    // MARK: - JSON Schema Specification

    public static let jsonSchemaV1: String = """
    {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "https://xpadinput.org/schema/ocds-v1.json",
      "title": "Open Controller Definition Standard (OCDS)",
      "description": "Universal open-source specification for gamepad mapping profiles, tactile curves, adaptive triggers, and 3D visual skinning.",
      "type": "object",
      "required": ["schemaVersion", "metadata", "hardwareSpec", "inputBindings", "triggerConfigs", "visualSkin", "hapticProfile"],
      "properties": {
        "schemaVersion": {
          "type": "string",
          "pattern": "^1\\\\.[0-9]+\\\\.[0-9]+$"
        },
        "metadata": {
          "type": "object",
          "required": ["id", "name", "author", "version", "category"],
          "properties": {
            "id": { "type": "string" },
            "name": { "type": "string" },
            "author": { "type": "string" },
            "description": { "type": "string" },
            "version": { "type": "string" },
            "category": { "type": "string" },
            "targetVendor": { "type": ["string", "null"] },
            "targetProductID": { "type": ["string", "null"] },
            "tags": {
              "type": "array",
              "items": { "type": "string" }
            }
          }
        },
        "hardwareSpec": {
          "type": "object",
          "required": ["stickCount", "triggerCount", "buttonCount"],
          "properties": {
            "stickCount": { "type": "integer", "minimum": 0 },
            "triggerCount": { "type": "integer", "minimum": 0 },
            "buttonCount": { "type": "integer", "minimum": 0 },
            "hasMotionIMU": { "type": "boolean" },
            "hasTouchpad": { "type": "boolean" },
            "hasHaptics": { "type": "boolean" },
            "hasAdaptiveTriggers": { "type": "boolean" },
            "hasRotaryEncoders": { "type": "boolean" },
            "hasTurntable": { "type": "boolean" },
            "hasFrets": { "type": "boolean" },
            "hasThrottle": { "type": "boolean" },
            "hasRudderPedals": { "type": "boolean" },
            "hasDancePads": { "type": "boolean" },
            "discreteElementLabels": {
              "type": "array",
              "items": { "type": "string" }
            }
          }
        },
        "inputBindings": {
          "type": "array",
          "items": {
            "type": "object",
            "required": ["source", "target", "deadzone", "curve", "isInverted", "sensitivity"],
            "properties": {
              "source": { "type": "string" },
              "target": { "type": "string" },
              "deadzone": { "type": "number", "minimum": 0.0, "maximum": 1.0 },
              "curve": { "type": "string", "enum": ["linear", "exponential", "logarithmic", "s_curve"] },
              "isInverted": { "type": "boolean" },
              "sensitivity": { "type": "number", "minimum": 0.1, "maximum": 10.0 }
            }
          }
        },
        "triggerConfigs": {
          "type": "array",
          "items": {
            "type": "object",
            "required": ["trigger", "mode", "startPosition", "endPosition", "resistiveStrength"],
            "properties": {
              "trigger": { "type": "string", "enum": ["left_trigger", "right_trigger"] },
              "mode": { "type": "string", "enum": ["guitar_string", "bow_drag", "mod_detents", "palm_mute", "off"] },
              "startPosition": { "type": "number", "minimum": 0.0, "maximum": 1.0 },
              "endPosition": { "type": "number", "minimum": 0.0, "maximum": 1.0 },
              "resistiveStrength": { "type": "number", "minimum": 0.0, "maximum": 1.0 },
              "detentStepCount": { "type": "integer", "minimum": 0 },
              "stringGaugePreset": { "type": ["string", "null"] }
            }
          }
        },
        "visualSkin": {
          "type": "object",
          "required": ["skinName", "baseColorHex", "accentColorHex", "ledGlowHex", "meshAnchors"],
          "properties": {
            "skinName": { "type": "string" },
            "modelAssetURI": { "type": ["string", "null"] },
            "baseColorHex": { "type": "string", "pattern": "^#[0-9A-Fa-f]{6}$" },
            "accentColorHex": { "type": "string", "pattern": "^#[0-9A-Fa-f]{6}$" },
            "ledGlowHex": { "type": "string", "pattern": "^#[0-9A-Fa-f]{6}$" },
            "meshAnchors": {
              "type": "array",
              "items": {
                "type": "object",
                "required": ["id", "elementName", "meshNodeID", "positionOffset", "rotationOffset", "highlightColorHex"],
                "properties": {
                  "id": { "type": "string" },
                  "elementName": { "type": "string" },
                  "meshNodeID": { "type": "string" },
                  "positionOffset": { "type": "array", "items": { "type": "number" }, "minItems": 3, "maxItems": 3 },
                  "rotationOffset": { "type": "array", "items": { "type": "number" }, "minItems": 3, "maxItems": 3 },
                  "highlightColorHex": { "type": "string", "pattern": "^#[0-9A-Fa-f]{6}$" }
                }
              }
            }
          }
        },
        "hapticProfile": {
          "type": "object",
          "required": ["defaultIntensity", "defaultSharpness", "bendDetentFeedback", "pickAttackFeedback", "slideArrivalFeedback"],
          "properties": {
            "defaultIntensity": { "type": "number", "minimum": 0.0, "maximum": 1.0 },
            "defaultSharpness": { "type": "number", "minimum": 0.0, "maximum": 1.0 },
            "bendDetentFeedback": { "type": "boolean" },
            "pickAttackFeedback": { "type": "boolean" },
            "slideArrivalFeedback": { "type": "boolean" }
          }
        }
      }
    }
    """

    // MARK: - Validation & Serialization

    public func encodeToJSON(_ profile: OCDSProfile) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(profile)
        guard let json = String(data: data, encoding: .utf8) else {
            throw OCDSValidationError.invalidEncoding
        }
        return json
    }

    public func decodeFromJSON(_ jsonString: String) throws -> OCDSProfile {
        guard let data = jsonString.data(using: .utf8) else {
            throw OCDSValidationError.invalidEncoding
        }
        let decoder = JSONDecoder()
        let profile = try decoder.decode(OCDSProfile.self, from: data)
        try validate(profile)
        return profile
    }

    public func validate(_ profile: OCDSProfile) throws {
        guard profile.schemaVersion.starts(with: "1.") else {
            throw OCDSValidationError.unsupportedSchemaVersion(profile.schemaVersion)
        }
        guard !profile.metadata.id.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw OCDSValidationError.missingRequiredField("metadata.id")
        }
        guard !profile.metadata.name.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw OCDSValidationError.missingRequiredField("metadata.name")
        }
        for binding in profile.inputBindings {
            guard binding.deadzone >= 0.0 && binding.deadzone <= 1.0 else {
                throw OCDSValidationError.outOfRange("deadzone for \(binding.source.rawValue)")
            }
            guard binding.sensitivity > 0.0 else {
                throw OCDSValidationError.outOfRange("sensitivity for \(binding.source.rawValue)")
            }
        }
        for trigger in profile.triggerConfigs {
            guard trigger.startPosition >= 0 && trigger.startPosition <= 1.0 else {
                throw OCDSValidationError.outOfRange("trigger startPosition")
            }
            guard trigger.endPosition >= 0 && trigger.endPosition <= 1.0 else {
                throw OCDSValidationError.outOfRange("trigger endPosition")
            }
            guard trigger.resistiveStrength >= 0 && trigger.resistiveStrength <= 1.0 else {
                throw OCDSValidationError.outOfRange("trigger resistiveStrength")
            }
        }
    }

    // MARK: - Profile Management

    public func registerCustomProfile(_ profile: OCDSProfile) throws {
        try validate(profile)
        customProfiles[profile.id] = profile
    }

    public func profile(for id: String) -> OCDSProfile? {
        customProfiles[id] ?? bundledProfiles[id]
    }

    public var allProfiles: [OCDSProfile] {
        Array(bundledProfiles.values) + Array(customProfiles.values)
    }

    // MARK: - Bundled Profiles

    private func loadBundledProfiles() {
        bundledProfiles = [
            "sony_dualsense_mpe": makeDualSenseProfile(),
            "xbox_wireless_expressive": makeXboxProfile(),
            "switch_pro_gyro": makeSwitchProProfile(),
            "steam_deck_mpe": makeSteamDeckProfile(),
            "guitar_hero_fretboard": makeGuitarHeroProfile(),
            "sound_voltex_console": makeSDVXProfile(),
            "beatmania_djdao": makeBeatmaniaProfile(),
            "popn_music_arcade": makePopnProfile(),
            "taiko_tatacon": makeTaikoProfile(),
            "dance_mat_ddr": makeDanceMatProfile(),
            "flight_stick_hotas": makeFlightStickProfile(),
            "racing_wheel_pedals": makeRacingWheelProfile(),
            "arcade_fight_stick": makeFightStickProfile()
        ]
    }

    private func makeDualSenseProfile() -> OCDSProfile {
        OCDSProfile(
            metadata: OCDSMetadata(
                id: "sony_dualsense_mpe",
                name: "Sony DualSense (PS5) MPE Expressive",
                author: "XPI Core Team",
                description: "Full MPE control with adaptive trigger string tension and voice-led soloing on right stick.",
                version: "1.0.0",
                category: "Standard Gamepad",
                targetVendor: "Sony Interactive Entertainment",
                targetProductID: "Wireless Controller (DualSense)",
                tags: ["DualSense", "AdaptiveTriggers", "Haptics", "IMU", "MPE"]
            ),
            hardwareSpec: OCDSHardwareSpec(
                stickCount: 2,
                triggerCount: 2,
                buttonCount: 16,
                hasMotionIMU: true,
                hasTouchpad: true,
                hasHaptics: true,
                hasAdaptiveTriggers: true,
                discreteElementLabels: ["Cross", "Circle", "Square", "Triangle", "L1", "R1", "L2", "R2", "Touchpad"]
            ),
            inputBindings: [
                OCDSInputBinding(source: .leftStick, target: .harmonicLayerSelect, deadzone: 0.12),
                OCDSInputBinding(source: .rightStick, target: .soloLead, deadzone: 0.10, curve: "exponential"),
                OCDSInputBinding(source: .leftTrigger, target: .palmMute, deadzone: 0.05),
                OCDSInputBinding(source: .rightTrigger, target: .pressure, deadzone: 0.05),
                OCDSInputBinding(source: .buttonA, target: .chordTone1),
                OCDSInputBinding(source: .buttonX, target: .chordTone3),
                OCDSInputBinding(source: .buttonY, target: .chordTone5),
                OCDSInputBinding(source: .buttonB, target: .chordTone7),
                OCDSInputBinding(source: .gyroPitch, target: .vibrato, deadzone: 0.08)
            ],
            triggerConfigs: [
                OCDSAdaptiveTriggerSpec(trigger: .leftTrigger, mode: "palm_mute", startPosition: 0.4, endPosition: 1.0, resistiveStrength: 0.8),
                OCDSAdaptiveTriggerSpec(trigger: .rightTrigger, mode: "guitar_string", startPosition: 0.0, endPosition: 1.0, resistiveStrength: 0.7, stringGaugePreset: "regular")
            ],
            visualSkin: OCDSVisualSkin(
                skinName: "DualSense Obsidian Emerald",
                baseColorHex: "#0D1117",
                accentColorHex: "#00E676",
                ledGlowHex: "#00FF88",
                meshAnchors: [
                    OCDSMeshAnchor(id: "anchor_lstick", elementName: "Left Stick", meshNodeID: "node_lstick_cap", positionOffset: [-35, 12, 10]),
                    OCDSMeshAnchor(id: "anchor_rstick", elementName: "Right Stick", meshNodeID: "node_rstick_cap", positionOffset: [35, 12, 10]),
                    OCDSMeshAnchor(id: "anchor_touchpad", elementName: "Touchpad", meshNodeID: "node_touchpad_surface", positionOffset: [0, 30, 15])
                ]
            ),
            hapticProfile: OCDSHapticSpec(defaultIntensity: 0.65, defaultSharpness: 0.7, bendDetentFeedback: true, pickAttackFeedback: true, slideArrivalFeedback: true)
        )
    }

    private func makeXboxProfile() -> OCDSProfile {
        OCDSProfile(
            metadata: OCDSMetadata(
                id: "xbox_wireless_expressive",
                name: "Xbox Wireless Controller",
                author: "XPI Core Team",
                description: "Standard Xbox gamepad mapping with impulse trigger expression and chord wheel navigation.",
                category: "Standard Gamepad",
                tags: ["Xbox", "ImpulseTriggers"]
            ),
            hardwareSpec: OCDSHardwareSpec(
                stickCount: 2, triggerCount: 2, buttonCount: 14,
                hasMotionIMU: false, hasTouchpad: false, hasHaptics: true, hasAdaptiveTriggers: false,
                discreteElementLabels: ["A", "B", "X", "Y", "LB", "RB", "LT", "RT"]
            ),
            inputBindings: [
                OCDSInputBinding(source: .leftStick, target: .harmonicLayerSelect),
                OCDSInputBinding(source: .rightStick, target: .soloLead),
                OCDSInputBinding(source: .leftTrigger, target: .palmMute),
                OCDSInputBinding(source: .rightTrigger, target: .pressure),
                OCDSInputBinding(source: .buttonA, target: .chordTone1),
                OCDSInputBinding(source: .buttonX, target: .chordTone3),
                OCDSInputBinding(source: .buttonY, target: .chordTone5),
                OCDSInputBinding(source: .buttonB, target: .chordTone7)
            ]
        )
    }

    private func makeSwitchProProfile() -> OCDSProfile {
        OCDSProfile(
            metadata: OCDSMetadata(
                id: "switch_pro_gyro",
                name: "Nintendo Switch Pro Controller",
                author: "XPI Core Team",
                description: "Switch Pro Controller with HD Rumble and gyro-assisted vibrato.",
                category: "Standard Gamepad",
                tags: ["Switch", "Gyro", "HDRumble"]
            ),
            hardwareSpec: OCDSHardwareSpec(
                stickCount: 2, triggerCount: 2, buttonCount: 14,
                hasMotionIMU: true, hasTouchpad: false, hasHaptics: true, hasAdaptiveTriggers: false,
                discreteElementLabels: ["B", "A", "Y", "X", "L", "R", "ZL", "ZR"]
            ),
            inputBindings: [
                OCDSInputBinding(source: .leftStick, target: .harmonicLayerSelect),
                OCDSInputBinding(source: .rightStick, target: .soloLead),
                OCDSInputBinding(source: .gyroPitch, target: .vibrato),
                OCDSInputBinding(source: .buttonB, target: .chordTone1),
                OCDSInputBinding(source: .buttonY, target: .chordTone3),
                OCDSInputBinding(source: .buttonX, target: .chordTone5),
                OCDSInputBinding(source: .buttonA, target: .chordTone7)
            ]
        )
    }

    private func makeSteamDeckProfile() -> OCDSProfile {
        OCDSProfile(
            metadata: OCDSMetadata(id: "steam_deck_mpe", name: "Steam Deck / Steam Controller", category: "Standard Gamepad"),
            hardwareSpec: OCDSHardwareSpec(stickCount: 2, triggerCount: 2, buttonCount: 18, hasMotionIMU: true, hasTouchpad: true, hasHaptics: true)
        )
    }

    private func makeGuitarHeroProfile() -> OCDSProfile {
        OCDSProfile(
            metadata: OCDSMetadata(id: "guitar_hero_fretboard", name: "Guitar Hero Fretboard", category: "Rhythm Game Controllers"),
            hardwareSpec: OCDSHardwareSpec(stickCount: 1, triggerCount: 1, buttonCount: 8, hasFrets: true, discreteElementLabels: ["Green", "Red", "Yellow", "Blue", "Orange", "Strum Up", "Strum Down", "Whammy"]),
            inputBindings: [
                OCDSInputBinding(source: .fret1, target: .chordTone1),
                OCDSInputBinding(source: .fret2, target: .chordTone3),
                OCDSInputBinding(source: .fret3, target: .chordTone5),
                OCDSInputBinding(source: .fret4, target: .chordTone7),
                OCDSInputBinding(source: .strumUp, target: .strumming),
                OCDSInputBinding(source: .strumDown, target: .strumming),
                OCDSInputBinding(source: .whammy, target: .pitchBend)
            ]
        )
    }

    private func makeSDVXProfile() -> OCDSProfile {
        OCDSProfile(
            metadata: OCDSMetadata(id: "sound_voltex_console", name: "Sound Voltex (SDVX) Controller", category: "Rhythm Game Controllers"),
            hardwareSpec: OCDSHardwareSpec(stickCount: 0, triggerCount: 0, buttonCount: 6, hasRotaryEncoders: true, discreteElementLabels: ["VOL-L", "VOL-R", "BT-A", "BT-B", "BT-C", "BT-D", "FX-L", "FX-R"])
        )
    }

    private func makeBeatmaniaProfile() -> OCDSProfile {
        OCDSProfile(
            metadata: OCDSMetadata(id: "beatmania_djdao", name: "Beatmania IIDX Controller", category: "Rhythm Game Controllers"),
            hardwareSpec: OCDSHardwareSpec(stickCount: 0, triggerCount: 0, buttonCount: 7, hasTurntable: true, discreteElementLabels: ["Turntable Scratch", "Key 1", "Key 2", "Key 3", "Key 4", "Key 5", "Key 6", "Key 7"])
        )
    }

    private func makePopnProfile() -> OCDSProfile {
        OCDSProfile(
            metadata: OCDSMetadata(id: "popn_music_arcade", name: "Pop'n Music 9-Button Arcade", category: "Rhythm Game Controllers"),
            hardwareSpec: OCDSHardwareSpec(stickCount: 0, triggerCount: 0, buttonCount: 9, discreteElementLabels: ["W1", "Y1", "G1", "B1", "Red", "B2", "G2", "Y2", "W2"])
        )
    }

    private func makeTaikoProfile() -> OCDSProfile {
        OCDSProfile(
            metadata: OCDSMetadata(id: "taiko_tatacon", name: "Taiko no Tatsujin Drum", category: "Rhythm Game Controllers"),
            hardwareSpec: OCDSHardwareSpec(stickCount: 0, triggerCount: 0, buttonCount: 4, discreteElementLabels: ["Don Left", "Don Right", "Ka Left", "Ka Right"])
        )
    }

    private func makeDanceMatProfile() -> OCDSProfile {
        OCDSProfile(
            metadata: OCDSMetadata(id: "dance_mat_ddr", name: "Dance Mat / DDR Stage Pad", category: "Rhythm Game Controllers"),
            hardwareSpec: OCDSHardwareSpec(stickCount: 0, triggerCount: 0, buttonCount: 4, hasDancePads: true, discreteElementLabels: ["Left", "Down", "Up", "Right"])
        )
    }

    private func makeFlightStickProfile() -> OCDSProfile {
        OCDSProfile(
            metadata: OCDSMetadata(id: "flight_stick_hotas", name: "Flight Sim HOTAS & Flight Stick", category: "Flight & Racing & Arcade"),
            hardwareSpec: OCDSHardwareSpec(stickCount: 1, triggerCount: 2, buttonCount: 12, hasThrottle: true, hasRudderPedals: true)
        )
    }

    private func makeRacingWheelProfile() -> OCDSProfile {
        OCDSProfile(
            metadata: OCDSMetadata(id: "racing_wheel_pedals", name: "Racing Wheel & Pedals", category: "Flight & Racing & Arcade"),
            hardwareSpec: OCDSHardwareSpec(stickCount: 0, triggerCount: 3, buttonCount: 10, hasRudderPedals: true)
        )
    }

    private func makeFightStickProfile() -> OCDSProfile {
        OCDSProfile(
            metadata: OCDSMetadata(id: "arcade_fight_stick", name: "Arcade Fight Stick / Leverless", category: "Flight & Racing & Arcade"),
            hardwareSpec: OCDSHardwareSpec(stickCount: 1, triggerCount: 0, buttonCount: 8)
        )
    }
}

public enum OCDSValidationError: LocalizedError, Sendable {
    case invalidEncoding
    case unsupportedSchemaVersion(String)
    case missingRequiredField(String)
    case outOfRange(String)

    public var errorDescription: String? {
        switch self {
        case .invalidEncoding: return "Invalid UTF-8 encoding in OCDS profile."
        case .unsupportedSchemaVersion(let ver): return "Unsupported OCDS schema version: \(ver). Required: 1.x.x"
        case .missingRequiredField(let field): return "Missing required field: \(field)"
        case .outOfRange(let field): return "Value out of range for: \(field)"
        }
    }
}
