import XCTest
@testable import XPadCore

final class InstrumentTechniqueTests: XCTestCase {
    func testTechniquePlayLabelsHideWhenNormal() {
        XCTAssertNil(MusicalTechnique.normal.playLabel)
        XCTAssertEqual(MusicalTechnique.hammerOn.playLabel, "Hammer-On")
        XCTAssertEqual(MusicalTechnique.bend.displayName, "Bend")
        XCTAssertTrue(MusicalTechnique.slideUp.isSlideFamily)
        XCTAssertTrue(MusicalTechnique.pinchHarmonic.isHarmonicFamily)
    }

    func testGuitarProfileSupportsIdiomaticTechniques() {
        let guitar = InstrumentProfile.guitar
        XCTAssertEqual(guitar.preferredPitchBendRange, 2.0)
        XCTAssertTrue(guitar.supportsHammerOns)
        XCTAssertTrue(guitar.supportsPitchBend)
        XCTAssertTrue(guitar.supportsPinchHarmonics)
        XCTAssertTrue(guitar.supportsStrumming)
        XCTAssertEqual(guitar.defaultGestureMapping.rightStick, "Strum / Bend")
        XCTAssertEqual(guitar.defaultGestureMapping.l2, "Mute")
        XCTAssertEqual(guitar.defaultGestureMapping.r2, "Pressure")
    }

    func testKeysProfileDoesNotInventGuitarTechniques() {
        let keys = InstrumentProfile.keys
        XCTAssertFalse(keys.supportsHammerOns)
        XCTAssertFalse(keys.supportsPitchBend)
        XCTAssertFalse(keys.supportsPinchHarmonics)
        XCTAssertTrue(keys.supports(.aftertouch))
        XCTAssertTrue(keys.supports(.sustain))
    }

    func testSynthLeadUsesBendAndTimbreNotStrum() {
        let lead = InstrumentProfile.synthLead
        XCTAssertFalse(lead.supportsStrumming)
        XCTAssertTrue(lead.supportsPitchBend)
        XCTAssertEqual(lead.defaultGestureMapping.rightStick, "Bend / Timbre")
        XCTAssertEqual(lead.preferredPitchBendRange, 12.0)
    }

    func testDestinationFallbacks() {
        let midi = DestinationCapabilityProfile.genericMIDI
        let pressure = midi.resolvedPressureMode(preferred: .mpePressure)
        XCTAssertEqual(pressure.mode, .channelPressure)
        XCTAssertNotNil(pressure.fallback)

        let slide = midi.resolvedSlideStrategy(preferred: .mpePitch)
        XCTAssertEqual(slide.strategy, .pitchBend)
        XCTAssertFalse(midi.canBendIndependently(activeVoiceCount: 4))
        XCTAssertTrue(DestinationCapabilityProfile.genericMPE.canBendIndependently(activeVoiceCount: 4))
    }

    func testPerformanceEventDimensions() {
        let event = InstrumentPerformanceEvent(
            note: .middleC,
            technique: .hammerOn,
            velocity: 72,
            pressure: 0.41,
            timbre: 0.62
        )
        XCTAssertEqual(event.note.midiNote, 60)
        XCTAssertEqual(event.technique, .hammerOn)
        XCTAssertEqual(event.expression.midiPressure, 52)
    }

    func testChordToneRoles() {
        let dMinor = Chord(root: .d, quality: .minor)
        XCTAssertEqual(dMinor.pitchClass(for: .root), .d)
        XCTAssertEqual(dMinor.pitchClass(for: .third), .f)
        XCTAssertEqual(dMinor.pitchClass(for: .fifth), .a)
        XCTAssertEqual(dMinor.pitchClass(for: .seventh), .c)
    }
}
