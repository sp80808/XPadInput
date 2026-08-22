import Foundation
import GameController
import CoreHaptics
#if canImport(AppKit)
import AppKit
#endif
import XPadCore

/// Haptic tactile feedback mode for game controller actuators.
public enum HapticFeedbackMode: String, CaseIterable, Codable, Sendable, Identifiable {
    case fullAudioTactile = "Full Audio-Tactile (DualSense Voice-Coil)"
    case musicalTransients = "Musical Transients Only (Strums & Plucks)"
    case harmonicDetents = "Harmonic Detents & Alerts"
    case off = "Disabled"

    public var id: String { rawValue }
    public var displayName: String { rawValue }
}

/// Real-time CoreHaptics and Voice-Coil Tactile Synthesis Engine for Sony DualSense & MFi gamepads.
public final class CoreHapticsEngine: @unchecked Sendable {
    public var mode: HapticFeedbackMode = .fullAudioTactile
    public var masterIntensity: Float = 0.8
    public private(set) var isSupported: Bool = false
    public private(set) var isRunning: Bool = false

    private var hapticEngine: CHHapticEngine?
    private let lock = NSLock()
    private var continuousPlayer: CHHapticAdvancedPatternPlayer?

    public init() {
        checkHapticCapabilities()
    }

    /// Attaches the haptic engine to a connected GameController instance.
    public func attach(to controller: GCController) {
        lock.lock()
        defer { lock.unlock() }

        // CoreHaptics on macOS creates an engine from the GCController haptics property
        if let controllerHaptics = controller.haptics {
            do {
                if let engine = controllerHaptics.createEngine(withLocality: .default) {
                    self.hapticEngine = engine
                    configureEngineHandlers(engine)
                    try engine.start()
                    self.isRunning = true
                    self.isSupported = true
                }
            } catch {
                self.isSupported = false
                self.isRunning = false
            }
        }
    }

    public func detach() {
        lock.lock()
        defer { lock.unlock() }

        do {
            try continuousPlayer?.stop(atTime: CHHapticTimeImmediate)
            continuousPlayer = nil
            hapticEngine?.stop()
        } catch {}
        hapticEngine = nil
        isRunning = false
    }

    private func checkHapticCapabilities() {
        self.isSupported = CHHapticEngine.capabilitiesForHardware().supportsHaptics
    }

    private func configureEngineHandlers(_ engine: CHHapticEngine) {
        engine.resetHandler = { [weak self] in
            guard let self else { return }
            self.lock.lock()
            defer { self.lock.unlock() }
            do {
                try self.hapticEngine?.start()
                self.isRunning = true
            } catch {
                self.isRunning = false
            }
        }

        engine.stoppedHandler = { [weak self] reason in
            guard let self else { return }
            self.lock.lock()
            self.isRunning = false
            self.lock.unlock()
        }
    }

    // MARK: - Musical Tactile Events

    /// Plays a crisp haptic pluck when a musical note is struck.
    public func playNotePluck(velocity: UInt8) {
        guard mode != .off, isRunning, let engine = hapticEngine else { return }

        let normalizedVelocity = Float(min(127, velocity)) / 127.0
        let intensity = normalizedVelocity * masterIntensity
        let sharpness = 0.5 + normalizedVelocity * 0.4

        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
            ],
            relativeTime: 0
        )

        playSinglePattern([event], on: engine)
    }

    /// Plays a multi-string textured haptic sensation for a chord strum sweep.
    public func playStrumSweep(stringCount: Int = 6, speed: Float = 1.0, isDownstrum: Bool = true, isMuted: Bool = false) {
        guard mode != .off, isRunning, let engine = hapticEngine else { return }

        let totalDuration = max(0.02, min(0.18, 0.12 / Double(max(0.1, speed))))
        let step = totalDuration / Double(max(1, stringCount))
        var events: [CHHapticEvent] = []

        let baseIntensity: Float = (isMuted ? 0.4 : 0.85) * masterIntensity
        let baseSharpness: Float = isMuted ? 0.9 : 0.65

        for i in 0..<stringCount {
            let relTime = step * Double(i)
            let dynamicGain = isDownstrum ? (1.0 - Float(i) * 0.08) : (0.6 + Float(i) * 0.08)
            let intensity = max(0.1, min(1.0, baseIntensity * dynamicGain))

            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: baseSharpness)
                ],
                relativeTime: relTime
            )
            events.append(event)
        }

        playSinglePattern(events, on: engine)
    }

    /// Plays a subtle tactile detent click when shifting between chords on the harmonic wheel.
    public func playHarmonicDetent(tension: Float = 0.0) {
        guard mode == .fullAudioTactile || mode == .harmonicDetents, isRunning, let engine = hapticEngine else { return }

        let intensity = max(0.15, min(0.65, 0.35 + tension * 0.3)) * masterIntensity
        let sharpness = max(0.2, min(0.9, 0.4 + tension * 0.4))

        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
            ],
            relativeTime: 0
        )

        playSinglePattern([event], on: engine)
    }

    /// Starts or updates continuous low-frequency bass rumble corresponding to synth bass fundamentals.
    public func updateBassResonance(frequencyHz: Float, amplitude: Float) {
        guard mode == .fullAudioTactile, isRunning, let engine = hapticEngine else { return }

        let clampedAmp = max(0.0, min(1.0, amplitude)) * masterIntensity
        guard clampedAmp > 0.02 else {
            stopContinuousHaptic()
            return
        }

        // Map audio frequency (30Hz...180Hz) to haptic sharpness (0.1...0.6)
        let sharpness = max(0.1, min(0.7, (frequencyHz - 30.0) / 150.0))

        do {
            let intensityParam = CHHapticDynamicParameter(
                parameterID: .hapticIntensityControl,
                value: clampedAmp,
                relativeTime: 0
            )
            let sharpnessParam = CHHapticDynamicParameter(
                parameterID: .hapticSharpnessControl,
                value: sharpness,
                relativeTime: 0
            )

            if let player = continuousPlayer {
                try player.sendParameters([intensityParam, sharpnessParam], atTime: CHHapticTimeImmediate)
            } else {
                let continuousEvent = CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: clampedAmp),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
                    ],
                    relativeTime: 0,
                    duration: 5.0
                )
                let pattern = try CHHapticPattern(events: [continuousEvent], parameters: [])
                let player = try engine.makeAdvancedPlayer(with: pattern)
                try player.start(atTime: CHHapticTimeImmediate)
                continuousPlayer = player
            }
        } catch {}
    }

    public func stopContinuousHaptic() {
        do {
            try continuousPlayer?.stop(atTime: CHHapticTimeImmediate)
        } catch {}
        continuousPlayer = nil
    }

    /// Plays a standardized musical technique tactile cue on controller voice-coils or macOS trackpad.
    public func playTechniqueHaptic(_ haptic: TechniqueHaptic, intensityMultiplier: Float = 1.0) {
        guard mode != .off else { return }

        let intensity = min(1.0, haptic.intensity * intensityMultiplier * masterIntensity)
        let sharpness = haptic.sharpness

        if isRunning, let engine = hapticEngine {
            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
                ],
                relativeTime: 0
            )
            playSinglePattern([event], on: engine)
            return
        }

        #if canImport(AppKit)
        // Fallback for macOS Force Touch trackpad when no gamepad actuator is connected
        let pattern: NSHapticFeedbackManager.FeedbackPattern
        switch haptic {
        case .bendDetent, .chordChange, .octaveShift:
            pattern = .alignment
        case .hammerOn, .pullOff, .pinchHarmonic, .soloGuideTone:
            pattern = .levelChange
        default:
            pattern = .generic
        }
        NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .default)
        #endif
    }

    private func playSinglePattern(_ events: [CHHapticEvent], on engine: CHHapticEngine) {
        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {}
    }
}
