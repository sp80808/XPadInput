# PRODUCT RESEARCH — XPI: Game Controller MIDI

## 1. Executive Summary & Product Vision

**XPI: Game Controller MIDI** transforms standard game controllers (Sony DualSense / DualShock 4, Microsoft Xbox Wireless Controller, Nintendo Switch Pro Controller, and generic MFi/HID gamepads) into professional-grade, expressive musical instruments, MPE MIDI controllers, and intelligent harmony workstations for macOS.

Rather than treating game controllers as awkward arrays of arbitrary binary MIDI buttons, **XPI** treats the physical vocabulary of a gamepad — dual analog sticks (angular position, radius, velocity, trajectory), analog triggers (progressive travel), capacitive touchpads (2D surface strumming and timbre sweeps), IMU motion sensors (6-axis gyro and accelerometer), and haptic actuators — as an expressive musical interface.

---

## 2. Competitive & Workflow Analysis

### 2.1 MIDIpad (Core Insight & Limitations)
* **What works:** Treating the left stick as a radial chord selector and the right stick as a virtual strumming gesture; mapping face buttons to instant rhythmic triggers.
* **Limitations to overcome:**
  * Fixed, rigid chord layouts with limited modal interchange or dynamic voice leading.
  * Basic standard MIDI 1.0 output without polyphonic expression (MPE) voice allocation.
  * Lack of deep music theory engines, Roman numeral analysis, progression builders, or modulation assistance.
  * Often requires external DAWs/plugins to produce any sound.
* **Our differentiation:** Full MPE note-channel allocation per virtual string, multi-tier harmonic wheels (Diatonic, Colour, Borrowed, Tension, Mediant), real-time voice-leading optimization, gesture clip recording, and built-in low-latency polyphonic synthesis.

### 2.2 Scaler 3 & Captain Chords (Theory & Progression Building)
* **What works:** Intelligent chord recommendations ("What Next?"), circle of fifths integration, modal interchange, song templates across genres (Neo-Soul, Cinematic, Liquid DnB), and automatic voice leading (keeping common tones, minimising voice movement).
* **Limitations to overcome:** Mouse/keyboard-driven or static MIDI keyboard trigger pads; no continuous physical strumming or gesture recording.
* **Our differentiation:** Real-time physical gamepad interaction married to deep theory heuristics. As the left stick sweeps through harmonic space, chord voicings are dynamically voice-led in real time, and right stick displacement triggers organic strumming dynamics.

### 2.3 Hookpad / Hooktheory (Harmonic Function & Melody Harmonization)
* **What works:** Roman numeral relative theory (I, IV, V, vi, secondary dominants like V/vi), harmonic rhythm, melody-to-chord fit scoring.
* **Our differentiation:** Theory assist overlay explaining harmonic functions (e.g. *"IV → iv borrowed from parallel Aeolian"*), melody harmonization suggestions (Safe, Pop, Emotional, Jazzy, Cinematic), and Roman-numeral scale degree representations (1, 2, 3... or Solfège).

### 2.4 Ableton Push / Novation Launchpad / Expressive E Osmose
* **What works:** Scale locking, isomorphically arranged pads, MPE per-note pitch bend and pressure modulation.
* **Our differentiation:** Translating MPE dimensions into natural gamepad controls (trigger depth = bow/articulation pressure; gyro tilt = pitch bend / vibrato; touchpad X/Y = CC74 timbre / filter cutoff).

---

## 3. Technology Architecture on macOS

### 3.1 GameController.framework (`GCController`)
* Real-time polling and handler callbacks on `GCController.controllers()`, `GCControllerDidConnect`, `GCControllerDidDisconnect`.
* Dynamic inspection of `extendedGamepad`, `motion` (gyroscope & accelerometer), `touchpad` (DualSense/DualShock 4), and `haptics` via `CHHapticEngine`.
* Normalization pipeline: Configurable deadzones, radial/angular coordinate transformation, circular clamp, velocity delta computation for strumming.

### 3.2 CoreMIDI & MPE Engine
* Native `MIDIClientCreateWithBlock` and virtual source endpoints (`MIDISourceCreate`) exposing independent virtual ports:
  1. *XPI Main*
  2. *XPI Chords*
  3. *XPI Melody*
  4. *XPI Bass*
  5. *XPI Drums*
  6. *XPI Expression (MPE)*
* MPE Channel Manager: Allocates MPE Member Channels (Channels 2–15) with Zone Master on Channel 1, distributing strummed chord notes across unique channels with per-note pitch bend (±48 semitones), polyphonic pressure / aftertouch, and CC74 timbre.
* Tracked note cleanup plus MIDI Panic using CC123 All Notes Off on all 16 channels.

### 3.3 Audio Engine (`AVAudioEngine`)
* Built-in multi-timbral polyphonic synthesizer built with custom `AVAudioSourceNode` and `AVAudioUnitSampler` fallback.
* Custom DSP oscillator engine: Bandlimited PolyBLEP oscillators (Saw, Square, Triangle, Sine), ADSR envelope generators, resonant state-variable filters (LPF/HPF), dynamic voice allocation with smooth stealing, and stereo chorus/reverb.
* Zero latency playback when disconnected from DAWs.

### 3.4 Swift & SwiftUI 2026/macOS Architecture
* Modern Swift with `@Observable`, `@MainActor`, Swift Concurrency (`async`/`await`, `Actor`-isolated audio/MIDI schedulers).
* Clean separation of concern:
  * `Core/Theory`: Pure deterministic Swift structs (`PitchClass`, `Scale`, `Chord`, `VoiceLeading`, `Progression`, `Modulation`).
  * `Core/Controller`: GameController wrapper, capability profiling, virtual input smoothing.
  * `Core/MIDI`: CoreMIDI virtual sources, MPE voice dispatching, MIDI recording & Standard MIDI File (SMF .mid) export.
  * `Core/Audio`: Real-time DSP audio engine and presets.
  * `Core/Sequencer`: High-resolution tick-based engine (960 PPQN), clip timeline, scene management.
  * `UI`: Liquid-styled native macOS interface with 5 primary workspaces (PLAY, HARMONY, SEQUENCE, MAP, LIBRARY).

---

## 4. Gamepad Musical Innovations

1. **Intelligent Harmonic Wheel (Left Stick)**:
   - Polar coordinates $(\theta, r)$ map angle $\theta$ to chord selection (Diatonic, Colour, Borrowed, Tension, Mediant layers switched via Shoulder L1/R1).
   - Radius $r$ represents *Harmonic Risk Radius*: distance from center expands chord extensions and adventurousness.
2. **Virtual Strumming Surface (Right Stick & Touchpad)**:
   - Stick crossing virtual string thresholds triggers note-on events.
   - Sweep velocity calculates note velocity and strum spread time (rake, fast strum, down/up strum detection).
   - Trigger L2/R2 controls palm mute / dampening / envelope decay.
3. **Rhythm Compass (Drum & Arp Mode)**:
   - Radial division map: Left stick angle selects subdivision (1/4, 1/8, 1/8T, 1/16, 1/16T, 1/32), radius selects groove intensity/swing/ratchet.
4. **Gesture Recorder & Modulation Matrix**:
   - Continuous capture of stick trajectories, trigger travel, and 6-axis gyro motion into reusable `GestureClip`s that can modulate any musical parameter.
5. **Direct DAW Drag-and-Drop**:
   - Recorded performances exported on the fly to `.mid` URLs enabling native drag-and-drop directly into Ableton Live, Logic Pro, Bitwig, or Finder.
