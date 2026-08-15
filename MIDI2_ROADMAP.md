# MIDI 2.0 / MIDI-CI Roadmap — XPI

> **Status:** Experimental transport work. This document deliberately does **not** claim formal MIDI 2.0 compatibility or MIDI-CI support.

## Goal

Move XPI toward higher-resolution, more discoverable expressive MIDI while keeping the existing MIDI 1.0/MPE path dependable for current DAWs and Alpha 0.0.01 testers.

The architecture remains:

```text
controller gesture
→ musical technique / InstrumentPerformanceEvent
→ semantic PerformanceEvent
→ transport adapter
→ CoreMIDI MIDI 1.0 or MIDI 2.0 UMP
→ DAW / instrument
```

MIDI versioning belongs at the transport/destination boundary. Instrument technique logic should not become duplicated MIDI-1 and MIDI-2 code paths.

## Phase 1 — Protocol-selectable UMP transport

Implemented by the `feature/midi2-ump-transport` spike:

- keep MIDI 1.0 as the default;
- expose a compact MIDI 1 / MIDI 2 selector;
- create all six CoreMIDI virtual sources using the selected `MIDIProtocolID`;
- retain the existing semantic MIDI-byte diagnostic log;
- when MIDI 2 is selected, convert supported semantic channel messages to native MIDI 2.0 Channel Voice UMP using Apple's CoreMIDI message builders;
- scale 7-bit velocity to 16-bit velocity;
- scale 7-bit CC / pressure to 32-bit values;
- scale 14-bit pitch bend to 32-bit while preserving minimum, centre and maximum exactly;
- cleanly panic/dispose/recreate virtual endpoints when changing protocol live.

Supported in this first adapter:

- Note On
- Note Off
- Control Change
- Poly Pressure
- Channel Pressure
- Pitch Bend

The existing MPE manager and technique translator do not need separate MIDI-2 implementations for this compatibility slice because their events already pass through `MIDIEngine`.

### Important resolution boundary

The first implementation improves the **wire format**, but most values still originate in the current MIDI-1-shaped semantic representation. This means a trigger pressure that has already been quantised to `0...127` is expanded to 32 bits; it does not magically regain sensor precision that was discarded earlier.

A later high-resolution pass should carry normalized or native precision through `PerformanceEvent` / destination translation before final protocol encoding.

## Phase 1 acceptance tests

- MIDI 1 remains the default after a clean launch.
- Existing MIDI 1 tests remain byte-for-byte unchanged.
- MIDI 2 Note/CC/Pressure/Pitch messages use UMP MIDI 2 Channel Voice packets.
- 7-bit minimum and maximum map exactly to MIDI-2 minimum and maximum.
- MIDI-1 pitch bend `8192` maps exactly to MIDI-2 `0x80000000`.
- Protocol switching while live closes notes before endpoint replacement.
- Six XPI virtual sources appear under both transport selections.
- At least one MIDI-2-aware destination receives Note On/Off, CC, pressure and bend correctly.
- A MIDI-1-only destination is tested for CoreMIDI's protocol-conversion behaviour rather than assumed compatible.

## Phase 2 — Native high-resolution expression

Once host interoperability is proven, stop quantising expressive controller data early.

Candidate semantic changes:

- attack velocity remains normalized until transport mapping;
- pressure uses normalized/high-resolution state rather than `UInt8` at the musical boundary;
- timbre/controller dimensions retain normalized/high-resolution values;
- pitch continues to be represented musically in semitones/cents and encodes directly to the destination resolution;
- add MIDI 2 per-note pitch bend where destination capability and technique semantics make it useful;
- consider registered/assignable per-note controllers for future instrument profiles.

Do this without weakening the MIDI 1 / MPE fallback path.

## Phase 3 — UMP endpoint discovery and Function Blocks

A fully discoverable MIDI-2 device is broader than sending Channel Voice UMP.

Investigate CoreMIDI's current UMP endpoint APIs:

- `MIDIUMPEndpointManager`
- `MIDIUMPMutableEndpoint`
- `MIDIUMPMutableFunctionBlock`
- `MIDI2DeviceInfo`

Potential XPI topology:

- one XPI UMP Endpoint;
- Function Blocks/groups describing Main, Chords, Melody, Bass, Drums and Expression roles;
- meaningful endpoint manufacturer/model/version/product-instance metadata;
- only expose Function Blocks that improve host interoperability and remain understandable to users.

The package currently targets macOS 14. Any newer CoreMIDI API introduced after that deployment target must be availability-gated, with the Phase-1 virtual-source path retained as fallback.

## Phase 4 — MIDI-CI

MIDI-CI is **not** a one-way output format. It assumes bidirectional communication and capability discovery.

Do not hand-roll a MIDI-CI SysEx implementation merely to add a badge to the feature list.

Research/use CoreMIDI's current capability-inquiry model rather than building new work against Apple's deprecated `MIDICISession` / `MIDICIDiscoveryManager` / `MIDICIResponder` APIs.

Current CoreMIDI surfaces to evaluate include:

- `MIDICIDeviceManager`
- `MIDICIDevice`
- UMP Endpoint / Function Block capability metadata

Only implement a CI feature when it solves a concrete XPI interoperability problem.

Most promising uses:

1. **Profile Configuration** — negotiate a known expressive-instrument profile when a destination supports one relevant to XPI.
2. **Property Exchange** — expose or inspect useful destination properties such as controller capabilities/configuration rather than making users manually configure every mapping.
3. **Process Inquiry** — defer until a real XPI use case appears.

## Compliance language

Until discovery requirements and interoperability tests are met, describe the feature as:

> **Experimental MIDI 2.0 UMP output**

Do not market it as:

> MIDI 2.0 certified / fully MIDI 2.0 compatible / MIDI-CI compatible

Formal MIDI 2.0 minimum compatibility requirements include discovery mechanisms in addition to using MIDI 2 Channel Voice UMP.

## Core references

Primary sources used for this plan:

- Apple CoreMIDI — Incorporating MIDI 2 into your apps
  - https://developer.apple.com/documentation/coremidi/incorporating-midi-2-into-your-apps
- Apple CoreMIDI — MIDISourceCreateWithProtocol
  - https://developer.apple.com/documentation/coremidi/midisourcecreatewithprotocol(_:_:_:_:)
- Apple CoreMIDI — MIDI2NoteOn and MIDI 2 message builders
  - https://developer.apple.com/documentation/coremidi/midi2noteon(_:_:_:_:_:_:)
- Apple CoreMIDI — MIDI Capability Inquiry / current and deprecated API surface
  - https://developer.apple.com/documentation/coremidi
- The MIDI Association — MIDI 2.0 core architecture / minimum compatibility requirements
  - https://midi.org/details-about-midi-2-0-midi-ci-profiles-and-property-exchange-updated-june-2023
- The MIDI Association — MIDI-CI specification overview
  - https://midi.org/midi-ci-specification

## Next implementation gate

Do **not** proceed directly to MIDI-CI after this PR.

First verify:

1. the branch builds on the repository's macOS CI;
2. MIDI 1 regression tests stay green;
3. UMP packet tests pass;
4. MIDI 2 output reaches at least one real MIDI-2-aware host/instrument;
5. CoreMIDI fallback/conversion behaviour is observed in a MIDI-1 destination;
6. no stuck notes or expression-state leaks occur when switching transport.

Then decide whether native high-resolution expression or discovery/CI creates more immediate musical value.
