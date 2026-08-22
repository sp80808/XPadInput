# 🎮 XPI: Game Controller MIDI

<div align="center">

[![Platform](https://img.shields.io/badge/Platform-macOS%2014.0%2B-000000.svg?style=for-the-badge&logo=apple)](https://apple.com)
[![Swift](https://img.shields.io/badge/Swift-6.0-F05138.svg?style=for-the-badge&logo=swift)](https://swift.org)
[![MPE](https://img.shields.io/badge/MIDI-MPE%20Compatible-00D084.svg?style=for-the-badge)](https://midi.org)
[![License](https://img.shields.io/badge/License-MIT-blue.svg?style=for-the-badge)](LICENSE)
[![Tests](https://img.shields.io/badge/Tests-100%25%20Passing-success.svg?style=for-the-badge)]()

**Transform standard PlayStation DualSense, Xbox, and Nintendo Switch Pro controllers into expressive, low-latency polyphonic MPE instruments and intelligent harmony workstations for macOS.**

</div>

---

## ⬇️ Download Alpha Releases

Pre-built native macOS universal releases are packaged directly via GitHub Actions CI.

### Alpha 0.0.04 (CI-Validated Latest)
Validated release build incorporating dynamic animated micro-interactions, spring physics, live visualizer radar scanner, matched-geometry tab capsules, diatonic consonant chord pitch bending, Universal MIDI Packet (UMP) decoding, accurate MIDI Passthru routing, enhanced DualSense/CoreHaptics feedback, and macOS Force Touch trackpad tactile support:
- **Recommended:** [Download XPadInput-0.0.04.dmg](https://github.com/sp80808/XPadInput/releases)
- **Fallback ZIP:** [Download XPadInput-0.0.04.zip](https://github.com/sp80808/XPadInput/releases)
- **Full Release Notes:** See [CHANGELOG.md](CHANGELOG.md)

SHA-256:
```text
b6107d03977c5e5cabc7b43662d1d967339034da241c7a97411ca7b107b2164f  XPadInput-0.0.04.dmg
35929c2490a7eba8c821c323f9c7311be589684bab24fe27a7e8944f56411f67  XPadInput-0.0.04.zip
```

### Alpha 0.0.03
- [Download XPadInput-0.0.03.dmg](https://github.com/sp80808/XPadInput/releases)
- [Download XPadInput-0.0.03.zip](https://github.com/sp80808/XPadInput/releases)

### Alpha 0.0.02
- [Download XPadInput-0.0.02.dmg](https://github.com/sp80808/XPadInput/releases)
- [Download XPadInput-0.0.02.zip](https://github.com/sp80808/XPadInput/releases)

### Alpha 0.0.01 (Initial Prerelease)
- [Download XPadInput-0.0.01.dmg](https://github.com/sp80808/XPadInput/releases/download/macos/XPadInput-0.0.01.dmg)
- [Download XPadInput-0.0.01.zip](https://github.com/sp80808/XPadInput/releases/download/macos/XPadInput-0.0.01.zip)
- [View GitHub Prerelease](https://github.com/sp80808/XPadInput/releases/tag/macos)

### Install & test

1. Download and open the DMG.
2. Drag **XPI: Game Controller MIDI** to **Applications**.
3. Connect a supported controller over Bluetooth or USB.
4. Launch **XPI: Game Controller MIDI**.
5. If macOS blocks first launch for an unsigned alpha, right-click the app in Applications and choose **Open**.

Please test controller detection, analog sticks, triggers, chord selection, virtual strumming, internal synth, MIDI/MPE routing, and disconnect/reconnect resilience. Report issues at [GitHub Issues](https://github.com/sp80808/XPadInput/issues).

> **Alpha Notice:** XPI is under active development. Mappings, UI controls, and MIDI features evolve rapidly.

---

## 🌟 Key Features

### 1. 🎯 Intelligent 5-Layer Harmonic Wheel
- **Polar Harmonic Mapping**: Left analog stick sweeps through harmonic space with real-time Circle of Fifths orientation.
- **5 Dynamic Harmonic Layers**:
  - 🟢 **Diatonic**: Natural scale chords (I, ii, iii, IV, V, vi, vii°).
  - 🔵 **Colour / Extensions**: Rich 7ths, 9ths, and sus chords.
  - 🟣 **Modal Interchange**: Chords borrowed from parallel Aeolian, Dorian, and Phrygian modes.
  - 🟠 **Tension & Secondary Dominants**: V7/V, V7/vi, and tritone substitutions (subV7).
  - 🔴 **Chromatic Mediants**: Film-score emotional shifts (♭III, III, ♭VI, VI).
- **Harmonic Risk Radius**: Radial deflection ($r$) expands chord extensions and tension.

### 2. 🎸 Continuous Virtual Strumming Engine
- **Physical Velocity Dynamics**: Right analog stick crossing virtual string thresholds triggers note-on events.
- **Natural Strum Speed**: Swipe velocity dynamically modulates note velocity and string spread arpeggiation delay (2ms–35ms).
- **Direction Awareness**: Down-strums and up-strums automatically trigger proper bottom-to-top or top-to-bottom voice excitation.
- **Palm Mute & Dampening**: Progressive analog trigger (L2/R2) dampens string vibrations in real time.

### 3. 🎹 Real-Time Voice Leading & Harmonic Suggestions
- **Pianistic Voice Leading**: Minimal voice displacement heuristics prevent large register leaps and anchor common tones.
- **Strategies**: `Smooth (Minimal Motion)`, `Piano (SATB)`, `Bass Anchored`, `Cinematic (Open Spread)`, `Parallel`.
- **"What Next?" AI Suggestions**: Ranked next-chord recommendations across 8 categories (`Familiar`, `Smooth`, `Resolution`, `Colourful`, `Darker`, `Brighter`, `Cinematic`, `Outside`).
- **Modulation Navigator**: Automatic generation of `ii–V–I` dominant cycles, pivot chords, and chromatic mediant transition pathways.

### 4. ⚡ True MPE & Multi-Port CoreMIDI Routing
- **Native CoreMIDI Virtual Ports**:
  - `XPI Main`
  - `XPI Chords`
  - `XPI Melody`
  - `XPI Bass`
  - `XPI Drums`
  - `XPI Expression (MPE)`
- **MPE Zone Distribution**: Independent per-note voice allocation across Channels 2–16 for DAW MPE hosts (2–15 for the internal synth).
- **Multi-Dimensional Expression**:
  - **Pitch Bend**: 6-axis gyro tilt or stick deflection ($\pm 48$ semitones).
  - **Polyphonic Pressure (Z-Axis)**: Trigger travel / aftertouch.
  - **Timbre CC74 (Y-Axis)**: Capacitive touchpad or vertical stick deflection.
- **Experimental MIDI 2.0 UMP Transport**: Selectable Universal MIDI Packet transport supporting native 32-bit pitch bend, high-resolution pressure, and 32-bit CC74 with automated CoreMIDI virtual-source loopback verification.

### 5. 🔊 Built-in Zero-Latency DSP Synthesizer
- Built with `AVAudioEngine` and custom low-latency `AVAudioSourceNode` C-callbacks.
- PolyBLEP bandlimited oscillators (Sawtooth, Square, Triangle, Sine), ADSR envelope generators, and resonant state-variable filters.
- **Factory Presets**: Poly Lead, Rhodes Electric Piano, Lush Ambient Pad, Acoustic Pluck, Sub Bass.

### 6. ⏱️ 960 PPQN Multi-Track Timeline Sequencer
- Multi-track clip timeline supporting Chords, Melody, Bass, Drums, and Gesture automation.
- Real-time gesture recording (`GestureRecorder`) capturing stick trajectories and gyro motion.
- One-click Standard MIDI File (`.mid`) export with native drag-and-drop directly into Ableton Live, Logic Pro, Bitwig Studio, or Finder.

### 7. 🎓 Practice Mode for Chord Progression Learning
- Interactive lessons for mastering chord progressions and harmonic movement.
- Real-time chord evaluation with timing accuracy feedback.
- Progress tracking with session history and improvement metrics.

### 8. 🔌 AUv3 Plugin & Virtual Audio Driver
- **AUv3 MIDI FX & Instrument**: Package XPI as an Audio Unit v3 plugin for direct hosting inside Logic Pro, Ableton Live, Bitwig Studio, and Cubase.
- **Virtual Audio Driver**: Direct virtual loopback audio stream for zero-configuration system audio capture.
- **Built-in Drums**: Dedicated drum synthesis engine for rhythm production.

### 9. 🎧 Spatial Audio Engine
- Real-time binaural spatial audio rendering with head-related transfer function (HRTF) processing.
- 3D audio positioning for immersive performance experience.

### 10. 🎛️ Semantic Control Schemes
- **7 Built-in Control Schemes**: Performance (default), Classic, Low-Fatigue, Left-Handed, One-Hand Left, One-Hand Right, Custom.
- **Semantic Musical Action Layer**: Decouples physical inputs from instrument profiles for flexible remapping.
- **Runtime Remapping**: `ControlSurfaceResolver` projects bindings onto canonical performance layout.

### 11. 📋 Open Controller Definition Standard (OCDS)
- Open-source JSON schema for community controller mapping profiles.
- Visual 3D skinning support for niche controllers.

---

## 🕹️ Controller Support & Mapping

### Supported Hardware Matrix

| Controller Family | Connection | IMU Gyro | Haptics | Status | Notes |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Sony DualSense (PS5)** | Bluetooth / USB-C | ✅ 6-Axis | ✅ Advanced | **Source-Supported** | Touchpad CC74, Light/Strong pitch assist |
| **Sony DualShock 4 (PS4)** | Bluetooth / Micro-USB | ✅ 6-Axis | ✅ Standard | **Source-Supported** | Full polar chord & strumming support |
| **Microsoft Xbox Wireless** | Bluetooth / USB-C | ❌ N/A | ✅ Standard | **Source-Supported** | Impulse trigger support |
| **Nintendo Switch Pro** | Bluetooth / USB-C | ✅ 6-Axis | ✅ Standard | **Source-Supported** | Gyro vibrato & spatial modulation |
| **Generic MFi / HID** | Bluetooth / USB | Optional | Optional | **Detected** | Standard gamepad profile fallback |

### Mapping Overview

| Gamepad Input | Musical Mapping |
| :--- | :--- |
| **Left Stick ($\theta, r$)** | Polar Chord Selector (Angle = Chord, Radius = Harmonic Tension) |
| **Right Stick (Sweep $Y$)** | Virtual Strumming Surface (Velocity + Up/Down Strum) |
| **Right Stick ($X$, Note Sustained)** | Contextual Guitar Pitch Bend (±2 semitones with soft attraction) |
| **L1 / R1 Shoulders** | Switch Harmonic Wheel Layers (Diatonic $\leftrightarrow$ Colour $\leftrightarrow$ Borrowed $\leftrightarrow$ Tension) |
| **L2 / R2 Triggers** | Progressive Palm Mute / Expression Pressure (MPE Z-Axis) |
| **Face Buttons (A/B/X/Y)** | Quick Rhythmic Triggers & Harmonic Degrees |
| **D-Pad (Up/Down/Left/Right)** | Octave Shift & Inversion Selector |
| **6-Axis Gyro (Tilt)** | MPE Polyphonic Pitch Bend & Spatial Filter Panning |
| **Capacitive Touchpad** | MPE Timbre Sweep (CC74) & Surface Arpeggiation |

---

## 🚀 Quickstart & Installation

### Requirements
- macOS 14.0 (Sonoma) or macOS 15.0+ (Sequoia)
- Supported game controller (DualSense, Xbox, Switch Pro, or generic MFi)
- Apple Silicon or Intel Mac

### Build & Run
```bash
# Clone the repository
git clone https://github.com/sp80808/XPadInput.git
cd XPadInput

# Build the macOS application
swift build

# Run the branded application
swift run XPI
```

### Running Automated Test Suites
```bash
# Run standard test suite
swift test

# Run exhaustive test runner
swift run XPadTests
```

---

## 🎛️ DAW Setup & Certification Matrix

### Host Certification Status

| Host DAW | Protocol Mode | Default zone / channels | Pitch Bend | Status | Notes |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Apple Logic Pro** | MIDI 1.0 / MIDI 2.0 | Lower zone, master Ch 1, members 2–16 | ±48 st | 🔄 **In Validation** | MIDI Mono Mode common base 1; track MIDI Channel = All |
| **Ableton Live 11 / 12** | MIDI 1.0 MPE | Lower zone, master Ch 1, members 2–16 | ±48 st | 🔄 **In Validation** | MPE input locks the track to All Channels; notes never on master Ch 1 |
| **Bitwig Studio** | MIDI 1.0 MPE | Lower zone, master Ch 1, members 2–16 | ±48 st | 🔄 **In Validation** | Generic MPE / Force MPE Mode; note filter All |
| **Cubase / Nuendo** | MPE + Note Expression | Lower zone, base Ch 1, members 2–16 | ±48 st | 🔄 **Profiled** | MPE Mode base Ch 1; generic CoreMIDI needs Any Input |
| **Studio One** | MPE (Enable MPE) | Lower zone, members 2–16 | ±48 st | 🔄 **Profiled** | Enabling MPE greys out the channel selector |
| **REAPER / Ardour / Gig Performer** | Multi-channel MIDI | Lower zone, All Channels | ±48 st | 🔄 **Profiled** | No/optional MPE toggle; map input = Through |
| **Digital Performer / Waveform / MainStage** | MPE | Lower zone, members 2–16 | ±48 st | 🔄 **Profiled** | MainStage follows Logic MIDI Mono Mode |
| **FL Studio / Pro Tools / Reason / LUNA / GarageBand** | Conventional MIDI | Ch 1 pitched, GM Ch 10 drums | ±2 st | 🔄 **Profiled** | No shipping MPE zone; track channel is followed |

XPI **Auto-Detect** (MAP → MIDI Translation) applies these channel maps from the frontmost macOS DAW. A filtered DAW track channel (1–16) collapses pitched roles onto that channel and turns MPE off so notes are not dropped.

### Setup Instructions

#### Ableton Live 11 / 12
1. Launch **XPI** and connect your controller.
2. Open Ableton Live **Settings $\rightarrow$ Link/MIDI**.
3. Under MIDI Inputs, enable **Track** and **Remote** for `XPI Main` or `XPI Chords`.
4. In your MIDI Track, set MIDI From $\rightarrow$ `XPI Expression (MPE)` and enable MPE Mode in a compatible instrument (e.g. Wavetable, Drift, Sampler).

#### Apple Logic Pro
1. Create a Software Instrument track (e.g. Alchemy, Studio Strings, Retro Synth).
2. In Track Inspector, select MIDI Input Port: `XPI Chords` or `XPI Expression (MPE)`.
3. In instrument settings, enable MPE mode for multi-channel pitch bend and pressure.
4. To test experimental MIDI 2.0, enable the **MIDI 2.0** preference in Logic Pro settings.

#### Bitwig Studio
1. In Bitwig Settings $\rightarrow$ Controllers, add an MPE controller targeting `XPI Expression (MPE)`.
2. Route member channels directly into Polymer, Phase-4, or The Grid.


---

## 📁 Project Architecture

```
XPadInput/
├── Package.swift              # Swift Package Manager manifest
├── Sources/
│   ├── XPadCore/              # Pure 12-TET theory primitives (PitchClass, Note, Scale, Chord)
│   ├── XPadTheory/            # Harmonic wheel, voice leading, suggestions & progressions
│   ├── XPadPractice/          # Practice mode for chord progression learning
│   ├── XPadController/        # GCController abstraction, virtual strummer & gesture DSP
│   ├── XPadMIDI/              # CoreMIDI virtual ports, MPE zone manager & SMF exporter
│   ├── XPadAudio/             # PolyBLEP DSP synthesizer, AUv3 plugin & virtual audio driver
│   ├── XPadSequencer/         # 960 PPQN tick clock, clips, tracks & scenes
│   ├── XPadUI/                # Native SwiftUI 6-workspace desktop interface
│   ├── XPadInput/             # Application main entrypoint
│   └── XPadTests/             # Universal exhaustive test runner (executable target)
├── Tests/
│   ├── XPadCoreTests/         # Unit tests for theory primitives
│   ├── XPadTheoryTests/       # Unit tests for harmony engine
│   ├── XPadPracticeTests/     # Unit tests for practice mode
│   ├── XPadControllerTests/   # Unit tests for controller abstraction
│   ├── XPadMIDITests/         # Unit tests for CoreMIDI & MPE
│   ├── XPadAudioTests/        # Unit tests for DSP synth
│   └── XPadSequencerTests/    # Unit tests for timeline engine
├── .github/workflows/         # Automated macOS CI & packaging workflow (macos-ci.yml)
├── .agents/skills/            # Specialized agent skills and workflow guides
├── AGENTS.md                  # Agent operating instructions and modular rules
├── CHANGELOG.md               # Version history and detailed changelogs
├── DESIGN.md                  # Authoritative interaction, feedback, and ergonomic rules
├── INSTRUMENT_TECHNIQUES.md   # Semantic technique and instrument-profile contract
├── MIDI2_ROADMAP.md           # MIDI 2.0 & MIDI-CI experimental roadmap
├── MIDI_MPE_SPEC.md           # CoreMIDI, MPE zone, expression, and fallback contract
├── PRODUCT_RESEARCH.md        # Competitive and product research
├── ROADMAP.md                 # 5-phase product development trajectory
├── SOUL.md                    # Philosophical and artistic instrument manifesto
├── TECH_STACK.md              # Technical, mathematical & latency specifications
└── README.md                  # Project documentation and guide
```

---

## 📄 License
MIT License. Crafted for musicians, beatmakers, and performers.

---

## 🤝 Contributing

1. Fork the repository and create a feature branch from `main`.
2. Follow the module conventions in `AGENTS.md` — pure theory in `XPadCore`/`XPadTheory`, no audio/UI dependencies in core modules.
3. Run `swift test` before committing; all test suites must pass.
4. Keep commits semantic: `feat:`, `fix:`, `refactor:`, `test:`, `docs:`.
5. Purge `._*` AppleDouble files before committing.
6. Open a PR with a clear description of the musical or technical motivation.
