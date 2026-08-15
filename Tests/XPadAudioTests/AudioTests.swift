import Testing
import Foundation
@testable import XPadCore
@testable import XPadTheory
@testable import XPadAudio

@Suite("Exhaustive Audio Engine & DSP Tests")
struct AudioTests {

    // MARK: - SynthPreset Tests
    @Test("SynthPreset Factory Presets Completeness")
    func testSynthPresets() {
        #expect(SynthPreset.allPresets.count == 5)

        let lead = SynthPreset.polyLead
        #expect(lead.osc1Type == .saw)
        #expect(lead.filterCutoffHz == 2800.0)

        let rhodes = SynthPreset.rhodesEP
        #expect(rhodes.osc1Type == .sine)

        let pad = SynthPreset.warmPad
        #expect(pad.attackSeconds > 0.1)

        let sub = SynthPreset.subBass
        #expect(sub.filterCutoffHz <= 1000.0)
    }

    // MARK: - VoiceDSP Tests
    @Test("VoiceDSP Note Lifecycle & ADSR Envelope State Machine")
    func testVoiceDSPLifecycle() {
        let voice = VoiceDSP()
        #expect(!voice.isActive)
        #expect(voice.envStage == 0)

        // Note On
        voice.noteOn(note: 60, velocity: 100)
        #expect(voice.isActive)
        #expect(voice.isKeyOn)
        #expect(voice.note == 60)
        #expect(voice.velocity > 0.7)
        #expect(voice.envStage == 1) // Attack

        // Note Off
        voice.noteOff()
        #expect(!voice.isKeyOn)
        #expect(voice.envStage == 4) // Release
    }

    // MARK: - AudioEngine Interface Tests
    @Test("AudioEngine State and Preset Controls")
    func testAudioEngineControls() {
        let audio = AudioEngine.shared

        // Set Presets
        for preset in SynthPreset.allPresets {
            audio.setPreset(preset)
        }

        // Note On & Off
        audio.noteOn(note: 60, velocity: 100)
        audio.noteOn(note: 64, velocity: 100)
        audio.noteOn(note: 67, velocity: 100)

        // Pitch Bend
        audio.setPitchBend(for: 60, semitones: 2.0)

        // Note Off
        audio.noteOff(note: 60)
        audio.noteOff(note: 64)
        audio.noteOff(note: 67)

        // Panic
        audio.panic()
    }
}
