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
- **MPE Zone Distribution**: Independent per-note voice allocation across Channels 2–15.
- **Multi-Dimensional Expression**:
  - **Pitch Bend**: 6-axis gyro tilt or stick deflection ($\pm 48$ semitones).
  - **Polyphonic Pressure (Z-Axis)**: Trigger travel / aftertouch.
  - **Timbre CC74 (Y-Axis)**: Capacitive touchpad or vertical stick deflection.

### 5. 🔊 Built-in Zero-Latency DSP Synthesizer
- Built with `AVAudioEngine` and custom low-latency `AVAudioSourceNode` C-callbacks.
- PolyBLEP bandlimited oscillators (Sawtooth, Square, Triangle, Sine), ADSR envelope generators, and resonant state-variable filters.
- **Factory Presets**: Poly Lead, Rhodes Electric Piano, Lush Ambient Pad, Acoustic Pluck, Sub Bass.

### 6. ⏱️ 960 PPQN Multi-Track Timeline Sequencer
- Multi-track clip timeline supporting Chords, Melody, Bass, Drums, and Gesture automation.
- Real-time gesture recording (`GestureRecorder`) capturing stick trajectories and gyro motion.
- One-click Standard MIDI File (`.mid`) export with native drag-and-drop directly into Ableton Live, Logic Pro, Bitwig Studio, or Finder.

---

## 🕹️ Controller Mapping Overview

| Gamepad Input | Musical Mapping |
| :--- | :--- |
| **Left Stick ($\theta, r$)** | Polar Chord Selector (Angle = Chord, Radius = Harmonic Tension) |
| **Right Stick (Sweep $Y$)** | Virtual Strumming Surface (Velocity + Up/Down Strum) |
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
- Any supported game controller:
  - Sony DualSense (PS5) / DualShock 4 (PS4) (Bluetooth or USB-C)
  - Microsoft Xbox Wireless Controller (Bluetooth or USB-C)
  - Nintendo Switch Pro Controller
  - Generic MFi / HID Gamepads

### Build & Run
```bash
# Clone the repository
git clone https://github.com/your-username/XPadInput.git
cd XPadInput

# Build the macOS application
swift build

# Run the branded application (the legacy XPadInput product remains available)
swift run XPI
```

### Running Automated Test Suites
```bash
swift run XPadTests
```

---

## 🎛️ DAW Setup Guide

### Ableton Live 11 / 12
1. Launch **XPI: Game Controller MIDI** and connect your controller.
2. Open Ableton Live **Settings $\rightarrow$ Link/MIDI**.
3. Under MIDI Inputs, enable **Track** and **Remote** for `XPI Main` or `XPI Chords`.
4. In your MIDI Track, set MIDI From $\rightarrow$ `XPI Expression (MPE)` and enable MPE Mode in a compatible instrument.

### Apple Logic Pro
1. Create a Software Instrument track (e.g. Alchemy or Studio Strings).
2. In Track Inspector, select MIDI Input Port: `XPI Chords`.
3. In Alchemy settings, enable MPE mode for multi-channel pitch bend and pressure.

### Bitwig Studio
1. Select `XPI Expression (MPE)` as the controller input.
2. Route its member channels directly into Polymer, Phase-4, or The Grid.

---

## 📁 Project Architecture

```
XPadInput/
├── Sources/
│   ├── XPadCore/        # Pure 12-TET theory primitives (PitchClass, Note, Scale, Chord)
│   ├── XPadTheory/      # Harmonic wheel, voice leading, suggestions & progressions
│   ├── XPadController/  # GCController abstraction, virtual strummer & gesture DSP
│   ├── XPadMIDI/        # CoreMIDI virtual ports, MPE zone manager & SMF exporter
│   ├── XPadAudio/       # PolyBLEP DSP synthesizer & factory presets
│   ├── XPadSequencer/   # 960 PPQN tick clock, clips, tracks & scenes
│   ├── XPadUI/          # Native SwiftUI 5-workspace desktop interface
│   ├── XPadInput/       # Application main entrypoint
│   └── XPadTests/       # Universal exhaustive test runner
├── Tests/               # Unit and integration test suites
├── .agents/skills/      # Specialized agent skills and workflow guides
├── AGENTS.md            # Agent operating instructions and modular rules
├── DESIGN.md            # Authoritative interaction, feedback, and ergonomic rules
├── INSTRUMENT_TECHNIQUES.md # Semantic technique and instrument-profile contract
├── MIDI_MPE_SPEC.md      # CoreMIDI, MPE zone, expression, and fallback contract
├── SOUL.md              # Philosophical and artistic instrument manifesto
├── ROADMAP.md           # 5-phase product development trajectory
├── TECH_STACK.md        # Technical, mathematical & latency specifications
└── README.md            # Project documentation and guide
```

---

## 📄 License
MIT License. Crafted for musicians, beatmakers, and performers.
