import Testing
import Foundation
@testable import XPadCore
@testable import XPadTheory
@testable import XPadController

@Suite("Exhaustive Gamepad & Controller Engine Tests")
struct ControllerTests {

    // MARK: - StickCoordinates Tests
    @Test("StickCoordinates Deadzones, Radius Clamping & Polar Angles")
    func testStickCoordinates() {
        // Within deadzone (0.05 < 0.12)
        let deadStick = StickCoordinates(x: 0.05, y: 0.05, deadzone: 0.12)
        #expect(deadStick.radius == 0.0)
        #expect(!deadStick.isActive)

        // Full deflection East (x=1.0, y=0.0)
        let eastStick = StickCoordinates(x: 1.0, y: 0.0, deadzone: 0.12)
        #expect(eastStick.radius == 1.0)
        #expect(eastStick.isActive)
        #expect(abs(eastStick.angle - 0.0) < 0.001)

        // Full deflection North (x=0.0, y=1.0)
        let northStick = StickCoordinates(x: 0.0, y: 1.0, deadzone: 0.12)
        #expect(northStick.radius == 1.0)
        #expect(abs(northStick.angle - Double.pi / 2.0) < 0.001)

        // Full deflection South (x=0.0, y=-1.0)
        let southStick = StickCoordinates(x: 0.0, y: -1.0, deadzone: 0.12)
        #expect(southStick.radius == 1.0)
        #expect(abs(southStick.angle - (-Double.pi / 2.0)) < 0.001)

        // Diagonal partial deflection
        let diagStick = StickCoordinates(x: 0.5, y: 0.5, deadzone: 0.10)
        #expect(diagStick.radius > 0.5)
        #expect(diagStick.isActive)
    }

    // MARK: - GamepadState Tests
    @Test("GamepadState Default State & Properties")
    func testGamepadStateDefault() {
        let state = GamepadState()
        #expect(!state.leftStick.isActive)
        #expect(!state.rightStick.isActive)
        #expect(state.leftTrigger == 0.0)
        #expect(state.rightTrigger == 0.0)
        #expect(!state.leftShoulder)
        #expect(!state.rightShoulder)
        #expect(!state.buttonA)
        #expect(!state.buttonB)
        #expect(!state.buttonX)
        #expect(!state.buttonY)
        #expect(!state.dpadUp)
        #expect(!state.isTouching)
        #expect(state.gyroPitch == 0.0)
    }

    // MARK: - Controller Capability Profile Tests
    @Test("Controller Capability Profiles Verification")
    func testControllerCapabilityProfiles() {
        let ps5 = ControllerCapabilityProfile.dualSense
        #expect(ps5.hasTouchpad)
        #expect(ps5.hasMotionIMU)
        #expect(ps5.hasHaptics)
        #expect(ps5.hasAnalogTriggers)
        #expect(ps5.buttonLabels.contains("Cross (✕)"))

        let xbox = ControllerCapabilityProfile.xbox
        #expect(!xbox.hasTouchpad)
        #expect(!xbox.hasMotionIMU)
        #expect(xbox.hasHaptics)
        #expect(xbox.buttonLabels.contains("A"))

        let sw = ControllerCapabilityProfile.switchPro
        #expect(sw.hasMotionIMU)
        #expect(!sw.hasAnalogTriggers) // Digital triggers on Switch
    }

    // MARK: - Virtual Strummer Tests
    @Test("Virtual Strummer Down-Strum, Up-Strum, Velocity and Muting")
    func testVirtualStrummerDetailed() {
        let strummer = VirtualStrummer()
        let notes = Chord(root: .c, quality: .major).voicedNotes()

        // 1. Initial position setup
        _ = strummer.processStick(x: 0.0, y: 0.8, triggerMute: 0.0, chordNotes: notes, timestamp: 1.0)

        // 2. Fast Down-Strum (y moves from +0.8 to -0.8 in 50ms)
        let downResult = strummer.processStick(x: 0.0, y: -0.8, triggerMute: 0.0, chordNotes: notes, timestamp: 1.05)
        #expect(downResult != nil)
        #expect(downResult?.direction == .down)
        #expect(downResult?.notes.count == notes.count)
        #expect((downResult?.velocity ?? 0) >= 40)
        #expect((downResult?.notes[0].delayMs ?? 0) == 0.0)
        #expect((downResult?.notes[1].delayMs ?? 0) > 0.0)

        // 3. Fast Up-Strum (y moves from -0.8 to +0.8 in 50ms)
        let upResult = strummer.processStick(x: 0.0, y: 0.8, triggerMute: 0.0, chordNotes: notes, timestamp: 1.10)
        #expect(upResult != nil)
        #expect(upResult?.direction == .up)
        #expect(upResult?.notes.first?.note == notes.last) // Reverse order on up-strum

        // 4. Palm Muted Strum (triggerMute > 0.3)
        let muteResult = strummer.processStick(x: 0.0, y: -0.8, triggerMute: 0.8, chordNotes: notes, timestamp: 1.15)
        #expect(muteResult != nil)
        #expect(muteResult?.direction == .muted)
        #expect((muteResult?.velocity ?? 0) <= 100)

        // 5. Small jitter below threshold should not trigger strum
        let jitterResult = strummer.processStick(x: 0.0, y: -0.81, triggerMute: 0.0, chordNotes: notes, timestamp: 1.20)
        #expect(jitterResult == nil)
    }

    // MARK: - Rhythm Compass Engine Tests
    @Test("Rhythm Compass Subdivisions and Polar Direction Mapping")
    func testRhythmCompassAllSectors() {
        let engine = RhythmCompassEngine()

        // Inactive stick
        let inactive = StickCoordinates(x: 0.0, y: 0.0, deadzone: 0.1)
        let (subInactive, _, isPlayingInactive) = engine.evaluate(stick: inactive)
        #expect(!isPlayingInactive)
        #expect(subInactive == .sixteenth)

        // Test ticksPerStep
        #expect(RhythmicSubdivision.quarter.ticksPerStep == 960)
        #expect(RhythmicSubdivision.eighth.ticksPerStep == 480)
        #expect(RhythmicSubdivision.sixteenth.ticksPerStep == 240)
        #expect(RhythmicSubdivision.thirtySecond.ticksPerStep == 120)

        // North deflection -> 1/4
        let north = StickCoordinates(x: 0.0, y: 1.0, deadzone: 0.1)
        let (subNorth, intensityNorth, isPlayingNorth) = engine.evaluate(stick: north)
        #expect(isPlayingNorth)
        #expect(subNorth == .quarter)
        #expect(intensityNorth == 1.0)

        // Sweep through all 8 sectors
        for i in 0..<8 {
            let angle = (Double(i) * Double.pi / 4.0) - (Double.pi / 2.0)
            let x = cos(angle)
            let y = sin(angle)
            let stick = StickCoordinates(x: x, y: y, deadzone: 0.1)
            let (_, intensity, isPlaying) = engine.evaluate(stick: stick)
            #expect(isPlaying)
            #expect(intensity > 0.9)
        }
    }

    // MARK: - Gesture Recorder Tests
    @Test("Gesture Recorder Start, Sample Capture and Clip Retrieval")
    func testGestureRecorderCapture() {
        let recorder = GestureRecorder()

        // Stop before start returns nil
        #expect(recorder.stopRecording() == nil)

        recorder.startRecording()

        var sampleState = GamepadState()
        sampleState.buttonA = true
        sampleState.leftTrigger = 0.75
        recorder.recordSample(state: sampleState)

        sampleState.buttonA = false
        sampleState.rightTrigger = 1.0
        recorder.recordSample(state: sampleState)

        let clip = recorder.stopRecording()
        #expect(clip != nil)
        #expect(clip?.samples.count == 2)
        #expect(clip?.samples[0].state.buttonA == true)
        #expect(clip?.samples[1].state.rightTrigger == 1.0)
    }

    // MARK: - Controller Manager Tests
    @Test("ControllerManager Simulated State Injection")
    @MainActor
    func testControllerManagerSimulatedState() {
        let manager = ControllerManager()
        #expect(manager.controllerKind == .simulated || manager.isHardwareConnected)

        var callbackTriggered = false
        manager.onStateChanged = { state in
            callbackTriggered = true
        }

        manager.injectSimulatedState { state in
            state.buttonA = true
            state.leftStick = StickCoordinates(x: 0.5, y: 0.5)
        }

        #expect(callbackTriggered)
        #expect(manager.currentState.buttonA)
        #expect(manager.currentState.leftStick.x == 0.5)
    }
}
