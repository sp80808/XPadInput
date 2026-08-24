import Foundation
import XPadCore
import XPadMIDI
import XPadAudio

public enum TrackType: String, CaseIterable, Identifiable, Codable, Sendable {
    case chords = "Chords"
    case melody = "Melody"
    case bass = "Bass"
    case drums = "Drums"
    case gesture = "Gesture / Motion"

    public var id: String { rawValue }
}

public struct SequencerClip: Identifiable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var startTick: UInt64
    public var durationTicks: UInt64
    public var notes: [RecordedNoteEvent]

    public init(
        id: UUID = UUID(),
        name: String = "Clip",
        startTick: UInt64 = 0,
        durationTicks: UInt64 = 960 * 4, // 1 Bar in 4/4
        notes: [RecordedNoteEvent] = []
    ) {
        self.id = id
        self.name = name
        self.startTick = startTick
        self.durationTicks = durationTicks
        self.notes = notes
    }
}

public struct TimelineTrack: Identifiable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var type: TrackType
    public var isMuted: Bool
    public var isSolo: Bool
    public var clips: [SequencerClip]

    public init(
        id: UUID = UUID(),
        name: String,
        type: TrackType,
        isMuted: Bool = false,
        isSolo: Bool = false,
        clips: [SequencerClip] = []
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.isMuted = isMuted
        self.isSolo = isSolo
        self.clips = clips
    }
}

public struct Scene: Identifiable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var lengthBars: Int
    public var tracks: [TimelineTrack]

    public init(
        id: UUID = UUID(),
        name: String = "Verse",
        lengthBars: Int = 4,
        tracks: [TimelineTrack] = []
    ) {
        self.id = id
        self.name = name
        self.lengthBars = lengthBars
        self.tracks = tracks
    }
}

@MainActor
public final class Sequencer: ObservableObject {
    @Published public var transport: TransportState = TransportState()
    @Published public var scenes: [Scene] = []
    @Published public var activeSceneIndex: Int = 0
    @Published public var recordedEvents: [RecordedNoteEvent] = []

    private var timer: DispatchSourceTimer?
    private let timerQueue = DispatchQueue(label: "com.xpadinput.clock", qos: .userInteractive)
    private var clockStartHostTime: DispatchTime = .now()
    private var clockStartTick: UInt64 = 0
    private var activeNoteStarts: [UInt8: UInt64] = [:]

    public init() {
        setupDefaultScene()
    }

    private func setupDefaultScene() {
        let defaultTracks = TrackType.allCases.map { type in
            TimelineTrack(name: type.rawValue, type: type)
        }
        scenes = [
            Scene(name: "Intro", lengthBars: 4, tracks: defaultTracks),
            Scene(name: "Verse", lengthBars: 8, tracks: defaultTracks),
            Scene(name: "Chorus", lengthBars: 8, tracks: defaultTracks),
            Scene(name: "Bridge", lengthBars: 4, tracks: defaultTracks)
        ]
    }

    public func play() {
        guard !transport.isPlaying else { return }
        transport.isPlaying = true
        clockStartHostTime = .now()
        clockStartTick = transport.currentTick
        startClock()
    }

    public func stop() {
        if transport.isRecording {
            finalizeActiveNotes()
        }
        transport.isPlaying = false
        stopClock()
        transport.currentTick = 0
    }

    public func setBPM(_ bpm: Double) {
        let clamped = max(20.0, min(300.0, bpm))
        guard clamped != transport.bpm else { return }
        if transport.isPlaying {
            clockStartTick = transport.currentTick
            clockStartHostTime = .now()
        }
        transport.bpm = clamped
    }

    public func toggleRecording() {
        transport.isRecording.toggle()
        if !transport.isRecording {
            finalizeActiveNotes()
        } else if !transport.isPlaying {
            play()
        }
    }

    public func recordNoteOn(note: UInt8, velocity: UInt8) {
        guard transport.isRecording else { return }
        activeNoteStarts[note] = transport.currentTick
    }

    public func recordNoteOff(note: UInt8) {
        guard transport.isRecording, let start = activeNoteStarts.removeValue(forKey: note) else { return }
        let duration: UInt64
        if transport.currentTick >= start {
            duration = max(60, transport.currentTick - start)
        } else if transport.loopEnabled && transport.loopEndTick > start {
            let preWrap = transport.loopEndTick - start
            let postWrap = transport.currentTick >= transport.loopStartTick ? (transport.currentTick - transport.loopStartTick) : 0
            duration = max(60, preWrap + postWrap)
        } else {
            duration = 60
        }
        let event = RecordedNoteEvent(note: note, velocity: 100, startTick: start, durationTicks: duration)
        recordedEvents.append(event)
    }

    private func finalizeActiveNotes() {
        for (note, start) in activeNoteStarts {
            let duration: UInt64
            if transport.currentTick >= start {
                duration = max(60, transport.currentTick - start)
            } else if transport.loopEnabled && transport.loopEndTick > start {
                let preWrap = transport.loopEndTick - start
                let postWrap = transport.currentTick >= transport.loopStartTick ? (transport.currentTick - transport.loopStartTick) : 0
                duration = max(60, preWrap + postWrap)
            } else {
                duration = 60
            }
            let event = RecordedNoteEvent(note: note, velocity: 100, startTick: start, durationTicks: duration)
            recordedEvents.append(event)
        }
        activeNoteStarts.removeAll()
    }

    private func startClock() {
        stopClock()
        let t = DispatchSource.makeTimerSource(queue: timerQueue)
        // High-resolution ~2ms timer tick, calculated against host clock for 0 drift
        t.schedule(deadline: .now(), repeating: .milliseconds(2))

        t.setEventHandler { [weak self] in
            DispatchQueue.main.async {
                self?.tick()
            }
        }
        timer = t
        t.resume()
    }

    private func stopClock() {
        timer?.cancel()
        timer = nil
    }

    public func tick() {
        guard transport.isPlaying else { return }
        let elapsedNs = DispatchTime.now().uptimeNanoseconds - clockStartHostTime.uptimeNanoseconds
        let elapsedSeconds = Double(elapsedNs) / 1_000_000_000.0
        let ticksElapsed = UInt64(elapsedSeconds * (transport.bpm / 60.0) * 960.0)
        var newTick = clockStartTick + ticksElapsed

        if transport.loopEnabled && transport.loopEndTick > transport.loopStartTick {
            let loopSpan = transport.loopEndTick - transport.loopStartTick
            if newTick >= transport.loopEndTick {
                let offset = (newTick - transport.loopStartTick) % loopSpan
                newTick = transport.loopStartTick + offset
            }
        }
        transport.currentTick = newTick
    }
}
