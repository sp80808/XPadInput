import XCTest
@testable import XPadCore
@testable import XPadTheory
@testable import XPadMIDI
@testable import XPadAudio
@testable import XPadSequencer

final class SequencerTests: XCTestCase {

    // MARK: - Track & Clip Data Model Tests
    func testTrackTypes() {
        XCTAssertEqual(TrackType.allCases.count, 5)
        XCTAssertEqual(TrackType.chords.rawValue, "Chords")
        XCTAssertEqual(TrackType.melody.rawValue, "Melody")
        XCTAssertEqual(TrackType.bass.rawValue, "Bass")
        XCTAssertEqual(TrackType.drums.rawValue, "Drums")
        XCTAssertEqual(TrackType.gesture.rawValue, "Gesture / Motion")
    }

    func testSequencerClipAndTrack() {
        let clip = SequencerClip(
            name: "Verse Lead",
            startTick: 0,
            durationTicks: 3840,
            notes: [RecordedNoteEvent(note: 60, velocity: 100, startTick: 0, durationTicks: 480)]
        )
        XCTAssertEqual(clip.name, "Verse Lead")
        XCTAssertEqual(clip.notes.count, 1)

        let track = TimelineTrack(
            name: "Melody Track",
            type: .melody,
            isMuted: false,
            isSolo: false,
            clips: [clip]
        )
        XCTAssertEqual(track.type, .melody)
        XCTAssertEqual(track.clips.count, 1)
    }

    func testSceneModel() {
        let scene = Scene(name: "Chorus", lengthBars: 8, tracks: [])
        XCTAssertEqual(scene.name, "Chorus")
        XCTAssertEqual(scene.lengthBars, 8)
    }

    // MARK: - Sequencer Engine Tests
    @MainActor
    func testSequencerTransport() {
        let sequencer = Sequencer()

        XCTAssertEqual(sequencer.scenes.count, 4)
        XCTAssertEqual(sequencer.scenes[0].name, "Intro")
        XCTAssertEqual(sequencer.scenes[1].name, "Verse")
        XCTAssertEqual(sequencer.scenes[2].name, "Chorus")
        XCTAssertEqual(sequencer.scenes[3].name, "Bridge")

        XCTAssertFalse(sequencer.transport.isPlaying)
        sequencer.play()
        XCTAssertTrue(sequencer.transport.isPlaying)

        XCTAssertFalse(sequencer.transport.isRecording)
        sequencer.toggleRecording()
        XCTAssertTrue(sequencer.transport.isRecording)

        sequencer.transport.currentTick = 0
        sequencer.recordNoteOn(note: 60, velocity: 100)
        sequencer.transport.currentTick = 480
        sequencer.recordNoteOff(note: 60)

        XCTAssertEqual(sequencer.recordedEvents.count, 1)
        XCTAssertEqual(sequencer.recordedEvents[0].note, 60)
        XCTAssertEqual(sequencer.recordedEvents[0].startTick, 0)
        XCTAssertEqual(sequencer.recordedEvents[0].durationTicks, 480)

        sequencer.stop()
        XCTAssertFalse(sequencer.transport.isPlaying)
        XCTAssertEqual(sequencer.transport.currentTick, 0)
    }
}
