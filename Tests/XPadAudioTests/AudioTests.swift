import XCTest
@testable import XPadCore
@testable import XPadTheory
@testable import XPadAudio

final class AudioTests: XCTestCase {

    // MARK: - SynthPreset Tests
    func testSynthPresets() {
        XCTAssertEqual(SynthPreset.allPresets.count, 5)

        let lead = SynthPreset.polyLead
        XCTAssertEqual(lead.osc1Type, .saw)
        XCTAssertEqual(lead.filterCutoffHz, 2800.0)

        let rhodes = SynthPreset.rhodesEP
        XCTAssertEqual(rhodes.osc1Type, .sine)

        let pad = SynthPreset.warmPad
        XCTAssertTrue(pad.attackSeconds > 0.1)

        let sub = SynthPreset.subBass
        XCTAssertTrue(sub.filterCutoffHz <= 1000.0)
    }

    // MARK: - VoiceDSP Tests
    func testVoiceDSPLifecycle() {
        let voice = VoiceDSP()
        XCTAssertFalse(voice.isActive)
        XCTAssertEqual(voice.envStage, 0)

        // Note On
        voice.noteOn(note: 60, velocity: 100)
        XCTAssertTrue(voice.isActive)
        XCTAssertTrue(voice.isKeyOn)
        XCTAssertEqual(voice.note, 60)
        XCTAssertTrue(voice.velocity > 0.7)
        XCTAssertEqual(voice.envStage, 1)

        // Note Off
        voice.noteOff()
        XCTAssertFalse(voice.isKeyOn)
        XCTAssertEqual(voice.envStage, 4)
    }

    // MARK: - AudioEngine Interface Tests
    func testAudioEngineControls() {
        let audio = AudioEngine.shared

        for preset in SynthPreset.allPresets {
            audio.setPreset(preset)
        }

        audio.noteOn(note: 60, velocity: 100)
        audio.noteOn(note: 64, velocity: 100)
        audio.noteOn(note: 67, velocity: 100)

        audio.setPitchBend(for: 60, semitones: 2.0)

        audio.noteOff(note: 60)
        audio.noteOff(note: 64)
        audio.noteOff(note: 67)

        audio.panic()
    }
}
