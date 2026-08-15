# TECH_STACK.md: Technology Stack & Architectural Specifications

This document outlines the architectural patterns, native frameworks, performance parameters, and mathematical foundations powering **XPadInput**.

---

## 1. System Architecture Diagram

```
+-----------------------------------------------------------------------------------+
|                                 XPadInputApp                                      |
|                               (SwiftUI / AppKit)                                  |
+-----------------------------------------------------------------------------------+
                                         |
     +-------------------+---------------+-------------------+
     |                   |                                   |
     v                   v                                   v
[ Workspace UI ]  [ Controller Manager ]              [ Transport & Clock ]
  - Play            - GCController Discovery            - 960 PPQN Timer Source
  - Harmony         - Polar Coordinate Normalizer       - Multi-Track Sequencer
  - Sequence        - Virtual Strummer DSP              - Clip Event Recorder
  - Map             - Rhythm Compass Engine             - SMF Exporter (.mid)
  - Library         - Gesture Recorder
     |                   |                                   |
     +-------------------+-----------------------------------+
                         |
                         v
            [ Music Theory & Harmony Engine ]
              - 12-TET Pitch Classes & Intervals
              - 5-Tier Polar Harmonic Wheel
              - Voice Leading Optimizer (Cost Heuristics)
              - "What Next?" Harmonic Suggestions
              - Modulation Pathways & Chord Blocks
                         |
     +-------------------+-------------------+
     |                                       |
     v                                       v
[ CoreMIDI / MPE Output ]             [ Native Audio Synth ]
  - 6 Virtual Endpoints                 - AVAudioEngine & AVAudioSourceNode
  - MPE Zone Manager (Ch 2-15)          - PolyBLEP Bandlimited Oscillators
  - Per-note Pitch Bend (±48 st)        - ADSR Envelope Generators
  - Poly Pressure & CC74 Timbre         - State-Variable Filters & Soft Limiter
```

---

## 2. Core Technologies & Frameworks

| Domain | Framework | Architectural Role |
| :--- | :--- | :--- |
| **Language** | **Swift 6** | Strict concurrency checking, typed actors, `@MainActor`, zero pointers. |
| **User Interface** | **SwiftUI 2026 / AppKit** | Declarative state management, vector rendering, fluid canvas visualizers. |
| **Gamepad Hardware** | **`GameController.framework`** | Hardware polling, HID enumeration, extended gamepad profiles, 6-axis IMU, and haptic actuation. |
| **MIDI & Expression** | **`CoreMIDI.framework`** | Virtual MIDI source endpoints (`MIDISourceCreate`), low-jitter packet dispatching, MPE standard compliance. |
| **DSP & Sound** | **`AVFAudio` (`AVAudioEngine`)** | Real-time C-function audio callback (`AVAudioSourceNode`), 44.1/48kHz 32-bit floating-point DSP. |
| **Build System** | **Swift Package Manager (SPM)** | Modular sub-packages, reproducible zero-dependency builds. |

---

## 3. Performance Budgets & Real-Time Specifications

- **Input Sampling Frequency**: 120 Hz – 250 Hz (via GameController handlers).
- **Audio Output Latency**: $< 5.8\text{ ms}$ at 256 frame buffer (44.1 kHz).
- **MIDI Transmission Jitter**: $< 1.2\text{ ms}$ on CoreMIDI virtual queue.
- **Clock Resolution**: 960 PPQN (Pulses Per Quarter Note) for sample-accurate groove and swing quantizing.
- **Memory Footprint**: $< 45\text{ MB}$ residential memory footprint during full 16-voice synthesis and timeline playback.
- **Zero Allocations on Audio Thread**: All voice DSP state, buffers, and oscillators are pre-allocated and statically indexed to eliminate garbage collection and heap locks during audio rendering.

---

## 4. Mathematical Foundations

### 4.1 12-TET Frequency Computation
Given a MIDI note number $m \in [0, 127]$ and a fractional pitch bend offset in semitones $\Delta s$:
$$f(m, \Delta s) = 440.0 \times 2^{\frac{m + \Delta s - 69}{12}}\text{ Hz}$$

### 4.2 Polar Harmonic Wheel Geometry
The harmonic wheel maps analog thumbstick polar coordinates $(r, \theta)$ to chord sectors:
$$\theta = \text{atan2}(y, x) \in [-\pi, \pi]$$
$$\text{Sector Index } k = \left\lfloor \frac{(\theta + \frac{\pi}{2} \pmod{2\pi}) \times N}{2\pi} \right\rfloor$$
Where $N$ is the sector count of the active layer, and $r = \sqrt{x^2 + y^2}$ defines the harmonic tension radius.

### 4.3 Voice Leading Cost Function
The transition cost between previous voicing $V_{\text{prev}}$ and candidate voicing $V_{\text{cand}}$ is:
$$\mathcal{C}(V_{\text{prev}}, V_{\text{cand}}) = \sum_{i=1}^{\min(|V_{\text{prev}}|, |V_{\text{cand}}|)} (v_{\text{cand}, i} - v_{\text{prev}, i})^2 + 15.0 \cdot \big| |V_{\text{cand}}| - |V_{\text{prev}}| \big| + \text{Penalty}_{\text{register}} + \text{Penalty}_{\text{strategy}}$$
Minimizing $\mathcal{C}$ ensures smooth pianistic transitions with minimal physical voice displacement and maximum preserved common tones.
