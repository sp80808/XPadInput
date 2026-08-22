import Foundation
import simd

/// 3D Spatial audio panning and acoustic simulation mode.
public enum SpatialAudioMode: String, CaseIterable, Codable, Sendable, Identifiable {
    case binaural3D = "Binaural 3D (HRTF/ITD)"
    case stereoPanner = "Constant-Power Stereo"
    case orbitPanner = "Dynamic Gyro Orbit"
    case quadSurround = "Ambisonic / Quad"

    public var id: String { rawValue }
    public var displayName: String { rawValue }
}

/// 3D Spatial point in spherical coordinates relative to the listener head.
public struct SpatialCoordinates: Sendable, Codable, Equatable {
    /// Horizontal angle in degrees (-180° left/rear ... 0° front ... +180° right/rear).
    public var azimuthDegrees: Float
    /// Vertical angle in degrees (-90° bottom ... 0° horizon ... +90° zenith).
    public var elevationDegrees: Float
    /// Distance from listener in meters (0.2m ... 10.0m).
    public var distanceMeters: Float

    public init(
        azimuthDegrees: Float = 0.0,
        elevationDegrees: Float = 0.0,
        distanceMeters: Float = 1.0
    ) {
        self.azimuthDegrees = azimuthDegrees.clamped(to: -180.0...180.0)
        self.elevationDegrees = elevationDegrees.clamped(to: -90.0...90.0)
        self.distanceMeters = max(0.2, min(10.0, distanceMeters))
    }

    /// Converts spherical coordinates to 3D Cartesian coordinates (X: Left/Right, Y: Up/Down, Z: Front/Back).
    public var cartesian: SIMD3<Float> {
        let azRad = azimuthDegrees * .pi / 180.0
        let elRad = elevationDegrees * .pi / 180.0
        let x = distanceMeters * cos(elRad) * sin(azRad)
        let y = distanceMeters * sin(elRad)
        let z = distanceMeters * cos(elRad) * cos(azRad)
        return SIMD3<Float>(x, y, z)
    }
}

/// Real-time 3D Spatial Audio DSP Engine for binaural spatialization and gyro panning.
public final class SpatialAudioEngine: @unchecked Sendable {
    public var isEnabled: Bool = true
    public var mode: SpatialAudioMode = .binaural3D
    public private(set) var currentCoordinates = SpatialCoordinates()

    // Smoothing filter coefficients
    private var targetAzimuth: Float = 0.0
    private var targetElevation: Float = 0.0
    private var targetDistance: Float = 1.0

    private var smoothedAzimuth: Float = 0.0
    private var smoothedElevation: Float = 0.0
    private var smoothedDistance: Float = 1.0

    // DSP State: Fractional Delay Lines for Interaural Time Difference (ITD)
    private let maxDelaySamples: Int = 128
    private var delayBufferLeft: [Float]
    private var delayBufferRight: [Float]
    private var delayWriteIndex: Int = 0

    // Head-shadow one-pole filters for Interaural Level Difference (ILD)
    private var filterStateLeft: Float = 0.0
    private var filterStateRight: Float = 0.0

    private let sampleRate: Float
    private let lock = NSLock()

    // Physics constants
    private let speedOfSoundM_S: Float = 343.0
    private let headRadiusM: Float = 0.0875 // Average adult head radius ~8.75cm

    public init(sampleRate: Float = 44100.0) {
        self.sampleRate = sampleRate
        self.delayBufferLeft = [Float](repeating: 0.0, count: maxDelaySamples)
        self.delayBufferRight = [Float](repeating: 0.0, count: maxDelaySamples)
    }

    /// Thread-safe update of spatial target coordinates (e.g. from Gamepad IMU / Gyro).
    public func setCoordinates(azimuth: Float, elevation: Float, distance: Float) {
        lock.lock()
        targetAzimuth = azimuth.clamped(to: -180.0...180.0)
        targetElevation = elevation.clamped(to: -90.0...90.0)
        targetDistance = max(0.2, min(10.0, distance))
        currentCoordinates = SpatialCoordinates(azimuthDegrees: targetAzimuth, elevationDegrees: targetElevation, distanceMeters: targetDistance)
        lock.unlock()
    }

    /// Updates spatial coordinates from 6-axis controller gyro & acceleration readings.
    public func updateFromIMU(gyroPitch: Float, gyroRoll: Float, gyroYaw: Float, accelMagnitude: Float = 1.0) {
        // Gyro pitch [-1...1] -> Elevation [-60°...+60°]
        // Gyro yaw / roll [-1...1] -> Azimuth [-180°...+180°]
        // Accel -> Distance dynamics
        let az = gyroYaw * 180.0 + gyroRoll * 45.0
        let el = gyroPitch * 60.0
        let dist = 1.0 + (accelMagnitude - 1.0) * 0.5

        setCoordinates(azimuth: az, elevation: el, distance: dist)
    }

    /// Real-time DSP spatial processing for a single stereo frame inside the audio rendering loop.
    /// Returns a tuple of (leftSample, rightSample) spatialized output.
    @inline(__always)
    public func processSample(inputLeft: Float, inputRight: Float) -> (Float, Float) {
        guard isEnabled else { return (inputLeft, inputRight) }

        // Parameter smoothing (approx. 20ms time constant at 44.1kHz)
        let alpha: Float = 0.005
        smoothedAzimuth += alpha * (targetAzimuth - smoothedAzimuth)
        smoothedElevation += alpha * (targetElevation - smoothedElevation)
        smoothedDistance += alpha * (targetDistance - smoothedDistance)

        let azRad = smoothedAzimuth * .pi / 180.0
        let elRad = smoothedElevation * .pi / 180.0
        let dist = smoothedDistance

        // Distance attenuation (Inverse square law with soft floor)
        let distanceGain = min(1.5, 1.0 / (dist * 0.85 + 0.15))

        // Mono sum for spatial point source
        let monoInput = (inputLeft + inputRight) * 0.5 * distanceGain

        switch mode {
        case .stereoPanner, .orbitPanner:
            // Constant-power pan: angle from 0 (hard left) to pi/2 (hard right)
            let pan = (sin(azRad) + 1.0) * 0.5 // 0.0 (left) ... 1.0 (right)
            let angle = pan * (.pi / 2.0)
            let leftGain = cos(angle)
            let rightGain = sin(angle)
            return (monoInput * leftGain, monoInput * rightGain)

        case .binaural3D:
            // 1. Interaural Time Difference (ITD) Calculation: Woodworth's formula approximation
            // ITD = (headRadius / speedOfSound) * (sin(theta) + theta)
            let sinTheta = sin(azRad)
            let itdSeconds = (headRadiusM / speedOfSoundM_S) * (sinTheta + (sinTheta >= 0 ? azRad : -azRad) * 0.5)
            let delaySamples = itdSeconds * sampleRate

            // Delay positive: right ear delayed (source on left); delay negative: left ear delayed (source on right)
            let leftDelay = max(0.0, -delaySamples)
            let rightDelay = max(0.0, delaySamples)

            // Write to delay buffers
            delayBufferLeft[delayWriteIndex] = monoInput
            delayBufferRight[delayWriteIndex] = monoInput

            // Read with linear interpolation
            let leftDelayed = readDelayInterpolated(buffer: delayBufferLeft, delay: leftDelay)
            let rightDelayed = readDelayInterpolated(buffer: delayBufferRight, delay: rightDelay)

            delayWriteIndex = (delayWriteIndex + 1) % maxDelaySamples

            // 2. Interaural Level Difference (ILD) & Head Shadowing
            // Shadow contralateral ear with a dynamic one-pole low-pass filter
            let shadowCutoffLeft = calculateShadowFilterCoeff(azimuthRad: -azRad, elevationRad: elRad)
            let shadowCutoffRight = calculateShadowFilterCoeff(azimuthRad: azRad, elevationRad: elRad)

            filterStateLeft += shadowCutoffLeft * (leftDelayed - filterStateLeft)
            filterStateRight += shadowCutoffRight * (rightDelayed - filterStateRight)

            // 3. Elevation spectral shaping (pinna notch approximation)
            let elevationGain = 1.0 + 0.15 * sin(elRad)

            let outL = filterStateLeft * elevationGain
            let outR = filterStateRight * elevationGain

            return (outL, outR)

        case .quadSurround:
            // Quad / Ambisonic simulation downmixed to binaural stereo
            let panX = sin(azRad)
            let panZ = cos(azRad)

            let left = monoInput * max(0.0, (1.0 - panX) * 0.707)
            let right = monoInput * max(0.0, (1.0 + panX) * 0.707)
            let rearAtten = (panZ < 0) ? (1.0 + panZ * 0.3) : 1.0

            return (left * rearAtten, right * rearAtten)
        }
    }

    @inline(__always)
    private func readDelayInterpolated(buffer: [Float], delay: Float) -> Float {
        let clampedDelay = min(Float(maxDelaySamples - 2), max(0.0, delay))
        let intDelay = Int(clampedDelay)
        let fracDelay = clampedDelay - Float(intDelay)

        var readIndex0 = delayWriteIndex - intDelay
        if readIndex0 < 0 { readIndex0 += maxDelaySamples }

        var readIndex1 = readIndex0 - 1
        if readIndex1 < 0 { readIndex1 += maxDelaySamples }

        let sample0 = buffer[readIndex0]
        let sample1 = buffer[readIndex1]

        return sample0 + fracDelay * (sample1 - sample0)
    }

    @inline(__always)
    private func calculateShadowFilterCoeff(azimuthRad: Float, elevationRad: Float) -> Float {
        // Ear facing source (azimuth > 0) -> wide open (coeff ~0.9)
        // Ear in head shadow (azimuth < 0) -> muffled low-pass (coeff ~0.15 to 0.35)
        let normalizedFacing = (sin(azimuthRad) + 1.0) * 0.5 // 0.0 (shadow) ... 1.0 (direct)
        let baseCoeff = 0.20 + 0.75 * normalizedFacing
        return min(0.95, max(0.08, baseCoeff))
    }
}
