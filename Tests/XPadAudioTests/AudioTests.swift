import XCTest
@testable import XPadCore
@testable import XPadTheory
@testable import XPadAudio

final class AudioTests: XCTestCase {

    // MARK: - SynthPreset Tests
    func testSynthPresets() {
        XCTAssertEqual(SynthPreset.allPresets.count, 8)

        let lead = SynthPreset.polyLead
        XCTAssertEqual(lead.osc1Type, .saw)
        XCTAssertEqual(lead.osc2Type, .square)
        XCTAssertEqual(lead.filterCutoffHz, 3200.0)
        XCTAssertEqual(lead.filterType, .lowPass)
        XCTAssertGreaterThan(lead.filterResonance, 0)
        XCTAssertGreaterThan(lead.saturationAmount, 0)

        let rhodes = SynthPreset.rhodesEP
        XCTAssertEqual(rhodes.osc1Type, .sine)

        let pad = SynthPreset.warmPad
        XCTAssertTrue(pad.attack > 0.1)
        XCTAssertEqual(pad.id, "warmPad")

        let sub = SynthPreset.subBass
        XCTAssertTrue(sub.filterCutoffHz <= 1000.0)

        let brass = SynthPreset.analogBrass
        XCTAssertEqual(brass.osc1Type, .saw)
        XCTAssertGreaterThan(brass.filterResonance, 0.4)

        let bell = SynthPreset.digitalBell
        XCTAssertEqual(bell.filterType, .lowPass)
        XCTAssertGreaterThan(bell.osc2DetuneCents, 15)
    }

    func testPresetParametersAreSensible() {
        for preset in SynthPreset.allPresets {
            XCTAssertTrue(preset.attack >= 0, "Attack should be non-negative for \(preset.name)")
            XCTAssertTrue(preset.decay >= 0, "Decay should be non-negative for \(preset.name)")
            XCTAssertTrue(preset.sustain >= 0 && preset.sustain <= 1, "Sustain should be 0-1 for \(preset.name)")
            XCTAssertTrue(preset.release >= 0, "Release should be non-negative for \(preset.name)")
            XCTAssertTrue(preset.filterCutoffHz > 0, "Cutoff should be positive for \(preset.name)")
            XCTAssertTrue(preset.filterResonance >= 0 && preset.filterResonance <= 0.95, "Resonance should be 0-0.95 for \(preset.name)")
            XCTAssertTrue(preset.osc2Level >= 0 && preset.osc2Level <= 1, "osc2Level should be 0-1 for \(preset.name)")
            XCTAssertTrue(preset.osc2DetuneCents >= 0, "Detune should be non-negative for \(preset.name)")
            XCTAssertTrue(preset.saturationAmount >= 0 && preset.saturationAmount <= 1, "Saturation should be 0-1 for \(preset.name)")
        }
    }

    func testFilterTypeEnum() {
        let types: [FilterType] = [.lowPass, .highPass, .bandPass]
        XCTAssertEqual(types.count, 3)
        XCTAssertEqual(types.map { $0.rawValue }, ["Low Pass", "High Pass", "Band Pass"])
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

    func testFirstBufferGateFiresOnce() {
        let gate = FirstBufferGate()
        let expectation = expectation(description: "first buffer")
        var times: [TimeInterval] = []
        gate.arm { t in
            times.append(t)
            expectation.fulfill()
        }
        gate.signalIfNeeded()
        gate.signalIfNeeded()
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(times.count, 1)
        XCTAssertGreaterThan(times[0], 0)
    }
}
