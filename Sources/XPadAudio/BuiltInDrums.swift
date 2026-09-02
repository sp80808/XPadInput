import AVFoundation
import Foundation

/// The compact General MIDI drum set used by Duo performance mode.
public enum BuiltInDrumSound: String, CaseIterable, Codable, Sendable, Identifiable {
    case kick = "Kick"
    case snare = "Snare"
    case closedHiHat = "Closed Hat"
    case openHiHat = "Open Hat"

    public var id: String { rawValue }

    /// General MIDI channel-10 note number for the equivalent sound.
    public var midiNote: UInt8 {
        switch self {
        case .kick: 36
        case .snare: 38
        case .closedHiHat: 42
        case .openHiHat: 46
        }
    }

    var duration: Double {
        switch self {
        case .kick: 0.42
        case .snare: 0.28
        case .closedHiHat: 0.10
        case .openHiHat: 0.46
        }
    }
}

/// Allocation-free one-shot percussion synthesis once the source node starts
/// rendering. Node creation and graph changes happen on the control thread.
final class PercussionVoice: @unchecked Sendable {
    let sourceNode: AVAudioSourceNode
    let duration: Double

    private let control = PercussionControlState()

    init(
        sound: BuiltInDrumSound,
        velocity: UInt8,
        velocityCurve: SynthVelocityCurve,
        sampleRate: Double
    ) {
        duration = sound.duration
        let amplitude = velocityCurve.normalizedAmplitude(for: velocity)
        let totalDuration = sound.duration
        let state = control

        var elapsed = 0.0
        var phase = 0.0
        var metallicPhase = 0.0
        var noiseState = UInt32(0x9E37_79B9) ^ UInt32(velocity) ^ UInt32(sound.midiNote)
        var previousNoise = 0.0
        var highPassState = 0.0
        var renderFinished = false

        sourceNode = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard let rawPointer = buffers[0].mData else { return noErr }
            let output = rawPointer.assumingMemoryBound(to: Float.self)

            if renderFinished || state.isStopped {
                for frame in 0..<Int(frameCount) {
                    output[frame] = 0
                }
                return noErr
            }

            for frame in 0..<Int(frameCount) {
                guard elapsed < totalDuration else {
                    output[frame] = 0
                    renderFinished = true
                    continue
                }

                noiseState = noiseState &* 1_664_525 &+ 1_013_904_223
                let unitNoise = Double(noiseState) / Double(UInt32.max)
                let noise = unitNoise * 2.0 - 1.0
                let highPassedNoise = noise - previousNoise + 0.94 * highPassState
                previousNoise = noise
                highPassState = highPassedNoise

                let sample: Double
                switch sound {
                case .kick:
                    let pitchEnvelope = exp(-elapsed * 28.0)
                    let frequency = 48.0 + 92.0 * pitchEnvelope
                    phase += frequency / sampleRate
                    if phase >= 1.0 { phase -= floor(phase) }
                    let body = sin(phase * 2.0 * .pi) * exp(-elapsed * 9.0)
                    let click = elapsed < 0.012 ? highPassedNoise * (1.0 - elapsed / 0.012) : 0
                    sample = body + click * 0.12

                case .snare:
                    phase += 185.0 / sampleRate
                    if phase >= 1.0 { phase -= floor(phase) }
                    let envelope = exp(-elapsed * 15.0)
                    sample = (highPassedNoise * 0.76 + sin(phase * 2.0 * .pi) * 0.24) * envelope

                case .closedHiHat, .openHiHat:
                    metallicPhase += 5_800.0 / sampleRate
                    if metallicPhase >= 1.0 { metallicPhase -= floor(metallicPhase) }
                    let decay = sound == .closedHiHat ? 48.0 : 11.0
                    let envelope = exp(-elapsed * decay)
                    let metallic = sin(metallicPhase * 2.0 * .pi) * 0.22
                    sample = (highPassedNoise * 0.78 + metallic) * envelope
                }

                // The shared master limiter remains a second line of defence.
                output[frame] = Float(tanh(sample * amplitude * 0.4))
                elapsed += 1.0 / sampleRate
            }

            return noErr
        }
    }

    func stop() {
        control.stop()
    }
}

private final class PercussionControlState: @unchecked Sendable {
    private let lock = NSLock()
    private var stopped = false

    var isStopped: Bool {
        guard lock.try() else { return false }
        defer { lock.unlock() }
        return stopped
    }

    func stop() {
        lock.lock()
        defer { lock.unlock() }
        stopped = true
    }
}
