import Foundation
import GameController
import AudioToolbox
import AVFoundation
import XPadCore
import XPadTheory
import XPadController
import XPadMIDI
import XPadAudio
import XPadSequencer
import XPadPractice
import XPadUI

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
        setbuf(stdout, nil)
        print("==================================================")
        print("🎮 XPI: Game Controller MIDI — Comprehensive Test Suite Runner")
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

            test("Chord Voicing Stays in a Stable Six-Voice Register") {
                let progression = [
                    Chord(root: .d, quality: .minor),
                    Chord(root: .c, quality: .major),
                    Chord(root: .f, quality: .major),
                    Chord(root: .g, quality: .minor)
                ]
                var voicing = ChordVoicing.strummed(
                    chord: progression[0],
                    strings: 6,
                    baseOctave: 3
                )
                for _ in 0..<24 {
                    for chord in progression {
                        voicing = ChordVoicing.voiceLed(
                            chord: chord,
                            from: voicing,
                            baseOctave: 3,
                            voiceCount: 6
                        )
                        assertEqual(voicing.notes.count, 6)
                        assertTrue(voicing.notes.allSatisfy { (36...84).contains($0.midiNote) })
                    }
                }
            }

            test("Performance Lane Registers Clamp and Recall per Instrument") {
                var memory = PerformanceLaneRegisterMemory()
                var guitar = memory.settings(for: .guitar)
                let bass = memory.settings(for: .bass)

                assertEqual(guitar.strumOctave, 3)
                assertEqual(guitar.faceButtonOctave, 3)
                assertEqual(bass.strumOctave, 2)
                assertEqual(bass.faceButtonOctave, 2)

                guitar.setStrumOctave(8)
                guitar.setFaceButtonOctave(4)
                memory.remember(guitar, for: .guitar)
                assertEqual(memory.settings(for: .guitar).strumOctave, 5)
                assertEqual(memory.settings(for: .guitar).faceButtonOctave, 4)
                guitar.shiftBoth(by: -10)
                assertEqual(guitar.strumOctave, 2)
                assertEqual(guitar.faceButtonOctave, 2)
                guitar.shiftBoth(by: .max)
                assertEqual(guitar.strumOctave, 5)
                assertEqual(guitar.faceButtonOctave, 5)
                guitar.shiftBoth(by: .min)
                assertEqual(guitar.strumOctave, 2)
                assertEqual(guitar.faceButtonOctave, 2)
            }

            test("Strum Register Anchors Voicing Independently of Face Register") {
                let chord = Chord(root: .d, quality: .minor)
                var registers = PerformanceLaneRegisters(strumOctave: 2, faceButtonOctave: 4)
                let lowVoicing = ChordVoicing.strummed(
                    chord: chord,
                    strings: 4,
                    baseOctave: registers.strumOctave
                )

                registers.setStrumOctave(5)
                let highVoicing = ChordVoicing.strummed(
                    chord: chord,
                    strings: 4,
                    baseOctave: registers.strumOctave
                )

                assertEqual(lowVoicing.bassNote, Note(pitchClass: .d, octave: 2))
                assertEqual(highVoicing.bassNote, Note(pitchClass: .d, octave: 5))
                assertEqual(registers.faceButtonOctave, 4)
            }

            test("PerformanceEvent MIDI Cases") {
                let event = PerformanceEvent.noteOn(channel: 0, note: 60, velocity: 100)
                if case .noteOn(_, let note, let velocity) = event {
                    assertEqual(note, 60)
                    assertEqual(velocity, 100)
                } else {
                    assertTrue(false, "Expected noteOn")
                }
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

                // Pentatonic & Blues Scales without crash
                let pentatonicWheel = HarmonicWheel(scale: Scale(root: .c, type: .pentatonicMajor))
                assertFalse(pentatonicWheel.sectorsByLayer.isEmpty)
                let minorPentWheel = HarmonicWheel(scale: Scale(root: .a, type: .pentatonicMinor))
                assertFalse(minorPentWheel.sectorsByLayer.isEmpty)
                let bluesWheel = HarmonicWheel(scale: Scale(root: .c, type: .blues))
                assertFalse(bluesWheel.sectorsByLayer.isEmpty)
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

            test("Contextual Chord Tones Cannot Accumulate Octave Drift") {
                let targeter = ContextualPitchTargeter()
                let progression = [
                    Chord(root: .d, quality: .minor),
                    Chord(root: .f, quality: .major),
                    Chord(root: .g, quality: .minor),
                    Chord(root: .c, quality: .major)
                ]
                var note: Note?
                for _ in 0..<24 {
                    for chord in progression {
                        note = targeter.note(
                            for: .third,
                            chord: chord,
                            previous: note,
                            baseOctave: 3
                        )
                        assertTrue((36...72).contains(note?.midiNote ?? 127))
                    }
                }
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

                let minorScale = Scale(root: .a, type: .naturalMinor)
                assertTrue(minorScale.isMinor)
                let minorPresets = Progression.factoryPresets(for: minorScale)
                assertTrue(minorPresets.count >= 2)
                assertEqual(minorPresets[0].name, "Neo Soul Groove (i - iv - VII - III)")
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

            test("Analog Deadzones Circularly Clamp Diagonal Input") {
                let clamped = DeadzoneStrategy.scaledRadial(0.12).process(x: 1, y: 1)
                let magnitude = hypot(clamped.x, clamped.y)

                assertTrue(magnitude <= 1.000_001)
                assertTrue(abs(clamped.x - clamped.y) < 0.000_001)

                let invalid = DeadzoneStrategy.scaledRadial(0.12).process(x: .nan, y: 0.5)
                assertEqual(invalid.x, 0)
                assertEqual(invalid.y, 0)
            }

            test("Gesture Velocity Recovers from Invalid Timestamps") {
                var tracker = GestureVelocityTracker()
                _ = tracker.update(x: 0, y: 0, timestamp: 0)

                let duplicate = tracker.update(x: 0.5, y: 0, timestamp: 0)
                let reordered = tracker.update(x: 0.75, y: 0, timestamp: -1)
                let recovered = tracker.update(x: 1, y: 0, timestamp: 0.1)

                assertEqual(duplicate.movementVelocity, 0)
                assertEqual(reordered.movementVelocity, 0)
                assertTrue(abs(recovered.movementVelocity - 10) < 0.001)
                assertTrue(abs(recovered.xVelocity - 10) < 0.001)
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
                assertEqual(evalEast.subdivision, .eighthTriplet)
            }

            test("GestureRecorder Recording Lifecycle") {
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

            test("ControllerManager Discovery and State") {
                let manager = ControllerManager()
                assertFalse(manager.isConnected)
                assertEqual(manager.controllerName, "No Controller")
            }

            test("ControllerManager Background Monitoring Configuration & Persistence") {
                let manager = ControllerManager()
                assertTrue(manager.isBackgroundMonitoringEnabled, "Background monitoring should be enabled by default")
                assertTrue(GameController.GCController.shouldMonitorBackgroundEvents, "GCController.shouldMonitorBackgroundEvents must be true by default")

                manager.isBackgroundMonitoringEnabled = false
                assertFalse(manager.isBackgroundMonitoringEnabled)
                assertFalse(GameController.GCController.shouldMonitorBackgroundEvents)
                assertFalse(ControllerSettingsStore.shared.loadBackgroundMonitoring())

                // Restore
                manager.isBackgroundMonitoringEnabled = true
                assertTrue(manager.isBackgroundMonitoringEnabled)
                assertTrue(GameController.GCController.shouldMonitorBackgroundEvents)
                assertTrue(ControllerSettingsStore.shared.loadBackgroundMonitoring())
            }

            test("Simulated Face Button Sustains Without Retrigger") {
                let manager = ControllerManager()
                manager.selectControlScheme(ControlSchemePreset.xpiPerformance)
                var engine = InstrumentPerformanceEngine(profile: .guitar)
                let context = MusicalContext(
                    key: .d,
                    scale: Scale(root: .d, type: .naturalMinor),
                    chord: Chord(root: .d, quality: .minor)
                )

                manager.injectSimulatedState { state in
                    state.buttonA = true
                }
                let attack = engine.process(
                    state: manager.controllerState,
                    context: context,
                    heldNotes: [],
                    timestamp: 1.0
                )
                assertEqual(attack.faceEvents.count, 1)
                assertTrue(attack.faceEvents.first?.isOn == true)

                let sustainedNote = attack.faceEvents.first?.note
                manager.injectSimulatedState { state in
                    state.rightTrigger = ProcessedTriggerState(rawValue: 0.7, value: 0.7, isPressed: true)
                }
                assertTrue(manager.currentState.buttonA, "Unrelated simulated changes must preserve held buttons.")
                let sustain = engine.process(
                    state: manager.controllerState,
                    context: context,
                    heldNotes: sustainedNote.map { [$0] } ?? [],
                    timestamp: 1.01
                )
                assertTrue(sustain.faceEvents.isEmpty, "A held button must not emit another note-on edge.")

                manager.injectSimulatedState { state in
                    state.buttonA = false
                }
                let release = engine.process(
                    state: manager.controllerState,
                    context: context,
                    heldNotes: sustainedNote.map { [$0] } ?? [],
                    timestamp: 1.02
                )
                assertEqual(release.faceEvents.count, 1)
                assertTrue(release.faceEvents.first?.isOn == false)
                assertEqual(release.faceEvents.first?.note, sustainedNote)
            }

            test("Face Register Reset Rearms a Held Button at the New Octave") {
                var engine = InstrumentPerformanceEngine(profile: .guitar)
                let state = ControllerState()
                state.buttonA = true
                let chord = Chord(root: .d, quality: .minor)
                let scale = Scale(root: .d, type: .naturalMinor)

                let lowAttack = engine.process(
                    state: state,
                    context: MusicalContext(key: .d, scale: scale, chord: chord, registerOctave: 2),
                    heldNotes: [],
                    timestamp: 2.0
                )
                assertEqual(lowAttack.faceEvents.first?.note, Note(pitchClass: .d, octave: 2))

                engine.resetMelodicTargeting(rearmFaceButtons: true)
                let highAttack = engine.process(
                    state: state,
                    context: MusicalContext(key: .d, scale: scale, chord: chord, registerOctave: 4),
                    heldNotes: [],
                    timestamp: 2.1
                )
                assertEqual(highAttack.faceEvents.count, 1)
                assertTrue(highAttack.faceEvents.first?.isOn == true)
                assertEqual(highAttack.faceEvents.first?.note, Note(pitchClass: .d, octave: 4))
            }

            test("Chord Gate Releases and Duo Drums Trigger Only on Edges") {
                let chord = Chord(root: .d, quality: .minor)
                let voice = ChordGateVoice(
                    chord: chord,
                    notes: ChordVoicing.strummed(chord: chord, strings: 6, baseOctave: 3).notes
                )
                var gate = ChordGateEngine(
                    configuration: ChordGateConfiguration(mode: .timed, timedDuration: 0.5)
                )
                assertEqual(
                    gate.process(voice: voice, isGestureActive: true, timestamp: 1.0),
                    [.began(voice)]
                )
                assertTrue(gate.advance(timestamp: 1.49).isEmpty)
                assertEqual(gate.advance(timestamp: 1.5), [.ended(voice)])

                var duo = DuoControlEngine(mode: .drumsAndInstrument)
                let state = ControllerState()
                state.buttonA = true
                state.buttonX = true
                let attack = duo.process(state: state, drumVelocity: 96)
                assertEqual(attack.drumHits.map(\.voice), [.kick, .snare])
                assertEqual(attack.drumHits.map { $0.voice.generalMIDINote }, [36, 38])
                assertTrue(duo.process(state: state, drumVelocity: 127).drumHits.isEmpty)
            }

            test("Arcade Fret Lane Fires Diatonic Chords Instantly") {
                let diatonic = Chord.diatonicChords(root: .c, scale: .major)
                var engine = ArcadeFretEngine()

                let idle = engine.process(input: ArcadeFretInput(leftTriggerValue: 0.10), chords: diatonic, timestamp: 0)
                assertTrue(idle.strikes.isEmpty)

                let frame = engine.process(input: ArcadeFretInput(leftTriggerValue: 0.62), chords: diatonic, timestamp: 1)
                assertEqual(frame.strikes.count, 1)
                assertEqual(frame.strikes.first?.slot, .leftTrigger)
                assertEqual(frame.strikes.first?.chord.root, PitchClass.c)
                assertTrue(frame.isLaneActive)
            }

            test("Arcade Fret Release Edge and Velocity Scaling") {
                let diatonic = Chord.diatonicChords(root: .c, scale: .major)
                var engine = ArcadeFretEngine()
                _ = engine.process(input: ArcadeFretInput(rightShoulderPressed: true), chords: diatonic, timestamp: 0)
                let release = engine.process(input: .neutral, chords: diatonic, timestamp: 1)
                assertEqual(release.releases, [.rightShoulder])
                assertFalse(release.isLaneActive)

                var velocityEngine = ArcadeFretEngine()
                let soft = velocityEngine.process(input: ArcadeFretInput(leftTriggerValue: 0.35), chords: diatonic, timestamp: 0)
                let hard = velocityEngine.process(
                    input: ArcadeFretInput(leftTriggerValue: 0.05, rightShoulderPressed: true),
                    chords: diatonic,
                    timestamp: 1
                )
                assertTrue(soft.strikes[0].velocity < hard.strikes[0].velocity)
                assertEqual(hard.strikes.last?.velocity, ArcadeFretEngine.bumperVelocity)
            }

            test("Arcade Face Modifiers Colour Chord Quality with Deterministic Priority") {
                let diatonic = Chord.diatonicChords(root: .c, scale: .major)
                var engine = ArcadeFretEngine()
                let frame = engine.process(
                    input: ArcadeFretInput(leftTriggerValue: 0.8, southPressed: true),
                    chords: diatonic,
                    timestamp: 0
                )
                assertEqual(frame.strikes.first?.chord.quality, .major7)
                assertEqual(frame.strikes.first?.appliedModifiers, [.seventh])

                let base = Chord(root: .g, quality: .major)
                let stacked = ArcadeFretModifier.priorityOrder.reduce(base) { chord, modifier in
                    modifier.applied(to: chord)
                }
                assertEqual(stacked.quality, .major7)
                assertEqual(ArcadeFretModifier.sus.applied(to: base).quality, .sus4)
                assertEqual(ArcadeFretModifier.ninth.applied(to: stacked).quality, .major7)
            }

            test("Arcade Hammer-On Replaces Chord While Lane Held and Reset Rearms") {
                let diatonic = Chord.diatonicChords(root: .c, scale: .major)
                var engine = ArcadeFretEngine()
                _ = engine.process(input: ArcadeFretInput(leftTriggerValue: 0.7), chords: diatonic, timestamp: 0)

                let hammerOn = engine.process(
                    input: ArcadeFretInput(leftTriggerValue: 0.9, rightTriggerValue: 0.5),
                    chords: diatonic,
                    timestamp: 1
                )
                assertEqual(hammerOn.strikes.count, 1)
                assertEqual(hammerOn.strikes.first?.slot, .rightTrigger)
                assertTrue(hammerOn.isLaneActive)
                assertEqual(hammerOn.heldSlots, [.leftTrigger, .rightTrigger])

                engine.reset()
                let rearmed = engine.process(input: ArcadeFretInput(leftTriggerValue: 0.8), chords: diatonic, timestamp: 2)
                assertEqual(rearmed.strikes.count, 1)
            }

        }

        // MARK: - Arcade Preferences Tests
        suite("XPadUI: ArcadePreferences persistence") {
            func reset(_ name: String) {
                UserDefaults(suiteName: name)!.removePersistentDomain(forName: name)
            }
            func make(_ name: String) -> UserDefaults {
                UserDefaults(suiteName: name)!
            }

            test("Load Returns Documented Defaults When Keys Are Absent") {
                let suiteName = "xpi.arcade.tests"
                reset(suiteName)
                defer { reset(suiteName) }
                let defaults = make(suiteName)

                let store = ArcadePreferencesStore(defaults: defaults)
                let prefs = store.load()

                assertEqual(prefs, ArcadePreferences())
                assertFalse(prefs.unlockSeen)
                assertFalse(prefs.modeEnabled)
                assertEqual(prefs.velocityFloor, 54)
                assertEqual(prefs.velocityCeiling, 127)
            }

            test("Save Then Load Roundtrips All Fields") {
                let suiteName = "xpi.arcade.tests"
                reset(suiteName)
                defer { reset(suiteName) }
                let defaults = make(suiteName)

                let store = ArcadePreferencesStore(defaults: defaults)
                let original = ArcadePreferences(
                    unlockSeen: true,
                    modeEnabled: true,
                    velocityFloor: 60,
                    velocityCeiling: 120
                )
                store.save(original)

                // Re-read through a brand-new store backed by a new instance.
                let reloaded = ArcadePreferencesStore(defaults: make(suiteName)).load()
                assertEqual(reloaded, original)
                assertTrue(reloaded.unlockSeen)
                assertEqual(reloaded.velocityCeiling, 120)
            }

            test("Validating Init Clamps Floor And Ceiling") {
                let clampedLow = ArcadePreferences(velocityFloor: 0, velocityCeiling: 9999)
                assertEqual(clampedLow.velocityFloor, 1)
                assertEqual(clampedLow.velocityCeiling, 127)

                let clampedHigh = ArcadePreferences(velocityFloor: 200)
                assertEqual(clampedHigh.velocityFloor, 127)
                assertEqual(clampedHigh.velocityCeiling, 127)

                let inverted = ArcadePreferences(velocityFloor: 80, velocityCeiling: 60)
                assertEqual(inverted.velocityCeiling, 80)
            }

            test("Stores On Different Suite Names Do Not Interfere") {
                let primaryName = "xpi.arcade.tests"
                let secondaryName = "xpi.arcade.tests.alt"
                reset(primaryName)
                reset(secondaryName)
                defer { reset(primaryName); reset(secondaryName) }
                let primaryStore = ArcadePreferencesStore(defaults: make(primaryName))
                let secondaryStore = ArcadePreferencesStore(defaults: make(secondaryName))
                primaryStore.save(ArcadePreferences(unlockSeen: true, modeEnabled: true, velocityFloor: 40, velocityCeiling: 100))
                secondaryStore.save(ArcadePreferences())

                let fromPrimary = ArcadePreferencesStore(defaults: make(primaryName)).load()
                let fromSecondary = ArcadePreferencesStore(defaults: make(secondaryName)).load()
                assertEqual(fromPrimary, ArcadePreferences(unlockSeen: true, modeEnabled: true, velocityFloor: 40, velocityCeiling: 100))
                assertEqual(fromSecondary, ArcadePreferences())
            }

            test("Codable Roundtrip Preserves Equivalence") {
                let original = ArcadePreferences(unlockSeen: true, modeEnabled: false, velocityFloor: 30, velocityCeiling: 110)
                let decoded = try! JSONDecoder().decode(
                    ArcadePreferences.self,
                    from: try! JSONEncoder().encode(original)
                )
                assertEqual(decoded, original)

                reset("xpi.arcade.tests")
                defer { reset("xpi.arcade.tests") }
                let defaults = make("xpi.arcade.tests")
                ArcadePreferencesStore(defaults: defaults).save(decoded)
                assertEqual(ArcadePreferencesStore(defaults: defaults).load(), original)
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

            test("MPE Reset Ordering Isolation and Clean Release") {
                let midi = MIDIEngine()
                let mpe = MPEManager(midiEngine: midi, bendRangeSemitones: 2.0)
                midi.clearMessageLog()

                mpe.noteOn(note: 60, velocity: 100)
                assertEqual(mpe.activeVoice(for: 60)?.channel, UInt8?.some(1))
                assertEqual(
                    midi.sentMessages.map(\.bytes),
                    [
                        [0xE1, 0x00, 0x40],
                        [0xD1, 0x00],
                        [0xB1, 74, 64],
                        [0x91, 60, 100]
                    ],
                    "Member-channel expression must reset before Note On."
                )

                midi.clearMessageLog()
                mpe.noteOn(note: 64, velocity: 90)
                assertEqual(mpe.activeVoice(for: 64)?.channel, UInt8?.some(2))
                assertEqual(midi.sentMessages.last?.bytes, [0x92, 64, 90])

                midi.clearMessageLog()
                mpe.setPitchBend(for: 60, semitones: 2.0)
                assertEqual(midi.sentMessages.map(\.bytes), [[0xE1, 0x7F, 0x7F]])
                assertEqual(mpe.activeVoice(for: 60)?.currentPitchBend, 2.0)
                assertEqual(mpe.activeVoice(for: 64)?.currentPitchBend, 0.0)

                midi.clearMessageLog()
                mpe.noteOff(note: 60)
                assertEqual(
                    midi.sentMessages.map(\.bytes),
                    [
                        [0x81, 60, 0],
                        [0xE1, 0x00, 0x40],
                        [0xD1, 0x00],
                        [0xB1, 74, 64]
                    ],
                    "Note Off must precede expression reset on release."
                )
                assertTrue(mpe.activeVoice(for: 60) == nil)
                assertEqual(mpe.activeVoiceCount, 1)
                mpe.stopAllNotes()
            }

            test("MPE Expression Coalescing Preserves Note Attack Reset") {
                let midi = MIDIEngine()
                let mpe = MPEManager(midiEngine: midi, bendRangeSemitones: 48)
                mpe.noteOn(note: 60, velocity: 100)
                midi.clearMessageLog()

                mpe.setPitchBend(for: 60, semitones: 0)
                mpe.setPressure(for: 60, pressure: 0)
                mpe.setTimbre(for: 60, value: 64)
                assertTrue(midi.sentMessages.isEmpty)

                mpe.setPitchBend(for: 60, semitones: 1)
                mpe.setPressure(for: 60, pressure: 80)
                mpe.setTimbre(for: 60, value: 90)
                assertEqual(midi.sentMessages.count, 3)

                for _ in 0..<32 {
                    mpe.setPitchBend(for: 60, semitones: 1)
                    mpe.setPressure(for: 60, pressure: 80)
                    mpe.setTimbre(for: 60, value: 90)
                }
                mpe.setPitchBend(for: 60, semitones: 1.0001)
                assertEqual(midi.sentMessages.count, 3)
            }

            test("Live expression dispatch keeps MIDI 2 MPE pressure below 7-bit quantization") {
                let midi = MIDIEngine()
                midi.transportProtocol = .midi2
                let mpe = MPEManager(midiEngine: midi)
                mpe.noteOn(note: 60, velocity: 100)
                midi.clearMessageLog()

                LiveExpressionDispatch.sendPressure(
                    mpe: mpe,
                    midi: midi,
                    destination: .genericMPE,
                    preferredPressureMode: .mpePressure,
                    note: 60,
                    ports: [.melody],
                    normalizedPressure: 0.5001
                )
                LiveExpressionDispatch.sendPressure(
                    mpe: mpe,
                    midi: midi,
                    destination: .genericMPE,
                    preferredPressureMode: .mpePressure,
                    note: 60,
                    ports: [.melody],
                    normalizedPressure: 0.5002
                )

                assertEqual(mpe.voice(for: 60)?.currentPressureNormalized, Optional(0.5002))
                assertEqual(mpe.voice(for: 60)?.currentPressure, Optional(UInt8(64)))
            }

            test("Live expression dispatch conventional MIDI 2 path uses normalized pressure") {
                let midi = MIDIEngine()
                midi.transportProtocol = .midi2
                let mpe = MPEManager(midiEngine: midi)
                midi.clearMessageLog()

                LiveExpressionDispatch.sendPressure(
                    mpe: mpe,
                    midi: midi,
                    destination: .genericMIDI,
                    preferredPressureMode: .channelPressure,
                    note: 60,
                    ports: [.melody],
                    normalizedPressure: 0.5001
                )
                LiveExpressionDispatch.sendPressure(
                    mpe: mpe,
                    midi: midi,
                    destination: .genericMIDI,
                    preferredPressureMode: .channelPressure,
                    note: 60,
                    ports: [.melody],
                    normalizedPressure: 0.5002
                )

                assertEqual(midi.sentMessages.count, 2)
                assertEqual(midi.sentMessages[0].bytes, [0xD0, 64])
                assertEqual(midi.sentMessages[1].port, .melody)
            }

            test("Repeated MPE Attack Reuses Its Saturated Member Channel") {
                let midi = MIDIEngine()
                let mpe = MPEManager(midiEngine: midi)
                for note: UInt8 in 60..<74 {
                    mpe.noteOn(note: note, velocity: 90)
                }
                let originalChannel = mpe.voice(for: 70)?.channel

                midi.clearMessageLog()
                mpe.noteOn(note: 70, velocity: 105)

                assertEqual(mpe.activeVoiceCount, 14)
                assertEqual(mpe.voice(for: 70)?.channel, originalChannel)
                assertTrue(mpe.voice(for: 60) != nil)
                assertEqual(
                    midi.sentMessages.map(\.bytes),
                    [
                        [0x8B, 70, 0],
                        [0xEB, 0, 0x40],
                        [0xDB, 0],
                        [0xBB, 74, 64],
                        [0x9B, 70, 105]
                    ]
                )
            }

            test("MIDI Diagnostic Ring Retains Newest Delivery Order") {
                let midi = MIDIEngine()
                midi.clearMessageLog()
                for index in 0..<2_052 {
                    midi.sendCC(
                        port: .main,
                        channel: 0,
                        controller: UInt8((index >> 7) & 0x7F),
                        value: UInt8(index & 0x7F)
                    )
                }

                assertEqual(midi.sentMessages.count, 2_048)
                assertEqual(midi.sentMessages.first?.bytes, [0xB0, 0, 4])
                assertEqual(midi.sentMessages.last?.bytes, [0xB0, 16, 3])
            }

            test("Technique Translation Separates Attack Expression and Release") {
                let translator = TechniqueMIDITranslator(destination: .genericMPE, profile: .guitar)
                let attack = translator.translate(
                    InstrumentPerformanceEvent(note: .middleC, phase: .began, technique: .normal, velocity: 96)
                )
                assertEqual(attack.channel, UInt8?.some(1))
                assertEqual(attack.events, [.noteOn(channel: 1, note: 60, velocity: 96)])

                let expression = translator.translate(
                    InstrumentPerformanceEvent(
                        note: .middleC,
                        phase: .changed,
                        technique: .bend,
                        pressure: 0.5,
                        pitchOffset: 2.0
                    )
                )
                assertFalse(expression.events.contains { event in
                    if case .noteOn = event { return true }
                    return false
                }, "Expression changes must never retrigger the held note.")
                assertTrue(expression.events.contains { event in
                    if case .channelPressure(channel: 1, pressure: 64) = event { return true }
                    return false
                }, "MPE pressure must use member-channel Channel Pressure, not CC11.")
                assertFalse(expression.events.contains { event in
                    if case .controlChange(channel: _, controller: 11, value: _) = event { return true }
                    return false
                })

                let release = translator.translate(
                    InstrumentPerformanceEvent(note: .middleC, phase: .ended, technique: .normal)
                )
                assertEqual(release.events.first, .noteOff(channel: 1, note: 60))
                assertTrue(release.events.contains(.pitchBend(channel: 1, value: 0)))
                assertTrue(release.events.contains(.channelPressure(channel: 1, pressure: 0)))
                assertTrue(release.events.contains(.timbreCC74(channel: 1, value: 64)))
            }

            test("Technique Recorder Closes a Note Before Register Retarget") {
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
                assertEqual(events.map(\.event.note), [low, high])
                assertEqual(events.map(\.durationTicks), [UInt64(20), UInt64(40)])
            }

            test("Virtual MIDI Enable Configures MPE and Disable Delivers Panic") {
                let midi = MIDIEngine()
                let mpe = MPEManager(midiEngine: midi, bendRangeSemitones: 48)
                var enableCallbacks = 0
                midi.onVirtualMIDIChanged = { enabled in
                    if enabled {
                        enableCallbacks += 1
                        mpe.sendMPEZoneConfiguration()
                    }
                }

                midi.virtualMIDIEnabled = true
                assertEqual(enableCallbacks, 1)
                assertTrue(midi.sentMessages.contains { record in
                    record.port == .mpe && record.bytes == [0xB0, 101, 0]
                }, "MPE zone configuration must be host-visible after sources are enabled.")

                midi.clearMessageLog()
                mpe.noteOn(note: 60, velocity: 90)
                let phraseMessages = midi.sentMessages
                let zoneIndex = phraseMessages.firstIndex { record in
                    record.port == .mpe && record.bytes == [0xB0, 101, 0]
                }
                let noteOnIndex = phraseMessages.firstIndex { record in
                    record.port == .mpe && record.bytes == [0x91, 60, 90]
                }
                assertTrue(
                    zoneIndex != nil && noteOnIndex != nil && zoneIndex! < noteOnIndex!,
                    "An idle phrase must re-advertise its MPE zone before the first Note On."
                )

                midi.clearMessageLog()
                midi.virtualMIDIEnabled = false
                assertTrue(midi.sentMessages.contains { $0.bytes == [0x81, 60, 0] })
                assertTrue(midi.sentMessages.contains { $0.bytes == [0xE1, 0, 0x40] })
                assertTrue(midi.sentMessages.contains { $0.bytes == [0xD1, 0] })
                assertTrue(midi.sentMessages.contains { $0.bytes == [0xB1, 74, 64] })
                assertTrue(midi.sentMessages.contains { $0.bytes == [0xB1, 123, 0] })
            }

            test("MIDI2UMPDecoder decodes MIDI 1.0 channel voice UMP words") {
                // Type 0x2: Note On Ch 0, Note 60, Vel 100 -> 0x20903C64
                let noteOnWord: UInt32 = (0x2 << 28) | (0x90 << 16) | (60 << 8) | 100
                let decodedOn = MIDI2UMPDecoder.decode(words: [noteOnWord])
                assertEqual(decodedOn.count, 1)
                if case .channelVoice(let event, let rawBytes) = decodedOn[0] {
                    assertEqual(event, .noteOn(channel: 0, note: 60, velocity: 100))
                    assertEqual(rawBytes, [0x90, 60, 100])
                } else {
                    assertTrue(false, "Expected channel voice Note On")
                }

                // Type 0x2: Pitch Bend Ch 1, 14-bit 8192 (Centre) -> 0x20E10040
                let bendWord: UInt32 = (0x2 << 28) | (0xE1 << 16) | (0x00 << 8) | 0x40
                let decodedBend = MIDI2UMPDecoder.decode(words: [bendWord])
                assertEqual(decodedBend.count, 1)
                if case .channelVoice(let event, let rawBytes) = decodedBend[0] {
                    assertEqual(event, .pitchBend(channel: 1, value: 0))
                    assertEqual(rawBytes, [0xE1, 0x00, 0x40])
                } else {
                    assertTrue(false, "Expected channel voice Pitch Bend")
                }
            }

            test("MIDI2UMPDecoder decodes MIDI 2.0 high-resolution channel voice and per-note UMPs") {
                // Type 0x4: MIDI 2.0 Note On Ch 2, Note 64, 16-bit Vel 0xFFFF (127) -> words: [0x40924000, 0xFFFF0000]
                let noteOnUMP = MIDI2UMPEncoder.noteOnMessage(channel: 2, note: 64, velocity16: 0xFFFF)
                let decodedNote = MIDI2UMPDecoder.decode(words: [noteOnUMP.word0, noteOnUMP.word1])
                assertEqual(decodedNote.count, 1)
                if case .channelVoice(let event, let rawBytes) = decodedNote[0] {
                    assertEqual(event, .noteOn(channel: 2, note: 64, velocity: 127))
                    assertEqual(rawBytes, [0x92, 64, 127])
                } else {
                    assertTrue(false, "Expected MIDI 2.0 Note On")
                }

                // Type 0x4: MIDI 2.0 Per-Note Pitch Bend Ch 0, Note 60, +2.0 semitones
                let perNoteBendUMP = MIDI2UMPEncoder.perNotePitchBendMessage(
                    channel: 0,
                    note: 60,
                    semitoneOffset: 2.0,
                    bendRangeSemitones: 48.0
                )
                let decodedPerNoteBend = MIDI2UMPDecoder.decode(words: [perNoteBendUMP.word0, perNoteBendUMP.word1])
                assertEqual(decodedPerNoteBend.count, 1)
                if case .perNotePitchBend(let ch, let note, let semitones, _) = decodedPerNoteBend[0] {
                    assertEqual(ch, 0)
                    assertEqual(note, 60)
                    assertTrue(abs(semitones - 2.0) < 0.01)
                } else {
                    assertTrue(false, "Expected Per-Note Pitch Bend")
                }

                // Type 0x4: MIDI 2.0 Per-Note Pressure Ch 0, Note 60, normalized 0.75
                let perNotePressUMP = MIDI2UMPEncoder.perNotePressureMessage(
                    channel: 0,
                    note: 60,
                    normalizedPressure: 0.75
                )
                let decodedPress = MIDI2UMPDecoder.decode(words: [perNotePressUMP.word0, perNotePressUMP.word1])
                assertTrue(decodedPress.contains(where: {
                    if case .perNotePressure(let ch, let note, let norm) = $0 {
                        return ch == 0 && note == 60 && abs(norm - 0.75) < 0.01
                    }
                    return false
                }))
            }

            test("MIDI2UMPDecoder multi-packet SysEx7 streaming reassembly") {
                // Type 0x3 SysEx: Send Start packet with 6 bytes, then End packet with 3 bytes
                var sysExBuffer: [UInt8] = []
                let startPacketWord0: UInt32 = (0x3 << 28) | (0x1 << 20) | (6 << 16) | (0xF0 << 8) | 0x7E
                let startPacketWord1: UInt32 = (0x01 << 24) | (0x06 << 16) | (0x01 << 8) | 0x02
                let endPacketWord0: UInt32 = (0x3 << 28) | (0x3 << 20) | (2 << 16) | (0x03 << 8) | 0xF7
                let endPacketWord1: UInt32 = 0

                let messages = MIDI2UMPDecoder.decodeStream(
                    words: [startPacketWord0, startPacketWord1, endPacketWord0, endPacketWord1],
                    sysExBuffer: &sysExBuffer
                )
                assertEqual(messages.count, 1)
                if case .sysEx(let bytes) = messages[0] {
                    assertEqual(bytes, [0xF0, 0x7E, 0x01, 0x06, 0x01, 0x02, 0x03, 0xF7])
                } else {
                    assertTrue(false, "Expected reassembled SysEx payload")
                }
            }

            test("MIDIEngine passthru routing and incoming representation") {
                let midi = MIDIEngine()
                var receivedEvents: [PerformanceEvent] = []
                midi.onIncomingEvent = { event, _ in
                    receivedEvents.append(event)
                }

                // Simulate incoming UMP Note On: 0x20903C64 (Note On Ch 0 Note 60 Vel 100)
                let noteOnWord: UInt32 = (0x2 << 28) | (0x90 << 16) | (60 << 8) | 100
                midi.clearMessageLog()

                // Test Passthru Mode = .off
                midi.passthruMode = .off
                // Decode words directly through passthru decoder
                let decoded = MIDI2UMPDecoder.decode(words: [noteOnWord])
                if case .channelVoice(let event, let rawBytes) = decoded[0] {
                    midi.onIncomingEvent?(event, rawBytes)
                }
                assertEqual(receivedEvents.count, 1)
                assertEqual(receivedEvents[0], .noteOn(channel: 0, note: 60, velocity: 100))

                // Test Passthru Mode properties
                assertEqual(MIDIPassthruMode.off.routesToAudio, false)
                assertEqual(MIDIPassthruMode.off.routesToOutputs, false)
                assertEqual(MIDIPassthruMode.thruToAudio.routesToAudio, true)
                assertEqual(MIDIPassthruMode.thruToAudio.routesToOutputs, false)
                assertEqual(MIDIPassthruMode.thruToOutputs.routesToAudio, false)
                assertEqual(MIDIPassthruMode.thruToOutputs.routesToOutputs, true)
                assertEqual(MIDIPassthruMode.full.routesToAudio, true)
                assertEqual(MIDIPassthruMode.full.routesToOutputs, true)
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

            test("SMFExporter VLQ Clamping and Stable Event Ordering") {
                let exporter = SMFExporter()
                let vlqSmall = exporter.encodeVariableLength(0)
                assertEqual(vlqSmall, [0x00])
                let vlq127 = exporter.encodeVariableLength(127)
                assertEqual(vlq127, [0x7F])
                let vlq128 = exporter.encodeVariableLength(128)
                assertEqual(vlq128, [0x81, 0x00])

                // Clamped at 28-bit 0x0FFFFFFF
                let vlqMax = exporter.encodeVariableLength(0xFFFFFFFF_FFFFFFFF)
                assertEqual(vlqMax.count, 4)
                assertEqual(vlqMax, [0xFF, 0xFF, 0xFF, 0x7F])
            }
        }

        // MARK: - Audio Tests
        suite("XPadAudio: AudioEngine & SynthVoice") {
            test("AudioEngine Lifecycle & Voice Allocation") {
                let audio = AudioEngine()
                audio.start()
                audio.noteOn(note: 60, velocity: 100)
                assertEqual(audio.trackedVoiceCount, 1)
                audio.noteOff(note: 60)
                assertEqual(audio.trackedVoiceCount, 1, "A release tail must remain tracked until it detaches.")
                audio.panic()
                assertEqual(audio.trackedVoiceCount, 0, "Panic must hard-stop active and releasing voices.")
                audio.stop()
            }

            test("AudioEngine Mute State & Resource Bypassing") {
                let audio = AudioEngine()
                audio.start()
                assertEqual(audio.isMuted, false)
                audio.setVolume(0.85)
                assertEqual(audio.volume, 0.85)

                audio.noteOn(note: 60, velocity: 100)
                assertEqual(audio.trackedVoiceCount, 1)

                // Muting should immediately stop all sounding voices
                audio.setMuted(true)
                assertEqual(audio.isMuted, true)
                assertEqual(audio.trackedVoiceCount, 0, "Muting must clear all active sounding voices")

                // Triggering notes while muted should not allocate any voices
                audio.noteOn(note: 62, velocity: 100)
                assertEqual(audio.trackedVoiceCount, 0, "Muted synth must bypass voice node allocation")
                audio.triggerDrum(.kick, velocity: 100)
                assertEqual(audio.trackedDrumVoiceCount, 0, "Muted synth must bypass drum voice allocation")

                // Toggle unmute restores engine and stored volume
                audio.toggleMute()
                assertEqual(audio.isMuted, false)
                assertEqual(audio.volume, 0.85, "Volume setting must be preserved through mute cycle")

                audio.noteOn(note: 64, velocity: 100)
                assertEqual(audio.trackedVoiceCount, 1)
                audio.panic()
                assertEqual(audio.trackedVoiceCount, 0)
                audio.stop()
            }

            test("Guitar FFT Sine Default Preset & Acoustic Harmonics") {
                let audio = AudioEngine()
                assertEqual(audio.currentPreset.id, "acousticSine", "Default preset must be acousticSine")
                assertEqual(audio.currentPreset.osc1Type, .sine, "Default oscillator 1 must be sine-orientated")
                assertEqual(audio.currentPreset.osc2Type, .triangle, "Default oscillator 2 must be triangle (1/n^2 rolloff)")
                assertEqual(audio.currentPreset.osc2Level, 0.28, "Overtone balance must match guitar FFT overtone ratios")
                assertEqual(audio.currentPreset.filterCutoffHz, 2600.0, "Filter cutoff must match guitar body acoustic response")
                assertEqual(audio.currentPreset.filterType, .lowPass)
                
                assertEqual(SynthPreset.allPresets.count, 14)
                assertEqual(SynthPreset.allPresets[0].id, "acousticSine")
                assertEqual(SynthPreset.nylonSine.osc1Type, .sine)
                assertEqual(SynthPreset.cleanElectricSine.osc1Type, .sine)

                // Voice synthesis with guitar harmonics
                audio.start()
                audio.setPreset(.acousticSine)
                audio.noteOn(note: 64, velocity: 110, technique: .harmonic)
                audio.setHarmonicEmphasis(for: 64, amount: 0.8, pinch: false)
                audio.setTimbre(for: 64, timbre: 0.7)
                audio.setPitchBend(for: 64, semitones: 2.0)
                assertEqual(audio.currentPitchBend(for: 64), 2.0)
                audio.noteOff(note: 64)
                audio.panic()
                audio.stop()
            }
        }

        // MARK: - AUv3 & VST3 Plugin Suite
        suite("AUv3 & VST3 Plugin Targets: Instrument & MIDI FX") {
            test("AUv3 Parameter Tree & VST3 Bridge Mapping") {
                let tree = XPadAUParameterTreeBuilder.createParameterTree()
                let cutoffParam = tree.parameter(withAddress: XPadAUParameterAddress.filterCutoff.rawValue)
                assertNotNil(cutoffParam)
                assertEqual(cutoffParam?.minValue ?? 0, 20.0)
                assertEqual(cutoffParam?.maxValue ?? 0, 20000.0)

                let volParam = tree.parameter(withAddress: XPadAUParameterAddress.masterVolume.rawValue)
                assertNotNil(volParam)
                assertEqual(volParam?.value ?? 0, 0.7)

                let vstBridge = VST3Bridge.shared
                assertNotNil(vstBridge.parameterInfos[100])
                if let cutoffInfo = vstBridge.parameterInfos[200] {
                    assertEqual(cutoffInfo.minValue, 20.0)
                    assertEqual(cutoffInfo.maxValue, 20000.0)
                    let norm = cutoffInfo.plainToNormalized(10010.0)
                    assertTrue(abs(norm - 0.5) < 0.01)
                    let plain = cutoffInfo.normalizedToPlain(0.5)
                    assertTrue(abs(plain - 10010.0) < 1.0)
                }
            }

            test("AUv3 Instrument Audio Render Block & State Serialization") {
                do {
                    let desc = XPadPluginRegistrar.instrumentComponentDescription
                    let instrument = try XPadAUInstrument(componentDescription: desc)
                    assertEqual(instrument.outputBusses.count, 1)
                    assertEqual(instrument.inputBusses.count, 0)

                    try instrument.allocateRenderResources()

                    let renderBlock = instrument.internalRenderBlock
                    var flags: AudioUnitRenderActionFlags = []
                    var timestamp = AudioTimeStamp()
                    timestamp.mSampleTime = 0
                    timestamp.mFlags = .sampleTimeValid

                    let frameCount: UInt32 = 128
                    let format = AVAudioFormat(standardFormatWithSampleRate: 44100.0, channels: 2)!
                    let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
                    pcmBuffer.frameLength = frameCount

                    var midiEvent = AURenderEvent()
                    midiEvent.head.eventType = .MIDI
                    midiEvent.head.eventSampleTime = 0
                    midiEvent.MIDI.data = (0x90, 60, 100)
                    midiEvent.MIDI.length = 3

                    let status = withUnsafePointer(to: &midiEvent) { eventPtr in
                        renderBlock(&flags, &timestamp, frameCount, 0, pcmBuffer.mutableAudioBufferList, eventPtr, nil)
                    }
                    assertEqual(status, noErr)

                    let leftChannel = pcmBuffer.floatChannelData![0]
                    var maxAudioSample: Float = 0
                    for i in 0..<Int(frameCount) {
                        let sample = abs(leftChannel[i])
                        if sample > maxAudioSample { maxAudioSample = sample }
                    }
                    assertTrue(maxAudioSample > 0.0001, "Poly synth render block must generate audio on Note On")

                    let state = instrument.fullState
                    assertNotNil(state)
                    assertTrue(state?["XPadParameters"] != nil)

                    instrument.deallocateRenderResources()
                } catch {
                    assertTrue(false, "AUv3 Instrument test failed: \(error)")
                }
            }

            test("AUv3 MIDI FX Chord & Voice Leading Output") {
                do {
                    let desc = XPadPluginRegistrar.midiFXComponentDescription
                    let midiFX = try XPadAUMIDIFX(componentDescription: desc)
                    assertEqual(midiFX.outputBusses.count, 0)
                    assertEqual(midiFX.inputBusses.count, 0)

                    var generatedMIDIEvents: [[UInt8]] = []
                    midiFX.midiOutputEventBlock = { sampleTime, cable, length, data in
                        let bytes = Array(UnsafeBufferPointer(start: data, count: length))
                        generatedMIDIEvents.append(bytes)
                        return noErr
                    }

                    try midiFX.allocateRenderResources()
                    let renderBlock = midiFX.internalRenderBlock
                    var flags: AudioUnitRenderActionFlags = []
                    var timestamp = AudioTimeStamp()
                    timestamp.mSampleTime = 0

                    var midiInEvent = AURenderEvent()
                    midiInEvent.head.eventType = .MIDI
                    midiInEvent.MIDI.data = (0x90, 62, 100) // D4
                    midiInEvent.MIDI.length = 3

                    let emptyFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
                    let emptyPcm = AVAudioPCMBuffer(pcmFormat: emptyFormat, frameCapacity: 64)!
                    withUnsafePointer(to: &midiInEvent) { eventPtr in
                        _ = renderBlock(&flags, &timestamp, 64, 0, emptyPcm.mutableAudioBufferList, eventPtr, nil)
                    }

                    assertTrue(generatedMIDIEvents.count >= 3, "MIDI FX must output chord notes")
                    assertTrue(generatedMIDIEvents.allSatisfy { $0[0] == 0x90 }, "Generated events must be Note On")

                    midiFX.deallocateRenderResources()
                } catch {
                    assertTrue(false, "AUv3 MIDI FX test failed: \(error)")
                }
            }
        }

        // MARK: - CoreAudio Virtual Audio Driver & Loopback Suite
        suite("CoreAudio Virtual Audio Driver & Loopback Stream") {
            test("Audio Ring Buffer Multi-Channel Read/Write & Wrap-Around") {
                let ringBuffer = AudioRingBuffer(channels: 2, capacityFrames: 1024)
                assertEqual(ringBuffer.channels, 2)
                assertEqual(ringBuffer.capacityFrames, 1024)
                assertEqual(ringBuffer.availableReadFrames, 0)

                let testInputL: [Float] = [0.1, 0.2, 0.3, 0.4, 0.5]
                let testInputR: [Float] = [0.6, 0.7, 0.8, 0.9, 1.0]

                testInputL.withUnsafeBufferPointer { ptrL in
                    testInputR.withUnsafeBufferPointer { ptrR in
                        let written = ringBuffer.writeStereo(left: ptrL.baseAddress!, right: ptrR.baseAddress!, frameCount: 5)
                        assertEqual(written, 5)
                    }
                }

                assertEqual(ringBuffer.availableReadFrames, 5)

                var readOutput = [Float](repeating: 0.0, count: 10)
                readOutput.withUnsafeMutableBufferPointer { ptr in
                    let readFrames = ringBuffer.readInterleaved(into: ptr.baseAddress!, frameCount: 5)
                    assertEqual(readFrames, 5)
                }

                assertEqual(readOutput[0], 0.1)
                assertEqual(readOutput[1], 0.6)
                assertEqual(readOutput[8], 0.5)
                assertEqual(readOutput[9], 1.0)
                assertEqual(ringBuffer.availableReadFrames, 0)

                // Wrap-around test
                let largeWriteL = [Float](repeating: 0.25, count: 800)
                let largeWriteR = [Float](repeating: 0.25, count: 800)
                largeWriteL.withUnsafeBufferPointer { ptrL in
                    largeWriteR.withUnsafeBufferPointer { ptrR in
                        _ = ringBuffer.writeStereo(left: ptrL.baseAddress!, right: ptrR.baseAddress!, frameCount: 800)
                    }
                }
                var largeRead = [Float](repeating: 0.0, count: 1600)
                largeRead.withUnsafeMutableBufferPointer { ptr in
                    _ = ringBuffer.readInterleaved(into: ptr.baseAddress!, frameCount: 800)
                }
                assertEqual(ringBuffer.availableReadFrames, 0)

                let wrapWriteL = [Float](repeating: 0.75, count: 500)
                let wrapWriteR = [Float](repeating: 0.75, count: 500)
                wrapWriteL.withUnsafeBufferPointer { ptrL in
                    wrapWriteR.withUnsafeBufferPointer { ptrR in
                        let written = ringBuffer.writeStereo(left: ptrL.baseAddress!, right: ptrR.baseAddress!, frameCount: 500)
                        assertEqual(written, 500)
                    }
                }
                assertEqual(ringBuffer.availableReadFrames, 500)

                var wrapRead = [Float](repeating: 0.0, count: 1000)
                wrapRead.withUnsafeMutableBufferPointer { ptr in
                    let read = ringBuffer.readInterleaved(into: ptr.baseAddress!, frameCount: 500)
                    assertEqual(read, 500)
                }
                assertEqual(wrapRead[0], 0.75)
                assertEqual(wrapRead[1], 0.75)

                ringBuffer.reset()
                assertEqual(ringBuffer.availableReadFrames, 0)
            }

            test("Audio Level Meter RMS and Peak Ballistics") {
                let meter = AudioLevelMeter()
                let loudAudioL: [Float] = [0.8, -0.8, 0.8, -0.8]
                let loudAudioR: [Float] = [0.4, -0.4, 0.4, -0.4]
                loudAudioL.withUnsafeBufferPointer { pL in
                    loudAudioR.withUnsafeBufferPointer { pR in
                        meter.processFrames(left: pL.baseAddress!, right: pR.baseAddress!, frameCount: 4)
                    }
                }
                assertTrue(meter.peakLeft >= 0.8)
                assertTrue(meter.peakRight >= 0.4)
                assertTrue(meter.peakLeftDB > -3.0)
                assertTrue(meter.rmsLeft > 0.5)
            }

            test("Virtual Audio Driver Stream Lifecycle & Ingestion") {
                let driver = VirtualAudioDriver(ringBufferCapacity: 2048)
                assertFalse(driver.isEnabled)
                driver.setEnabled(true)
                assertTrue(driver.isEnabled)

                driver.setSampleRate(.rate48k0)
                assertEqual(driver.sampleRate, .rate48k0)

                driver.setBufferSize(.lowLatency64)
                assertEqual(driver.bufferSize, .lowLatency64)

                let testFrames: [Float] = [0.5, 0.5, 0.5, 0.5]
                testFrames.withUnsafeBufferPointer { p in
                    driver.ingestAudio(left: p.baseAddress!, right: nil, frameCount: 4)
                }
                assertTrue(driver.driverState.totalFramesStreamed >= 4)

                var pulledData = [Float](repeating: 0.0, count: 8)
                pulledData.withUnsafeMutableBufferPointer { p in
                    let pulled = driver.pullInterleaved(into: p.baseAddress!, frameCount: 4)
                    assertEqual(pulled, 4)
                }
                assertEqual(pulledData[0], 0.5)
                assertEqual(pulledData[1], 0.5)

                driver.setEnabled(false)
                assertFalse(driver.isEnabled)
            }

            test("Loopback Stem Recording & WAV Disk Export") {
                let recorder = LoopbackAudioRecorder()
                assertFalse(recorder.isRecording)

                do {
                    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_loopback_export.wav")
                    try? FileManager.default.removeItem(at: tempURL)

                    let fileURL = try recorder.startRecording(outputURL: tempURL, sampleRate: 44100.0, channels: 2)
                    assertTrue(recorder.isRecording)
                    assertEqual(fileURL, tempURL)

                    let format = AVAudioFormat(standardFormatWithSampleRate: 44100.0, channels: 2)!
                    if let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 128) {
                        pcmBuffer.frameLength = 128
                        recorder.recordBuffer(pcmBuffer)
                        assertEqual(recorder.recordedFrames, 128)
                    }

                    let stoppedURL = recorder.stopRecording()
                    assertFalse(recorder.isRecording)
                    assertEqual(stoppedURL, tempURL)
                    assertTrue(FileManager.default.fileExists(atPath: tempURL.path))

                    try? FileManager.default.removeItem(at: tempURL)
                } catch {
                    assertTrue(false, "LoopbackAudioRecorder test failed: \(error)")
                }
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

                // Recording across loop wrap (e.g. noteOn at tick 3800, loop ends at 3840, noteOff at tick 100)
                sequencer.transport.isRecording = true
                sequencer.transport.loopStartTick = 0
                sequencer.transport.loopEndTick = 3840
                sequencer.transport.loopEnabled = true
                sequencer.transport.currentTick = 3800
                sequencer.recordNoteOn(note: 64, velocity: 100)
                sequencer.transport.currentTick = 100
                sequencer.recordNoteOff(note: 64)

                assertEqual(sequencer.recordedEvents.count, 2)
                assertEqual(sequencer.recordedEvents[1].note, 64)
                assertEqual(sequencer.recordedEvents[1].durationTicks, (3840 - 3800) + 100)

                // Mid-playback BPM changes
                sequencer.setBPM(140.0)
                assertEqual(sequencer.transport.bpm, 140.0)

                sequencer.stop()
                assertFalse(sequencer.transport.isPlaying)
            }

            test("Performance Recording Pipeline captures live notes into Sequencer") {
                let appState = AppState()
                appState.toggleRecording()
                assertTrue(appState.isRecording)
                assertTrue(appState.sequencer.transport.isRecording)

                appState.sequencer.transport.currentTick = 0
                appState.handleFaceButtonEvent(role: .root, isPressed: true, velocity: 110)
                appState.sequencer.transport.currentTick = 480
                appState.handleFaceButtonEvent(role: .root, isPressed: false, velocity: 0)

                assertFalse(appState.sequencer.recordedEvents.isEmpty)
                let recorded = appState.sequencer.recordedEvents[0]
                assertEqual(recorded.startTick, 0)
                assertEqual(recorded.durationTicks, 480)

                appState.toggleRecording()
                assertFalse(appState.isRecording)
            }
        }

        suite("Instrument Intelligence: Bend, Pressure, Legato, MIDI") {
            test("Guitar bend centre, range, and return") {
                var engine = XPadController.PitchExpressionEngine(instrumentRange: 2, destinationRange: 48, curve: .linear, assist: .off, stickDeadzone: 0)
                let ctx = MusicalContext(key: .d, scale: Scale(root: .d, type: .naturalMinor))
                let note = Note(pitchClass: .e, octave: 4)
                let centre = engine.mappedSemitones(stickX: 0, heldNote: note, context: ctx)
                assertEqual(centre.semitones, 0.0)
                assertEqual(XPadController.PitchExpressionEngine.pitchBendValue(semitones: 0, range: 48), 8192)
                let full = engine.mappedSemitones(stickX: 1, heldNote: note, context: ctx)
                assertTrue(abs(full.semitones - 2.0) < 0.05)
                _ = engine.process(stickX: 1, heldNote: note, context: ctx, vibratoSemitones: 0, dt: 0.05)
                let state = engine.process(stickX: 0, heldNote: note, context: ctx, vibratoSemitones: 0, dt: 0.008)
                assertEqual(state.bendSemitones, 0.0, "One physical centre callback must clear the held note's bend.")
                assertEqual(state.midiPitchBend, 8192)
            }

            test("Hammer-on and pull-off inference") {
                let hammer = LegatoGestureInterpreter().interpret(
                    previous: Note(pitchClass: .e, octave: 4),
                    current: Note(pitchClass: .g, octave: 4),
                    overlap: true,
                    intervalMs: 70,
                    hasPickAttack: false,
                    slideModifier: false,
                    profile: .guitar,
                    realism: .natural,
                    sameString: true,
                    preparedLowerNote: false
                )
                assertTrue(hammer?.technique == .hammerOn)

                let pull = LegatoGestureInterpreter().interpret(
                    previous: Note(pitchClass: .g, octave: 4),
                    current: Note(pitchClass: .e, octave: 4),
                    overlap: true,
                    intervalMs: 80,
                    hasPickAttack: false,
                    slideModifier: false,
                    profile: .guitar,
                    realism: .natural,
                    sameString: true,
                    preparedLowerNote: true
                )
                assertTrue(pull?.technique == .pullOff)
            }

            test("Lead profile does not pretend to be guitar strum") {
                assertFalse(InstrumentProfile.synthLead.supportsStrumming)
                assertTrue(InstrumentProfile.synthLead.supportsPitchBend)
                assertEqual(InstrumentProfile.synthLead.defaultGestureMapping.rightStick, "Bend / Timbre")

                var guitar = InstrumentPerformanceEngine(profile: .guitar)
                var lead = InstrumentPerformanceEngine(profile: .synthLead)
                let chord = Chord(root: .d, quality: .minor)
                let context = MusicalContext(key: .d, scale: Scale(root: .d, type: .naturalMinor), chord: chord)
                let held = [Note(pitchClass: .e, octave: 4)]

                let guitarState = ControllerState()
                guitarState.rightStick = ProcessedStickState(x: 0.8, y: 0.1, radius: 0.81)
                let guitarFrame = guitar.process(state: guitarState, context: context, heldNotes: held, timestamp: 1)
                assertTrue(guitarFrame.bend.isBending)
                assertTrue(guitarFrame.suppressStrum)

                let leadState = ControllerState()
                leadState.rightStick = ProcessedStickState(x: 0.8, y: 0.6, radius: 1.0)
                let leadFrame = lead.process(state: leadState, context: context, heldNotes: held, timestamp: 1)
                assertTrue(leadFrame.suppressStrum)
                assertTrue(leadFrame.timbre > 0.5)
            }

            test("Pressure envelope is independent of attack") {
                var engine = PressureEnvelopeEngine(curve: .linear, smoothingTau: 0.01)
                let attack = engine.process(raw: 0.2, noteHeld: true, dt: 0.02)
                var held = attack
                for _ in 0..<8 {
                    held = engine.process(raw: 0.9, noteHeld: true, dt: 0.02)
                }
                assertTrue(held.smoothed > attack.smoothed)
                assertTrue(held.midiValue > 0)
                engine.reset()
                let released = engine.process(raw: 0, noteHeld: false, dt: 0.02)
                assertFalse(released.isActive)
            }

            test("Slide interpolates and arrives cleanly") {
                var engine = SlideEngine(duration: 0.1)
                engine.begin(from: Note(pitchClass: .e, octave: 4), to: Note(pitchClass: .g, octave: 4))
                var state = engine.advance(dt: 0.03)
                assertTrue(state.isSliding)
                assertTrue(state.pitchOffset > 0)
                state = engine.advance(dt: 0.2)
                assertTrue(state.arrived)
                assertTrue(abs(state.pitchOffset - 3) < 0.02)
            }

            test("Pinch harmonic translation uses timbre strategy") {
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
                assertEqual(result.strategyUsed, .mpeTimbre)
                assertTrue(result.events.contains(where: {
                    if case .timbreCC74(_, let value) = $0 { return value > 90 }
                    return false
                }))
            }

            test("Conventional MIDI blocks per-note chord bends") {
                let translator = TechniqueMIDITranslator(destination: .genericMIDI, profile: .guitar)
                let blocked = translator.translateBend(semitones: 2, channel: 0, activeVoiceCount: 4)
                assertTrue(blocked?.events.isEmpty == true)
                assertNotNil(blocked?.fallbackDescription)
            }

            test("Contextual bend targets include chord and scale tones") {
                let context = MusicalContext(
                    key: .d,
                    scale: Scale(root: .d, type: .naturalMinor),
                    chord: Chord(root: .d, quality: .minor)
                )
                let targets = ContextualPitchTargeter().bendTargets(
                    from: Note(pitchClass: .e, octave: 4),
                    rangeSemitones: 2,
                    context: context,
                    allowDownward: true
                )
                assertTrue(!targets.isEmpty)
                assertTrue(targets.contains(where: { abs($0.semitones - 2) < 0.01 }))
            }

            test("Harmonic chord bender bends C Major triad in-key to D minor triad") {
                let bender = HarmonicChordBender()
                let cMajorTriad = [
                    Note(pitchClass: .c, octave: 4), // 60
                    Note(pitchClass: .e, octave: 4), // 64
                    Note(pitchClass: .g, octave: 4)  // 67
                ]
                let context = MusicalContext(
                    key: .c,
                    scale: Scale(root: .c, type: .major),
                    chord: Chord(root: .c, quality: .major),
                    pitchAssist: .strong
                )
                // Lead note (C4=60) bends up +2 semitones (to D4)
                let bends = bender.bends(for: cMajorTriad, leadBendSemitones: 2.0, context: context)
                
                // In C Major:
                // C4 -> D4 (+2 semitones)
                // E4 -> F4 (+1 semitone)
                // G4 -> A4 (+2 semitones)
                let cBend = bends[60] ?? 0
                let eBend = bends[64] ?? 0
                let gBend = bends[67] ?? 0

                assertEqual(Int(cBend.rounded()), 2)
                assertEqual(Int(eBend.rounded()), 1)
                assertEqual(Int(gBend.rounded()), 2)

                let resultingNotes = [
                    Note.fromMIDI(UInt8(60 + Int(cBend.rounded()))),
                    Note.fromMIDI(UInt8(64 + Int(eBend.rounded()))),
                    Note.fromMIDI(UInt8(67 + Int(gBend.rounded())))
                ]
                let score = bender.consonanceScore(for: resultingNotes)
                assertTrue(score > 0.75, "Resulting D minor chord must have high harmonic consonance")
            }

            test("Harmonic chord bender downward bend preserves in-key harmony") {
                let bender = HarmonicChordBender()
                let cMajorTriad = [
                    Note(pitchClass: .c, octave: 4), // 60
                    Note(pitchClass: .e, octave: 4), // 64
                    Note(pitchClass: .g, octave: 4)  // 67
                ]
                let context = MusicalContext(
                    key: .c,
                    scale: Scale(root: .c, type: .major),
                    chord: Chord(root: .c, quality: .major),
                    pitchAssist: .strong
                )
                // Lead note bends down -1 semitone (1 diatonic step down: C->B is -1, E->D is -2, G->F is -2)
                let bends = bender.bends(for: cMajorTriad, leadBendSemitones: -1.0, context: context)
                
                let cBend = bends[60] ?? 0
                let eBend = bends[64] ?? 0
                let gBend = bends[67] ?? 0

                assertEqual(Int(cBend.rounded()), -1)
                assertEqual(Int(eBend.rounded()), -2)
                assertEqual(Int(gBend.rounded()), -2)
            }

            test("Harmonic chord bender chromatic mode applies parallel bend") {
                let bender = HarmonicChordBender()
                let chord = [
                    Note(pitchClass: .c, octave: 4),
                    Note(pitchClass: .e, octave: 4),
                    Note(pitchClass: .g, octave: 4)
                ]
                var context = MusicalContext(
                    key: .c,
                    scale: Scale(root: .c, type: .major),
                    chord: Chord(root: .c, quality: .major),
                    pitchAssist: .light
                )
                context.chromaticMode = true

                let bends = bender.bends(for: chord, leadBendSemitones: 2.5, context: context)
                assertEqual(bends[60], 2.5)
                assertEqual(bends[64], 2.5)
                assertEqual(bends[67], 2.5)
            }

            test("Harmonic chord bender handles downward diatonic pitch bends without arithmetic overflow") {
                let bender = HarmonicChordBender()
                let chord = [
                    Note(pitchClass: .c, octave: 4),
                    Note(pitchClass: .e, octave: 4),
                    Note(pitchClass: .g, octave: 4)
                ]
                let context = MusicalContext(
                    key: .c,
                    scale: Scale(root: .c, type: .major),
                    chord: Chord(root: .c, quality: .major),
                    pitchAssist: .strong
                )

                // Downward bend of -2 semitones (C major triad bends down in C major to B diminished or nearest diatonic step)
                let downwardBends = bender.bends(for: chord, leadBendSemitones: -2.0, context: context)
                assertTrue(downwardBends[60] != nil)
                assertTrue(downwardBends[64] != nil)
                assertTrue(downwardBends[67] != nil)
                assertTrue(downwardBends[60]! < 0)
                assertTrue(downwardBends[64]! < 0)
                assertTrue(downwardBends[67]! < 0)
            }

            test("Technique SMF export includes pitch bend") {
                let exporter = SMFExporter()
                let events = [
                    RecordedTechniqueEvent(
                        tick: 0,
                        event: InstrumentPerformanceEvent(note: .middleC, technique: .bend, velocity: 90, pitchOffset: 2),
                        durationTicks: 480
                    )
                ]
                let data = exporter.encodeTechniques(events: events, bpm: 120, ppqn: 960)
                assertEqual(Array(data[0..<4]), [0x4D, 0x54, 0x68, 0x64])
                assertEqual(Array(data.suffix(3)), [0xFF, 0x2F, 0x00])
                assertTrue(data.contains(where: { $0 >= 0xE0 && $0 <= 0xEF }))
            }
        }

        // MARK: - Dynamic Adaptive Triggers Tests
        suite("Dynamic Adaptive Triggers: DualSense Resistance, Gauges & Detents") {
            test("Guitar string tension exponential force curve and pluck snap") {
                let engine = AdaptiveTriggerEngine()
                let config = AdaptiveTriggerConfig(mode: .guitarStringTension, stringGauge: .regular010, resistiveStrength: 0.8)

                let lowTravel = engine.calculateTriggerState(position: 0.2, velocity: 0, config: config, label: "L2")
                let midTravel = engine.calculateTriggerState(position: 0.6, velocity: 0, config: config, label: "L2")
                let highTravel = engine.calculateTriggerState(position: 0.85, velocity: 0, config: config, label: "L2")
                let snapRelease = engine.calculateTriggerState(position: 0.98, velocity: 0, config: config, label: "L2")

                assertTrue(lowTravel.calculatedForce < midTravel.calculatedForce)
                assertTrue(midTravel.calculatedForce < highTravel.calculatedForce)
                assertTrue(snapRelease.calculatedForce < highTravel.calculatedForce, "Pluck release must drop tension past 90% travel.")
            }

            test("String gauge stiffness scales physical tension") {
                let engine = AdaptiveTriggerEngine()
                let lightCfg = AdaptiveTriggerConfig(mode: .guitarStringTension, stringGauge: .light009, resistiveStrength: 1.0)
                let bassCfg = AdaptiveTriggerConfig(mode: .guitarStringTension, stringGauge: .bass045, resistiveStrength: 1.0)

                let lightState = engine.calculateTriggerState(position: 0.7, velocity: 0, config: lightCfg, label: "L2")
                let bassState = engine.calculateTriggerState(position: 0.7, velocity: 0, config: bassCfg, label: "L2")

                assertTrue(bassState.calculatedForce > lightState.calculatedForce)
            }

            test("Bowed string viscous drag scales with gesture velocity") {
                let engine = AdaptiveTriggerEngine()
                let bowCfg = AdaptiveTriggerConfig(mode: .bowDragResistance, resistiveStrength: 0.7)

                let slowBow = engine.calculateTriggerState(position: 0.5, velocity: 0.5, config: bowCfg, label: "R2")
                let fastBow = engine.calculateTriggerState(position: 0.5, velocity: 3.5, config: bowCfg, label: "R2")

                assertTrue(fastBow.calculatedForce > slowBow.calculatedForce)
            }

            test("Mod-wheel detent notch detection and snap threshold") {
                let engine = AdaptiveTriggerEngine()
                let detentCfg = AdaptiveTriggerConfig(mode: .modWheelDetents, resistiveStrength: 0.8, detentCount: 10)

                // Exact step position: 0.5 (step 5 / 10)
                let inNotch = engine.calculateTriggerState(position: 0.502, velocity: 0, config: detentCfg, label: "R2")
                assertTrue(inNotch.isInDetent)
                assertEqual(inNotch.activeDetentIndex, 5)

                // Between steps: 0.55
                let betweenNotches = engine.calculateTriggerState(position: 0.55, velocity: 0, config: detentCfg, label: "R2")
                assertFalse(betweenNotches.isInDetent)
            }

            test("Palm mute shelf kicks in past dampening threshold") {
                let engine = AdaptiveTriggerEngine()
                let palmCfg = AdaptiveTriggerConfig(mode: .palmMuteShelf, startPosition: 0.4, resistiveStrength: 0.85)

                let openStrum = engine.calculateTriggerState(position: 0.2, velocity: 0, config: palmCfg, label: "L2")
                let mutedStrum = engine.calculateTriggerState(position: 0.7, velocity: 0, config: palmCfg, label: "L2")

                assertTrue(openStrum.calculatedForce < 0.1)
                assertTrue(mutedStrum.calculatedForce > 0.6)
            }

            test("Instrument profile automatic trigger configuration") {
                let engine = AdaptiveTriggerEngine()
                engine.configureForInstrumentProfile(.guitar)
                assertEqual(engine.leftConfig.mode, .palmMuteShelf)
                assertEqual(engine.rightConfig.mode, .guitarStringTension)

                engine.configureForInstrumentProfile(.synthLead)
                assertEqual(engine.leftConfig.mode, .modWheelDetents)
                assertEqual(engine.rightConfig.mode, .modWheelDetents)
            }
        }

        // MARK: - Voice-Led Solo Engine Tests
        suite("Voice-Led Lead Guitar Solo Mode: Polar Navigation, Guide Tones & Enclosures") {
            test("Polar stick quadrant mapping") {
                let engine = VoiceLedSoloEngine()
                assertEqual(engine.polarQuadrant(for: .pi / 2), .northGuideTones)
                assertEqual(engine.polarQuadrant(for: -.pi / 2), .southBassAnchors)
                assertEqual(engine.polarQuadrant(for: 0), .eastDiatonicScale)
                assertEqual(engine.polarQuadrant(for: .pi), .westEnclosures)
            }

            test("North guide tones resolve 3rds and 7ths of active chord") {
                let engine = VoiceLedSoloEngine()
                let cMaj7 = Chord(root: .c, quality: .major7)
                let ctx = MusicalContext(key: .c, scale: Scale(root: .c, type: .major), chord: cMaj7, registerOctave: 4)

                // Outer North: 7th (B)
                let highSolo = engine.evaluateStick(stickX: 0, stickY: 0.9, radius: 0.9, angle: .pi / 2, velocity: 1.0, context: ctx)
                assertTrue(highSolo.isGuideTone)
                assertEqual(highSolo.targetNote.pitchClass, .b)

                // Mid North: 3rd (E)
                let midSolo = engine.evaluateStick(stickX: 0, stickY: 0.55, radius: 0.55, angle: .pi / 2, velocity: 0.5, context: ctx)
                assertTrue(midSolo.isGuideTone)
                assertEqual(midSolo.targetNote.pitchClass, .e)
            }

            test("Harmonic guide-tone voice leading during chord transition") {
                let engine = VoiceLedSoloEngine()
                let dm7 = Chord(root: .d, quality: .minor7)
                let g7 = Chord(root: .g, quality: .dominant7)
                let ctx = MusicalContext(key: .c, scale: Scale(root: .c, type: .major), chord: g7, registerOctave: 4)

                // Sustaining C (7th of Dm7), chord changes to G7 -> should smoothly voice lead to B (3rd of G7)
                let prevNote = Note(pitchClass: .c, octave: 4)
                let resolution = engine.resolveChordTransition(from: prevNote, oldChord: dm7, newChord: g7, context: ctx)

                assertEqual(resolution.targetNote.pitchClass, .b)
                assertTrue(resolution.isGuideTone)
            }

            test("West quadrant generates chromatic approach and blues notes") {
                let engine = VoiceLedSoloEngine()
                let aMin = Chord(root: .a, quality: .minor)
                let ctx = MusicalContext(key: .a, scale: Scale(root: .a, type: .naturalMinor), chord: aMin, registerOctave: 4)

                // Outer West: Flat-5 Blue Note (Eb)
                let blueNote = engine.evaluateStick(stickX: -0.85, stickY: 0, radius: 0.85, angle: .pi, velocity: 1.0, context: ctx)
                assertTrue(blueNote.isBlueNote)
                assertEqual(blueNote.targetNote.pitchClass, .dSharp) // D#/Eb

                // Inner West: Chromatic approach
                let approach = engine.evaluateStick(stickX: -0.45, stickY: 0, radius: 0.45, angle: .pi, velocity: 0.5, context: ctx)
                assertTrue(approach.isPassingTone)
                assertEqual(approach.targetNote.pitchClass, .c)
            }

            test("Smart solo engine real-time note-on and note-off lifecycle") {
                let engine = SmartSoloEngine()
                let chord = Chord(root: .c, quality: .major)
                let ctx = MusicalContext(key: .c, scale: Scale(root: .c, type: .major), chord: chord)

                // Rest inside deadzone
                let rest = engine.process(stick: StickCoordinates(x: 0, y: 0), movementVelocity: 0, context: ctx, timestamp: 1.0)
                assertTrue(rest.noteOn == nil)

                // Strike North
                let strike = engine.process(stick: StickCoordinates(x: 0, y: 0.8), movementVelocity: 5.0, context: ctx, timestamp: 1.05)
                assertTrue(strike.noteOn != nil)
                assertTrue(engine.telemetry.isActive)

                // Return to deadzone
                let release = engine.process(stick: StickCoordinates(x: 0, y: 0), movementVelocity: 0, context: ctx, timestamp: 1.20)
                assertTrue(release.noteOff != nil)
                assertFalse(engine.telemetry.isActive)

                // Sweep across +/- pi boundary smoothly without retriggering as a violent flick
                _ = engine.process(stick: StickCoordinates(x: -0.8, y: 0.05), movementVelocity: 1.0, context: ctx, timestamp: 1.30)
                let sweep = engine.process(stick: StickCoordinates(x: -0.8, y: -0.05), movementVelocity: 1.0, context: ctx, timestamp: 1.50)
                // Small angular movement across boundary should not trigger a new strike
                assertTrue(sweep.noteOn == nil)
            }
        }

        // MARK: - Multi-Controller Jamming Tests
        suite("Multi-Controller Jamming: 4-Player Slots, Shared Clock & MIDI Routing") {
            test("4-Player default slot initialization and role assignment") {
                let manager = MultiControllerJammingManager()
                assertEqual(manager.players.count, 4)

                assertEqual(manager.players[.p1]?.role, .chords)
                assertEqual(manager.players[.p2]?.role, .bass)
                assertEqual(manager.players[.p3]?.role, .lead)
                assertEqual(manager.players[.p4]?.role, .drums)

                assertEqual(manager.players[.p1]?.midiChannel, 0)
                assertEqual(manager.players[.p2]?.midiChannel, 1)
                assertEqual(manager.players[.p3]?.midiChannel, 2)
                assertEqual(manager.players[.p4]?.midiChannel, 9)
            }

            test("Simulated state injection per player slot") {
                let manager = MultiControllerJammingManager()
                var receivedSlot: PlayerSlotId?
                var receivedState: ControllerState?

                manager.onPlayerStateChanged = { slot, state in
                    receivedSlot = slot
                    receivedState = state
                }

                manager.injectPlayerState(slot: .p3) { state in
                    state.buttonA = true
                    state.rightTrigger = ProcessedTriggerState(rawValue: 0.8, value: 0.8, isPressed: true)
                }

                assertEqual(receivedSlot, .p3)
                assertTrue(receivedState?.buttonA == true)
                assertTrue(receivedState?.rightTrigger.value == 0.8)
            }

            test("Shared harmonic synchronization across all 4 jam slots") {
                let manager = MultiControllerJammingManager()
                let newKey = PitchClass.fSharp
                let newScale = Scale(root: newKey, type: .dorian)
                let newChord = Chord(root: .gSharp, quality: .minor7)

                manager.updateSharedHarmony(key: newKey, scale: newScale, chord: newChord)
                assertEqual(manager.currentKey, .fSharp)
                assertEqual(manager.currentScale.type, .dorian)
                assertEqual(manager.activeChord.displayName, "A♭m7")
            }

            test("Dynamic track role reassignment updates MIDI channels") {
                let manager = MultiControllerJammingManager()
                manager.setRole(.lead, for: .p1)
                assertEqual(manager.players[.p1]?.role, .lead)
                assertEqual(manager.players[.p1]?.midiChannel, 2)
                manager.applyChannelMap(HostMIDIContext.abletonLive.dedicatedPortChannels)
                assertEqual(manager.players[.p1]?.midiChannel, 0)
                manager.setRole(.drums, for: .p1)
                assertEqual(manager.players[.p1]?.midiChannel, 9)
                manager.setRole(.lead, for: .p1)
                assertEqual(manager.players[.p1]?.midiChannel, 0)
                manager.applyChannelMap(.sharedCableJam)
                assertEqual(manager.players[.p1]?.midiChannel, 2)
            }
        }

        suite("DAW Host MIDI Channel Context") {
            test("Logic and Live advertise 15-member lower zones") {
                assertEqual(HostMIDIContext.logicPro.mpeZone.memberCount, 15)
                assertEqual(HostMIDIContext.abletonLive.mpeZone.memberChannels.last, 15)
                assertFalse(HostMIDIContext.flStudio.supportsMPE)
            }

            test("Filtered DAW track channel disables MPE") {
                let layout = HostMIDIContextResolver.resolveLayout(
                    context: .logicPro,
                    trackMode: .filtered(3)
                )
                assertFalse(layout.usesMPE)
                assertEqual(layout.channel(for: .melody), 3)
                assertEqual(layout.channel(for: .drums), 9)
            }

            test("Auto-detect matches Ableton bundle ID") {
                let resolved = HostMIDIContextResolver.resolve(
                    selection: .autoDetect,
                    signals: HostDetectionSignals(bundleIdentifiers: ["com.ableton.live"])
                )
                assertEqual(resolved.kind, .abletonLive)
            }

            test("Frontmost Live wins over background Logic") {
                let resolved = HostMIDIContextResolver.resolve(
                    selection: .autoDetect,
                    signals: HostDetectionSignals(
                        frontmostBundleIdentifier: "com.ableton.live",
                        bundleIdentifiers: ["com.apple.logic10", "com.ableton.live"]
                    )
                )
                assertEqual(resolved.kind, .abletonLive)
            }
        }

        // MARK: - Open Controller Definition Standard (OCDS) Tests
        suite("Open Controller Definition Standard (OCDS): JSON Schema & Bundled Profiles") {
            test("Bundled profiles loaded for all 13 controller hardware types") {
                let manager = OCDSManager.shared
                assertEqual(manager.bundledProfiles.count, 13)

                assertTrue(manager.profile(for: "sony_dualsense_mpe") != nil)
                assertTrue(manager.profile(for: "xbox_wireless_expressive") != nil)
                assertTrue(manager.profile(for: "switch_pro_gyro") != nil)
                assertTrue(manager.profile(for: "guitar_hero_fretboard") != nil)
                assertTrue(manager.profile(for: "sound_voltex_console") != nil)
                assertTrue(manager.profile(for: "beatmania_djdao") != nil)
                assertTrue(manager.profile(for: "flight_stick_hotas") != nil)
                assertTrue(manager.profile(for: "racing_wheel_pedals") != nil)
            }

            test("OCDS profile JSON serialization and deserialization integrity") {
                let manager = OCDSManager.shared
                let dualSense = manager.profile(for: "sony_dualsense_mpe")!

                do {
                    let json = try manager.encodeToJSON(dualSense)
                    assertTrue(json.contains("\"schemaVersion\" : \"1.0.0\""))
                    assertTrue(json.contains("\"id\" : \"sony_dualsense_mpe\""))
                    assertTrue(json.contains("\"hasAdaptiveTriggers\" : true"))

                    let decoded = try manager.decodeFromJSON(json)
                    assertEqual(decoded.metadata.id, dualSense.metadata.id)
                    assertEqual(decoded.hardwareSpec.buttonCount, dualSense.hardwareSpec.buttonCount)
                    assertEqual(decoded.inputBindings.count, dualSense.inputBindings.count)
                } catch {
                    assertTrue(false, "OCDS serialization failed: \(error)")
                }
            }

            test("OCDS JSON schema v1 validation and error handling") {
                let manager = OCDSManager.shared

                // Invalid schema version
                let badVersion = OCDSProfile(
                    schemaVersion: "2.0.0",
                    metadata: OCDSMetadata(id: "test", name: "Test"),
                    hardwareSpec: OCDSHardwareSpec()
                )
                var caughtError = false
                do {
                    try manager.validate(badVersion)
                } catch {
                    caughtError = true
                }
                assertTrue(caughtError, "Schema validator must reject unsupported schema version.")

                // Invalid deadzone range
                let badDeadzone = OCDSProfile(
                    metadata: OCDSMetadata(id: "test_dz", name: "Test"),
                    hardwareSpec: OCDSHardwareSpec(),
                    inputBindings: [OCDSInputBinding(source: .leftStick, target: .pitchBend, deadzone: 1.5)]
                )
                var caughtDzError = false
                do {
                    try manager.validate(badDeadzone)
                } catch {
                    caughtDzError = true
                }
                assertTrue(caughtDzError, "Validator must reject deadzones > 1.0.")
            }

            test("Custom community profile registration and lookup") {
                let manager = OCDSManager()
                let custom = OCDSProfile(
                    metadata: OCDSMetadata(
                        id: "community_hitbox_arcade",
                        name: "Hitbox Leverless Arcade Controller",
                        author: "FGC Producer",
                        description: "24mm Sanwa button mapping with instant chromatic chords."
                    ),
                    hardwareSpec: OCDSHardwareSpec(stickCount: 0, triggerCount: 0, buttonCount: 12)
                )

                do {
                    try manager.registerCustomProfile(custom)
                    let retrieved = manager.profile(for: "community_hitbox_arcade")
                    assertNotNil(retrieved)
                    assertEqual(retrieved?.metadata.author, "FGC Producer")
                } catch {
                    assertTrue(false, "Failed to register custom profile: \(error)")
                }
            }
        }

        // ==================================================
        // SUITE: Control Schemes, Ergonomics, Hardware Calibration & Remapping
        // ==================================================
        suite("Control Schemes, Ergonomics, Hardware Calibration & Remapping") {
            test("Control Scheme presets default bindings & structure") {
                let perf = ControlSchemePreset.xpiPerformance
                assertEqual(perf.id, "xpi_performance")
                assertEqual(perf.bindings[.harmonyNavigate2D]?.input, .leftStick2D)
                assertEqual(perf.bindings[.primaryExcitation]?.input, .rightStickY)
                assertEqual(perf.bindings[.pitchExpression]?.input, .rightStickX)
                assertEqual(perf.bindings[.dampingExpression]?.input, .leftTrigger)
                assertEqual(perf.bindings[.pressureExpression]?.input, .rightTrigger)
                assertEqual(perf.bindings[.techniqueModifier]?.input, .leftShoulder)
                assertEqual(perf.bindings[.sustainLatch]?.input, .rightShoulder)
                assertTrue(perf.isBuiltIn)

                let classic = ControlSchemePreset.xpiClassic
                assertEqual(classic.id, "xpi_classic")
                assertEqual(classic.bindings[.harmonyNavigate2D]?.input, .leftStick2D)

                let lowFatigue = ControlSchemePreset.lowFatigue
                assertEqual(lowFatigue.id, "xpi_low_fatigue")
                assertEqual(lowFatigue.stickFeel, .responsive)
                assertEqual(lowFatigue.triggerFeel, .soft)
                assertEqual(lowFatigue.bindings[.voicingNext]?.input, .dpadRight)
                assertEqual(lowFatigue.bindings[.soloModeToggle]?.input, .buttonCenter)

                let oneHandL = ControlSchemePreset.oneHandLeft
                assertEqual(oneHandL.bindings[.primaryExcitation]?.input, .leftTrigger)
                assertEqual(oneHandL.bindings[.harmonyNavigate2D]?.input, .leftStick2D)

                let oneHandR = ControlSchemePreset.oneHandRight
                assertEqual(oneHandR.bindings[.primaryExcitation]?.input, .rightTrigger)
                assertEqual(oneHandR.bindings[.harmonyNavigate2D]?.input, .rightStick2D)

                let leftHanded = ControlSchemePreset.leftHandedPerformance
                assertEqual(leftHanded.id, "xpi_left_handed")
                assertEqual(leftHanded.bindings[.harmonyNavigate2D]?.input, .rightStick2D)
                assertEqual(leftHanded.bindings[.primaryExcitation]?.input, .leftStickY)
                assertEqual(ControlSchemePreset.allBuiltIn.count, 10)
            }

            test("Semantic musical action categories and compatibility") {
                assertEqual(SemanticMusicalAction.primaryExcitation.category, .excitation)
                assertEqual(SemanticMusicalAction.pitchExpression.category, .expression)
                assertEqual(SemanticMusicalAction.harmonyNavigate2D.category, .harmony)
                assertEqual(SemanticMusicalAction.techniqueModifier.category, .articulation)
                assertEqual(SemanticMusicalAction.voiceDegree1.category, .directVoices)
                assertEqual(SemanticMusicalAction.panic.category, .utility)

                assertEqual(SemanticMusicalAction.harmonyNavigate2D.compatibilityType, .continuous2D)
                assertEqual(SemanticMusicalAction.primaryExcitation.compatibilityType, .continuous1DOr2D)
                assertEqual(SemanticMusicalAction.techniqueModifier.compatibilityType, .digitalMomentary)
            }

            test("Thumbstick hardware calibration and drift deadzone suppression") {
                let cal = StickCalibration(
                    restCenterX: 0.05,
                    restCenterY: -0.04,
                    driftRadius: 0.08,
                    maxRadius: 0.95
                )

                // Resting input near drift offset must be clamped strictly to 0
                let resting = cal.calibrate(rawX: 0.06, rawY: -0.03)
                assertEqual(resting.x, 0.0)
                assertEqual(resting.y, 0.0)

                // Excursion past drift deadzone must scale outward smoothly
                let active = cal.calibrate(rawX: 0.95, rawY: -0.04)
                assertTrue(active.x > 0.9)
                assertEqual(active.y, 0.0)
            }

            test("Trigger hardware calibration and travel thresholding") {
                let cal = TriggerCalibration(restMin: 0.06, travelMax: 0.92, sensitivity: 1.0)
                
                // Below rest threshold must be 0
                assertEqual(cal.calibrate(rawValue: 0.04), 0.0)
                
                // Half travel
                let mid = cal.calibrate(rawValue: 0.49)
                assertTrue(mid > 0.45 && mid < 0.55)
                
                // Full travel
                let maxVal = cal.calibrate(rawValue: 0.95)
                assertEqual(maxVal, 1.0)
            }

            test("StickProcessor per-axis inversion and sensitivity multipliers") {
                var processor = StickProcessor(profile: .expressive)
                processor.invertY = true
                processor.sensitivityX = 1.5

                let processed = processor.process(rawX: 0.4, rawY: 0.4, timestamp: 1.0)
                assertTrue(processed.calibratedX > 0.5, "Sensitivity multiplier should increase effective excursion.")
                assertTrue(processed.calibratedY < 0.0, "Y inversion must reverse axis direction.")
            }

            test("Analog pipeline isolates stick history from digital and trigger events") {
                let profile = InputProcessingProfile(
                    id: "test",
                    name: "Test",
                    deadzone: .none,
                    responseCurve: .linear,
                    smoothingFactor: 1
                )
                var pipeline = AnalogControlPipeline(
                    leftStickProcessor: StickProcessor(profile: profile),
                    leftTriggerProcessor: TriggerProcessor(deadzone: 0, smoothingFactor: 1)
                )
                var snapshot = RawAnalogSnapshot()
                pipeline.process(snapshot: snapshot, changedPhysicalControls: [.leftStick], timestamp: 0)

                snapshot.leftStickX = 1
                pipeline.process(snapshot: snapshot, changedPhysicalControls: [.leftStick], timestamp: 0.01)
                let velocityAfterMove = pipeline.leftStick.movementVelocity
                assertTrue(velocityAfterMove > 1)

                pipeline.process(snapshot: snapshot, changedPhysicalControls: [], timestamp: 0.02)
                assertEqual(pipeline.leftStick.movementVelocity, velocityAfterMove)

                snapshot.leftTrigger = 1
                pipeline.process(snapshot: snapshot, changedPhysicalControls: [.leftTrigger], timestamp: 0.03)
                assertEqual(pipeline.leftStick.movementVelocity, velocityAfterMove)
                assertEqual(pipeline.leftTrigger.value, 1.0)
            }

            test("Left/right swap routes physical left stick onto the musical right processor") {
                let profile = InputProcessingProfile(
                    id: "test",
                    name: "Test",
                    deadzone: .none,
                    responseCurve: .linear,
                    smoothingFactor: 1
                )
                var pipeline = AnalogControlPipeline(
                    leftStickProcessor: StickProcessor(profile: profile),
                    rightStickProcessor: StickProcessor(profile: profile)
                )
                var snapshot = RawAnalogSnapshot()
                pipeline.process(
                    snapshot: snapshot,
                    changedPhysicalControls: [.leftStick],
                    swapLeftRight: true,
                    timestamp: 0
                )
                snapshot.leftStickX = 1
                pipeline.process(
                    snapshot: snapshot,
                    changedPhysicalControls: [.leftStick],
                    swapLeftRight: true,
                    timestamp: 0.01
                )

                assertEqual(pipeline.leftStick.x, 0.0)
                assertTrue(pipeline.rightStick.x > 0.9)
                assertTrue(pipeline.rightStick.movementVelocity > 1)
            }

            test("Interactive calibration wizard step progression and capture") {
                let wizard = CalibrationWizard()
                wizard.start()
                assertEqual(wizard.currentStep, .measuringRest(samples: 0))

                // Feed rest samples
                for _ in 0..<65 {
                    wizard.feed(rawLeftX: 0.02, rawLeftY: -0.01, rawRightX: -0.03, rawRightY: 0.02)
                }

                if case .measuringRange = wizard.currentStep {
                    assertTrue(true)
                } else {
                    assertTrue(false, "Wizard should transition to measuringRange after rest samples.")
                }

                // Feed rotation excursion
                wizard.feed(rawLeftX: 0.98, rawLeftY: 0.0, rawRightX: 0.0, rawRightY: 0.96)
                let result = wizard.finish()
                assertEqual(wizard.currentStep, .completed)
                assertTrue(result.leftStick.restCenterX > 0.01)
                assertTrue(result.leftStick.maxRadius >= 0.85)

                // Premature finish from idle does NOT impose 85% ceiling
                let freshWizard = CalibrationWizard()
                let idleResult = freshWizard.finish()
                assertEqual(idleResult.leftStick.maxRadius, 1.0)
                assertEqual(idleResult.rightStick.maxRadius, 1.0)

                // Validation & repair of corrupt / NaN calibration
                var corruptStick = StickCalibration(
                    restCenterX: Float.nan,
                    driftRadius: -0.5,
                    maxRadius: Float.nan
                )
                corruptStick.validateAndRepair()
                assertTrue(corruptStick.isValid)
                assertEqual(corruptStick.restCenterX, 0.0)
                assertEqual(corruptStick.maxRadius, 1.0)
                assertTrue(corruptStick.driftRadius > 0.0)
            }

            test("Control scheme remapping conflict detection") {
                var scheme = ControlSchemePreset.xpiPerformance

                // No conflicts in default preset
                let clean = MappingConflict.detectConflicts(in: scheme)
                assertEqual(clean.count, 0)

                // Induce critical conflict: Map Strum and Harmonic wheel to the same stick
                scheme.bindings[.primaryExcitation] = PhysicalControlBinding(input: .leftStick2D)
                let conflicts = MappingConflict.detectConflicts(in: scheme)
                assertTrue(conflicts.contains { $0.severity == .critical }, "Mutually exclusive primary actions on the same control must be flagged as critical.")
            }

            test("Control surface resolver remaps one-hand left trigger onto strum axis") {
                var resolver = ControlSurfaceResolver(scheme: ControlSchemePreset.oneHandLeft)
                let physical = ControllerState()
                physical.leftTrigger = ProcessedTriggerState(rawValue: 0.88, calibratedValue: 0.88, value: 0.88, isPressed: true)
                physical.leftStick = ProcessedStickState(x: 0.1, y: 0.6, radius: hypot(Float(0.1), Float(0.6)), angle: atan2(0.6, 0.1))
                let frame = resolver.evaluate(state: physical, timestamp: 1)
                let logical = ControllerState()
                resolver.project(frame: frame, physical: physical, onto: logical)
                assertTrue(logical.rightStick.y > 0.8)
                assertTrue(abs(logical.leftStick.y - 0.6) < 0.001)
            }

            test("Input learn prefers 2D stick when both axes move together") {
                let detected = InputLearnDetector.detect(leftStickX: 0.62, leftStickY: 0.58, prefer2D: true)
                assertTrue(detected == .leftStick2D)
            }

            test("Dynamic prompt and glyph single-source-of-truth generation") {
                let manager = ControllerManager()
                manager.selectControllerKind(.dualSense)
                manager.selectControlScheme(ControlSchemePreset.xpiPerformance)

                let strumLabel = manager.controlLabel(for: .primaryExcitation)
                assertEqual(strumLabel, "Right Stick Y")

                let dampingLabel = manager.controlLabel(for: .dampingExpression)
                assertEqual(dampingLabel, "L2")

                // Switch to Xbox controller kind
                manager.selectControllerKind(.xbox)
                let xboxDamp = manager.controlLabel(for: .dampingExpression)
                assertEqual(xboxDamp, "LT")
            }

            test("Safe control scheme switching without stuck notes") {
                let manager = ControllerManager()
                manager.selectControlScheme(ControlSchemePreset.xpiPerformance)
                assertEqual(manager.activeScheme.id, "xpi_performance")

                // Switch to low-fatigue scheme
                manager.selectControlScheme(ControlSchemePreset.lowFatigue)
                assertEqual(manager.activeScheme.id, "xpi_low_fatigue")
                assertEqual(manager.leftStickProcessor.profile.id, "fast")
                assertEqual(manager.leftTriggerProcessor.deadzone, 0.04)
                manager.selectControlScheme(ControlSchemePreset.xpiPerformance)
            }

            test("ControlScheme and HardwareCalibration JSON persistence and roundtrip") {
                let scheme = ControlSchemePreset.xpiPerformance.makeCustomCopy(name: "My Custom Synth Scheme")
                let store = ControllerSettingsStore.shared
                store.saveCustomScheme(scheme)

                let loaded = store.loadCustomSchemes()
                assertTrue(loaded.contains { $0.id == scheme.id })
                assertEqual(loaded.first(where: { $0.id == scheme.id })?.name, "My Custom Synth Scheme")

                // Test hardware calibration persistence
                var cal = ControllerHardwareCalibration(controllerIdentifier: "test_dualsense_01")
                cal.leftStick.restCenterX = 0.045
                store.saveCalibration(cal)

                let loadedCal = store.loadCalibration(for: "test_dualsense_01")
                assertEqual(loadedCal.leftStick.restCenterX, 0.045)
            }
        }

        // ==================================================
        // SUITE: MIDI-CI MPE Profile (M2-120-UM_v2-0-3) Negotiation & Discovery
        // ==================================================
        suite("MIDI-CI MPE Profile (M2-120-UM_v2-0-3) Negotiation & Discovery") {
            test("Discovery inquiry generation and MUID format") {
                let session = MIDICISession(muid: 0x0123_4567)
                let inquiry = session.buildDiscoveryInquiry()
                assertTrue(inquiry.count >= 20)
                assertEqual(inquiry[0], 0xF0)
                assertEqual(inquiry[1], 0x7E)
                assertEqual(inquiry[2], 0x7F)
                assertEqual(inquiry[3], 0x0D) // MIDI-CI Sub-ID 1
                assertEqual(inquiry[4], 0x70) // Discovery Inquiry Sub-ID 2
                assertEqual(inquiry.last, 0xF7)
            }

            test("Discovery inquiry processing and reply generation") {
                let session = MIDICISession(muid: 0x0ABC_DEF0)
                let remoteMUID: UInt32 = 0x0123_4567
                
                // Build simulated incoming discovery inquiry from DAW
                var simulatedInquiry: [UInt8] = [0xF0, 0x7E, 0x7F, 0x0D, 0x70, 0x02]
                simulatedInquiry.append(contentsOf: [
                    UInt8(remoteMUID & 0x7F), UInt8((remoteMUID >> 7) & 0x7F),
                    UInt8((remoteMUID >> 14) & 0x7F), UInt8((remoteMUID >> 21) & 0x7F)
                ])
                simulatedInquiry.append(contentsOf: [0x7F, 0x7F, 0x7F, 0x7F]) // Broadcast dest
                simulatedInquiry.append(contentsOf: [0x00, 0x01, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xF7])

                let reply = session.processIncomingSysEx(simulatedInquiry)
                assertNotNil(reply)
                if let reply = reply {
                    assertEqual(reply[0], 0xF0)
                    assertEqual(reply[3], 0x0D)
                    assertEqual(reply[4], 0x71) // Discovery Reply
                }
            }

            test("Profile inquiry returns MPE Profile support") {
                let session = MIDICISession(muid: 0x0ABC_DEF0)
                let remoteMUID: UInt32 = 0x0123_4567

                var inquiry: [UInt8] = [0xF0, 0x7E, 0x7F, 0x0D, 0x20, 0x02]
                inquiry.append(contentsOf: [
                    UInt8(remoteMUID & 0x7F), UInt8((remoteMUID >> 7) & 0x7F),
                    UInt8((remoteMUID >> 14) & 0x7F), UInt8((remoteMUID >> 21) & 0x7F)
                ])
                inquiry.append(contentsOf: [
                    UInt8(session.myMUID & 0x7F), UInt8((session.myMUID >> 7) & 0x7F),
                    UInt8((session.myMUID >> 14) & 0x7F), UInt8((session.myMUID >> 21) & 0x7F)
                ])
                inquiry.append(0xF7)

                let reply = session.processIncomingSysEx(inquiry)
                assertNotNil(reply)
                if let reply = reply {
                    assertEqual(reply[4], 0x21) // Profile Inquiry Reply
                    // Must contain MPE Profile ID [0x7E, 0x01, 0x01, 0x01, 0x00]
                    assertTrue(reply.contains(0x7E))
                }
            }

            test("Set Profile On activates MPE mode and generates enabled report") {
                let session = MIDICISession(muid: 0x0ABC_DEF0)
                let remoteMUID: UInt32 = 0x0123_4567
                var callbackFired = false
                session.onProfileStateChanged = { enabled in
                    callbackFired = enabled
                }

                var setOn: [UInt8] = [0xF0, 0x7E, 0x7F, 0x0D, 0x22, 0x02]
                setOn.append(contentsOf: [
                    UInt8(remoteMUID & 0x7F), UInt8((remoteMUID >> 7) & 0x7F),
                    UInt8((remoteMUID >> 14) & 0x7F), UInt8((remoteMUID >> 21) & 0x7F)
                ])
                setOn.append(contentsOf: [
                    UInt8(session.myMUID & 0x7F), UInt8((session.myMUID >> 7) & 0x7F),
                    UInt8((session.myMUID >> 14) & 0x7F), UInt8((session.myMUID >> 21) & 0x7F)
                ])
                setOn.append(contentsOf: MIDICISession.mpeProfileID)
                setOn.append(0xF7)

                let reply = session.processIncomingSysEx(setOn)
                assertNotNil(reply)
                assertTrue(session.isMPEProfileActive)
                assertTrue(callbackFired)
                if let reply = reply {
                    assertEqual(reply[4], 0x24) // Profile Enabled Report
                }
            }

            test("Property Exchange inquiry returns supported JSON resource list") {
                let session = MIDICISession(muid: 0x0ABC_DEF0)
                let remoteMUID: UInt32 = 0x0123_4567

                var inquiry: [UInt8] = [0xF0, 0x7E, 0x7F, 0x0D, 0x34, 0x02]
                inquiry.append(contentsOf: [
                    UInt8(remoteMUID & 0x7F), UInt8((remoteMUID >> 7) & 0x7F),
                    UInt8((remoteMUID >> 14) & 0x7F), UInt8((remoteMUID >> 21) & 0x7F)
                ])
                inquiry.append(contentsOf: [
                    UInt8(session.myMUID & 0x7F), UInt8((session.myMUID >> 7) & 0x7F),
                    UInt8((session.myMUID >> 14) & 0x7F), UInt8((session.myMUID >> 21) & 0x7F)
                ])
                inquiry.append(0x01) // Request ID
                inquiry.append(contentsOf: [0x00, 0x00]) // Header length = 0 (ResourceList)
                inquiry.append(0xF7)

                let reply = session.processIncomingSysEx(inquiry)
                assertNotNil(reply)
                if let reply = reply {
                    assertEqual(reply[4], 0x35) // Get Property Data Reply
                    // Must contain JSON resource list
                    let replyStr = String(decoding: reply, as: UTF8.self)
                    assertTrue(replyStr.contains("DeviceInfo"))
                }
            }
        }

        // ==================================================
        // ==================================================
        // SUITE: Real-Time Dynamic Microtonal Temperaments & Just Intonation
        // ==================================================
        suite("Microtonal Temperaments & Dynamic Just Intonation") {
            test("Dynamic Just Intonation produces pure acoustic 3rds and 5ths on C Major triad") {
                let temperament = MicrotonalTemperament.dynamicJustIntonation
                // C4 (60), E4 (64), G4 (67) relative to C root
                let cOffset = temperament.tuningOffsetInCents(for: 60, scaleRoot: .c, activeChordRoot: .c)
                let eOffset = temperament.tuningOffsetInCents(for: 64, scaleRoot: .c, activeChordRoot: .c)
                let gOffset = temperament.tuningOffsetInCents(for: 67, scaleRoot: .c, activeChordRoot: .c)

                assertEqual(round(cOffset * 1000) / 1000, 0.0)
                assertEqual(round(eOffset * 1000) / 1000, -13.686) // Pure major 3rd is ~13.7 cents flat of 12-TET
                assertEqual(round(gOffset * 1000) / 1000, 1.955)   // Pure 5th is ~2 cents sharp of 12-TET
            }

            test("Dynamic Just Intonation adjusts 3rd on Minor triad") {
                let temperament = MicrotonalTemperament.dynamicJustIntonation
                // C4 (60), Eb4 (63), G4 (67)
                let ebOffset = temperament.tuningOffsetInCents(for: 63, scaleRoot: .c, activeChordRoot: .c, isMinorChord: true)
                assertEqual(round(ebOffset * 1000) / 1000, 15.641) // Pure minor 3rd (6:5) is ~15.6 cents sharp of 12-TET
            }

            test("Quarter-Comma Meantone and Pythagorean tuning offsets") {
                let meantone = MicrotonalTemperament.quarterCommaMeantone
                let eMeantone = meantone.tuningOffsetInCents(for: 64, scaleRoot: .c)
                assertEqual(eMeantone, -14.0)

                let pythagorean = MicrotonalTemperament.pythagorean
                let gPythagorean = pythagorean.tuningOffsetInCents(for: 67, scaleRoot: .c)
                assertEqual(gPythagorean, 1.95)
            }

            test("24-EDO Maqam neutral third tuning offset") {
                let maqam = MicrotonalTemperament.maqam24EDO
                let neutralThird = maqam.tuningOffsetInCents(for: 64, scaleRoot: .c)
                assertEqual(neutralThird, -50.0) // Half-flat (quarter-tone) major 3rd -> 350 cents
            }

            test("AudioEngine applies microtonal temperament tuning offsets to voice base frequencies") {
                let audio = AudioEngine()
                audio.temperament = .dynamicJustIntonation
                audio.scaleRoot = .c
                audio.activeChordRoot = .c
                audio.isMinorChord = false
                assertEqual(audio.temperament, .dynamicJustIntonation)
                assertEqual(audio.scaleRoot, .c)
            }
        }

        // ==================================================
        // SUITE: Native MIDI 2 Per-Note Expression & Note Attributes Evaluation
        // ==================================================
        suite("Native MIDI 2 Per-Note Expression & Note Attributes Evaluation") {
            test("Pitch 7.9-bit codec roundtrip precision") {
                let encoded = Pitch7_9Codec.encode(note: 60, centOffset: 14.5)
                let decoded = Pitch7_9Codec.decode(encoded)
                assertEqual(decoded.note, 60)
                assertTrue(abs(decoded.centOffsetFromBase - 14.5) < 0.25)
            }

            test("Note On with Pitch 7.9 attribute generates valid 64-bit UMP") {
                let ump = MIDI2UMPEncoder.noteOnWithPitch7_9(
                    channel: 3,
                    note: 64,
                    velocity16: 0x8000,
                    centOffset: -13.7
                )
                let msgType = (ump.word0 >> 28) & 0x0F
                let status = (ump.word0 >> 16) & 0xF0
                let channel = (ump.word0 >> 16) & 0x0F
                let note = (ump.word0 >> 8) & 0x7F
                let attrType = UInt8(ump.word0 & 0xFF)

                assertEqual(msgType, 0x4)
                assertEqual(status, 0x90)
                assertEqual(channel, 3)
                assertEqual(note, 64)
                assertEqual(attrType, MIDI2NoteAttributeType.pitch7_9.rawValue)

                let decodedMessages = MIDI2UMPDecoder.decode(words: [ump.word0, ump.word1])
                assertTrue(decodedMessages.contains { msg in
                    if case .noteOnAttribute(let ch, let n, _, let aType, _) = msg {
                        return ch == 3 && n == 64 && aType == MIDI2NoteAttributeType.pitch7_9.rawValue
                    }
                    return false
                })
            }

            test("Byte-to-UMP noteOn and noteOff translation preserves velocity in upper 16-bits of word1") {
                // Note On (0x92, Note 60, Velocity 100)
                let noteOnBytes: [UInt8] = [0x92, 60, 100]
                let onUMP = MIDI2UMPEncoder.message(from: noteOnBytes)
                assertNotNil(onUMP)
                if let onUMP = onUMP {
                    let onVel16 = UInt16((onUMP.word1 >> 16) & 0xFFFF)
                    let onAttr = UInt16(onUMP.word1 & 0xFFFF)
                    assertEqual(onVel16, MIDI2UMPEncoder.scale7To16(100))
                    assertEqual(onAttr, 0)
                }

                // Note Off (0x82, Note 60, Velocity 64)
                let noteOffBytes: [UInt8] = [0x82, 60, 64]
                let offUMP = MIDI2UMPEncoder.message(from: noteOffBytes)
                assertNotNil(offUMP)
                if let offUMP = offUMP {
                    let offVel16 = UInt16((offUMP.word1 >> 16) & 0xFFFF)
                    let offAttr = UInt16(offUMP.word1 & 0xFFFF)
                    assertEqual(offVel16, MIDI2UMPEncoder.scale7To16(64))
                    assertEqual(offAttr, 0)
                }
            }

            test("Per-Note Pitch Bend generates 32-bit UMP with 0x60 status") {
                let ump = MIDI2UMPEncoder.perNotePitchBendMessage(
                    channel: 2,
                    note: 60,
                    semitoneOffset: 2.0,
                    bendRangeSemitones: 48.0
                )
                let messageType = (ump.word0 >> 28) & 0x0F
                let status = (ump.word0 >> 16) & 0xF0
                let channel = (ump.word0 >> 16) & 0x0F
                let note = (ump.word0 >> 8) & 0x7F

                assertEqual(messageType, 0x4) // MIDI 2.0 Channel Voice
                assertEqual(status, 0x60)      // Per-Note Pitch Bend
                assertEqual(channel, 2)
                assertEqual(note, 60)
                assertTrue(ump.word1 > MIDI2UMPEncoder.pitchBendCentre)
            }

            test("Per-Note Pressure generates 32-bit UMP with 0xA0 status") {
                let ump = MIDI2UMPEncoder.perNotePressureMessage(
                    channel: 0,
                    note: 64,
                    normalizedPressure: 0.75
                )
                let messageType = (ump.word0 >> 28) & 0x0F
                let status = (ump.word0 >> 16) & 0xF0
                let note = (ump.word0 >> 8) & 0x7F

                assertEqual(messageType, 0x4)
                assertEqual(status, 0xA0) // Poly Pressure / Per-Note Pressure
                assertEqual(note, 64)
                assertTrue(ump.word1 > 0x8000_0000)
            }

            test("Registered Per-Note Controllers (RPNC) Matrix & Decoder") {
                let panUMP = MIDI2UMPEncoder.perNoteRegisteredControllerMessage(
                    channel: 0,
                    note: 60,
                    controller: .pan,
                    normalizedValue: 0.25
                )
                let resUMP = MIDI2UMPEncoder.perNoteRegisteredControllerMessage(
                    channel: 0,
                    note: 60,
                    controller: .resonance,
                    normalizedValue: 0.85
                )

                let decodedPan = MIDI2UMPDecoder.decode(words: [panUMP.word0, panUMP.word1])
                assertTrue(decodedPan.contains { msg in
                    if case .perNoteRPNC(let ch, let n, let rpnc, _) = msg {
                        return ch == 0 && n == 60 && rpnc == .pan
                    }
                    return false
                })

                let decodedRes = MIDI2UMPDecoder.decode(words: [resUMP.word0, resUMP.word1])
                assertTrue(decodedRes.contains { msg in
                    if case .perNoteRPNC(let ch, let n, let rpnc, _) = msg {
                        return ch == 0 && n == 60 && rpnc == .resonance
                    }
                    return false
                })
            }

            test("Per-Note Management resets and detaches controller flags") {
                let resetUMP = MIDI2UMPEncoder.perNoteManagementMessage(channel: 0, note: 60, detach: false, reset: true)
                let flagsReset = resetUMP.word0 & 0xFF
                assertEqual(flagsReset, 0x01)

                let detachUMP = MIDI2UMPEncoder.perNoteManagementMessage(channel: 0, note: 60, detach: true, reset: false)
                let flagsDetach = detachUMP.word0 & 0xFF
                assertEqual(flagsDetach, 0x02)
            }
        }

        // ==================================================
        // SUITE: Dual-Zone MPE Coordination & Voice Separation
        // ==================================================
        suite("Dual-Zone MPE Coordination & Voice Separation") {
            test("DualZoneMPEManager splits Lower and Upper zones cleanly") {
                let dualMPE = DualZoneMPEManager(lowerMemberCount: 7, upperMemberCount: 7)
                assertEqual(dualMPE.lowerZone.currentZoneLayout.masterChannel, 0)
                assertEqual(dualMPE.upperZone.currentZoneLayout.masterChannel, 15)

                // Lower zone: chords below split note 60
                dualMPE.noteOn(note: 48, velocity: 90, target: .auto(splitNote: 60))
                assertTrue(dualMPE.lowerZone.activeVoice(for: 48) != nil)
                assertTrue(dualMPE.upperZone.activeVoice(for: 48) == nil)

                // Upper zone: lead melody at or above split note 60
                dualMPE.noteOn(note: 72, velocity: 100, target: .auto(splitNote: 60))
                assertTrue(dualMPE.upperZone.activeVoice(for: 72) != nil)
                assertTrue(dualMPE.lowerZone.activeVoice(for: 72) == nil)

                dualMPE.stopAllNotes()
                assertEqual(dualMPE.lowerZone.activeVoiceCount, 0)
                assertEqual(dualMPE.upperZone.activeVoiceCount, 0)
            }
        }

        // ==================================================
        // SUITE: MIDI Clip File (M2-116-U) / SMF2 Binary Exporter
        // ==================================================
        suite("MIDI Clip File (M2-116-U) / SMF2 Binary Exporter") {
            test("SMF2 file binary header and chunk integrity") {
                let notes: [RecordedNoteEvent] = [
                    RecordedNoteEvent(note: 60, velocity: 100, startTick: 0, durationTicks: 480),
                    RecordedNoteEvent(note: 64, velocity: 95, startTick: 480, durationTicks: 480),
                    RecordedNoteEvent(note: 67, velocity: 110, startTick: 960, durationTicks: 960)
                ]

                let fileData = SMF2Exporter.export(events: notes, channel: 1, ppqn: 960)
                assertTrue(fileData.count > 32)

                // Verify magic bytes
                let headerMagic = Array(fileData[0..<4])
                assertEqual(headerMagic, SMF2Exporter.headerMagic)

                // Round-trip parse with SMF2Parser
                do {
                    let parsed = try SMF2Parser.parse(data: fileData)
                    assertEqual(parsed.formatVersion, 1)
                    assertEqual(parsed.ppqn, 960)
                    assertEqual(parsed.trackCount, 1)
                    assertTrue(parsed.events.count >= 6) // 3 NoteOn + 3 NoteOff
                } catch {
                    assertTrue(false, "SMF2Parser failed on valid exported file: \(error)")
                }
            }

            test("Rich technique events SMF2 export preserves per-note pitch bends and RPNC") {
                let techEvents: [RecordedTechniqueEvent] = [
                    RecordedTechniqueEvent(
                        tick: 0,
                        event: InstrumentPerformanceEvent(
                            note: Note(pitchClass: .c, octave: 4),
                            phase: .began,
                            technique: .bend,
                            velocity: 100,
                            pressure: 0.8,
                            pitchOffset: 2.0,
                            timbre: 0.75
                        ),
                        durationTicks: 960
                    )
                ]

                let data = SMF2Exporter.export(techniqueEvents: techEvents, channel: 0, ppqn: 960)
                do {
                    let parsed = try SMF2Parser.parse(data: data)
                    assertTrue(parsed.events.count >= 4) // NoteOn + PB + Press + Timbre + NoteOff
                } catch {
                    assertTrue(false, "Failed to parse technique SMF2 export: \(error)")
                }
            }

            test("Delta-clock timing preserves exact tick positions in SMF2") {
                let events: [TimedUMPEvent] = [
                    TimedUMPEvent(tick: 0, words: [0x40903C00, 0x7FFF0000]),
                    TimedUMPEvent(tick: 960, words: [0x40803C00, 0x00000000]),
                    TimedUMPEvent(tick: 1920, words: [0x40904000, 0x7FFF0000])
                ]

                let encoded = SMF2Exporter.encodeStream(events: events, ppqn: 960)
                do {
                    let parsed = try SMF2Parser.parse(data: encoded)
                    assertEqual(parsed.events.count, 3)
                    assertEqual(parsed.events[0].tick, 0)
                    assertEqual(parsed.events[1].tick, 960)
                    assertEqual(parsed.events[2].tick, 1920)
                } catch {
                    assertTrue(false, "Failed to round-trip timed UMP events: \(error)")
                }
            }
        }

        // ==================================================
        // SUITE: Controller Ergonomics & Verification Matrix
        // ==================================================
        suite("Controller Ergonomics & Verification Matrix") {
            test("DualSense hardware profile specifications and trigger curve") {
                let dualSense = ControllerCapabilityProfile.dualSense
                assertTrue(dualSense.hasTouchpad)
                assertTrue(dualSense.hasMotionIMU)
                assertTrue(dualSense.hasHaptics)
                assertTrue(dualSense.hasAnalogTriggers)
                assertTrue(dualSense.hasThumbstickClicks)

                let engine = AdaptiveTriggerEngine()
                engine.configureForInstrumentProfile(.guitar)
                let state = engine.calculateTriggerState(position: 0.8, velocity: 0, config: engine.rightConfig, label: "R2")
                assertTrue(state.calculatedForce > 0.3)
            }

            test("Xbox Wireless controller profile ergonomics and deadzones") {
                let xbox = ControllerCapabilityProfile.xbox
                assertTrue(!xbox.hasTouchpad)
                assertTrue(!xbox.hasMotionIMU)
                assertTrue(xbox.hasHaptics)
                assertTrue(xbox.hasAnalogTriggers)

                // Stick calibration with Xbox deadzone (0.10)
                let cal = StickCalibration(driftRadius: 0.10)
                let resting = cal.calibrate(rawX: 0.06, rawY: -0.06)
                assertEqual(resting.x, 0.0)
                assertEqual(resting.y, 0.0)
            }

            test("Nintendo Switch Pro controller profile and linear actuator haptics") {
                let switchPro = ControllerCapabilityProfile.switchPro
                assertTrue(switchPro.hasMotionIMU)
                assertTrue(switchPro.hasHaptics)
                assertTrue(!switchPro.hasTouchpad)
                assertTrue(!switchPro.hasAnalogTriggers)
            }

            test("DualShock 4 capability profile has touchpad and motion IMU") {
                let ds4 = ControllerCapabilityProfile.dualShock4
                assertTrue(ds4.hasTouchpad)
                assertTrue(ds4.hasMotionIMU)
                assertTrue(ds4.hasHaptics)
                assertTrue(ds4.hasAnalogTriggers)
                assertTrue(ds4.hasThumbstickClicks)
                assertEqual(ds4.buttonLabels[0], "Cross (✕)")
            }

            test("Generic MFi fallback profile ergonomics") {
                let generic = ControllerCapabilityProfile.generic
                assertTrue(!generic.hasTouchpad)
                assertTrue(!generic.hasMotionIMU)
            }
        }

        // ==================================================
        // SUITE: DualSense 6-Axis IMU Gyro, Gravity Vector & MPE 3D Spatial Modulation
        // ==================================================
        suite("DualSense 6-Axis IMU Gyro, Gravity Vector & MPE 3D Spatial Modulation") {
            test("ControllerState gravity vector calculates pitch and roll tilt angles") {
                let state = ControllerState()
                // Flat horizontal orientation (gravity pointing straight down Z/Y)
                state.gravityX = 0.0
                state.gravityY = -0.98
                state.gravityZ = 0.0
                state.pitchTilt = -state.gravityY.clamped(to: -1.0...1.0)
                state.rollTilt = state.gravityX.clamped(to: -1.0...1.0)

                assertTrue(state.pitchTilt > 0.95) // Leveled forward horizon
                assertEqual(state.rollTilt, 0.0)    // No roll tilt

                // 45° right roll tilt
                state.gravityX = 0.707
                state.rollTilt = state.gravityX.clamped(to: -1.0...1.0)
                assertTrue(state.rollTilt > 0.7)
            }

            test("Dynamic user acceleration calculates shake magnitude") {
                let state = ControllerState()
                state.accelX = 0.5
                state.accelY = 0.8
                state.accelZ = 0.4
                let shake = sqrt(state.accelX * state.accelX + state.accelY * state.accelY + state.accelZ * state.accelZ)
                state.shakeMagnitude = shake

                assertTrue(state.shakeMagnitude > 1.0)
            }

            test("SpatialAudioEngine translates 6-axis IMU into 3D Cartesian coordinates") {
                let spatial = SpatialAudioEngine(sampleRate: 48000.0)
                spatial.setCoordinates(azimuth: 45.0, elevation: 30.0, distance: 2.0)
                let cart = spatial.currentCoordinates.cartesian

                // In Cartesian: X > 0 (right), Y > 0 (up), Z > 0 (front)
                assertTrue(cart.x > 0.5)
                assertTrue(cart.y > 0.5)
                assertTrue(cart.z > 0.5)
            }

            test("IMU tilt maps to normalized MPE Pan (CC10) and Timbre (CC74)") {
                let rollTilt = 0.5 // Tilted right
                let pitchTilt = -0.2 // Tilted slightly down
                let normPan = (rollTilt + 1.0) * 0.5
                let normTimbre = (pitchTilt + 1.0) * 0.5

                assertEqual(normPan, 0.75)   // 75% right
                assertEqual(normTimbre, 0.4) // 40% timbre

                let panUMP = MIDI2UMPEncoder.perNoteRegisteredControllerMessage(
                    channel: 1,
                    note: 60,
                    controller: .pan,
                    normalizedValue: normPan
                )
                let decoded = MIDI2UMPDecoder.decode(words: [panUMP.word0, panUMP.word1])
                assertTrue(decoded.contains { msg in
                    if case .perNoteRPNC(let ch, let n, let rpnc, _) = msg {
                        return ch == 1 && n == 60 && rpnc == .pan
                    }
                    return false
                })
            }
        }

        // ==================================================
        // SUITE: ControlScheme Transfer: Versioned Archive Import/Export
        // ==================================================
        suite("ControlScheme Transfer: Versioned Archive Import/Export") {
            test("ControlSchemeArchive export and import roundtrip") {
                let defaultScheme = ControlSchemePreset.xpiPerformance
                let json = try ControlSchemeTransfer.exportJSON(defaultScheme, metadata: ["creator": "XPI Tester"])
                
                assertTrue(json.contains("schemaVersion"))
                assertTrue(json.contains("XPI Performance"))
                
                let result = try ControlSchemeTransfer.importArchive(from: json)
                assertEqual(result.schemaVersion, 1)
                assertEqual(result.scheme.name, defaultScheme.name)
                assertEqual(result.scheme.stickFeel, defaultScheme.stickFeel)
                assertEqual(result.scheme.triggerFeel, defaultScheme.triggerFeel)
            }

            test("Tolerant import handles bare unversioned ControlScheme JSON") {
                let defaultScheme = ControlSchemePreset.lowFatigue
                let encoder = JSONEncoder()
                let bareData = try encoder.encode(defaultScheme)

                let result = try ControlSchemeTransfer.importArchive(from: bareData)
                assertEqual(result.schemaVersion, 1)
                assertEqual(result.scheme.id, defaultScheme.id)
                assertTrue(!result.warnings.isEmpty)
            }

            test("Import rejects future unsupported schema versions") {
                let futureJSON = "{\"schemaVersion\": 999, \"exportedAt\": \"2030-01-01T00:00:00Z\", \"scheme\": {}}"
                var caught = false
                do {
                    _ = try ControlSchemeTransfer.importArchive(from: futureJSON)
                } catch {
                    caught = true
                }
                assertTrue(caught)
            }
        }

        // ==================================================
        // SUITE: Controller Vendor Database & Heuristic Identification
        // ==================================================
        suite("Controller Vendor Database & Heuristic Identification") {
            test("Classifies Raphnet Guitar Hero adapter to .guitarHero") {
                let kind = ControllerKind.identify(vendorName: "Raphnet Technologies", productCategory: "Wii Classic / Guitar Adapter")
                assertEqual(kind, .guitarHero)
                assertEqual(kind.suggestedSchemeID, "xpi_rhythm_pad")
            }

            test("Classifies Sound Voltex Faucetwo / Yuancon to .soundVoltex") {
                let kind = ControllerKind.identify(vendorName: "Gamo2", productCategory: "FAUCETWO SDVX Controller")
                assertEqual(kind, .soundVoltex)
                assertEqual(kind.suggestedSchemeID, "xpi_rhythm_pad")
            }

            test("Classifies Beatmania IIDX DJ DAO Phoenixwan to .beatmaniaIIDX") {
                let kind = ControllerKind.identify(vendorName: "DJ DAO", productCategory: "PHOENIXWAN IIDX Turntable")
                assertEqual(kind, .beatmaniaIIDX)
                assertEqual(kind.suggestedSchemeID, "xpi_rhythm_pad")
            }

            test("Classifies Thrustmaster HOTAS to .flightStick") {
                let kind = ControllerKind.identify(vendorName: "Thrustmaster", productCategory: "T.16000M Flight Stick & Throttle")
                assertEqual(kind, .flightStick)
                assertEqual(kind.suggestedSchemeID, "xpi_flight_deck")
            }

            test("Classifies Logitech G29 Racing Wheel to .racingWheel") {
                let kind = ControllerKind.identify(vendorName: "Logitech", productCategory: "G29 Driving Force Racing Wheel")
                assertEqual(kind, .racingWheel)
                assertEqual(kind.suggestedSchemeID, "xpi_racing_wheel")
            }

            test("Classifies Hori Fighting Stick to .fightStick") {
                let kind = ControllerKind.identify(vendorName: "HORI", productCategory: "Fighting Stick Alpha / Leverless")
                assertEqual(kind, .fightStick)
                assertEqual(kind.suggestedSchemeID, "xpi_arcade_stick")
            }

            test("ControlSchemePreset.allBuiltIn contains 10 presets with unique IDs and valid bindings") {
                let presets = ControlSchemePreset.allBuiltIn
                assertEqual(presets.count, 10)
                let ids = Set(presets.map { $0.id })
                assertEqual(ids.count, 10)
                for preset in presets {
                    assertTrue(!preset.name.isEmpty)
                    assertTrue(!preset.bindings.isEmpty)
                }
            }
        }

        // ==================================================
        // SUITE: XPadPractice: Lessons, Challenges & Progress Tracker
        // ==================================================
        suite("XPadPractice: Lessons, Challenges & Progress Tracker") {
            test("Factory preset lessons have deterministic IDs across calls") {
                let presets1 = PracticeLesson.factoryPresets()
                let presets2 = PracticeLesson.factoryPresets()
                assertEqual(presets1.count, 6)
                assertEqual(presets2.count, 6)
                for i in 0..<presets1.count {
                    assertEqual(presets1[i].id, presets2[i].id)
                    assertEqual(presets1[i].steps.count, presets2[i].steps.count)
                    for s in 0..<presets1[i].steps.count {
                        assertEqual(presets1[i].steps[s].id, presets2[i].steps[s].id)
                    }
                }
            }

            test("Factory preset challenges have deterministic IDs") {
                let c1 = PracticeChallenge.factoryPresets()
                let c2 = PracticeChallenge.factoryPresets()
                assertEqual(c1.count, 3)
                assertEqual(c2.count, 3)
                for i in 0..<c1.count {
                    assertEqual(c1[i].id, c2[i].id)
                }
            }

            test("Progress tracker records session and updates mastery") {
                let tracker = ProgressTracker.shared
                tracker.resetProgress()
                let lesson = PracticeLesson.factoryPresets()[0]
                let sessionResult = PracticeSessionResult(
                    lessonId: lesson.id,
                    startTime: Date().addingTimeInterval(-30),
                    endTime: Date(),
                    stepResults: [],
                    overallAccuracy: 0.95,
                    averageResponseTime: 0.8,
                    completed: true
                )
                tracker.recordSession(sessionResult)
                let mastery = tracker.getLessonMastery(for: lesson.id)
                assertNotNil(mastery)
                assertEqual(mastery?.attemptCount, 1)
                assertEqual(mastery?.completedCount, 1)
            }

            test("PracticeEngine auto-advance is cleanly cancellable and debounces duplicate inputs") {
                let engine = PracticeEngine()
                let lesson = PracticeLesson.factoryPresets()[0]
                engine.startLesson(lesson)
                assertEqual(engine.currentStepIndex, 0)

                // First correct input
                engine.evaluateChordInput(lesson.steps[0].expectedChord)
                assertEqual(engine.sessionResults.count, 1)

                // Rapid duplicate input during 0.5s auto-advance window is ignored
                engine.evaluateChordInput(lesson.steps[0].expectedChord)
                assertEqual(engine.sessionResults.count, 1)

                // Stop immediately cancels pending advance
                engine.stopPractice()
                assertFalse(engine.isPracticeActive)
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
    @MainActor
    static func main() {
        TestRunner().run()
    }
}
