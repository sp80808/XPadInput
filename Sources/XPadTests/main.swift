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
                    state.rightTrigger = 0.7
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
                assertEqual(audio.trackedVoiceCount, 1)
                audio.noteOff(note: 60)
                assertEqual(audio.trackedVoiceCount, 1, "A release tail must remain tracked until it detaches.")
                audio.panic()
                assertEqual(audio.trackedVoiceCount, 0, "Panic must hard-stop active and releasing voices.")
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
