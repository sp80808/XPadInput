# TECH_STACK.md: Technology Stack & Architectural Specifications

This document outlines the architectural patterns, native frameworks, performance parameters, and mathematical foundations powering **XPI: Game Controller MIDI**.

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
- **Audio I/O Buffer Target**: 128 frames (`AudioEngine.preferredIOBufferFrames`). That is 2.7 ms at 48 kHz or 2.9 ms at 44.1 kHz. The engine follows the hardware output sample rate rather than resampling from a hardcoded 44.1 kHz graph.
- **Voice Topology**: 16 `AVAudioSourceNode` voices are attached once at engine setup. Note On / Note Off retrigger or steal a pooled voice in place; attack never `attach`/`connect`/`detach`s the graph.
- **MIDI Play-Now**: `MIDIEventListAdd` uses timestamp `0` (CoreMIDI “now”) so pass-through is not queued against a stale `mach_absolute_time()` stamp.
- **MPE Setup vs Attack**: Lower-zone RPNs are sent when virtual MIDI is enabled or the destination changes, not on the first Note On of an idle phrase.
- **Measurement Boundary**: These are software scheduling choices. They are not a claim that internal timestamps equal acoustic hardware action-to-sound latency. Distributional timing (p50/p95/p99, jitter) remains GitHub issue #26.
- **Clock Resolution**: 960 PPQN (Pulses Per Quarter Note) for sample-accurate groove and swing quantizing.
- **Memory Footprint**: $< 45\text{ MB}$ residential memory footprint during full 16-voice synthesis and timeline playback.
- **Zero Allocations on Audio Thread**: All voice DSP state, buffers, and oscillators are pre-allocated and statically indexed to eliminate garbage collection and heap locks during audio rendering.

---

## 5. Concurrency & Threading Model

### 5.1 Actor Isolation

- **UI state** (`ControllerManager`, `Sequencer`, `AppState`) is `@MainActor`-isolated.
- **Audio DSP** runs on a high-priority real-time thread via `AVAudioSourceNode` C-callback. No Swift concurrency features (`async`/`await`, `Task`) are used inside the audio render callback.
- **MIDI dispatch** uses a dedicated serial queue with `NSLock` synchronization for voice allocation state.

### 5.2 Real-Time Safety Rules

- No blocking I/O, file access, or heavy theory loops inside `AVAudioSourceNode` render block.
- Voice DSP state, buffers, and oscillators are pre-allocated and statically indexed.
- Controller input callbacks publish lightweight state; heavy processing is deferred to the main actor or a background scheduler.
- SwiftUI view updates are throttled to display refresh cadence; audio/MIDI scheduling never waits for SwiftUI invalidation.

### 5.3 Communication Boundaries

```
@MainActor (UI) ──Publisher──▶ ──Publisher──▶ Real-Time Threads
     ▲                        │
     │                        ▼
 Background Scheduler    MIDI / Audio Queues
 (theory, analysis)
```

Pure theory models (`XPadCore`, `XPadTheory`) are `Sendable` value types with no side effects.

---

## 6. Verification, Testing & CI Pipeline

### 6.1 Automated macOS CI & Release Packaging Gate

Every commit to `main` and all pull requests are validated via GitHub Actions on a native macOS runner (`.github/workflows/macos-ci.yml`):
- **Diagnostic Toolchain**: Verifies active Swift 6.0 toolchain and macOS environment.
- **Automated Test Gate**: Runs full unit test suites across all 6 submodules via `swift test`.
- **Release Packaging**: Compiles release binary, builds universal `XPI.app` bundle, ad-hoc signs with entitlements, and packages distributable `.dmg` and `.zip` archives.
- **Checksum Verification**: Generates and validates cryptographic SHA-256 hashes against all distribution artifacts.

### 6.2 Test Suite Structure

| Suite | Domain | Focus |
| :--- | :--- | :--- |
| `XPadCoreTests` | Theory primitives | Pitch math, enharmonics, intervals, scales, chords, voicings |
| `XPadTheoryTests` | Harmony engine | Polar wheels, voice leading, suggestions, modulations, progressions |
| `XPadControllerTests` | Hardware abstraction | Deadzones, strum velocity, direction heuristics, rhythm compass, gesture capture |
| `XPadMIDITests` | MIDI/MPE & CoreMIDI | Port lifecycle, MPE channel distribution, SMF encoding, UMP translation, **CoreMIDI virtual loopback** |
| `XPadAudioTests` | DSP synth | Preset configurations, ADSR state transitions, filter responses |
| `XPadSequencerTests` | Timeline | Transport states, clip recording, 960 PPQN clock, scene transitions |

### 6.3 CoreMIDI Virtual-Source Loopback Testing

To prove high-resolution MIDI 2.0 delivery without third-party host dependency in CI:
- An in-process CoreMIDI test receiver initializes a `._2_0` input port via `MIDIInputPortCreateWithProtocol`.
- Connects directly to the `XPI Main` virtual source endpoint (`MIDISourceCreateWithProtocol`).
- Validates that native 32-bit pitch bend words (`0x80000000` centre anchor) and UMP packet headers (`0x4` Channel Voice) survive the real macOS CoreMIDI driver transport without truncation.

### 6.4 Recording Architecture: Dual SMF1 & MIDI Clip File (SMF2)

```
Recorded Gesture / Performance Timeline (Transport-Neutral Normalized Events)
                         │
         +---------------+---------------+
         │                               │
         ▼                               ▼
Standard MIDI File 1.0          MIDI Clip File (SMF2 / M2-116-U)
  - Type 0 / Type 1 SMF           - Single UMP stream
  - 14-bit pitch bend             - 32-bit pitch / pressure / CC
  - 7-bit velocity & CC           - 16-bit note velocity
  - Legacy DAW drag-and-drop      - Native MIDI 2.0 clip export
```

### 6.5 Determinism Requirements

All `XPadCore` and `XPadTheory` models must be deterministic given identical inputs. Randomness is confined to optional generative features in `XPadTheory` and is explicitly seeded.

---

## 7. Mathematical Foundations

### 7.1 12-TET Frequency Computation

Given a MIDI note number $m \in [0, 127]$ and a fractional pitch bend offset in semitones $\Delta s$:

$$f(m, \Delta s) = 440.0 \times 2^{\frac{m + \Delta s - 69}{12}}\text{ Hz}$$

### 7.2 Polar Harmonic Wheel Geometry

The harmonic wheel maps analog thumbstick polar coordinates $(r, \theta)$ to chord sectors:

$$\theta = \text{atan2}(y, x) \in [-\pi, \pi]$$

$$\text{Sector Index } k = \left\lfloor \frac{(\theta + \frac{\pi}{2} \pmod{2\pi}) \times N}{2\pi} \right\rfloor$$

Where $N$ is the sector count of the active layer, and $r = \sqrt{x^2 + y^2}$ defines the harmonic tension radius.

### 7.3 Voice Leading Cost Function

The transition cost between previous voicing $V_{\text{prev}}$ and candidate voicing $V_{\text{cand}}$ is:

$$\mathcal{C}(V_{\text{prev}}, V_{\text{cand}}) = \sum_{i=1}^{\min(|V_{\text{prev}}|, |V_{\text{cand}}|)} (v_{\text{cand}, i} - v_{\text{prev}, i})^2 + 15.0 \cdot \big| |V_{\text{cand}}| - |V_{\text{prev}}| \big| + \text{Penalty}_{\text{register}} + \text{Penalty}_{\text{strategy}}$$

Minimizing $\mathcal{C}$ ensures smooth pianistic transitions with minimal physical voice displacement and maximum preserved common tones.
