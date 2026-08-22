import XCTest
@testable import XPadCore
@testable import XPadMIDI

final class TechniqueTranslationTests: XCTestCase {
    func testMPEBendIsolation() {
        let midi = MIDIEngine()
        let mpe = MPEManager(midiEngine: midi, bendRangeSemitones: 48)
        mpe.noteOn(note: 64, velocity: 90)
        mpe.noteOn(note: 67, velocity: 90)
        mpe.setPitchBend(for: 64, semitones: 2)
        XCTAssertEqual(mpe.voice(for: 64)?.currentPitchBend ?? 0, 2, accuracy: 0.001)
        XCTAssertEqual(mpe.voice(for: 67)?.currentPitchBend ?? -1, 0, accuracy: 0.001)
        XCTAssertEqual(mpe.activeVoiceCount, 2)
        mpe.noteOff(note: 64)
        XCTAssertNil(mpe.voice(for: 64))
        mpe.stopAllNotes()
        XCTAssertEqual(mpe.activeVoiceCount, 0)
    }

    func testPitchBendCentreAndRange() {
        XCTAssertEqual(PitchBendCodec.value(semitones: 0, range: 48), 8192)
        XCTAssertGreaterThan(PitchBendCodec.value(semitones: 2, range: 48), 8192)
        XCTAssertLessThan(PitchBendCodec.value(semitones: 2, range: 48), PitchBendCodec.value(semitones: 48, range: 48))
        XCTAssertEqual(PitchBendCodec.value(semitones: -48, range: 48), 0)
    }

    func testHammerOnTranslationUsesNoteOn() {
        let translator = TechniqueMIDITranslator(destination: .genericMPE, profile: .guitar)
        let result = translator.translate(
            InstrumentPerformanceEvent(
                note: Note(pitchClass: .g, octave: 4),
                phase: .began,
                technique: .hammerOn,
                velocity: 80
            ),
            memberChannel: 3
        )
        XCTAssertEqual(result.technique, .hammerOn)
        XCTAssertTrue(result.events.contains(where: {
            if case .noteOn(_, let note, let vel) = $0 { return note == 67 && vel < 80 }
            return false
        }))
    }

    func testPinchHarmonicUsesConfiguredStrategy() {
        var translator = TechniqueMIDITranslator(destination: .genericMPE, profile: .guitar)
        translator.profile.midiArticulationStrategy = .mpeTimbre
        let result = translator.translate(
            InstrumentPerformanceEvent(
                note: Note(pitchClass: .e, octave: 4),
                phase: .began,
                technique: .pinchHarmonic,
                velocity: 110
            ),
            memberChannel: 2
        )
        XCTAssertEqual(result.strategyUsed, .mpeTimbre)
        XCTAssertTrue(result.events.contains(where: {
            if case .timbreCC74(_, let value) = $0 { return value > 90 }
            return false
        }))
    }

    func testConventionalMIDIBlocksPerNoteChordBend() {
        let translator = TechniqueMIDITranslator(destination: .genericMIDI, profile: .guitar)
        let blocked = translator.translateBend(semitones: 2, channel: 0, activeVoiceCount: 4)
        XCTAssertEqual(blocked?.events.count, 0)
        XCTAssertNotNil(blocked?.fallbackDescription)
    }

    func testPressureFallbackToChannelPressure() {
        let translator = TechniqueMIDITranslator(destination: .genericMIDI, profile: .guitar)
        let result = translator.translate(
            InstrumentPerformanceEvent(note: .middleC, technique: .aftertouch, pressure: 0.5)
        )
        XCTAssertEqual(result.pressureMode, .channelPressure)
        XCTAssertTrue(result.events.contains(where: {
            if case .channelPressure(_, let p) = $0 { return p > 0 }
            return false
        }))
    }

    func testCC11ReleaseRestoresFullExpressionInsteadOfSilence() {
        let destination = DestinationCapabilityProfile(
            name: "CC11 Only",
            supportsMPE: false,
            supportsChannelPressure: false,
            supportsPolyPressure: false,
            bendRangeSemitones: 2,
            supportsCC74: false,
            supportsKeyswitchArticulations: false,
            supportsPortamento: false,
            supportsLegatoOverlap: true,
            pressureMode: .cc11
        )
        let translator = TechniqueMIDITranslator(
            destination: destination,
            profile: .guitar
        )

        let release = translator.translate(
            InstrumentPerformanceEvent(
                note: .middleC,
                phase: .ended,
                technique: .normal
            )
        )

        XCTAssertTrue(release.events.contains(
            .controlChange(channel: 0, controller: 11, value: 127)
        ))
        XCTAssertFalse(release.events.contains { event in
            if case .channelPressure = event { return true }
            return false
        })
    }

    func testLegatoRetriggerReleaseStopsTargetNote() {
        var profile = InstrumentProfile.guitar
        profile.slideMIDIStrategy = .legatoRetrigger
        let translator = TechniqueMIDITranslator(
            destination: .genericMIDI,
            profile: profile
        )
        let target = Note(pitchClass: .g, octave: 4)

        let release = translator.translate(
            InstrumentPerformanceEvent(
                note: Note(pitchClass: .e, octave: 4),
                targetNote: target,
                phase: .ended,
                technique: .slideUp
            )
        )

        XCTAssertTrue(release.events.contains(
            .noteOff(channel: 0, note: target.midiNote)
        ))
    }

    func testHarmonicMIDINoteReleaseClosesAuxiliaryPitch() {
        var profile = InstrumentProfile.guitar
        profile.midiArticulationStrategy = .midiNote
        let translator = TechniqueMIDITranslator(
            destination: .genericMIDI,
            profile: profile
        )
        let note = Note(pitchClass: .e, octave: 4)

        let release = translator.translate(
            InstrumentPerformanceEvent(
                note: note,
                phase: .ended,
                technique: .harmonic
            )
        )

        XCTAssertTrue(release.events.contains(
            .noteOff(channel: 0, note: note.transposed(by: 12).midiNote)
        ))
    }

    func testRecorderClosesOriginalNoteBeforeRegisterRetarget() {
        let recorder = TechniqueRecorder()
        let low = Note(pitchClass: .d, octave: 2)
        let high = Note(pitchClass: .d, octave: 4)
        recorder.start()

        recorder.record(
            InstrumentPerformanceEvent(note: low, phase: .began, velocity: 96),
            tick: 100
        )
        recorder.recordNoteOff(note: low.midiNote, tick: 120)
        recorder.record(
            InstrumentPerformanceEvent(note: high, phase: .began, velocity: 96),
            tick: 120
        )
        recorder.recordNoteOff(note: high.midiNote, tick: 160)

        let events = recorder.stop()
        XCTAssertEqual(events.map(\.event.note), [low, high])
        XCTAssertEqual(events.map(\.durationTicks), [20, 40])
    }

    func testTechniqueExportProducesSMF() {
        let exporter = SMFExporter()
        let events = [
            RecordedTechniqueEvent(
                tick: 0,
                event: InstrumentPerformanceEvent(note: .middleC, technique: .bend, velocity: 90, pitchOffset: 2),
                durationTicks: 480
            )
        ]
        let data = exporter.encodeTechniques(events: events, bpm: 120, ppqn: 960)
        XCTAssertEqual(Array(data[0..<4]), [0x4D, 0x54, 0x68, 0x64])
        XCTAssertEqual(Array(data.suffix(3)), [0xFF, 0x2F, 0x00])
    }
}
