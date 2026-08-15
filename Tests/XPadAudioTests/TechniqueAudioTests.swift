import XCTest
@testable import XPadCore
@testable import XPadAudio

final class TechniqueAudioTests: XCTestCase {
    func testPitchBendDoesNotRetrigger() {
        let audio = AudioEngine()
        audio.start()
        audio.noteOn(note: 64, velocity: 80)
        audio.setPitchBend(for: 64, semitones: 2)
        XCTAssertEqual(audio.currentPitchBend(for: 64) ?? 0, 2, accuracy: 0.001)
        audio.setPitchBend(for: 64, semitones: 0)
        XCTAssertEqual(audio.currentPitchBend(for: 64) ?? 1, 0, accuracy: 0.001)
        audio.noteOff(note: 64)
        audio.stop()
    }

    func testPressureAndMuteApplyToVoice() {
        let audio = AudioEngine()
        audio.start()
        audio.noteOn(note: 60, velocity: 40, technique: .normal)
        audio.setPressure(for: 60, pressure: 0.8)
        audio.setDamping(for: 60, damping: 0.7)
        audio.applyExpression(InstrumentPerformanceEvent(
            note: .middleC,
            technique: .pinchHarmonic,
            velocity: 110,
            pitchOffset: 0
        ))
        audio.panic()
        audio.stop()
    }

    func testPanicStopsAnExistingReleaseTail() {
        let audio = AudioEngine()
        audio.start()
        audio.noteOn(note: 60, velocity: 80)
        audio.noteOff(note: 60)

        XCTAssertEqual(audio.trackedVoiceCount, 1)
        audio.panic()
        XCTAssertEqual(audio.trackedVoiceCount, 0)
        audio.stop()
    }
}
