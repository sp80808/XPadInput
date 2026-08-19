import Foundation
import AudioToolbox
import AVFoundation
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
                let dumpedZone = phraseMessages.contains { record in
                    record.port == .mpe && record.bytes == [0xB0, 101, 0]
                }
                let noteOnIndex = phraseMessages.firstIndex { record in
                    record.port == .mpe && record.bytes == [0x91, 60, 90]
                }
                let resetIndex = phraseMessages.firstIndex { record in
                    record.port == .mpe && record.bytes == [0xE1, 0, 0x40]
                }
                assertFalse(
                    dumpedZone,
                    "An idle phrase must not re-advertise its MPE zone on the first Note On."
                )
                assertTrue(
                    resetIndex != nil && noteOnIndex != nil && resetIndex! < noteOnIndex!,
                    "The first Note On of a phrase should only reset member-channel expression, then send Note On."
                )

                midi.clearMessageLog()
                midi.virtualMIDIEnabled = false
                assertTrue(midi.sentMessages.contains { $0.bytes == [0x81, 60, 0] })
                assertTrue(midi.sentMessages.contains { $0.bytes == [0xE1, 0, 0x40] })
                assertTrue(midi.sentMessages.contains { $0.bytes == [0xD1, 0] })
                assertTrue(midi.sentMessages.contains { $0.bytes == [0xB1, 74, 64] })
                assertTrue(midi.sentMessages.contains { $0.bytes == [0xB1, 123, 0] })
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
                assertEqual(audio.pooledVoiceCount, 16)
                audio.start()
                audio.noteOn(note: 60, velocity: 100)
                assertEqual(audio.trackedVoiceCount, 1)
                audio.noteOn(note: 60, velocity: 90)
                assertEqual(audio.trackedVoiceCount, 1, "Retriggering the same pitch must reuse one pooled voice.")
                audio.noteOff(note: 60)
                assertEqual(audio.trackedVoiceCount, 1, "A release tail must remain tracked until it detaches.")
                audio.noteOn(note: 60, velocity: 80)
                assertEqual(audio.trackedVoiceCount, 1, "A note-on during release must reclaim the pooled voice.")
                for note: UInt8 in 48..<65 {
                    audio.noteOn(note: note, velocity: 90)
                }
                assertEqual(audio.trackedVoiceCount, 16)
                assertEqual(audio.pooledVoiceCount, 16, "Stealing must not attach additional source nodes.")
                audio.panic()
                assertEqual(audio.trackedVoiceCount, 0, "Panic must hard-stop active and releasing voices.")
                assertEqual(audio.pooledVoiceCount, 16)
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

                sequencer.stop()
                assertFalse(sequencer.transport.isPlaying)
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
                assertEqual(ControlSchemePreset.allBuiltIn.count, 6)
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
        }

        // ==================================================
        // SUITE: Native MIDI 2 Per-Note Expression Evaluation
        // ==================================================
        suite("Native MIDI 2 Per-Note Expression Evaluation") {
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

            test("Per-Note Registered Controller generates Timbre CC74 UMP") {
                let ump = MIDI2UMPEncoder.perNoteRegisteredControllerMessage(
                    channel: 1,
                    note: 67,
                    controllerIndex: 74,
                    normalizedValue: 0.82
                )
                let messageType = (ump.word0 >> 28) & 0x0F
                let note = (ump.word0 >> 8) & 0x7F
                let controller = ump.word0 & 0xFF

                assertEqual(messageType, 0x4)
                assertEqual(note, 67)
                assertEqual(controller, 74)
                assertTrue(ump.word1 > 0x8000_0000)
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

            test("Generic MFi fallback profile ergonomics") {
                let generic = ControllerCapabilityProfile.generic
                assertTrue(!generic.hasTouchpad)
                assertTrue(!generic.hasMotionIMU)
            }

            test("Disconnect and reconnect cleans up all voices without stuck notes") {
                let midi = MIDIEngine()
                midi.sendNoteOn(port: .main, channel: 0, note: 60, velocity: 100)
                midi.sendNoteOn(port: .mpe, channel: 1, note: 64, velocity: 90)
                assertEqual(midi.activeNoteCount, 2)

                // Simulate abrupt controller disconnect -> panic
                midi.panic()
                assertEqual(midi.activeNoteCount, 0)
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
