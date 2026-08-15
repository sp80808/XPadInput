import Testing
import Foundation
@testable import XPadCore
@testable import XPadTheory
@testable import XPadMIDI
@testable import XPadAudio
@testable import XPadSequencer

@Suite("Exhaustive Sequencer & Timeline Engine Tests")
struct SequencerTests {

    // MARK: - Track & Clip Data Model Tests
    @Test("TrackType Enum and Identifiers")
    func testTrackTypes() {
        #expect(TrackType.allCases.count == 5)
        #expect(TrackType.chords.rawValue == "Chords")
        #expect(TrackType.melody.rawValue == "Melody")
        #expect(TrackType.bass.rawValue == "Bass")
        #expect(TrackType.drums.rawValue == "Drums")
        #expect(TrackType.gesture.rawValue == "Gesture / Motion")
    }

    @Test("SequencerClip & TimelineTrack Creation")
    func testSequencerClipAndTrack() {
        let clip = SequencerClip(
            name: "Verse Lead",
            startTick: 0,
            durationTicks: 3840,
            notes: [RecordedNoteEvent(note: 60, velocity: 100, startTick: 0, durationTicks: 480)]
        )
        #expect(clip.name == "Verse Lead")
        #expect(clip.notes.count == 1)

        let track = TimelineTrack(
            name: "Melody Track",
            type: .melody,
            isMuted: false,
            isSolo: false,
            clips: [clip]
        )
        #expect(track.type == .melody)
        #expect(track.clips.count == 1)
    }

    @Test("Scene Model Verification")
    func testSceneModel() {
        let scene = Scene(name: "Chorus", lengthBars: 8, tracks: [])
        #expect(scene.name == "Chorus")
        #expect(scene.lengthBars == 8)
    }

    // MARK: - Sequencer Engine Tests
    @Test("Sequencer Transport Lifecycle & Scene Initialization")
    @MainActor
    func testSequencerTransport() {
        let sequencer = Sequencer()

        // Verify default scenes
        #expect(sequencer.scenes.count == 4)
        #expect(sequencer.scenes[0].name == "Intro")
        #expect(sequencer.scenes[1].name == "Verse")
        #expect(sequencer.scenes[2].name == "Chorus")
        #expect(sequencer.scenes[3].name == "Bridge")

        // Play and Stop
        #expect(!sequencer.transport.isPlaying)
        sequencer.play()
        #expect(sequencer.transport.isPlaying)

        // Toggle Recording
        #expect(!sequencer.transport.isRecording)
        sequencer.toggleRecording()
        #expect(sequencer.transport.isRecording)

        // Record Note Events
        sequencer.transport.currentTick = 0
        sequencer.recordNoteOn(note: 60, velocity: 100)
        sequencer.transport.currentTick = 480
        sequencer.recordNoteOff(note: 60)

        #expect(sequencer.recordedEvents.count == 1)
        #expect(sequencer.recordedEvents[0].note == 60)
        #expect(sequencer.recordedEvents[0].startTick == 0)
        #expect(sequencer.recordedEvents[0].durationTicks == 480)

        sequencer.stop()
        #expect(!sequencer.transport.isPlaying)
        #expect(sequencer.transport.currentTick == 0)
    }
}
