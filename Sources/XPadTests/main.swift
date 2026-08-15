import Foundation
import XPadCore
import XPadTheory
import XPadController
import XPadMIDI
import XPadAudio
import XPadSequencer

@MainActor
final class TestRunner {
    var totalTests = 0
    var passedTests = 0
    var failedTests = 0

    func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String = "", file: String = #file, line: Int = #line) {
        if actual != expected {
            print("  ❌ FAIL [\(URL(fileURLWithPath: file).lastPathComponent):\(line)]: expected \(expected), got \(actual). \(message)")
            failedTests += 1
        }
    }

    func assertTrue(_ condition: Bool, _ message: String = "", file: String = #file, line: Int = #line) {
        if !condition {
            print("  ❌ FAIL [\(URL(fileURLWithPath: file).lastPathComponent):\(line)]: Condition was false. \(message)")
            failedTests += 1
        }
    }

    func assertFalse(_ condition: Bool, _ message: String = "", file: String = #file, line: Int = #line) {
        if condition {
            print("  ❌ FAIL [\(URL(fileURLWithPath: file).lastPathComponent):\(line)]: Condition was true. \(message)")
            failedTests += 1
        }
    }

    func assertNotNil<T>(_ value: T?, _ message: String = "", file: String = #file, line: Int = #line) {
        if value == nil {
            print("  ❌ FAIL [\(URL(fileURLWithPath: file).lastPathComponent):\(line)]: Expected non-nil value. \(message)")
            failedTests += 1
        }
    }

    func test(_ name: String, block: () throws -> Void) {
        totalTests += 1
        let previousFailures = failedTests
        do {
            try block()
            if failedTests == previousFailures {
                passedTests += 1
                print("  ✅ PASS: \(name)")
            } else {
                print("  ❌ FAIL: \(name)")
            }
        } catch {
            failedTests += 1
            print("  💥 ERROR: \(name) threw exception: \(error)")
        }
    }

    func suite(_ name: String, block: () -> Void) {
        print("\n📦 Test Suite: \(name)")
        print("--------------------------------------------------")
        block()
    }

    func run() {
        print("==================================================")
        print("🚀 Running Exhaustive Test Suites for XPadInput")
        print("==================================================")

        // MARK: - Core Tests
        suite("XPadCore: PitchClass, Interval, Note, Scale, Chord") {
            test("PitchClass Raw Values & Modulo Math") {
                assertEqual(PitchClass.allCases.count, 12)
                assertEqual(PitchClass.c.rawValue, 0)
                assertEqual(PitchClass.b.rawValue, 11)
                assertEqual(PitchClass.c.transposed(by: 4), .e)
                assertEqual(PitchClass.c.transposed(by: 7), .g)
                assertEqual(PitchClass.c.transposed(by: -1), .b)
                assertEqual(PitchClass.c.transposed(by: -13), .b)
                assertEqual(PitchClass.c.semitones(to: .g), 7)
                assertEqual(PitchClass.g.semitones(to: .c), 5)
            }

            test("PitchClass Circle of Fifths Indices") {
                assertEqual(PitchClass.c.circleOfFifthsIndex, 0)
                assertEqual(PitchClass.g.circleOfFifthsIndex, 1)
                assertEqual(PitchClass.d.circleOfFifthsIndex, 2)
                assertEqual(PitchClass.a.circleOfFifthsIndex, 3)
                assertEqual(PitchClass.e.circleOfFifthsIndex, 4)
                assertEqual(PitchClass.b.circleOfFifthsIndex, 5)
                assertEqual(PitchClass.fSharp.circleOfFifthsIndex, 6)
                assertEqual(PitchClass.cSharp.circleOfFifthsIndex, 7)
                assertEqual(PitchClass.gSharp.circleOfFifthsIndex, 8)
                assertEqual(PitchClass.dSharp.circleOfFifthsIndex, 9)
                assertEqual(PitchClass.aSharp.circleOfFifthsIndex, 10)
                assertEqual(PitchClass.f.circleOfFifthsIndex, 11)
            }

            test("Interval Constants & Names") {
                assertEqual(Interval.unison.semitones, 0)
                assertEqual(Interval.unison.shortName, "P1")
                assertEqual(Interval.minorThird.shortName, "m3")
                assertEqual(Interval.majorThird.shortName, "M3")
                assertEqual(Interval.perfectFifth.shortName, "P5")
                assertEqual(Interval.tritone.shortName, "TT")
                assertEqual(Interval.octave.shortName, "P8")
                assertEqual(Interval.majorNinth.shortName, "M9")
                assertTrue(Interval.minorThird < Interval.majorThird)
            }

            test("Note Frequencies & Standard Pitches") {
                let a4 = Note(midiNumber: 69)
                assertEqual(a4.pitchClass, .a)
                assertEqual(a4.octave, 4)
                assertEqual(a4.name, "A4")
                assertTrue(abs(a4.frequency - 440.0) < 0.001)

                let c4 = Note.c4
                assertEqual(c4.midiNumber, 60)
                assertEqual(c4.name, "C4")

                let transposed = c4.transposed(by: 7)
                assertEqual(transposed.midiNumber, 67)
                assertEqual(transposed.pitchClass, .g)
            }

            test("Scale Construction & Quantization") {
                let cMajor = Scale.cMajor
                let expected: [PitchClass] = [.c, .d, .e, .f, .g, .a, .b]
                assertEqual(cMajor.pitchClasses, expected)
                assertTrue(cMajor.contains(PitchClass.c))
                assertTrue(cMajor.contains(Note.c4))
                assertFalse(cMajor.contains(PitchClass.cSharp))

                assertEqual(cMajor.snapToScale(.c), .c)
                let snapped = cMajor.snapToScale(.cSharp)
                assertTrue(snapped == .c || snapped == .d)
            }

            test("Chord Voicings, Inversions & Styles") {
                let cMaj = Chord(root: .c, quality: .major, inversion: .root)
                assertEqual(cMaj.symbol, "C")
                let notes = cMaj.voicedNotes(baseOctave: 3)
                assertEqual(notes.map { $0.midiNumber }, [48, 52, 55])

                var inv1 = cMaj
                inv1.inversion = .first
                assertEqual(inv1.voicedNotes(baseOctave: 3).map { $0.midiNumber }, [52, 55, 60])

                let drop2 = Chord(root: .c, quality: .major7, voicingStyle: .drop2)
                assertEqual(drop2.voicedNotes(baseOctave: 3).count, 4)

                let acoustic = Chord(root: .c, quality: .major, voicingStyle: .guitarAcoustic)
                assertEqual(acoustic.voicedNotes(baseOctave: 3).count, 5)

                let shell = Chord(root: .c, quality: .major7, voicingStyle: .shellJazz)
                assertEqual(shell.voicedNotes(baseOctave: 3).count, 3)
            }

            test("PerformanceEvent & TransportState Math") {
                var transport = TransportState(bpm: 120.0, timeSignatureNumerator: 4)
                assertEqual(transport.currentBar, 1)
                assertTrue(abs(transport.currentBeat - 1.0) < 0.001)

                transport.currentTick = 3840
                assertEqual(transport.currentBar, 2)
                assertTrue(abs(transport.currentBeat - 1.0) < 0.001)
            }
        }

        // MARK: - Theory Tests
        suite("XPadTheory: Wheel, Voice Leading, Suggestions, Modulation, Progression") {
            test("Harmonic Wheel 5-Layer Layout") {
                let wheel = HarmonicWheel(scale: .cMajor)
                for layer in WheelLayer.allCases {
                    assertNotNil(wheel.sectorsByLayer[layer])
                    assertFalse(wheel.sectorsByLayer[layer]?.isEmpty ?? true)
                }
                let diatonic = wheel.sectorsByLayer[.diatonic] ?? []
                assertEqual(diatonic.count, 7)
                assertEqual(diatonic[0].chord.symbol, "C")
                assertEqual(diatonic[4].chord.symbol, "G")

                let north = wheel.sector(forAngle: -Double.pi / 2.0, layer: .diatonic)
                assertNotNil(north)
                assertEqual(north?.chord.root, .c)
            }

            test("Voice Leading Optimization & Minimal Motion") {
                let engine = VoiceLeadingEngine()
                let cMaj = Chord(root: .c, quality: .major)
                let aMin = Chord(root: .a, quality: .minor)

                let cVoicing = cMaj.voicedNotes(baseOctave: 3)
                let aVoicing = engine.optimizeTransition(from: cVoicing, to: aMin, strategy: .smooth)

                let common = Set(aVoicing.map { $0.pitchClass }).intersection([.c, .e])
                assertEqual(common.count, 2)
            }

            test("Harmonic Suggestion Engine Ranking") {
                let engine = HarmonicSuggestionEngine()
                let suggestions = engine.suggestions(for: Chord(root: .c, quality: .major), in: .cMajor)
                assertFalse(suggestions.isEmpty)
                assertTrue(suggestions.contains(where: { $0.category == .resolution }))
                assertTrue(suggestions.contains(where: { $0.category == .cinematic }))
            }

            test("Modulation Pathways (ii-V-I and Mediant)") {
                let engine = ModulationEngine()
                let paths = engine.pathways(from: .cMajor, to: Scale(root: .g, type: .major))
                assertFalse(paths.isEmpty)
                assertTrue(paths.contains(where: { $0.type == .dominantCycle }))
            }

            test("Progression Presets & Mutation") {
                let presets = Progression.factoryPresets(for: .cMajor)
                assertTrue(presets.count >= 3)
                let mutated = presets[0].mutated(complexity: 0.5, preserveRoots: true)
                assertEqual(mutated.blocks.count, presets[0].blocks.count)
            }
        }

        // MARK: - Controller Tests
        suite("XPadController: StickCoordinates, Strummer, RhythmCompass, GestureRecorder") {
            test("StickCoordinates Deadzone & Radius Clamping") {
                let dead = StickCoordinates(x: 0.05, y: 0.05, deadzone: 0.12)
                assertEqual(dead.radius, 0.0)
                assertFalse(dead.isActive)

                let full = StickCoordinates(x: 1.0, y: 0.0, deadzone: 0.12)
                assertEqual(full.radius, 1.0)
                assertTrue(full.isActive)
                assertTrue(abs(full.angle) < 0.001)
            }

            test("Virtual Strummer Dynamic Velocity & Strum Direction") {
                let strummer = VirtualStrummer()
                let notes = Chord(root: .c, quality: .major).voicedNotes()

                _ = strummer.processStick(x: 0.0, y: 0.8, triggerMute: 0.0, chordNotes: notes, timestamp: 1.0)
                let down = strummer.processStick(x: 0.0, y: -0.8, triggerMute: 0.0, chordNotes: notes, timestamp: 1.05)
                assertNotNil(down)
                assertEqual(down?.direction, .down)
                assertEqual(down?.notes.count, notes.count)
                assertTrue((down?.velocity ?? 0) >= 40)

                let up = strummer.processStick(x: 0.0, y: 0.8, triggerMute: 0.0, chordNotes: notes, timestamp: 1.10)
                assertNotNil(up)
                assertEqual(up?.direction, .up)
                assertEqual(up?.notes.first?.note, notes.last)

                let mute = strummer.processStick(x: 0.0, y: -0.8, triggerMute: 0.8, chordNotes: notes, timestamp: 1.15)
                assertNotNil(mute)
                assertEqual(mute?.direction, .muted)
            }

            test("Rhythm Compass 8-Directional Mapping") {
                let engine = RhythmCompassEngine()
                let north = StickCoordinates(x: 0.0, y: 1.0, deadzone: 0.1)
                let (sub, intensity, isPlaying) = engine.evaluate(stick: north)
                assertTrue(isPlaying)
                assertEqual(sub, .quarter)
                assertEqual(intensity, 1.0)
                assertEqual(RhythmicSubdivision.sixteenth.ticksPerStep, 240)
            }

            test("Gesture Recorder Capture Lifecycle") {
                let recorder = GestureRecorder()
                assertFalse(recorder.stopRecording() != nil)

                recorder.startRecording()
                var state = GamepadState()
                state.buttonA = true
                recorder.recordSample(state: state)

                state.rightTrigger = 1.0
                recorder.recordSample(state: state)

                let clip = recorder.stopRecording()
                assertNotNil(clip)
                assertEqual(clip?.samples.count, 2)
            }

            test("ControllerManager Simulation Injection") {
                let manager = ControllerManager()
                var changed = false
                manager.onStateChanged = { _ in changed = true }
                manager.injectSimulatedState { s in s.buttonA = true }
                assertTrue(changed)
                assertTrue(manager.currentState.buttonA)
            }
        }

        // MARK: - MIDI Tests
        suite("XPadMIDI: MIDIManager, MPEManager, SMFExporter") {
            test("Virtual Ports Identification") {
                assertEqual(VirtualPort.allCases.count, 6)
                assertEqual(VirtualPort.main.rawValue, "XPadInput Main")
                assertEqual(VirtualPort.mpe.rawValue, "XPadInput Expression (MPE)")
            }

            test("MIDIManager Message Dispatching & Panic") {
                let midi = MIDIManager.shared
                midi.sendNoteOn(port: .main, channel: 0, note: 60, velocity: 100)
                midi.sendPitchBend(port: .main, channel: 0, semitoneOffset: 2.0)
                midi.sendPolyPressure(port: .main, channel: 0, note: 60, pressure: 80)
                midi.sendNoteOff(port: .main, channel: 0, note: 60)
                midi.panic()
            }

            test("MPEManager Voice Lifecycle") {
                let mpe = MPEManager(midiManager: MIDIManager.shared)
                mpe.sendMPEZoneConfiguration()
                mpe.noteOn(note: 60, velocity: 100)
                mpe.setPitchBend(for: 60, semitones: 2.0)
                mpe.setTimbre(for: 60, value: 90)
                mpe.noteOff(note: 60)
                mpe.stopAllNotes()
            }

            test("SMFExporter MIDI File Binary Structure") {
                let exporter = SMFExporter()
                let events = [
                    RecordedNoteEvent(note: 60, velocity: 100, startTick: 0, durationTicks: 480),
                    RecordedNoteEvent(note: 64, velocity: 110, startTick: 480, durationTicks: 480)
                ]
                let data = exporter.encode(events: events, bpm: 120.0, ppqn: 480)
                assertTrue(data.count > 30)
                let header = Array(data[0..<4])
                assertEqual(header, [0x4D, 0x54, 0x68, 0x64]) // "MThd"
            }
        }

        // MARK: - Audio Tests
        suite("XPadAudio: SynthPreset, VoiceDSP, AudioEngine") {
            test("SynthPreset Factory Collection") {
                assertEqual(SynthPreset.allPresets.count, 5)
                assertEqual(SynthPreset.polyLead.osc1Type, .saw)
                assertEqual(SynthPreset.rhodesEP.osc1Type, .sine)
            }

            test("VoiceDSP ADSR Envelope State Machine") {
                let voice = VoiceDSP()
                assertFalse(voice.isActive)
                voice.noteOn(note: 60, velocity: 100)
                assertTrue(voice.isActive)
                assertEqual(voice.envStage, 1) // Attack
                voice.noteOff()
                assertEqual(voice.envStage, 4) // Release
            }

            test("AudioEngine Preset & Playback Controls") {
                let audio = AudioEngine.shared
                for preset in SynthPreset.allPresets {
                    audio.setPreset(preset)
                }
                audio.noteOn(note: 60, velocity: 100)
                audio.setPitchBend(for: 60, semitones: 1.0)
                audio.noteOff(note: 60)
                audio.panic()
            }
        }

        // MARK: - Sequencer Tests
        suite("XPadSequencer: Track, Clip, Scene, Transport, Recording") {
            test("Sequencer Data Models") {
                assertEqual(TrackType.allCases.count, 5)
                let clip = SequencerClip(name: "Test Clip", startTick: 0, durationTicks: 3840)
                assertEqual(clip.name, "Test Clip")
                let track = TimelineTrack(name: "Chords", type: .chords, clips: [clip])
                assertEqual(track.type, .chords)
                let scene = Scene(name: "Verse", lengthBars: 4, tracks: [track])
                assertEqual(scene.name, "Verse")
            }

            test("Sequencer Transport Lifecycle & Note Recording") {
                let sequencer = Sequencer()
                assertEqual(sequencer.scenes.count, 4)
                assertFalse(sequencer.transport.isPlaying)
                sequencer.play()
                assertTrue(sequencer.transport.isPlaying)

                sequencer.toggleRecording()
                assertTrue(sequencer.transport.isRecording)

                sequencer.transport.currentTick = 0
                sequencer.recordNoteOn(note: 60, velocity: 100)
                sequencer.transport.currentTick = 480
                sequencer.recordNoteOff(note: 60)

                assertEqual(sequencer.recordedEvents.count, 1)
                assertEqual(sequencer.recordedEvents[0].note, 60)
                assertEqual(sequencer.recordedEvents[0].durationTicks, 480)

                sequencer.stop()
                assertFalse(sequencer.transport.isPlaying)
            }
        }

        // MARK: - Final Summary
        print("\n==================================================")
        print("📊 Test Execution Summary")
        print("==================================================")
        print("  Total Tests Run: \(totalTests)")
        print("  Passed:          \(passedTests)")
        print("  Failed:          \(failedTests)")
        print("==================================================")

        if failedTests == 0 {
            print("🎉 ALL \(totalTests) TESTS PASSED SUCCESSFULLY! (100% PASS RATE)\n")
        } else {
            print("❌ SOME TESTS FAILED.\n")
            exit(1)
        }
    }
}

TestRunner().run()
