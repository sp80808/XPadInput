import Foundation
import GameController
import XPadCore
import XPadTheory

// MARK: - Jam Track Roles & Player Slots

public enum PlayerSlotId: String, Codable, Sendable, CaseIterable, Identifiable {
    case p1 = "Player 1"
    case p2 = "Player 2"
    case p3 = "Player 3"
    case p4 = "Player 4"

    public var id: String { rawValue }

    public var defaultRole: JamTrackRole {
        switch self {
        case .p1: return .chords
        case .p2: return .bass
        case .p3: return .lead
        case .p4: return .drums
        }
    }

    public var defaultColorHex: String {
        switch self {
        case .p1: return "#00E676" // Emerald Green (Chords)
        case .p2: return "#2979FF" // Electric Blue (Bass)
        case .p3: return "#FF9100" // Amber Gold (Lead)
        case .p4: return "#FF1744" // Crimson Red (Drums)
        }
    }
}

public enum JamTrackRole: String, Codable, Sendable, CaseIterable, Identifiable {
    case chords = "Chords & Harmony"
    case bass = "Bass & Grooves"
    case lead = "Voice-Led Solo & Melody"
    case drums = "Drums & Rhythm Compass"

    public var id: String { rawValue }

    public var defaultMidiChannel: UInt8 {
        switch self {
        case .chords: return 0 // Channel 1
        case .bass: return 1   // Channel 2
        case .lead: return 2   // Channel 3
        case .drums: return 9  // Channel 10
        }
    }
}

public struct PlayerAssignment: Sendable, Identifiable, Equatable {
    public var slot: PlayerSlotId
    public var controllerName: String
    public var controllerKind: ControllerKind
    public var role: JamTrackRole
    public var isConnected: Bool
    public var batteryLevel: Float
    public var activeNotes: [Note]
    public var midiChannel: UInt8

    public var id: String { slot.rawValue }

    public init(
        slot: PlayerSlotId,
        controllerName: String = "Simulated Controller",
        controllerKind: ControllerKind = .simulated,
        role: JamTrackRole? = nil,
        isConnected: Bool = false,
        batteryLevel: Float = 1.0,
        activeNotes: [Note] = [],
        midiChannel: UInt8? = nil
    ) {
        self.slot = slot
        self.controllerName = controllerName
        self.controllerKind = controllerKind
        self.role = role ?? slot.defaultRole
        self.isConnected = isConnected
        self.batteryLevel = batteryLevel
        self.activeNotes = activeNotes
        self.midiChannel = midiChannel ?? self.role.defaultMidiChannel
    }
}

public struct JamSessionClock: Sendable, Equatable {
    public var bpm: Double
    public var currentTick: UInt64
    public var currentBeat: Int
    public var currentBar: Int
    public var timeSignature: (numerator: Int, denominator: Int)

    public init(
        bpm: Double = 120.0,
        currentTick: UInt64 = 0,
        currentBeat: Int = 1,
        currentBar: Int = 1,
        timeSignature: (numerator: Int, denominator: Int) = (4, 4)
    ) {
        self.bpm = bpm
        self.currentTick = currentTick
        self.currentBeat = currentBeat
        self.currentBar = currentBar
        self.timeSignature = timeSignature
    }

    public static func == (lhs: JamSessionClock, rhs: JamSessionClock) -> Bool {
        lhs.bpm == rhs.bpm &&
        lhs.currentTick == rhs.currentTick &&
        lhs.currentBeat == rhs.currentBeat &&
        lhs.currentBar == rhs.currentBar &&
        lhs.timeSignature.numerator == rhs.timeSignature.numerator &&
        lhs.timeSignature.denominator == rhs.timeSignature.denominator
    }
}

// MARK: - Multi-Controller Jamming Manager

@Observable
public final class MultiControllerJammingManager: @unchecked Sendable {
    public var players: [PlayerSlotId: PlayerAssignment] = [:]
    public var playerStates: [PlayerSlotId: ControllerState] = [:]
    public var sessionClock = JamSessionClock()
    public var currentKey: PitchClass = .d
    public var currentScale: Scale = .naturalMinor
    public var activeChord: Chord = Chord(root: .d, quality: .minor)

    public var onPlayerNoteTriggered: ((PlayerSlotId, Note, UInt8, Bool) -> Void)?
    public var onPlayerStateChanged: ((PlayerSlotId, ControllerState) -> Void)?

    private var physicalControllers: [PlayerSlotId: GCController] = [:]

    public var isSessionActive: Bool {
        physicalControllers.count > 1
    }

    public init() {
        // Initialize 4 default player slots
        for slot in PlayerSlotId.allCases {
            players[slot] = PlayerAssignment(slot: slot)
            playerStates[slot] = ControllerState()
        }
        scanAndAssignControllers()
    }

    public func scanAndAssignControllers() {
        let connected = GCController.controllers()
        for (index, controller) in connected.prefix(4).enumerated() {
            let slot = PlayerSlotId.allCases[index]
            assignPhysicalController(controller, to: slot)
        }
    }

    public func assignPhysicalController(_ controller: GCController, to slot: PlayerSlotId) {
        physicalControllers[slot] = controller
        let kind = identifyControllerKind(controller)
        let name = controller.vendorName ?? controller.productCategory

        players[slot] = PlayerAssignment(
            slot: slot,
            controllerName: name,
            controllerKind: kind,
            role: players[slot]?.role ?? slot.defaultRole,
            isConnected: true,
            batteryLevel: controller.battery?.batteryLevel ?? 1.0,
            midiChannel: players[slot]?.midiChannel ?? slot.defaultRole.defaultMidiChannel
        )

        setupInputHandlers(for: controller, slot: slot)
    }

    public func disconnectSlot(_ slot: PlayerSlotId) {
        physicalControllers.removeValue(forKey: slot)
        players[slot] = PlayerAssignment(slot: slot, isConnected: false)
        playerStates[slot] = ControllerState()
    }

    public func setRole(_ role: JamTrackRole, for slot: PlayerSlotId) {
        guard var assignment = players[slot] else { return }
        assignment.role = role
        assignment.midiChannel = role.defaultMidiChannel
        players[slot] = assignment
    }

    /// Allows simulated state injection per player slot for tests, previews, and keyboard controls.
    public func injectPlayerState(slot: PlayerSlotId, transform: (inout ControllerState) -> Void) {
        var state = playerStates[slot] ?? ControllerState()
        transform(&state)
        playerStates[slot] = state
        onPlayerStateChanged?(slot, state)
    }

    /// Synchronizes harmonic state across all jam participants.
    public func updateSharedHarmony(key: PitchClass, scale: Scale, chord: Chord) {
        self.currentKey = key
        self.currentScale = scale
        self.activeChord = chord
    }

    private func setupInputHandlers(for controller: GCController, slot: PlayerSlotId) {
        guard let gamepad = controller.extendedGamepad else { return }

        gamepad.valueChangedHandler = { [weak self] (_, _) in
            guard let self = self else { return }
            let state = self.playerStates[slot] ?? ControllerState()

            state.leftStick = ProcessedStickState(
                rawX: gamepad.leftThumbstick.xAxis.value,
                rawY: gamepad.leftThumbstick.yAxis.value,
                x: gamepad.leftThumbstick.xAxis.value,
                y: gamepad.leftThumbstick.yAxis.value
            )
            state.rightStick = ProcessedStickState(
                rawX: gamepad.rightThumbstick.xAxis.value,
                rawY: gamepad.rightThumbstick.yAxis.value,
                x: gamepad.rightThumbstick.xAxis.value,
                y: gamepad.rightThumbstick.yAxis.value
            )
            state.leftTrigger = ProcessedTriggerState(
                rawValue: gamepad.leftTrigger.value,
                value: gamepad.leftTrigger.value,
                isPressed: gamepad.leftTrigger.value > 0.1
            )
            state.rightTrigger = ProcessedTriggerState(
                rawValue: gamepad.rightTrigger.value,
                value: gamepad.rightTrigger.value,
                isPressed: gamepad.rightTrigger.value > 0.1
            )
            state.buttonA = gamepad.buttonA.isPressed
            state.buttonB = gamepad.buttonB.isPressed
            state.buttonX = gamepad.buttonX.isPressed
            state.buttonY = gamepad.buttonY.isPressed
            state.leftShoulder = gamepad.leftShoulder.isPressed
            state.rightShoulder = gamepad.rightShoulder.isPressed

            self.playerStates[slot] = state
            self.onPlayerStateChanged?(slot, state)
        }
    }

    private func identifyControllerKind(_ controller: GCController) -> ControllerKind {
        let identity = "\(controller.vendorName ?? "") \(controller.productCategory)".lowercased()
        if identity.contains("dualsense") || identity.contains("ps5") { return .dualSense }
        if identity.contains("dualshock") || identity.contains("ps4") { return .dualShock4 }
        if identity.contains("xbox") { return .xbox }
        if identity.contains("switch") || identity.contains("pro controller") { return .switchPro }
        if identity.contains("steam") { return .steamDeck }
        return .generic
    }
}
