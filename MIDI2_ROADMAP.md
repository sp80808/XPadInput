# MIDI 2.0 / MIDI-CI Roadmap — XPI

> **Status:** Experimental transport work. This document deliberately does **not** claim formal MIDI 2.0 compatibility or MIDI-CI support.

## Goal

Move XPI toward higher-resolution, more discoverable expressive MIDI while keeping the existing MIDI 1.0/MPE path dependable for current DAWs and alpha testers.

The architecture remains:

```text
controller gesture
→ musical technique / InstrumentPerformanceEvent
→ semantic performance state
→ destination strategy
→ transport adapter
→ CoreMIDI MIDI 1.0 or MIDI 2.0 UMP
→ DAW / instrument
```

MIDI versioning belongs at the destination/transport boundary. Instrument technique logic should not become duplicated MIDI-1 and MIDI-2 code paths.

## Research conclusions — 15 Aug 2026

Current Apple CoreMIDI and MIDI Association material changes the implementation priorities in a few useful ways:

1. **UMP transport and high-resolution semantics are separate layers.** CoreMIDI can carry MIDI 1 UMP and MIDI 2 UMP and can translate to the protocol a destination advertises, but values already quantized by XPI cannot regain lost precision merely because the wire field is wider.
2. **MIDI 2 Channel Voice has real musical advantages for XPI.** Note velocity is 16-bit; CC, channel/poly pressure and pitch bend use 32-bit data; MIDI 2 also adds per-note pitch bend and per-note controller messages.
3. **Several MIDI-2-only messages have no MIDI 1 equivalent.** Per-note controllers, Per-Note Management and Per-Note Pitch Bend therefore require explicit destination capability evidence rather than optimistic fallback assumptions.
4. **MIDI-CI requires bidirectional communication.** One-way MIDI 2 UMP output is not a MIDI-CI implementation.
5. **The MIDI-CI MPE Profile is directly relevant to XPI.** The current MPE Profile (`M2-120-UM_v2-0-3`) describes MPE over MIDI 1.0 and/or MIDI 2.0. Profile negotiation can coordinate channel count and supported expression dimensions instead of requiring XPI to assume a fixed 14-member lower zone forever.
6. **Property Exchange is not the first CI feature XPI needs.** MPE Profile negotiation solves a concrete setup problem immediately; Property Exchange should wait for a specific configuration/state-discovery use case.
7. **Recording has a separate MIDI 2 path.** The MIDI 2 core collection includes the MIDI Clip File / SMF2 format, so future high-resolution export should not be forced into the existing SMF1 renderer.

## Phase 1 — Protocol-selectable UMP transport — implemented

Implemented and merged in PR #12:

- MIDI 1.0 remains the default;
- compact MIDI 1 / MIDI 2 selector;
- all six CoreMIDI virtual sources are created with the selected `MIDIProtocolID`;
- existing MIDI-1-shaped diagnostic log remains stable;
- MIDI 2 mode converts supported channel events to native MIDI 2 Channel Voice UMP using CoreMIDI builders;
- 7-bit velocity expands to 16-bit;
- 7-bit CC / pressure expands to 32-bit;
- 14-bit pitch bend expands to 32-bit with exact min / centre / max anchors;
- protocol switching closes voices and recreates endpoints cleanly.

Supported by the compatibility adapter:

- Note On
- Note Off
- Control Change
- Poly Pressure
- Channel Pressure
- Pitch Bend

### Phase 1 remaining proof

Tracked by #13:

- all six sources appear under MIDI 2 in a real host;
- a MIDI-2-aware destination receives notes, CC, pressure and bend correctly;
- a MIDI-1-only destination is tested for CoreMIDI conversion/fallback behaviour;
- live MIDI 1 ↔ MIDI 2 switching creates no stuck notes or retained expression.

## Phase 2 — Native high-resolution expression — in progress

Tracked by #15.

XPI already has a better semantic source than `PerformanceEvent` suggests: `ExpressionDimensions` and performance frames keep pressure/timbre and related dimensions normalized as `Double`, while pitch is carried in musical semitones.

### 2A — Pitch — implemented & verified

Implemented in PR #16 and verified via CoreMIDI loopback in PR #17:

```text
stick / slide / vibrato motion
→ semitone offset
→ destination bend range
→ MIDI 1: 14-bit bend
→ MIDI 2: native 32-bit bend
```

- Direct 32-bit semantic pitch bend encoding without 14-bit intermediate down-quantization.
- MPE member-channel deduplication compares actual selected wire resolution so sub-14-bit bends are preserved in MIDI 2 and suppressed as redundant in MIDI 1.
- In-process CoreMIDI virtual-source loopback test proves the 32-bit pitch word survives the macOS transport path to a `._2_0` input port.

### 2B — Pressure and timbre — state merged (PR #20), live caller wiring next

Normalized models and builders added:
- High-resolution `MIDIEngine` / `MPEManager` normalized builders and member-voice state.
- Protocol-resolution-aware deduplication for Channel/Poly Pressure and CC74.
- Compatibility `UInt8` APIs preserved as wrappers.
- Next step: update `AppState.applyExpression` live callers to pass normalized `frame.pressure` and `frame.timbre`.

### 2C — Attack velocity

The current strum/face-button velocity pipeline resolves attack to `UInt8` before MIDI transport. Refactor the stabilizer/output boundary so musical attack remains normalized until destination rendering, then:

- MIDI 1 → 7-bit velocity;
- MIDI 2 → 16-bit velocity.

Do not simply expand a 7-bit velocity and call it high-resolution.

## Phase 3 — Native MIDI 2 per-note strategy — capability-gated

Apple CoreMIDI provides builders for `MIDI2PerNotePitchBend`, Registered/Assignable Per-Note Controllers and Per-Note Management.

These are attractive for bends, vibrato, slides and future instrument profiles, but they are **not** a safe universal replacement for MPE because some MIDI 2 per-note messages have no default MIDI 1 translation.

Prototype only after #13 and #15 provide real host evidence.

Candidate destination strategies:

```text
conventional MIDI
MPE member channels
native MIDI 2 per-note
```

Selection must be explicit/capability-driven. Never silently send a MIDI-2-only per-note message to an unknown destination.

## Phase 4 — UMP Endpoint discovery and Function Blocks

A discoverable MIDI 2 device is broader than six protocol-tagged one-way sources.

Investigate current CoreMIDI UMP endpoint APIs:

- `MIDIUMPEndpointManager`
- `MIDIUMPMutableEndpoint`
- `MIDIUMPMutableFunctionBlock`
- `MIDI2DeviceInfo`

Potential XPI topology:

- one XPI UMP Endpoint;
- clear Function Blocks/groups for Main, Chords, Melody, Bass, Drums and Expression only if hosts display/use them meaningfully;
- consistent manufacturer/model/version/product-instance metadata across CoreMIDI and later MIDI-CI layers.

The package currently targets macOS 14. Newer API surfaces must be availability-gated, and the current virtual-source implementation remains the fallback until compile + host proof exists.

## Phase 5 — MIDI-CI: MPE Profile first

Tracked by #14.

MIDI-CI assumes bidirectional communication and capability discovery. The first XPI CI target should be the **MIDI-CI Profile for MIDI Polyphonic Expression**, because it directly improves a system XPI already uses.

Desired flow:

```text
connect / discover destination
→ confirm MIDI-CI
→ discover MPE Profile support
→ inspect Profile Details
→ negotiate supported member channels / dimensions
→ reconcile bend sensitivity
→ enable profile
→ expose state in MAP diagnostics
→ otherwise fall back to explicit current MPE RPN setup
```

Do not build new work around deprecated `MIDICISession`, `MIDICIDiscoveryManager` or `MIDICIResponder` APIs. Evaluate current `MIDICIDeviceManager` / `MIDICIDevice` and UMP Endpoint surfaces against the actual SDK/deployment target before committing architecture.

### Property Exchange — later

Potentially useful future resources:

- destination/device metadata;
- controller capability/configuration;
- saved state/preset exchange;
- reducing manual mapping where a real host exposes useful resources.

Do not implement generic JSON-over-SysEx plumbing until an actual interoperability problem justifies it.

### Process Inquiry — defer

No current XPI use case justifies Process Inquiry.

## Phase 6 — MIDI 2 recording/export

The semantic recorder remains the source of truth. Existing SMF1 export stays as the compatibility renderer.

After high-resolution live output is proven, evaluate **MIDI Clip File / SMF2** export for data that cannot be represented faithfully in SMF1, especially:

- high-resolution velocity/pressure/controller curves;
- native MIDI 2 per-note pitch/controllers if adopted;
- profile-aware articulation data where a standardized profile defines it.

Do not invent a proprietary file format while a standard MIDI 2 clip format exists.

## Compliance language

Until bidirectional discovery requirements and interoperability tests are met, describe the feature as:

> **Experimental MIDI 2.0 UMP output**

Do not market it as:

> MIDI 2.0 certified / fully MIDI 2.0 compatible / MIDI-CI compatible

## Core references

Primary sources used for this plan:

- Apple CoreMIDI — Incorporating MIDI 2 into your apps
  - https://developer.apple.com/documentation/coremidi/incorporating-midi-2-into-your-apps
- Apple CoreMIDI — MIDI 2 Channel Voice builders / Per-Note Pitch Bend
  - https://developer.apple.com/documentation/coremidi/midi2pernotepitchbend(_:_:_:_:)
- Apple CoreMIDI — MIDI2ControlChange
  - https://developer.apple.com/documentation/coremidi/midi2controlchange(_:_:_:_:)
- The MIDI Association — MIDI 2.0 core specification collection
  - https://midi.org/midi-2-0-core-specification-collection
- The MIDI Association — UMP and MIDI 2.0 Protocol
  - https://midi.org/universal-midi-packet-ump-and-midi-2-0-protocol-specification
- The MIDI Association — MIDI-CI
  - https://midi.org/midi-ci-specification
- The MIDI Association — MIDI-CI MPE Profile
  - https://midi.org/midi-ci-profile-for-midi-polyphonic-expression
- The MIDI Association — Common Rules for Profiles
  - https://midi.org/common-rules-for-midi-ci-profiles
- The MIDI Association — Property Exchange
  - https://midi.org/midi-2-0-property-exchange

## Current gates

1. Keep macOS CI green for every transport change.
2. Finish the direct high-resolution pitch slice without changing MIDI 1 byte behaviour.
3. Wire normalized pressure and timbre into the live caller path.
4. Perform #13 against at least one genuinely MIDI-2-aware destination.
5. Only then prototype MIDI 2 per-note messages or UMP Endpoint/MIDI-CI topology.
6. Prefer the standardized MPE Profile as the first CI feature because it solves an existing XPI configuration problem.
