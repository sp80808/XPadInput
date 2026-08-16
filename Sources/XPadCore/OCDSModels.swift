import Foundation

/// Open Controller Definition Standard (OCDS) — Version 1.0.0
/// Universal open-source specification for gamepad mapping profiles,
/// tactile curves, haptic characteristics, and 3D visual skinning.

// MARK: - OCDS Profile

public struct OCDSProfile: Codable, Sendable, Identifiable, Equatable {
    public var schemaVersion: String
    public var metadata: OCDSMetadata
    public var hardwareSpec: OCDSHardwareSpec
    public var inputBindings: [OCDSInputBinding]
    public var triggerConfigs: [OCDSAdaptiveTriggerSpec]
    public var visualSkin: OCDSVisualSkin
    public var hapticProfile: OCDSHapticSpec

    public var id: String { metadata.id }

    public init(
        schemaVersion: String = "1.0.0",
        metadata: OCDSMetadata,
        hardwareSpec: OCDSHardwareSpec,
        inputBindings: [OCDSInputBinding] = [],
        triggerConfigs: [OCDSAdaptiveTriggerSpec] = [],
        visualSkin: OCDSVisualSkin = OCDSVisualSkin(),
        hapticProfile: OCDSHapticSpec = OCDSHapticSpec()
    ) {
        self.schemaVersion = schemaVersion
        self.metadata = metadata
        self.hardwareSpec = hardwareSpec
        self.inputBindings = inputBindings
        self.triggerConfigs = triggerConfigs
        self.visualSkin = visualSkin
        self.hapticProfile = hapticProfile
    }
}

// MARK: - Metadata

public struct OCDSMetadata: Codable, Sendable, Identifiable, Equatable {
    public var id: String
    public var name: String
    public var author: String
    public var description: String
    public var version: String
    public var category: String
    public var targetVendor: String?
    public var targetProductID: String?
    public var tags: [String]

    public init(
        id: String,
        name: String,
        author: String = "XPI Community",
        description: String = "",
        version: String = "1.0.0",
        category: String = "Standard Gamepad",
        targetVendor: String? = nil,
        targetProductID: String? = nil,
        tags: [String] = []
    ) {
        self.id = id
        self.name = name
        self.author = author
        self.description = description
        self.version = version
        self.category = category
        self.targetVendor = targetVendor
        self.targetProductID = targetProductID
        self.tags = tags
    }
}

// MARK: - Hardware Specification

public struct OCDSHardwareSpec: Codable, Sendable, Equatable {
    public var stickCount: Int
    public var triggerCount: Int
    public var buttonCount: Int
    public var hasMotionIMU: Bool
    public var hasTouchpad: Bool
    public var hasHaptics: Bool
    public var hasAdaptiveTriggers: Bool
    public var hasRotaryEncoders: Bool
    public var hasTurntable: Bool
    public var hasFrets: Bool
    public var hasThrottle: Bool
    public var hasRudderPedals: Bool
    public var hasDancePads: Bool
    public var discreteElementLabels: [String]

    public init(
        stickCount: Int = 2,
        triggerCount: Int = 2,
        buttonCount: Int = 12,
        hasMotionIMU: Bool = false,
        hasTouchpad: Bool = false,
        hasHaptics: Bool = false,
        hasAdaptiveTriggers: Bool = false,
        hasRotaryEncoders: Bool = false,
        hasTurntable: Bool = false,
        hasFrets: Bool = false,
        hasThrottle: Bool = false,
        hasRudderPedals: Bool = false,
        hasDancePads: Bool = false,
        discreteElementLabels: [String] = []
    ) {
        self.stickCount = stickCount
        self.triggerCount = triggerCount
        self.buttonCount = buttonCount
        self.hasMotionIMU = hasMotionIMU
        self.hasTouchpad = hasTouchpad
        self.hasHaptics = hasHaptics
        self.hasAdaptiveTriggers = hasAdaptiveTriggers
        self.hasRotaryEncoders = hasRotaryEncoders
        self.hasTurntable = hasTurntable
        self.hasFrets = hasFrets
        self.hasThrottle = hasThrottle
        self.hasRudderPedals = hasRudderPedals
        self.hasDancePads = hasDancePads
        self.discreteElementLabels = discreteElementLabels
    }
}

// MARK: - Input Bindings

public enum OCDSSourceElement: String, Codable, Sendable, CaseIterable {
    case leftStick = "left_stick"
    case rightStick = "right_stick"
    case leftTrigger = "left_trigger"
    case rightTrigger = "right_trigger"
    case buttonA = "button_a"
    case buttonB = "button_b"
    case buttonX = "button_x"
    case buttonY = "button_y"
    case leftShoulder = "left_shoulder"
    case rightShoulder = "right_shoulder"
    case dpadUp = "dpad_up"
    case dpadDown = "dpad_down"
    case dpadLeft = "dpad_left"
    case dpadRight = "dpad_right"
    case leftStickClick = "left_stick_click"
    case rightStickClick = "right_stick_click"
    case touchpad = "touchpad"
    case gyroPitch = "gyro_pitch"
    case gyroRoll = "gyro_roll"
    case gyroYaw = "gyro_yaw"
    case encoderL = "encoder_left"
    case encoderR = "encoder_right"
    case turntable = "turntable"
    case whammy = "whammy"
    case fret1 = "fret_1"
    case fret2 = "fret_2"
    case fret3 = "fret_3"
    case fret4 = "fret_4"
    case fret5 = "fret_5"
    case strumUp = "strum_up"
    case strumDown = "strum_down"
}

public enum OCDSTargetFunction: String, Codable, Sendable, CaseIterable {
    case pitchBend = "pitch_bend"
    case timbre = "timbre"
    case pressure = "pressure"
    case modulation = "modulation"
    case palmMute = "palm_mute"
    case strumming = "strumming"
    case soloLead = "solo_lead"
    case chordTone1 = "chord_tone_root"
    case chordTone3 = "chord_tone_third"
    case chordTone5 = "chord_tone_fifth"
    case chordTone7 = "chord_tone_seventh"
    case harmonicLayerSelect = "harmonic_layer_select"
    case rhythmCompass = "rhythm_compass"
    case filterCutoff = "filter_cutoff"
    case resonance = "resonance"
    case vibrato = "vibrato"
    case slide = "slide"
    case ghostNote = "ghost_note"
}

public struct OCDSInputBinding: Codable, Sendable, Equatable, Identifiable {
    public var id: String { "\(source.rawValue)_\(target.rawValue)" }
    public var source: OCDSSourceElement
    public var target: OCDSTargetFunction
    public var deadzone: Double
    public var curve: String // "linear", "exponential", "logarithmic", "s_curve"
    public var isInverted: Bool
    public var sensitivity: Double

    public init(
        source: OCDSSourceElement,
        target: OCDSTargetFunction,
        deadzone: Double = 0.05,
        curve: String = "linear",
        isInverted: Bool = false,
        sensitivity: Double = 1.0
    ) {
        self.source = source
        self.target = target
        self.deadzone = deadzone
        self.curve = curve
        self.isInverted = isInverted
        self.sensitivity = sensitivity
    }
}

// MARK: - Adaptive Trigger Specification

public struct OCDSAdaptiveTriggerSpec: Codable, Sendable, Equatable, Identifiable {
    public var id: String { trigger.rawValue }
    public var trigger: OCDSSourceElement // leftTrigger or rightTrigger
    public var mode: String // "guitar_string", "bow_drag", "mod_detents", "palm_mute", "off"
    public var startPosition: Double // 0.0 ... 1.0
    public var endPosition: Double // 0.0 ... 1.0
    public var resistiveStrength: Double // 0.0 ... 1.0
    public var detentStepCount: Int // e.g. 12 for semitones
    public var stringGaugePreset: String? // "light", "regular", "heavy", "bass"

    public init(
        trigger: OCDSSourceElement,
        mode: String = "guitar_string",
        startPosition: Double = 0.0,
        endPosition: Double = 1.0,
        resistiveStrength: Double = 0.6,
        detentStepCount: Int = 0,
        stringGaugePreset: String? = "regular"
    ) {
        self.trigger = trigger
        self.mode = mode
        self.startPosition = startPosition
        self.endPosition = endPosition
        self.resistiveStrength = resistiveStrength
        self.detentStepCount = detentStepCount
        self.stringGaugePreset = stringGaugePreset
    }
}

// MARK: - 3D Visual Skinning & Mesh Anchors

public struct OCDSMeshAnchor: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var elementName: String
    public var meshNodeID: String
    public var positionOffset: [Double] // [x, y, z]
    public var rotationOffset: [Double] // [pitch, roll, yaw]
    public var highlightColorHex: String

    public init(
        id: String,
        elementName: String,
        meshNodeID: String,
        positionOffset: [Double] = [0, 0, 0],
        rotationOffset: [Double] = [0, 0, 0],
        highlightColorHex: String = "#00FF66"
    ) {
        self.id = id
        self.elementName = elementName
        self.meshNodeID = meshNodeID
        self.positionOffset = positionOffset
        self.rotationOffset = rotationOffset
        self.highlightColorHex = highlightColorHex
    }
}

public struct OCDSVisualSkin: Codable, Sendable, Equatable {
    public var skinName: String
    public var modelAssetURI: String?
    public var baseColorHex: String
    public var accentColorHex: String
    public var ledGlowHex: String
    public var meshAnchors: [OCDSMeshAnchor]

    public init(
        skinName: String = "Midnight Emerald",
        modelAssetURI: String? = nil,
        baseColorHex: String = "#0A0D0B",
        accentColorHex: String = "#00E676",
        ledGlowHex: String = "#00FF88",
        meshAnchors: [OCDSMeshAnchor] = []
    ) {
        self.skinName = skinName
        self.modelAssetURI = modelAssetURI
        self.baseColorHex = baseColorHex
        self.accentColorHex = accentColorHex
        self.ledGlowHex = ledGlowHex
        self.meshAnchors = meshAnchors
    }
}

// MARK: - Haptic Specification

public struct OCDSHapticSpec: Codable, Sendable, Equatable {
    public var defaultIntensity: Double
    public var defaultSharpness: Double
    public var bendDetentFeedback: Bool
    public var pickAttackFeedback: Bool
    public var slideArrivalFeedback: Bool

    public init(
        defaultIntensity: Double = 0.5,
        defaultSharpness: Double = 0.6,
        bendDetentFeedback: Bool = true,
        pickAttackFeedback: Bool = true,
        slideArrivalFeedback: Bool = true
    ) {
        self.defaultIntensity = defaultIntensity
        self.defaultSharpness = defaultSharpness
        self.bendDetentFeedback = bendDetentFeedback
        self.pickAttackFeedback = pickAttackFeedback
        self.slideArrivalFeedback = slideArrivalFeedback
    }
}
