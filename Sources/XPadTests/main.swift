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
            }
        } catch {
            failedTests += 1
            print("  ❌ ERROR: \(name) threw exception: \(error)")
        }
    }

    func suite(_ name: String, block: () -> Void) {
        print("\n=== Running Suite: \(name) ===")
        block()
    }

    func run() {
        print("==================================================")
        print("🎮 XPadInput Comprehensive Test Suite Runner")
        print("==================================================")

        // MARK: - Core Domain Tests
        suite("XPadCore: PitchClass, Note, Interval, Scale, Chord, PerformanceEvent") {
            test("PitchClass Transposition & Semitones") {
                let c = PitchClass.c
                let g = c.transposed(by: 7)
                assertEqual(g, PitchClass.g)
                assertEqual(c.semitones(to: g), 7)
                assertEqual(c.circleOfFifthsIndex, 0)
                assertEqual(g.circleOfFifthsIndex, 1)

                let common = PitchClass.commonTones([.c, .e, .g], [.g, .b, .d])
                assertEqual(common, [.g])
            }

            test("Note Frequency, MIDI Mapping, and Math") {
                let a4 = Note(pitchClass: .a, octave: 4)
                assertEqual(a4.midiNumber, 69)
                assertEqual(round(a4.frequency * 10) / 10, 440.0)

                let middleC = Note.middleC
                assertEqual(middleC.midiNumber, 60)
                assertEqual(middleC.name, "C4")

                let c5 = middleC.transposed(by: 12)
                assertEqual(c5.octave, 5)
                assertEqual(c5.midiNumber, 72)
            }

            test("Interval Constants & Names") {
                assertEqual(Interval.unison.rawValue, 0)
                assertEqual(Interval.unison.shortName, "P1")
                assertEqual(Interval.minorThird.shortName, "m3")
                assertEqual(Interval.perfectFifth.semitones, 7)
                assertTrue(Interval.perfectFifth.consonance > Interval.tritone.consonance)
            }

            test("Scale Construction & Pitch Classes") {
                let cMaj = Scale.cMajor
                assertEqual(cMaj.root, .c)
                assertEqual(cMaj.type, .major)
                assertEqual(cMaj.pitchClasses, [.c, .d, .e, .f, .g, .a, .b])
                assertTrue(cMaj.contains(.c))
                assertTrue(cMaj.contains(.g))
                assertFalse(cMaj.contains(.fSharp))
                assertEqual(cMaj.degree(of: .g), 5)
                assertEqual(cMaj.degree(of: .fSharp), nil)

                let aMin = Scale.aMinor
                assertEqual(aMin.root, .a)
                assertEqual(aMin.type, .naturalMinor)
                assertEqual(aMin.pitchClasses, [.a, .b, .c, .d, .e, .f, .g])
            }

            test("Chord Voicing, Inversion & Voice Leading Distance") {
                let cMaj = Chord(root: .c, quality: .major)
                assertEqual(cMaj.symbol, "C")
                assertEqual(cMaj.pitchClasses, [.c, .e, .g])

                let rootNotes = cMaj.voicedNotes(baseOctave: 3)
                assertEqual(rootNotes.map { $0.midiNumber }, [48, 52, 55])

                let firstInv = Chord(root: .c, quality: .major, inversion: 1)
                let firstInvNotes = firstInv.voicedNotes(baseOctave: 3)
                assertEqual(firstInvNotes.map { $0.midiNumber }, [52, 55, 60])

                let aMin = Chord(root: .a, quality: .minor)
                let dist = cMaj.voiceLeadingDistance(to: aMin)
                assertTrue(dist > 0)
            }

            test("PerformanceEvent Serialization & Timing") {
                let event = PerformanceEvent(type: .noteOn, note: 60, velocity: 100, timestamp: 1.25)
                assertEqual(event.type, .noteOn)
                assertEqual(event.note, 60)
                assertEqual(event.velocity, 100)
                assertEqual(event.timestamp, 1.25)
            }
        }

        // MARK: - Theory Tests
        suite("XPadTheory: HarmonicWheel, VoiceLeading, Suggestions, Modulations") {
            test("Harmonic Degree Roman Numerals & Functions") {
                let numeralI = RomanNumeral.I
                assertEqual(numeralI.rawValue, "I")
                let numeralV = RomanNumeral.V
                assertEqual(numeralV.rawValue, "V")
                let degree = HarmonicDegree(romanNumeral: .I, chord: Chord(root: .c, quality: .major), harmonicFunction: "Tonic", description: "Tonic chord")
                assertEqual(degree.romanNumeral, .I)
                assertEqual(degree.harmonicFunction, "Tonic")
            }

            test("Harmonic Wheel Multi-Layer Sector Mapping") {
                let wheel = HarmonicWheel(scale: .cMajor)
                assertFalse(wheel.sectorsByLayer.isEmpty)

                let diatonicSectors = wheel.sectorsByLayer[.diatonic] ?? []
                assertEqual(diatonicSectors.count, 7)
                assertEqual(diatonicSectors[0].chord.root, .c)
                assertEqual(diatonicSectors[0].romanNumeral, "I")
                assertEqual(diatonicSectors[4].chord.root, .g)
                assertEqual(diatonicSectors[4].romanNumeral, "V")

                // Polar Angle Sector Lookup
                let topSector = wheel.sector(forAngle: -.pi / 2.0, layer: .diatonic)
                assertNotNil(topSector)
                assertEqual(topSector?.romanNumeral, "I")
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
                let suggestions = engine.suggestions(for: Chord(root: .c, type: .major), in: .c, scale: .cMajor)
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
                assertEqual(full.angle, 0.0)
                assertTrue(full.isActive)
            }

            test("GamepadState Initialization & Fields") {
                let state = GamepadState()
                assertEqual(state.leftTrigger, 0.0)
                assertEqual(state.rightTrigger, 0.0)
                assertFalse(state.buttonA)
                assertFalse(state.buttonB)
                assertEqual(state.throttle, 0.0)
            }

            test("VirtualStrummer Velocity & Note Generation") {
                let strummer = VirtualStrummer()
                let notes = [Note(pitchClass: .c, octave: 3), Note(pitchClass: .e, octave: 3), Note(pitchClass: .g, octave: 3)]
                let events = strummer.processStrum(rightStickY: 0.9, notes: notes)
                assertEqual(events.count, 3)
                assertTrue(events[0].velocity >= 60)
            }

            test("RhythmCompass 8-Sector Clockwise Mapping") {
                let compass = RhythmCompassEngine()
                let north = StickCoordinates(x: 0.0, y: 1.0, deadzone: 0.12)
                let evalNorth = compass.evaluate(stick: north)
                assertTrue(evalNorth.isPlaying)
                assertEqual(evalNorth.subdivision, .quarter)

                let east = StickCoordinates(x: 1.0, y: 0.0, deadzone: 0.12)
                let evalEast = compass.evaluate(stick: east)
                assertEqual(evalEast.subdivision, .eighth)
            }

            test("GestureRecorder Recording Lifecycle") {
                let recorder = GestureRecorder()
                assertFalse(recorder.stopRecording() != nil)

                recorder.startRecording()
                let state = ControllerState()
                state.buttonA = true
                recorder.recordSample(state: state)

                state.rightTrigger = 1.0
                recorder.recordSample(state: state)

                let clip = recorder.stopRecording()
                assertNotNil(clip)
                assertEqual(clip?.samples.count, 2)
            }

            test("ControllerManager Discovery and State") {
                let manager = ControllerManager()
                assertFalse(manager.isConnected)
                assertEqual(manager.controllerName, "No Controller")
            }
        }

        // MARK: - MIDI Tests
        suite("XPadMIDI: MIDIEngine, MPEManager, SMFExporter") {
            test("MIDIEngine Message Dispatching & Panic") {
                let midi = MIDIEngine()
                midi.sendNoteOn(note: 60, velocity: 100)
                midi.sendPitchBend(value: 8192)
                midi.sendCC(controller: 74, value: 80)
                midi.sendNoteOff(note: 60)
                midi.panic()
            }

            test("MPEManager Voice Lifecycle") {
                let mpe = MPEManager(midiEngine: MIDIEngine())
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
        suite("XPadAudio: AudioEngine & SynthVoice") {
            test("AudioEngine Lifecycle & Voice Allocation") {
                let audio = AudioEngine()
                audio.start()
                audio.noteOn(note: 60, velocity: 100)
                audio.noteOff(note: 60)
                audio.allNotesOff()
                audio.stop()
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

@main
struct AppTestMain {
    static func main() async {
        await TestRunner().run()
    }
}
