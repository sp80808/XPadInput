# ROADMAP.md — XPI: Game Controller MIDI Development & Innovation Roadmap

> **Status:** Living document. Checked items are implemented in source; automated proof and manual DAW/hardware certification are tracked separately in module specs.

This document outlines the multi-phase vision, milestones, and technical trajectory of **XPI: Game Controller MIDI** from MVP standalone instrument to an industry-standard expressive performance ecosystem.

---

## Phase 1: Core Engine & Standalone macOS Workstation (Current)
**Status:** Source-complete. Automated tests green. CI release pipeline active. Manual DAW/hardware proof and MIDI 2.0 extension ongoing.

- [x] Pure Swift 12-TET Theory Engine (`PitchClass`, `Interval`, `Note`, `Scale`, `Chord`).
- [x] Multi-tier Harmonic Wheel with 5 layers (Diatonic, Colour, Borrowed, Tension, Mediant).
- [x] Real-time voice leading optimization across multiple strategies (Smooth, SATB, Bass Anchored, Cinematic).
- [x] Gamepad hardware abstraction with dynamic capability profiling (DualSense, Xbox, Switch Pro).
- [x] Continuous virtual strumming engine with speed-to-velocity mapping and palm-mute dampening.
- [x] Polar Rhythm Compass for instantaneous sub-division and ratchet generation.
- [x] CoreMIDI virtual ports (`Main`, `Chords`, `Melody`, `Bass`, `Drums`, `MPE`).
- [x] MPE Zone Manager distributing polyphonic notes, ±48 semitone pitch bends, pressure, and CC74 timbre.
- [x] Automatic DAW host MIDI channel maps (Logic, Live, Bitwig, Cubase, Studio One, REAPER, DP, Waveform, MainStage, FL Studio, Pro Tools, Reason, LUNA, Ardour, Gig Performer, and others) with track-channel fallback.
- [x] Built-in low-latency polyphonic DSP synthesizer (PolyBLEP oscillators, ADSR, state-variable filters).
- [x] 960 PPQN multi-track timeline sequencer with scene management and SMF (.mid) export.
- [x] Practice mode with interactive lessons, chord evaluation, and progress tracking.
- [x] Native macOS liquid interface with 6 dedicated workspaces (`PLAY`, `HARMONY`, `SEQUENCE`, `MAP`, `LIBRARY`, `PRACTICE`).
- [x] Compact XTheme-consistent transport context selectors (`Instrument`, `Key`, `Scale`) in transport bar and chord card.
- [x] macOS automated CI build & test gate with release artifact packaging (`.github/workflows/macos-ci.yml`).
- [x] Distributable macOS release packaging (`XPI.app`, `XPadInput-0.0.01.dmg`, `XPadInput-0.0.02.dmg`, `XPadInput-0.0.03.dmg`, `XPadInput-0.0.04.dmg`, `XPadInput-0.0.05.dmg`, and ZIPs with SHA-256 validation).
- [x] Selectable experimental MIDI 2.0 Channel Voice UMP transport (`MIDISourceCreateWithProtocol`).
- [x] Native 32-bit semantic pitch bend encoding and protocol-resolution-aware de-duplication.
- [x] Automated CoreMIDI virtual-source loopback test verifying native 32-bit UMP delivery over macOS transport.
- [x] Normalized MPE member-voice pressure and CC74 timbre state management.
- [ ] Manual DAW certification (Ableton Live verified — all 6 virtual CoreMIDI endpoints exposed & isolated; Apple Logic Pro, Bitwig Studio in progress).
- [x] Controller ergonomics proof matrix (DualSense, Xbox Wireless, Switch Pro, Generic MFi) (`CONTROLLER_MATRIX.md`).
- [ ] Logic Pro and real-host experimental MIDI 2.0 UMP output validation (#13).
- [x] Live caller high-resolution expression wiring (`AppState.applyExpression`) (#15).
- [x] Attack velocity normalization so MIDI 2 can use 16-bit attack values (#15).
- [x] MIDI-CI MPE Profile (`M2-120-UM_v2-0-3`) negotiation and bidirectional CoreMIDI discovery (#14).
- [x] Native MIDI 2 per-note expression evaluation (#18).
- [x] MIDI Clip File (M2-116-U) / SMF2 export for native MIDI 2 performances (#19).
- [x] Semantic Musical Action layer with 7 built-in control schemes (Performance, Classic, Low-Fatigue, Left-Handed, One-Hand Left, One-Hand Right, Custom).
- [x] Spatial Audio Engine with real-time binaural rendering.
- [x] Built-in drum synthesis engine (`BuiltInDrums`).
- [x] Open Controller Definition Standard (OCDS) for community controller mapping profiles.

### Phase 1 Milestones
| Milestone | Target | Status | Notes |
| :--- | :--- | :--- | :--- |
| Core theory engine | Q4 2025 | ✅ Complete | Deterministic 12-TET math, scales, chords |
| MPE routing & CoreMIDI | Q4 2025 | ✅ Complete | 6 virtual ports, lower zone Ch 2-15 |
| Built-in synth & DSP | Q1 2026 | ✅ Complete | PolyBLEP, SVF filters, 5 presets |
| 6-workspace UI shell | Q1 2026 | ✅ Complete | Play, Harmony, Sequence, Map, Library, Practice |
| Automated test gate | Q1 2026 | ✅ Complete | macOS CI workflow on push & PR |
| Release packaging | Q1 2026 | ✅ Complete | Alpha 0.0.01, 0.0.02, 0.0.03, 0.0.04 & 0.0.05 DMG/ZIP + SHA-256 |
| Experimental MIDI 2 UMP | Q2 2026 | ✅ Complete | Selectable protocol, 32-bit pitch/pressure/timbre |
| CoreMIDI loopback proof | Q2 2026 | ✅ Complete | Virtual source → Input port 32-bit verification |
| DAW certification | Q2 2026 | 🔄 In progress | Live 12, Logic Pro, Bitwig Studio |
| Hardware ergonomics matrix | Q2 2026 | ✅ Complete | DualSense, Xbox, Switch Pro, MFi (`CONTROLLER_MATRIX.md`) |
| MIDI-CI MPE Profile | Q2 2026 | ✅ Complete | Bidirectional discovery & `M2-120-UM_v2-0-3` |
| Native MIDI 2 Per-Note | Q2 2026 | ✅ Complete | 32-bit Per-Note Pitch/Pressure/Timbre UMPs |
| SMF2 / MIDI Clip File | Q2 2026 | ✅ Complete | Binary encoder & parser (M2-116-U v1.0) |
| Live high-res expression | Q2 2026 | ✅ Complete | `AppState` strum path native 16-bit velocity; `process16` preserves float precision |
| Semantic control schemes | Q2 2026 | ✅ Complete | 7 built-in schemes with runtime remapping |
| Spatial audio engine | Q2 2026 | ✅ Complete | Real-time binaural rendering with HRTF |
| Built-in drums | Q2 2026 | ✅ Complete | Dedicated drum synthesis engine |
| OCDS | Q2 2026 | ✅ Complete | Open Controller Definition Standard |
| Motion & Micro-Interactions | Q3 2026 | ✅ Complete | Spring presets, XPulse, XShimmer, XRipple, radar sweep |


---

## Phase 2: DAW Plugin & Inter-App Audio Routing (Q3 2026)
- [x] **AUv3 / VST3 Plugin Targets**: Package XPI as an Audio Unit v3 MIDI FX and Instrument plugin for direct hosting inside Logic Pro, Ableton Live, Bitwig Studio, Reaper, and Cubase.
- [x] **CoreAudio Virtual Audio Driver**: Provide a direct virtual loopback audio stream for zero-configuration system audio capture.
- [ ] **Custom Scale & Microtuning Importer**: Support Scala (`.scl`) and MIDI Tuning Standard (MTS / MTS-ESP) for microtonal, just intonation, and non-Western harmonic wheels.
- [ ] **Preset Cloud Synchronization & Community Exchange**: Sharing progression templates, custom chord wheels, and controller mapping profiles.

---

## Phase 3: Spatial Audio, 3D Gyro Panning & Advanced Haptics (Q4 2026)
- [ ] **3D Spatial Audio & Dolby Atmos Panning**: Map gamepad 6-axis IMU (gyro pitch/roll/yaw) to real-time binaural spatial audio and Ambisonic sound positioning.
- [ ] **DualSense Voice-Coil Haptic Audio Synthesis**: Translate synthesizer waveforms and bass transients into haptic vibrations using Apple `CoreHaptics` and DualSense force-feedback triggers.
- [x] **Dynamic Adaptive Triggers**: Use DualSense adaptive motor resistance to emulate guitar string tension, bow drag resistance, and mod-wheel detents.
- [x] **Multi-Controller Jamming**: Support up to 4 simultaneous gamepads connected via Bluetooth, orchestrating independent tracks (Drums, Bass, Chords, Lead).
- [x] **Spatial Audio Engine**: Real-time binaural spatial audio rendering with head-related transfer function (HRTF) processing.

---

## Phase 4: AI Jam Co-Pilot & Generative Progression Explorer (Q1 2027)
- [ ] **On-Device Neural Co-Pilot**: Local CoreML neural network analyzing real-time strumming and chord selections to generate dynamic counter-melodies, basslines, and drum fills.
- [ ] **Generative Harmonic Morphing**: Continuous vector-space interpolation between distinct genre styles (e.g. morphing a Neo-Soul progression smoothly into Synthwave or Cinematic Trailer).
- [x] **Voice-Led Lead Guitar Solo Mode**: Smart soloing engine on the right stick that automatically stays locked to chord tones and passing notes of the active chord block.

---

## Phase 5: Hardware & Embedded Ecosystem (2027+)
- [ ] **XPI Wireless Hardware Bridge**: Dedicated low-latency USB-C / BLE hardware dongle delivering sub-1ms MIDI DIN and CV/Gate outputs for modular synthesizers (Eurorack).
- [ ] **iOS & iPadOS Companion**: Universal binary running on iPad with full Touch + Game Controller support.
- [x] **Open Controller Definition Standard (OCDS)**: Open-source JSON schema for community controller mapping profiles and visual 3D skinning.
