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
    private var recordStartTick: UInt64 = 0
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
        startClock()
    }

    public func stop() {
        transport.isPlaying = false
        stopClock()
        transport.currentTick = 0
        MIDIManager.shared.panic()
        AudioEngine.shared.panic()
    }

    public func toggleRecording() {
        transport.isRecording.toggle()
        if transport.isRecording && !transport.isPlaying {
            play()
        }
    }

    public func recordNoteOn(note: UInt8, velocity: UInt8) {
        guard transport.isRecording else { return }
        activeNoteStarts[note] = transport.currentTick
    }

    public func recordNoteOff(note: UInt8) {
        guard transport.isRecording, let start = activeNoteStarts[note] else { return }
        let duration = max(60, transport.currentTick - start)
        let event = RecordedNoteEvent(note: note, velocity: 100, startTick: start, durationTicks: duration)
        recordedEvents.append(event)
        activeNoteStarts.removeValue(forKey: note)
    }

    private func startClock() {
        timer = DispatchSource.makeTimerSource(queue: timerQueue)
        // 960 PPQN at 120 BPM = 1920 ticks/sec -> interval ~ 520 microseconds
        let intervalUs = Int(60_000_000.0 / (transport.bpm * 960.0))
        timer?.schedule(deadline: .now(), repeating: .microseconds(max(100, intervalUs)))

        timer?.setEventHandler { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                self.tick()
            }
        }
        timer?.resume()
    }

    private func stopClock() {
        timer?.cancel()
        timer = nil
    }

    private func tick() {
        transport.currentTick += 1
        if transport.loopEnabled && transport.currentTick >= transport.loopEndTick {
            transport.currentTick = transport.loopStartTick
        }
    }
}
