import Foundation
import XPadCore

public struct MIDITranslationResult: Sendable, Equatable {
    public var events: [PerformanceEvent]
    public var strategyUsed: ArticulationMIDIStrategy
    public var pressureMode: PressureMIDIMode
    public var slideStrategy: SlideMIDIStrategy
    public var fallbackDescription: String?
    public var technique: MusicalTechnique
    public var note: UInt8
    public var velocity: UInt8
    public var channel: UInt8?
    public var pitchBend: UInt16?
    public var pressure: UInt8?
    public var timbre: UInt8?

    public var diagnosticSummary: String {
        var lines = [
            "Technique: \(technique.displayName)",
            "Note: \(note)  Velocity: \(velocity)"
        ]
        if let channel { lines.append("Channel: \(channel + 1)") }
        if let pitchBend { lines.append("Pitch Bend: \(Int(pitchBend) - 8192)") }
        if let pressure { lines.append("Pressure: \(pressure)") }
        if let timbre { lines.append("CC74: \(timbre)") }
        if let fallbackDescription { lines.append("Fallback: \(fallbackDescription)") }
        return lines.joined(separator: "\n")
    }
}

/// Translates musical techniques into MIDI/MPE packets. Gesture code never talks MIDI directly.
public struct TechniqueMIDITranslator: Sendable {
    public var destination: DestinationCapabilityProfile
    public var profile: InstrumentProfile

    public init(
        destination: DestinationCapabilityProfile = .internalSynth,
        profile: InstrumentProfile = .guitar
    ) {
        self.destination = destination
        self.profile = profile
    }

    public func translate(
        _ event: InstrumentPerformanceEvent,
        memberChannel: UInt8? = nil,
        activeVoiceCount: Int = 1
    ) -> MIDITranslationResult {
        let articulation = destination.resolvedArticulationStrategy(preferred: profile.midiArticulationStrategy)
        let pressure = destination.resolvedPressureMode(preferred: profile.pressureMode)
        let slide = destination.resolvedSlideStrategy(preferred: profile.slideMIDIStrategy)
        var fallbacks = [articulation.fallback, pressure.fallback, slide.fallback].compactMap { $0 }

        let channel: UInt8
        if destination.supportsMPE {
            if let memberChannel, (1...14).contains(memberChannel) {
                channel = memberChannel
            } else {
                channel = 1
                fallbacks.append("MPE member channel unavailable → MIDI Ch 2")
            }
        } else {
            channel = min(memberChannel ?? 0, 15)
        }
        var events: [PerformanceEvent] = []
        var pitchBend: UInt16?
        var pressureValue: UInt8?
        var timbreValue: UInt8?

        let midiNote = event.note.midiNote
        var velocity = event.velocity
        switch event.technique {
        case .hammerOn, .pullOff, .legato:
            velocity = UInt8(max(36, Int(Double(velocity) * 0.78)))
        case .ghostNote:
            velocity = UInt8(max(8, Int(Double(velocity) * 0.28)))
        case .pinchHarmonic, .accent:
            velocity = UInt8(min(127, Int(velocity) + 18))
        default:
            break
        }

        if event.phase == .ended {
            events.append(.noteOff(channel: channel, note: midiNote))

            // Some translation strategies create a second sounding note or a
            // momentary articulation control. Close those alongside the source.
            if event.technique.isHarmonicFamily {
                switch articulation.strategy {
                case .midiNote:
                    let harmonic = event.note.transposed(
                        by: event.technique == .pinchHarmonic ? 19 : 12
                    )
                    events.append(.noteOff(channel: channel, note: harmonic.midiNote))
                case .keyswitch:
                    events.append(.noteOff(channel: channel, note: 12))
                case .midiCC:
                    events.append(
                        .controlChange(channel: channel, controller: 32, value: 0)
                    )
                case .mpeTimbre, .velocityTimbre:
                    break
                }
            }

            switch event.technique {
            case .slideUp, .slideDown, .portamento:
                switch slide.strategy {
                case .legatoRetrigger:
                    if let target = event.targetNote {
                        events.append(
                            .noteOff(channel: channel, note: target.midiNote)
                        )
                    }
                case .ccPortamento:
                    events.append(
                        .controlChange(channel: channel, controller: 5, value: 0)
                    )
                    events.append(
                        .controlChange(channel: channel, controller: 65, value: 0)
                    )
                case .mpePitch, .pitchBend:
                    break
                }
            default:
                break
            }

            events.append(.pitchBend(channel: channel, value: 0))
            pitchBend = 8192

            switch pressure.mode {
            case .mpePressure, .channelPressure:
                events.append(.channelPressure(channel: channel, pressure: 0))
                pressureValue = 0
            case .polyPressure:
                events.append(
                    .polyPressure(channel: channel, note: midiNote, pressure: 0)
                )
                pressureValue = 0
            case .cc11:
                // CC11's neutral idle value is full expression. Leaving it at
                // zero would make the next unpressured note silent in many DAWs.
                events.append(
                    .controlChange(channel: channel, controller: 11, value: 127)
                )
                pressureValue = 0
            }
            if destination.supportsCC74 {
                events.append(.timbreCC74(channel: channel, value: 64))
                timbreValue = 64
            }
            return MIDITranslationResult(
                events: events,
                strategyUsed: articulation.strategy,
                pressureMode: pressure.mode,
                slideStrategy: slide.strategy,
                fallbackDescription: fallbacks.isEmpty ? nil : fallbacks.joined(separator: "; "),
                technique: event.technique,
                note: midiNote,
                velocity: velocity,
                channel: channel,
                pitchBend: pitchBend,
                pressure: pressureValue,
                timbre: timbreValue
            )
        }

        let isAttack = event.phase == .began
        var translatedSlidePitch = false
        switch event.technique {
        case .normal, .accent, .staccato, .ghostNote, .graceNote, .harmonic, .pinchHarmonic, .hammerOn, .pullOff:
            if isAttack {
                events.append(.noteOn(channel: channel, note: midiNote, velocity: velocity))
                appendArticulation(
                    technique: event.technique,
                    event: event,
                    channel: channel,
                    strategy: articulation.strategy,
                    events: &events,
                    timbre: &timbreValue
                )
            }
        case .bend, .preBend, .releaseBend, .vibrato, .aftertouch, .polyPressure, .palmMute, .tremolo:
            break
        case .slideUp, .slideDown, .portamento:
            switch slide.strategy {
            case .mpePitch, .pitchBend:
                let value = PitchBendCodec.value(semitones: event.pitchOffset, range: destination.bendRangeSemitones)
                events.append(.pitchBend(channel: channel, value: Int16(Int(value) - 8192)))
                pitchBend = value
                translatedSlidePitch = true
            case .legatoRetrigger:
                if isAttack, let target = event.targetNote {
                    events.append(.noteOn(channel: channel, note: target.midiNote, velocity: velocity))
                }
            case .ccPortamento:
                let cc = UInt8(min(127, Int(abs(event.pitchOffset) * 24)))
                events.append(.controlChange(channel: channel, controller: 5, value: cc))
            }
        default:
            if isAttack {
                events.append(.noteOn(channel: channel, note: midiNote, velocity: velocity))
            }
        }

        if abs(event.pitchOffset) > 0.001 && !translatedSlidePitch {
            if destination.canBendIndependently(activeVoiceCount: activeVoiceCount) {
                let value = PitchBendCodec.value(semitones: event.pitchOffset, range: destination.bendRangeSemitones)
                events.append(.pitchBend(channel: channel, value: Int16(Int(value) - 8192)))
                pitchBend = value
            } else {
                fallbacks.append("Per-note bend blocked on conventional MIDI chord")
            }
        }

        if event.pressure > 0.01 {
            let p = UInt8(min(127, Int((event.pressure * 127.0).rounded())))
            pressureValue = p
            switch pressure.mode {
            case .mpePressure:
                events.append(.channelPressure(channel: channel, pressure: p))
            case .cc11:
                events.append(.controlChange(channel: channel, controller: 11, value: p))
            case .polyPressure:
                events.append(.polyPressure(channel: channel, note: midiNote, pressure: p))
            case .channelPressure:
                events.append(.channelPressure(channel: channel, pressure: p))
            }
        }

        if event.timbre != 0.5 && destination.supportsCC74 {
            let t = UInt8(min(127, Int((event.timbre * 127.0).rounded())))
            events.append(.timbreCC74(channel: channel, value: t))
            timbreValue = t
        }

        return MIDITranslationResult(
            events: events,
            strategyUsed: articulation.strategy,
            pressureMode: pressure.mode,
            slideStrategy: slide.strategy,
            fallbackDescription: fallbacks.isEmpty ? nil : fallbacks.joined(separator: "; "),
            technique: event.technique,
            note: midiNote,
            velocity: velocity,
            channel: channel,
            pitchBend: pitchBend,
            pressure: pressureValue,
            timbre: timbreValue
        )
    }

    public func translateBend(semitones: Double, channel: UInt8, activeVoiceCount: Int) -> MIDITranslationResult? {
        let safeChannel: UInt8
        let channelFallback: String?
        if destination.supportsMPE && !(1...14).contains(channel) {
            safeChannel = 1
            channelFallback = "MPE member channel unavailable → MIDI Ch 2"
        } else {
            safeChannel = min(channel, 15)
            channelFallback = nil
        }
        guard destination.canBendIndependently(activeVoiceCount: activeVoiceCount) || activeVoiceCount <= 1 else {
            return MIDITranslationResult(
                events: [],
                strategyUsed: profile.midiArticulationStrategy,
                pressureMode: destination.pressureMode,
                slideStrategy: profile.slideMIDIStrategy,
                fallbackDescription: "Per-note bend blocked: conventional MIDI chord uses shared pitch bend",
                technique: .bend,
                note: 0,
                velocity: 0,
                channel: safeChannel
            )
        }
        let value = PitchBendCodec.value(semitones: semitones, range: destination.bendRangeSemitones)
        return MIDITranslationResult(
            events: [.pitchBend(channel: safeChannel, value: Int16(Int(value) - 8192))],
            strategyUsed: profile.midiArticulationStrategy,
            pressureMode: destination.pressureMode,
            slideStrategy: profile.slideMIDIStrategy,
            fallbackDescription: channelFallback,
            technique: .bend,
            note: 0,
            velocity: 0,
            channel: safeChannel,
            pitchBend: value
        )
    }

    private func appendArticulation(
        technique: MusicalTechnique,
        event: InstrumentPerformanceEvent,
        channel: UInt8,
        strategy: ArticulationMIDIStrategy,
        events: inout [PerformanceEvent],
        timbre: inout UInt8?
    ) {
        guard technique.isHarmonicFamily else { return }
        switch strategy {
        case .mpeTimbre:
            let value = technique == .pinchHarmonic ? UInt8(118) : UInt8(96)
            events.append(.timbreCC74(channel: channel, value: value))
            let pressure = technique == .pinchHarmonic ? UInt8(110) : UInt8(80)
            events.append(.channelPressure(channel: channel, pressure: pressure))
            timbre = value
        case .midiNote:
            let harmonic = event.note.transposed(by: technique == .pinchHarmonic ? 19 : 12)
            events.append(.noteOn(channel: channel, note: harmonic.midiNote, velocity: event.velocity))
        case .keyswitch:
            events.append(.noteOn(channel: channel, note: 12, velocity: 100))
        case .midiCC:
            events.append(.controlChange(channel: channel, controller: 32, value: technique == .pinchHarmonic ? 64 : 32))
        case .velocityTimbre:
            break
        }
    }
}

public enum PitchBendCodec {
    public static func value(semitones: Double, range: Double) -> UInt16 {
        guard range > 0 else { return 8192 }
        let n = max(-1.0, min(1.0, semitones / range))
        let raw = 8192.0 + n * 8192.0
        return UInt16(max(0, min(16383, raw.rounded())))
    }
}

public final class TechniqueRecorder: @unchecked Sendable {
    private var events: [RecordedTechniqueEvent] = []
    private var openNotes: [UInt8: (tick: UInt64, event: InstrumentPerformanceEvent)] = [:]
    private let lock = NSLock()
    public private(set) var isRecording = false

    public init() {}

    public func start() {
        lock.lock()
        defer { lock.unlock() }
        isRecording = true
        events.removeAll()
        openNotes.removeAll()
    }

    public func record(_ event: InstrumentPerformanceEvent, tick: UInt64) {
        lock.lock()
        defer { lock.unlock() }
        guard isRecording else { return }
        events.append(RecordedTechniqueEvent(tick: tick, event: event))
        if event.velocity > 0 {
            openNotes[event.note.midiNote] = (tick, event)
        }
    }

    public func recordNoteOff(note: UInt8, tick: UInt64) {
        lock.lock()
        defer { lock.unlock() }
        guard isRecording, let opened = openNotes.removeValue(forKey: note) else { return }
        if let idx = events.lastIndex(where: { $0.event.note.midiNote == note && $0.tick == opened.tick }) {
            events[idx].durationTicks = tick >= opened.tick ? tick - opened.tick : 0
        }
    }

    public func stop() -> [RecordedTechniqueEvent] {
        lock.lock()
        defer { lock.unlock() }
        isRecording = false
        let captured = events
        events.removeAll()
        openNotes.removeAll()
        return captured
    }

    public var recordedEvents: [RecordedTechniqueEvent] {
        lock.lock()
        defer { lock.unlock() }
        return events
    }
}
