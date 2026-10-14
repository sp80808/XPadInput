import Foundation
import XPadCore
import XPadTheory
import XPadMIDI
import XPadAudio

/// Shared timeline grid so clips, scenes, and the transport all measure bars the
/// same way instead of repeating `960 * 4` arithmetic in every call site.
public enum SequencerGrid {
    /// Ticks per quarter note. The timeline resolution deliberately matches the
    /// internal PPQN so tick math never needs rounding.
    public static let ppqn: UInt64 = 960
    /// Ticks in one quarter-note beat.
    public static let ticksPerBeat: UInt64 = ppqn
    /// Ticks in one 4/4 bar.
    public static let ticksPerBar: UInt64 = ppqn * 4

    public static func ticks(forBeats beats: Double) -> UInt64 {
        guard beats.isFinite, beats > 0 else { return 0 }
        return UInt64((beats * Double(ppqn)).rounded())
    }

    public static func bars(forTicks ticks: UInt64) -> Int {
        guard ticks > 0 else { return 1 }
        return max(1, Int((Double(ticks) / Double(ticksPerBar)).rounded(.up)))
    }
}

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

    /// Musical length of the scene in ticks, derived from `lengthBars` so the
    /// transport loop, the ruler, and clip insertion cannot disagree.
    public var loopLengthTicks: UInt64 {
        UInt64(max(1, lengthBars)) * SequencerGrid.ticksPerBar
    }

    /// Last tick occupied by the scene's clips, independent of `lengthBars`.
    public var contentLengthTicks: UInt64 {
        tracks
            .flatMap(\.clips)
            .reduce(UInt64(0)) { longest, clip in
                max(longest, clip.startTick + clip.durationTicks)
            }
    }
}

@MainActor
public final class Sequencer: ObservableObject {
    @Published public var transport: TransportState = TransportState()
    @Published public var scenes: [Scene] = []
    @Published public var activeSceneIndex: Int = 0
    @Published public var recordedEvents: [RecordedNoteEvent] = []

    /// Playback note-on including the source track, so the host can route the
    /// note to the same port and engine the live performance would use.
    public var onPlaybackNoteOn: ((UInt8, UInt8, TrackType) -> Void)?
    /// Playback note-off including the source track.
    public var onPlaybackNoteOff: ((UInt8, TrackType) -> Void)?
    /// Invoked once per bar the transport enters, with the 0-based bar index.
    ///
    /// Arrangement features (the jam co-pilot, pattern changes, section cues)
    /// hang off this instead of polling the clock from a timer.
    public var onBarBoundary: ((Int) -> Void)?

    private var timer: DispatchSourceTimer?
    private let timerQueue = DispatchQueue(label: "com.xpadinput.clock", qos: .userInteractive)
    private var clockStartHostTime: DispatchTime = .now()
    private var clockStartTick: UInt64 = 0
    private var activeNoteStarts: [UInt8: UInt64] = [:]
    private var activePlaybackNotes: [UInt8: TrackType] = [:]
    private var lastDispatchedTick: UInt64 = 0
    private var lastBarIndex: Int?

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
        lastDispatchedTick = transport.currentTick
        startClock()
    }

    public func stop() {
        if transport.isRecording {
            finalizeActiveNotes()
        }
        transport.isPlaying = false
        stopClock()
        silencePlaybackNotes()
        transport.currentTick = 0
        lastDispatchedTick = 0
        lastBarIndex = nil
    }

    public func rewind() {
        transport.currentTick = 0
        clockStartTick = 0
        clockStartHostTime = .now()
        lastDispatchedTick = 0
        lastBarIndex = nil
        silencePlaybackNotes()
    }

    public func silencePlaybackNotes() {
        for (note, track) in activePlaybackNotes {
            onPlaybackNoteOff?(note, track)
        }
        activePlaybackNotes.removeAll()
    }

    public func toggleMute(trackIndex: Int) {
        guard activeSceneIndex < scenes.count,
              trackIndex < scenes[activeSceneIndex].tracks.count else { return }
        scenes[activeSceneIndex].tracks[trackIndex].isMuted.toggle()
        if scenes[activeSceneIndex].tracks[trackIndex].isMuted {
            silencePlaybackNotes()
        }
    }

    /// Mutes or unmutes every track carrying `type` in the active scene.
    ///
    /// Arrangement automation thinks in musical roles ("drop the melody"),
    /// not in row indices, so this is the seam it uses.
    public func setMuted(_ muted: Bool, forType type: TrackType) {
        guard activeSceneIndex < scenes.count else { return }
        var changed = false
        for index in scenes[activeSceneIndex].tracks.indices where scenes[activeSceneIndex].tracks[index].type == type {
            if scenes[activeSceneIndex].tracks[index].isMuted != muted {
                scenes[activeSceneIndex].tracks[index].isMuted = muted
                changed = true
            }
        }
        if changed && muted {
            silencePlaybackNotes()
        }
    }

    /// Whether every track carrying `type` is currently muted.
    public func isMuted(_ type: TrackType) -> Bool {
        guard activeSceneIndex < scenes.count else { return false }
        let tracks = scenes[activeSceneIndex].tracks.filter { $0.type == type }
        return !tracks.isEmpty && tracks.allSatisfy(\.isMuted)
    }

    /// Track roles that will sound in the active scene.
    public var audibleTracks: [TrackType] {
        guard activeSceneIndex < scenes.count else { return [] }
        let tracks = scenes[activeSceneIndex].tracks
        let anySolo = tracks.contains { $0.isSolo }
        return tracks
            .filter { anySolo ? $0.isSolo : !$0.isMuted }
            .map(\.type)
    }

    /// Track roles that actually have material in the active scene.
    ///
    /// The co-pilot only ever adds a layer that has something to play, so an
    /// empty track never gets unmuted into silence.
    public var populatedTracks: [TrackType] {
        guard activeSceneIndex < scenes.count else { return [] }
        return scenes[activeSceneIndex].tracks
            .filter { !$0.clips.isEmpty }
            .map(\.type)
    }

    public func toggleSolo(trackIndex: Int) {
        guard activeSceneIndex < scenes.count,
              trackIndex < scenes[activeSceneIndex].tracks.count else { return }
        scenes[activeSceneIndex].tracks[trackIndex].isSolo.toggle()
        silencePlaybackNotes()
    }

    /// Inserts a harmonic progression on the target track as one clip per chord block.
    ///
    /// One clip per block keeps the roman numeral and chord symbol visible on the
    /// timeline instead of hiding the harmony inside a single anonymous region, and
    /// makes rearranging a progression a matter of moving clips.
    @discardableResult
    public func insertProgressionClip(
        _ progression: Progression,
        targetTrack: TrackType = .chords
    ) -> [SequencerClip] {
        guard activeSceneIndex < scenes.count, !progression.blocks.isEmpty else { return [] }

        var clips: [SequencerClip] = []
        var timelineEvents: [RecordedNoteEvent] = []
        var cursor: UInt64 = 0

        for block in progression.blocks {
            let blockTicks = max(SequencerGrid.ticksPerBeat, SequencerGrid.ticks(forBeats: block.durationBeats))
            // Leave a short release gap so repeated chords re-articulate.
            let releaseGap = min(80, blockTicks / 8)
            let noteTicks = max(1, blockTicks - releaseGap)

            var notes: [RecordedNoteEvent] = []
            for note in block.chord.voicedNotes() {
                notes.append(
                    RecordedNoteEvent(
                        note: note.midiNote,
                        velocity: block.humanizedVelocity,
                        startTick: 0,
                        durationTicks: noteTicks
                    )
                )
            }

            clips.append(
                SequencerClip(
                    name: blockName(block, in: progression),
                    startTick: cursor,
                    durationTicks: blockTicks,
                    notes: notes
                )
            )
            timelineEvents.append(
                contentsOf: notes.map {
                    RecordedNoteEvent(
                        note: $0.note,
                        velocity: $0.velocity,
                        startTick: cursor + $0.startTick,
                        durationTicks: $0.durationTicks
                    )
                }
            )
            cursor += blockTicks
        }

        if let index = scenes[activeSceneIndex].tracks.firstIndex(where: { $0.type == targetTrack }) {
            scenes[activeSceneIndex].tracks[index].clips = clips
        } else if let fallback = scenes[activeSceneIndex].tracks.indices.first {
            scenes[activeSceneIndex].tracks[fallback].clips = clips
        }

        // Exported MIDI mirrors what the timeline will play.
        recordedEvents = timelineEvents

        // The scene loops exactly over the inserted progression.
        scenes[activeSceneIndex].lengthBars = SequencerGrid.bars(forTicks: cursor)
        transport.loopEndTick = scenes[activeSceneIndex].loopLengthTicks
        return clips
    }

    /// Clip label such as `I C` or `vi Am`, deriving the roman numeral when the
    /// block does not carry one.
    private func blockName(_ block: ChordBlock, in progression: Progression) -> String {
        let roman = block.romanNumeral.isEmpty
            ? (block.chord.romanNumeral(in: progression.root, scale: progression.scale) ?? "")
            : block.romanNumeral
        return roman.isEmpty ? block.chord.symbol : "\(roman) \(block.chord.symbol)"
    }

    public func setBPM(_ bpm: Double) {
        let clamped = max(20.0, min(300.0, bpm))
        guard clamped != transport.bpm else { return }
        if transport.isPlaying {
            clockStartTick = transport.currentTick
            clockStartHostTime = .now()
            startClock()
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
        let currentTick = transport.currentTick
        
        if currentTick >= start {
            duration = max(60, currentTick - start)
        } else if transport.loopEnabled && transport.loopEndTick > start {
            let preWrap = transport.loopEndTick - start
            let postWrap = currentTick >= transport.loopStartTick ? (currentTick - transport.loopStartTick) : 0
            duration = max(60, preWrap + postWrap)
        } else {
            duration = 60
        }
        let event = RecordedNoteEvent(note: note, velocity: 100, startTick: start, durationTicks: duration)
        recordedEvents.append(event)
    }

    private func finalizeActiveNotes() {
        let currentTick = transport.currentTick
        for (note, start) in activeNoteStarts {
            let duration: UInt64
            if currentTick >= start {
                duration = max(60, currentTick - start)
            } else if transport.loopEnabled && transport.loopEndTick > start {
                let preWrap = transport.loopEndTick - start
                let postWrap = currentTick >= transport.loopStartTick ? (currentTick - transport.loopStartTick) : 0
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
        // Adaptive timer interval based on BPM for smooth transport
        // At 960 PPQN: 120 BPM = 1920 ticks/sec = ~0.52ms/tick
        // Use min(2ms, tick_interval/2) for responsive updates
        let tickIntervalNs = UInt64(60_000_000_000.0 / (transport.bpm * 960.0))
        let timerIntervalNs = min(2_000_000, tickIntervalNs / 2)
        t.schedule(deadline: .now(), repeating: .nanoseconds(Int(timerIntervalNs)))
        
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
                // A wrap invalidates every sounding note so stuck notes cannot
                // survive the jump back to the loop start.
                silencePlaybackNotes()
                lastDispatchedTick = newTick
                transport.currentTick = newTick
                // The wrap is itself a bar boundary in the scene's bar grid.
                lastBarIndex = nil
                notifyBarBoundary(for: newTick)
                return
            }
        }

        tick(to: newTick)
    }

    /// Advances the transport to an absolute tick position, dispatching every note
    /// event the position crossed.
    ///
    /// This is the single place that turns a tick position into audible events, so
    /// the timer path and a test (or a scrub) behave identically.
    public func tick(to newTick: UInt64) {
        if newTick < lastDispatchedTick {
            // Backwards seek: release sounding notes rather than leaving them hanging.
            silencePlaybackNotes()
        } else {
            dispatchPlaybackEvents(from: lastDispatchedTick, to: newTick)
        }
        lastDispatchedTick = newTick
        transport.currentTick = newTick
        notifyBarBoundary(for: newTick)
    }

    /// Fires `onBarBoundary` once per bar the transport enters.
    private func notifyBarBoundary(for tick: UInt64) {
        let bar = Int(tick / SequencerGrid.ticksPerBar)
        guard lastBarIndex != bar else { return }
        lastBarIndex = bar
        onBarBoundary?(bar)
    }

    private func dispatchPlaybackEvents(from start: UInt64, to end: UInt64) {
        guard activeSceneIndex < scenes.count, end > start else { return }
        let currentTracks = scenes[activeSceneIndex].tracks
        let anySolo = currentTracks.contains { $0.isSolo }
        let activeTracks = currentTracks.filter { track in
            if anySolo { return track.isSolo }
            return !track.isMuted
        }

        for track in activeTracks {
            for clip in track.clips {
                for noteEvent in clip.notes {
                    let absoluteStart = clip.startTick + noteEvent.startTick
                    let absoluteEnd = absoluteStart + noteEvent.durationTicks

                    if absoluteStart >= start && absoluteStart < end {
                        onPlaybackNoteOn?(noteEvent.note, noteEvent.velocity, track.type)
                        activePlaybackNotes[noteEvent.note] = track.type
                    }
                    if absoluteEnd >= start && absoluteEnd < end {
                        onPlaybackNoteOff?(noteEvent.note, track.type)
                        activePlaybackNotes.removeValue(forKey: noteEvent.note)
                    }
                }
            }
        }
    }
}