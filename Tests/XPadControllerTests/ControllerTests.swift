import XCTest
@testable import XPadCore
@testable import XPadTheory
@testable import XPadController

final class ControllerTests: XCTestCase {

    // MARK: - StickCoordinates Tests
    func testStickCoordinates() {
        let deadStick = StickCoordinates(x: 0.05, y: 0.05, deadzone: 0.12)
        XCTAssertEqual(deadStick.radius, 0.0)
        XCTAssertFalse(deadStick.isActive)

        let eastStick = StickCoordinates(x: 1.0, y: 0.0, deadzone: 0.12)
        XCTAssertEqual(eastStick.radius, 1.0)
        XCTAssertTrue(eastStick.isActive)
        XCTAssertEqual(eastStick.angle, 0.0, accuracy: 0.001)

        let northStick = StickCoordinates(x: 0.0, y: 1.0, deadzone: 0.12)
        XCTAssertEqual(northStick.radius, 1.0)
        XCTAssertEqual(northStick.angle, Double.pi / 2.0, accuracy: 0.001)

        let southStick = StickCoordinates(x: 0.0, y: -1.0, deadzone: 0.12)
        XCTAssertEqual(southStick.radius, 1.0)
        XCTAssertEqual(southStick.angle, -Double.pi / 2.0, accuracy: 0.001)

        let diagStick = StickCoordinates(x: 0.5, y: 0.5, deadzone: 0.10)
        XCTAssertTrue(diagStick.radius > 0.5)
        XCTAssertTrue(diagStick.isActive)
    }

    // MARK: - GamepadState Tests
    func testGamepadStateDefault() {
        let state = GamepadState()
        XCTAssertFalse(state.leftStick.isActive)
        XCTAssertFalse(state.rightStick.isActive)
        XCTAssertEqual(state.leftTrigger, 0.0)
        XCTAssertEqual(state.rightTrigger, 0.0)
        XCTAssertFalse(state.leftShoulder)
        XCTAssertFalse(state.rightShoulder)
        XCTAssertFalse(state.buttonA)
        XCTAssertFalse(state.buttonB)
        XCTAssertFalse(state.buttonX)
        XCTAssertFalse(state.buttonY)
        XCTAssertFalse(state.dpadUp)
        XCTAssertFalse(state.isTouching)
        XCTAssertEqual(state.gyroPitch, 0.0)
    }

    // MARK: - Controller Capability Profile Tests
    func testControllerCapabilityProfiles() {
        let ps5 = ControllerCapabilityProfile.dualSense
        XCTAssertTrue(ps5.hasTouchpad)
        XCTAssertTrue(ps5.hasMotionIMU)
        XCTAssertTrue(ps5.hasHaptics)
        XCTAssertTrue(ps5.hasAnalogTriggers)
        XCTAssertTrue(ps5.buttonLabels.contains("Cross (✕)"))

        let xbox = ControllerCapabilityProfile.xbox
        XCTAssertFalse(xbox.hasTouchpad)
        XCTAssertFalse(xbox.hasMotionIMU)
        XCTAssertTrue(xbox.hasHaptics)
        XCTAssertTrue(xbox.buttonLabels.contains("A"))

        let sw = ControllerCapabilityProfile.switchPro
        XCTAssertTrue(sw.hasMotionIMU)
        XCTAssertFalse(sw.hasAnalogTriggers)
    }

    // MARK: - Virtual Strummer Tests
    func testVirtualStrummerDetailed() {
        let strummer = VirtualStrummer()
        let notes = Chord(root: .c, quality: .major).voicedNotes()

        _ = strummer.processStick(x: 0.0, y: 0.8, triggerMute: 0.0, chordNotes: notes, timestamp: 1.0)

        let downResult = strummer.processStick(x: 0.0, y: -0.8, triggerMute: 0.0, chordNotes: notes, timestamp: 1.05)
        XCTAssertNotNil(downResult)
        XCTAssertEqual(downResult?.direction, .down)
        XCTAssertEqual(downResult?.notes.count, notes.count)
        XCTAssertTrue((downResult?.velocity ?? 0) >= 40)
        XCTAssertEqual(downResult?.notes[0].delayMs ?? 0, 0.0)
        XCTAssertTrue((downResult?.notes[1].delayMs ?? 0) > 0.0)

        let upResult = strummer.processStick(x: 0.0, y: 0.8, triggerMute: 0.0, chordNotes: notes, timestamp: 1.10)
        XCTAssertNotNil(upResult)
        XCTAssertEqual(upResult?.direction, .up)
        XCTAssertEqual(upResult?.notes.first?.note, notes.last)

        let muteResult = strummer.processStick(x: 0.0, y: -0.8, triggerMute: 0.8, chordNotes: notes, timestamp: 1.15)
        XCTAssertNotNil(muteResult)
        XCTAssertEqual(muteResult?.direction, .muted)
        XCTAssertTrue((muteResult?.velocity ?? 0) <= 100)

        let jitterResult = strummer.processStick(x: 0.0, y: -0.81, triggerMute: 0.0, chordNotes: notes, timestamp: 1.20)
        XCTAssertNil(jitterResult)
    }

    // MARK: - Rhythm Compass Engine Tests
    func testRhythmCompassAllSectors() {
        let engine = RhythmCompassEngine()

        let inactive = StickCoordinates(x: 0.0, y: 0.0, deadzone: 0.1)
        let (subInactive, _, isPlayingInactive) = engine.evaluate(stick: inactive)
        XCTAssertFalse(isPlayingInactive)
        XCTAssertEqual(subInactive, .sixteenth)

        XCTAssertEqual(RhythmicSubdivision.quarter.ticksPerStep, 960)
        XCTAssertEqual(RhythmicSubdivision.eighth.ticksPerStep, 480)
        XCTAssertEqual(RhythmicSubdivision.sixteenth.ticksPerStep, 240)
        XCTAssertEqual(RhythmicSubdivision.thirtySecond.ticksPerStep, 120)

        let north = StickCoordinates(x: 0.0, y: 1.0, deadzone: 0.1)
        let (subNorth, intensityNorth, isPlayingNorth) = engine.evaluate(stick: north)
        XCTAssertTrue(isPlayingNorth)
        XCTAssertEqual(subNorth, .quarter)
        XCTAssertEqual(intensityNorth, 1.0)

        for i in 0..<8 {
            let angle = (Double(i) * Double.pi / 4.0) - (Double.pi / 2.0)
            let x = cos(angle)
            let y = sin(angle)
            let stick = StickCoordinates(x: x, y: y, deadzone: 0.1)
            let (_, intensity, isPlaying) = engine.evaluate(stick: stick)
            XCTAssertTrue(isPlaying)
            XCTAssertTrue(intensity > 0.9)
        }
    }

    // MARK: - Gesture Recorder Tests
    func testGestureRecorderCapture() {
        let recorder = GestureRecorder()

        XCTAssertNil(recorder.stopRecording())

        recorder.startRecording()

        var sampleState = GamepadState()
        sampleState.buttonA = true
        sampleState.leftTrigger = 0.75
        recorder.recordSample(state: sampleState)

        sampleState.buttonA = false
        sampleState.rightTrigger = 1.0
        recorder.recordSample(state: sampleState)

        let clip = recorder.stopRecording()
        XCTAssertNotNil(clip)
        XCTAssertEqual(clip?.samples.count, 2)
        XCTAssertEqual(clip?.samples[0].state.buttonA, true)
        XCTAssertEqual(clip?.samples[1].state.rightTrigger, 1.0)
    }

    // MARK: - Controller Manager Tests
    @MainActor
    func testControllerManagerSimulatedState() {
        let manager = ControllerManager()
        XCTAssertTrue(manager.controllerKind == .simulated || manager.isConnected)

        var callbackTriggered = false
        manager.onStateChanged = { _ in
            callbackTriggered = true
        }

        manager.injectSimulatedState { state in
            state.buttonA = true
            state.leftStick = ProcessedStickState(x: 0.5, y: 0.5)
        }

        XCTAssertTrue(callbackTriggered)
        XCTAssertTrue(manager.currentState.buttonA)
        XCTAssertEqual(manager.currentState.leftStick.x, 0.5)
    }
}
