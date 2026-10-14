# Changelog

All notable changes to **XPI: Game Controller MIDI** are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Added
- **Style Morphing & Generative Harmony (`DeterministicRandom.swift`, `HarmonicStyle.swift`, `StyleMorphEngine.swift`)**:
  - `HarmonicStyleDNA` measures a style on ten axes (degree emphasis, minor lean, extension richness, suspended colour, modal interchange, secondary dominants, tritone substitution, chromatic mediant shifts, harmonic rhythm, cadence strength) with `blend(_:_:amount:)` interpolating between two styles.
  - `HarmonicStyleLibrary` ships ten researched dialects: Pop / Royal Road, Neo-Soul, Synthwave, Cinematic Trailer, Lo-Fi Hip Hop, Gospel Soul, Deep House, Ambient Modal, Jazz Standard, Liquid Drum & Bass.
  - `StyleMorphEngine` generates seeded, roman-numeral-labelled progressions (degree walk → substitutions → extension colour) and re-harmonises an existing progression without touching its rhythm.
  - `DeterministicRandom` (SplitMix64) makes every generative feature reproducible from a seed or a string.
  - Harmony workspace gains a Style Morph card (from/to pickers, morph slider, bar length, Generate, Reharmonise).
- **Jam Co-Pilot & Generated Drum Fills (`JamCoPilot.swift`, `DrumFillGenerator.swift`, `Sequencer.swift`, `AppState.swift`)**:
  - `Sequencer` reports the bar it enters (`onBarBoundary`) and can mute by musical role (`setMuted(_:forType:)`, `isMuted(_:)`, `audibleTracks`, `populatedTracks`).
  - `JamCoPilot` turns player energy, sounding roles and progression age into an explainable `CoPilotDirective` (hold, drop out, add layer, fill, lift, regenerate harmony). Decisions are seeded and reproducible.
  - `DrumFillGenerator` writes turn-arounds that end before the downbeat (pickup, eighth-note run, or sixteenth run with ghost notes) and wraps them in a drums clip.
  - Compose workspace gains a Co-Pilot toggle, a manual Fill button and a readout of the last decision.
- **Generated Basslines (`BasslineGenerator.swift`, `Sequencer.swift`, `AppState.swift`)**:
  - Five feels — root notes, walking, octave pulse, syncopated and drone — all derived from the chord under them: downbeats are always chord tones and walking/syncopated lines use chromatic or rhythmic anticipation of the next chord.
  - The feel follows the active style, so deep house pumps octaves and jazz walks without the player choosing anything.
  - `Sequencer.insertClip(_:on:)` appends a generated part without replacing the other tracks and extends the scene loop to keep it audible; HARMONY and SEQUENCE both expose "Add Bassline"/"Bassline".
- **MIDI Tuning Standard output (`MIDITuningStandard.swift`, `AppState.swift`)**:
  - Frequency-word encoding, bulk tuning dump (with checksum), bulk dump request, single note tuning change, and both scale/octave tuning forms, plus the shared channel mask.
  - Switching temperament broadcasts a tuning table to every virtual port, and dynamic temperaments push real-time single-note retunes whenever the chord changes. The Tuning menu exposes a manual send.

### Fixed
- **The XCTest targets compile and pass again.** Between them the eleven XCTest suites now run 1185 test cases with zero failures; they had never been built by CI (`swift test` is non-gating there), which hid a scale preset that does not exist, UMP words read in the wrong byte order, stale preset/scheme counts, a wizard fallback asserted as a measured value, and a progress test that wrote tracker internals by hand instead of recording sessions.
- **Chromatic bend targets rank by distance.** With chromatic override on, interval consonance still influenced scoring, so the whole tone outranked the semitone the player reaches first — the opposite of what the override is for.
- Generated progressions honour an explicit start degree: the opening chord is no longer re-coloured by the substitution layers, so "start on the IV" always sounds like the IV.
- `HarmonicStyleLibrary.jazzStandard` degree weights were declared with a `)` instead of `]`, which broke the build.

### Changed
- The diagnostics workflow now builds the test targets and runs `swift test` as well, reporting compile errors, XCTest failures and the exhaustive runner's totals as check-run annotations (the job log is not reliably reachable from every environment).
- `ProgressTracker` tests snapshot and restore the shared store, so a test that records sessions no longer depends on — or disturbs — whatever state the user's own practice history is in.
- `CoreHapticsEngine` no longer swallows a failed haptic-engine start or restart: both are logged with `os.Logger` and published as `lastError` (was a `print` and a silent `catch`).
- `RecordedNoteEvent` is `Equatable`/`Hashable`, so generated and recorded parts can be compared and de-duplicated.

---

## [0.0.05] - 2026-08-24

### Added
- **Interactive Guided Tutorials & Learn Hub (`TutorialEngine.swift`, `LearnHubView.swift`, `MainAppView.swift`)**:
  - `TutorialEngine` evaluates real-time gamepad input against structured lesson milestones and scheme-resolved physical control hints.
  - Interactive overlay HUD (`TutorialOverlayView`) with step-by-step progress tracking, live gesture validation, and celebratory completion animations.
  - `LearnHubView` modal catalog accessible from the Library workspace, Help menu, and onboarding sequence with persistent mission completion tracking (`TutorialMissionStore`).
- **Drone Pad Play Mode (`DroneBedEngine.swift`, `AppState.swift`, `WorkspaceNavigation.swift`)**:
  - Dedicated `.drone` instrument play mode sustaining harmonic chord beds indefinitely without requiring active strum gating.
  - Delta voice-morphing algorithm diffs current vs next chord voicings so common tones sustain seamlessly while departing tones release and entering tones attack.
  - Strum trigger support for dynamic accent rearticulation without interrupting held sustain.
- **Ways to Play Gallery (`WaysToPlayView.swift`, `LibraryWorkspaceView.swift`)**:
  - One-tap control scheme switcher in the Library workspace featuring all 16 built-in presets (Performance, Classic, Low-Fatigue, Left-Handed, Drummer, Bass, Ambient, Theremin, Turntablist, Fight Stick, Flight Stick, Racing Wheel, Sound Voltex, Beatmania IIDX, Guitar Hero, First Timer).
  - Inline cheat-sheet displaying the three primary bindings for each scheme upon activation.
- **Arpeggiator Integration & Live Mode Switching (`AppState.swift`, `Arpeggiator.swift`)**:
  - Complete integration of multi-pattern arpeggiator engine into `AppState` with tempo-synced gate timing and octave registrations.
- **MIDI Learn & Physical Input Expansion (`MapWorkspaceView.swift`, `PhysicalControlInput`)**:
  - MIDI Learn tab in Map workspace for incoming event monitoring and rapid parameter mapping.
  - Extended `PhysicalControlInput` supporting MIDI note, CC, pitch bend, and channel pressure event types.
- **Exhaustive Automated Test Suite Expansion**:
  - 183 automated unit and integration tests (100% pass rate) covering Drone Bed lifecycle, Tutorial Engine gesture validation, Arpeggiator stepping, MIDI-CI MPE profile negotiation, and 16 hardware mapping presets.

### Fixed
- **SMFExporter**: Added stable indexed sorting for equal-tick events and 28-bit Variable Length Quantity (VLQ) clamping.
- **Concurrency & Lock Safety**: Replaced manual lock unwinding with scoped `defer { lock.unlock() }` across `AudioEngine`, `SpatialAudioEngine`, `VirtualAudioDriver`, `MIDICISession`, `MIDIEngine`, and `MPEManager`.
- **Pipeline State Recovery**: Added `reset()` methods on `AnalogControlPipeline`, `StickProcessor`, and `TriggerProcessor` for clean state recovery on controller reconnection or calibration changes.

---

## [0.0.04] - 2026-08-22

### Added
- **MIDI 2 Attack Velocity Normalization (#15)**:
  - `VelocityStabilizer.process16(normalizedIntensity:)` returns a `(velocity7: UInt8, velocity16: UInt16)` pair, preserving sub-step precision from the strum intensity float rather than upscaling a quantized 7-bit value.
  - `AppState` threads `velocity16` from the strum sensor through `handleChordGateEvents` → `startChordVoice` → `beginPhysicalVoice` → `MPEManager.noteOn` and `MIDIManager.sendNoteOn`.
  - Per-string velocity taper in chord strums scales `velocity16` proportionally so the 16-bit resolution is maintained across the strum arpeggio.
  - MIDI 1 / 7-bit paths are unchanged; `velocity16` is an additive opt-in for MIDI 2 UMP transports.
- **UI Design System & Motion Engine (`GreenTheme.swift`)**:
  - `XTheme.bouncy`: Spring with playful overshoot for toggles and icon bounces (`response: 0.30, dampingFraction: 0.52`).
  - `XTheme.snappy`: Crisp, responsive spring for tab switches and selections (`response: 0.22, dampingFraction: 0.80`).
  - `XTheme.glassIn`: Smooth ease-out for surface entrances (`duration: 0.22`).
  - `XPulseModifier` (`.xPulse`): Multi-ring heartbeat glow overlay for active states.
  - `XShimmerModifier` (`.xShimmer`): Horizontal shimmer sweep for active/selected items.
  - `XRippleModifier` (`.xRipple`): Tactile one-shot expanding ring burst on user actions.
- **3D Spatial Audio & Gyro Radar (`SpatialAudioVisualizerView.swift`)**:
  - Continuous 360° rotating radar scanner sweep beam gradient with angular trail.
  - Dynamic distance/azimuth vector line with animated node pulse rings.
- **Voice-Led Solo Engine HUD (`SoloModeHUD.swift`)**:
  - Ambient shimmer effect across the active key/chord harmonic lock badge.
  - High-precision spring animation on stick deflection and angle changes.
  - `.numericText()` transition with tactile ripple burst on target note changes.
- **Multi-Controller Jamming HUD (`MultiControllerHUD.swift`)**:
  - Player slot indicators pulse with slot-specific color codes (`.xPulse`).
  - Ambient shimmer indicator on shared harmonic progression lock badge.
- **Practice & Learning Workspace (`PracticeWorkspaceView.swift`)**:
  - `matchedGeometryEffect` sliding capsule indicator across Practice tabs (*Lessons*, *Practice*, *Progress*, *Challenges*).
  - `matchedGeometryEffect` sliding capsule indicator for Lesson Category selection (*Fundamentals*, *Jazz*, *Blues*, etc.).
  - Hover elevation and subtle shadow lift animations on lesson cards.
- **Workstation Header & Navigation (`MainAppView.swift`)**:
  - Settings gear rotates 45° with a snappy spring on hover.
  - Gamepad branding icon breathes when a controller is actively connected.
  - Controller status pill emits a green ripple burst upon hardware connection.
  - Asymmetric slide-and-fade transitions between Play and Practice views.
- **Transport Bar (`TransportBarView.swift`)**:
  - Live spinning arc overlay (`RotatingArcOverlay`) behind the active Play button.
  - Dual-ring pulse on Record button.
  - Tactile ripple burst on TAP tempo button and transport control clicks.
  - Panic button springs with an oscillation shake effect (±8°).
  - MIDI activity indicator utilizes smooth concentric pulses.
- **Harmonic Wheel (`HarmonicWheelView.swift`)**:
  - Slow-drifting dashed orbital ring.
  - Musical harmonic tension-tinted ripple burst on chord selection.
  - Multi-stage ghost trail (3 trailing dots at diminishing opacity) tracking thumbstick deflection.
  - Center key/scale badge animates smoothly with `.numericText()` content transitions.
- **Play Workspace & Chord Grid (`PlayWorkspaceView.swift`)**:
  - `matchedGeometryEffect` sliding capsule pill between harmonic and DSP workspace tabs.
  - Chord display flashes softly on chord changes.
  - Per-pad ripple burst on diatonic chord click and shimmer on active chord pads.
  - Shimmer highlights on selected progression blocks.
  - Contextual hints slide down smoothly from the top edge.
- **Controller & DSP Visualizers (`InputHUDs.swift`, `ControllerVisualizerView.swift`)**:
  - Analog stick HUD pulses amber when hitting the outer deflection boundary.
  - Triggers feature animated attack transient flashes on quick presses.
  - Shimmer on adaptive trigger HUD when locking into motor detents.
  - Card-level connection ripple burst when gamepads connect.
- **Performance Quick Controls (`PerformanceQuickControlsView.swift`)**:
  - Solo toggle triggers an upward bounce on the guitar icon.
  - Duo mode flips 180° along the 3D Y-axis.
  - Popover buttons wiggle subtly (±5°) on click.
- **Release Packaging**:
  - Automated release pipeline script (`scripts/package-macos.sh 0.0.04`) producing `dist/XPI.app`, `dist/XPadInput-0.0.04.dmg`, `dist/XPadInput-0.0.04.zip`, and `dist/SHA256SUMS.txt`.

### Changed
- Refactored all UI animations to be strictly non-layout-breaking (overlays, shadows, opacity, scale, rotation, and color transitions only).
- All motion animations now strictly respect macOS `accessibilityReduceMotion`.

---

## [0.0.03] - 2026-08-22

### Added
- **Universal MIDI Packet (UMP) & MIDI 2.0 Support**:
  - Selectable MIDI 2.0 Channel Voice UMP transport via `MIDISourceCreateWithProtocol`.
  - Native 32-bit semantic pitch bend encoding and protocol-resolution-aware de-duplication.
  - Automated CoreMIDI virtual-source loopback test verifying native 32-bit UMP delivery over macOS transport.
  - MIDI-CI MPE Profile (`M2-120-UM_v2-0-3`) negotiation and bidirectional CoreMIDI discovery.
  - Native MIDI 2 per-note expression evaluation (32-bit Per-Note Pitch, Pressure, Timbre).
  - SMF2 / MIDI Clip File (M2-116-U) binary exporter and parser.
- **Harmonic & Performance Features**:
  - Diatonic consonant chord pitch bending engine (`HarmonicChordBender`).
  - Accurate MIDI Passthru routing prioritizing DAW integration.
  - DualSense adaptive motor resistance emulation for string tension, bow drag, and mod-wheel detents.
  - Force Touch trackpad tactile haptic feedback for macOS laptops.

---

## [0.0.02] - 2026-08-22

### Added
- **Workstation Architecture**:
  - Native macOS liquid interface with 6 dedicated workspaces (`PLAY`, `HARMONY`, `SEQUENCE`, `MAP`, `LIBRARY`, `PRACTICE`).
  - Open Controller Definition Standard (OCDS) schema and profile loader for community controllers.
  - Semantic Musical Action layer with 7 built-in control schemes.
  - Built-in drum synthesis engine (`BuiltInDrums`).
  - 3D Spatial Audio Engine with real-time binaural rendering and HRTF.
  - Voice-Led Lead Guitar Solo Engine on the right thumbstick.

---

## [0.0.01] - 2026-08-22

### Added
- **Foundational Architecture**:
  - Pure Swift 12-TET Theory Engine (`PitchClass`, `Interval`, `Note`, `Scale`, `Chord`).
  - 5-Layer Harmonic Wheel with polar harmonic navigation.
  - Continuous virtual strumming engine with speed-to-velocity mapping and palm-mute dampening.
  - CoreMIDI MPE Zone Manager distributing 6 virtual ports and polyphonic expression across lower zone channels 2–15.
  - Built-in low-latency polyphonic DSP synthesizer (PolyBLEP oscillators, ADSR envelope generators, SVF filters).
  - 960 PPQN multi-track timeline sequencer with Standard MIDI File (.mid) export.
  - Practice workspace with interactive progression lessons and real-time chord evaluation.
  - macOS automated release packaging script and GitHub Actions CI workflow.
