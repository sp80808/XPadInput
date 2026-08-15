# ROADMAP.md — XPI: Game Controller MIDI Development & Innovation Roadmap

This document outlines the multi-phase vision, milestones, and technical trajectory of **XPI: Game Controller MIDI** from MVP standalone instrument to an industry-standard expressive performance ecosystem.

---

## Phase 1: Core Engine & Standalone macOS Workstation (Current)
- [x] Pure Swift 12-TET Theory Engine (`PitchClass`, `Interval`, `Note`, `Scale`, `Chord`).
- [x] Multi-tier Harmonic Wheel with 5 layers (Diatonic, Colour, Borrowed, Tension, Mediant).
- [x] Real-time voice leading optimization across multiple strategies (Smooth, SATB, Bass Anchored, Cinematic).
- [x] Gamepad hardware abstraction with dynamic capability profiling (DualSense, Xbox, Switch Pro).
- [x] Continuous virtual strumming engine with speed-to-velocity mapping and palm-mute dampening.
- [x] Polar Rhythm Compass for instantaneous sub-division and ratchet generation.
- [x] CoreMIDI virtual ports (`Main`, `Chords`, `Melody`, `Bass`, `Drums`, `MPE`).
- [x] MPE Zone Manager distributing polyphonic notes, ±48 semitone pitch bends, pressure, and CC74 timbre.
- [x] Built-in low-latency polyphonic DSP synthesizer (PolyBLEP oscillators, ADSR, state-variable filters).
- [x] 960 PPQN multi-track timeline sequencer with scene management and SMF (.mid) export.
- [x] Native macOS liquid interface with 5 dedicated workspaces (`PLAY`, `HARMONY`, `SEQUENCE`, `MAP`, `LIBRARY`).
- [x] Exhaustive automated test suites and agentic documentation.

---

## Phase 2: DAW Plugin & Inter-App Audio Routing (Q3 2026)
- [ ] **AUv3 / VST3 Plugin Targets**: Package XPI as an Audio Unit v3 MIDI FX and Instrument plugin for direct hosting inside Logic Pro, Ableton Live, Bitwig Studio, Reaper, and Cubase.
- [ ] **CoreAudio Virtual Audio Driver**: Provide a direct virtual loopback audio stream for zero-configuration system audio capture.
- [ ] **Custom Scale & Microtuning Importer**: Support Scala (`.scl`) and MIDI Tuning Standard (MTS / MTS-ESP) for microtonal, just intonation, and non-Western harmonic wheels.
- [ ] **Preset Cloud Synchronization & Community Exchange**: Sharing progression templates, custom chord wheels, and controller mapping profiles.

---

## Phase 3: Spatial Audio, 3D Gyro Panning & Advanced Haptics (Q4 2026)
- [ ] **3D Spatial Audio & Dolby Atmos Panning**: Map gamepad 6-axis IMU (gyro pitch/roll/yaw) to real-time binaural spatial audio and Ambisonic sound positioning.
- [ ] **DualSense Voice-Coil Haptic Audio Synthesis**: Translate synthesizer waveforms and bass transients into haptic vibrations using Apple `CoreHaptics` and DualSense force-feedback triggers.
- [ ] **Dynamic Adaptive Triggers**: Use DualSense adaptive motor resistance to emulate guitar string tension, bow drag resistance, and mod-wheel detents.
- [ ] **Multi-Controller Jamming**: Support up to 4 simultaneous gamepads connected via Bluetooth, orchestrating independent tracks (Drums, Bass, Chords, Lead).

---

## Phase 4: AI Jam Co-Pilot & Generative Progression Explorer (Q1 2027)
- [ ] **On-Device Neural Co-Pilot**: Local CoreML neural network analyzing real-time strumming and chord selections to generate dynamic counter-melodies, basslines, and drum fills.
- [ ] **Generative Harmonic Morphing**: Continuous vector-space interpolation between distinct genre styles (e.g. morphing a Neo-Soul progression smoothly into Synthwave or Cinematic Trailer).
- [ ] **Voice-Led Lead Guitar Solo Mode**: Smart soloing engine on the right stick that automatically stays locked to chord tones and passing notes of the active chord block.

---

## Phase 5: Hardware & Embedded Ecosystem (2027+)
- [ ] **XPI Wireless Hardware Bridge**: Dedicated low-latency USB-C / BLE hardware dongle delivering sub-1ms MIDI DIN and CV/Gate outputs for modular synthesizers (Eurorack).
- [ ] **iOS & iPadOS Companion**: Universal binary running on iPad with full Touch + Game Controller support.
- [ ] **Open Controller Definition Standard (OCDS)**: Open-source JSON schema for community controller mapping profiles and visual 3D skinning.
