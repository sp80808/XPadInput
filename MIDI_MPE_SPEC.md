# MIDI / MPE Specification — XPI: Game Controller MIDI

> **Status:** Canonical wire and lifecycle contract for the implemented contextual-expression slice.
>
> This specification distinguishes source implementation from automated and manual proof. It is not a declaration that every DAW or instrument has been certified. Experimental MIDI 2.0 UMP transport is explicitly separated from formal MIDI 2.0 / MIDI-CI compatibility claims.

## 1. Public CoreMIDI Sources

When virtual MIDI is enabled, the XPI CoreMIDI client creates these six virtual sources:

1. `XPI Main`
2. `XPI Chords`
3. `XPI Melody`
4. `XPI Bass`
5. `XPI Drums`
6. `XPI Expression (MPE)`

`VirtualPort` is the source of truth for these public names. Swift package, target, and module identifiers remain `XPadInput` / `XPad*`.

The first five ports provide role-oriented routing. Per-note expression and lower-zone MPE traffic use `XPI Expression (MPE)`.

### Wire protocol

`MIDITransportProtocol` controls the CoreMIDI protocol advertised by all six sources:

- **MIDI 1.0** — default and current compatibility baseline;
- **MIDI 2.0** — experimental native MIDI 2 Channel Voice UMP transport.

Changing protocol while virtual MIDI is live must first release active notes/expression, dispose the old endpoints, and recreate the six sources under the new `MIDIProtocolID`.

The first MIDI 2 implementation is deliberately a transport adapter. The musical/technique layers continue to generate the same semantic events, and diagnostic `MIDIMessageRecord` values retain their established MIDI-1-shaped byte representation. The adapter expands supported events to MIDI 2 UMP at the CoreMIDI boundary.

This means the first MIDI 2 slice improves protocol interoperability and wire resolution, but does **not** yet provide native high-resolution data end-to-end when a value was already quantized earlier in the pipeline. See `MIDI2_ROADMAP.md`.

Do not describe this implementation as formal MIDI 2.0 certification or MIDI-CI support.

## 2. Channel Numbering and Zone

The lower MPE zone is:

| Role | User-visible MIDI channel | Internal zero-based channel |
|---|---:|---:|
| Zone master | 1 | 0 |
| Member voices | 2...15 | 1...14 |
| Unused by the allocator | 16 | 15 |

All per-note pitch, pressure, timbre, note-on, and note-off messages for an MPE voice use that voice’s member channel.

### Zone configuration

`sendMPEZoneConfiguration()` sends the active zone's MPE Configuration Message on the zone master:

- Lower zone: master Channel 1; Upper zone: master Channel 16;
- RPN MSB `CC101 = 0`;
- RPN LSB `CC100 = 6`;
- Data Entry MSB `CC6` = member-channel count (14 for Internal Synth default, **15** for Logic / Live / Bitwig / Cubase / Studio One / REAPER / Digital Performer / Waveform / MainStage);
- RPN null reset: `CC101 = 127`, `CC100 = 127`.

Host routing (`HostMIDIContext`) selects that member count automatically. A DAW track filtered to a single MIDI channel cannot carry MPE; XPI then falls back to conventional MIDI on that channel.

The destination must receive this configuration before relying on zone semantics.

### DAW track channel context

XPI virtual sources are already role-separated (`XPI Melody`, `XPI Chords`, `XPI Bass`, `XPI Drums`, `XPI Expression (MPE)`). Dedicated ports default to MIDI Channel 1 for pitched roles and GM Channel 10 for drums.

If the host track inspector is set to a specific channel (1–16) instead of All / Any:

- pitched roles collapse onto that channel so the track actually hears notes;
- MPE is disabled, because Live, Logic MIDI Mono Mode, Cubase Note Expression, and Studio One MPE all require the track to accept every member channel;
- GM drums stay on Channel 10 unless the track itself is Channel 10.

Auto-Detect uses the **frontmost** macOS DAW (bundle ID / process name), then any running DAW. Manual host selection always wins. This is a routing policy, not a substitute for GitHub #3 host certification.

Under the experimental MIDI 2 transport, the existing MPE setup messages are translated at the transport boundary for continuity with the current expression engine. Native MIDI 2 per-note expression is a later phase, not a reason to duplicate the MPE allocator immediately.

## 3. Bend-Range Contract

The musical range and destination range are separate:

- the **instrument range** limits the gesture in musically meaningful semitones; Guitar defaults to ±2;
- the **destination range** determines pitch-bend encoding and the range advertised to the receiver; Generic MPE and the internal synth default to ±48.

Changing the configured MPE bend range re-sends Pitch Bend Sensitivity RPN `0,0` on every member channel:

- `CC101 = 0`;
- `CC100 = 0`;
- `CC6` = whole semitones, clamped to `1...96`;
- `CC38` = fractional cents, clamped to `0...99`;
- RPN null reset with `CC101 = 127`, `CC100 = 127`.

The pitch engine, translator, MPE manager, and destination instrument must agree on the destination range. A Guitar bend of +2 semitones inside a ±48 destination range is encoded as a small offset from centre, not as full-scale bend.

## 4. Pitch Bend Encoding

### MIDI 1.0

Pitch bend is encoded as two 7-bit data bytes:

- minimum: `0`;
- centre: `8192`;
- maximum: `16383`.

Conceptually:

```text
normalized = clamp(semitoneOffset / destinationRange, -1...1)
value      = clamp(round(8192 + normalized × 8192), 0...16383)
LSB        = value & 0x7F
MSB        = (value >> 7) & 0x7F
```

Zero or invalid range resolves to centre. Out-of-range bend input clamps safely at the destination limit.

### Experimental MIDI 2 transport

The current adapter maps the established 14-bit semantic bend value into MIDI 2's 32-bit pitch-bend field with exact anchors:

- `0` → `0x00000000`;
- `8192` → `0x80000000`;
- `16383` → `0xFFFFFFFF`.

The conversion is piecewise around centre so the asymmetric MIDI 1 positive/negative range cannot shift the neutral position.

Pitch assist operates before either encoding. It provides soft attraction to a target but never converts continuous bend into discrete note snapping.

## 5. Member-Voice Lifecycle

`MPEManager` allocates member channels deterministically in round-robin order across internal channels `1...14`.

### Allocation

Before every member-channel `NoteOn`, send neutral expression on the allocated channel in this order:

1. Pitch Bend = centre;
2. Channel Pressure = `0`;
3. CC74 Timbre = `64`;
4. `NoteOn` for the new note.

If the same note is already active, release its existing voice first. If the next round-robin channel is occupied, release that voice before reuse.

### Active state

Each active voice retains:

- note and member channel;
- allocation timestamp;
- current bend in semitones;
- current pressure and timbre;
- active musical technique;
- optional legato source.

### Release

On note release:

1. send `NoteOff` on the allocated member channel;
2. reset Pitch Bend to centre;
3. reset Channel Pressure to `0`;
4. reset CC74 Timbre to `64`;
5. only then make the channel available for reuse.

`stopAllNotes()` releases active voices in deterministic channel order. The global MIDI panic additionally sends tracked note-offs and channel cleanup on all sixteen channels of every public virtual port.

The lifecycle contract is transport-independent: protocol switching must use the same cleanup guarantees before endpoint replacement.

## 6. Pressure

Attack velocity is carried by `NoteOn`; sustained pressure is a separate continuous dimension.

Preferred MPE pressure is MIDI Channel Pressure (`0xDn`) on the note’s member channel. The MPE manager also supports Polyphonic Key Pressure (`0xAn`) when a destination profile selects it.

Capability-driven fallback is:

| Preferred mode | Fallback order |
|---|---|
| MPE Pressure | Poly Pressure → Channel Pressure → CC11 |
| Poly Pressure | MPE Pressure → Channel Pressure → CC11 |
| Channel Pressure | MPE Pressure → CC11 |
| CC11 | CC11 |

Normalized pressure is currently converted to `0...127` before the transport boundary. MIDI 2 transport expands that value to the full 32-bit pressure field, but true end-to-end high-resolution pressure requires a future semantic-layer change. Release/channel reuse resets MPE Channel Pressure to `0`.

Any fallback description must be retained in `MIDITranslationResult` and shown in MAP/diagnostics rather than silently changing musical behaviour.

## 7. Timbre / CC74

Per-note timbre is CC74 on the active member channel:

- normalized semantic timbre currently maps to `0...127`;
- `64` is the neutral allocation/release value;
- a non-neutral value is sent only when the destination advertises CC74 support.

Under MIDI 2 transport, CC74 is encoded as a MIDI 2 Control Change with a 32-bit value expanded from the current semantic 7-bit value. Native higher-resolution timbre is planned after host interoperability is proven.

If CC74 is unavailable, harmonic/articulation translation falls back to a velocity/filter approximation. If a requested keyswitch is unavailable but CC74 exists, the translator falls back to MPE timbre and reports that decision.

## 8. Technique Translation

`TechniqueMIDITranslator` is the boundary between `InstrumentPerformanceEvent` and packet-level `PerformanceEvent` values.

Its responsibilities include:

- velocity shaping for legato, ghost notes, accents, and pinch harmonics;
- pitch-bend encoding from semantic semitones;
- slide selection among MPE pitch, channel pitch bend, legato retrigger, and CC5 portamento;
- pressure selection among member-channel pressure, poly pressure, channel pressure, and CC11;
- CC74 and articulation translation;
- human-readable fallback and diagnostic output.

### Conventional MIDI safeguard

Pitch bend is channel-wide outside MPE. An independent bend is permitted only when:

- the destination supports MPE; or
- a single voice is sounding on the conventional channel.

If multiple conventional-MIDI voices share a channel, the translator blocks the per-note bend and reports the conflict. It must not bend an unintended chord silently.

The transport selector does not change this musical safety rule. Native MIDI 2 per-note pitch is a future capability that must be introduced explicitly at the destination/technique layer rather than inferred merely from choosing MIDI 2 transport.

## 9. Recording and Export Boundary

The semantic recorder retains technique-level events and note durations before MIDI flattening. `SMFExporter.encodeTechniques` writes a Type 0 Standard MIDI File containing:

- tempo;
- pitch-bend sensitivity RPN (`CC101/100 = 0`, `CC6` = destination range);
- note on/off on the allocated member channel;
- pitch-bend, channel pressure, and CC74 when those dimensions are active;
- a return-to-centre pitch-bend at note-off.

The live MIDI 2 UMP transport does not silently change SMF export format. MIDI Clip / UMP file support is a separate future decision.

Complete curve editing and DAW import proof remain planned. Byte-level tests currently verify header structure and the presence of pitch-bend status bytes.

## 10. Diagnostics

MAP diagnostics should identify:

- selected transport (`MIDI 1` / `MIDI 2`);
- technique and note;
- one-based MIDI channel;
- velocity;
- signed pitch-bend distance from centre;
- pressure and CC74 values;
- strategy used;
- any capability fallback or blocked unsafe bend.

PLAY must not expose packet numbers or channel bookkeeping during normal performance. The transport selector belongs with MIDI connection state rather than becoming a new workspace.

## 11. Delivery and Proof Status

### Implemented in source

- all six branded `VirtualPort` cases and dynamic CoreMIDI source creation;
- MIDI 1.0 note, CC, poly-pressure, channel-pressure, CC74, and 14-bit bend encoding;
- optional experimental MIDI 2.0 Channel Voice UMP transport for those same semantic messages;
- protocol-aware virtual-source recreation with cleanup when switching transport;
- lower-zone configuration for master Channel 1 and members Channels 2...15;
- deterministic allocation, voice stealing, pre-note reset, release reset, stop-all, and panic paths;
- configurable member-channel bend-range RPN messages;
- destination pressure, slide, articulation, and conventional-bend fallback rules;
- bounded diagnostic message logging.

### Automated proof boundary

Focused tests cover the six port names, member-channel isolation, pre-note pitch reset, note-off/reset lifecycle, bend centre/endpoints, pressure fallback, unsafe conventional-chord bend blocking, and basic SMF structure.

High-resolution and MIDI 2 automated proofs:
- **Native 32-bit semantic pitch bend (PR #16):** Direct encoding from semitone offsets to MIDI 2 32-bit pitch bend word (`0x00000000` min, `0x80000000` centre, `0xFFFFFFFF` max) without 14-bit down-quantization; protocol-aware deduplication ensures sub-14-bit movements are preserved in MIDI 2 while suppressed as redundant in MIDI 1.
- **CoreMIDI virtual-source loopback (PR #17):** In-process CoreMIDI test client creating a `._2_0` protocol input port (`MIDIInputPortCreateWithProtocol`) connected to `XPI Main` virtual source (`MIDISourceCreateWithProtocol`), proving the native 32-bit pitch word survives the real macOS CoreMIDI subsystem.
- **Normalized MPE pressure and timbre state (PR #20):** High-resolution normalized `Double` state tracking on member voices with protocol-resolution-aware deduplication for Channel/Poly Pressure and CC74.

A green repository CI workflow (`.github/workflows/macos-ci.yml`) executes these tests on every push and PR.

### Manual proof still required

Tracked by GitHub issues #3 and #13:
- **DAW Virtual Port Enumeration:** All six sources appearing correctly in macOS Audio MIDI Setup and each supported DAW (Logic Pro, Ableton Live, Bitwig Studio) under MIDI 1.0 and MIDI 2.0.
- **MPE Lower Zone & Bend Agreement:** Host recognition of Master Ch 1 + Member Ch 2–15 and agreement on configured ±48 semitone pitch-bend sensitivity.
- **Real-Host MIDI 2.0 Reception (Logic Pro):** With Logic Pro MIDI 2.0 preference enabled, verify Note On/Off, CC, Channel Pressure, Poly Pressure, and smooth continuous 32-bit pitch bend without stepping.
- **Ableton Live MPE Regression:** Member-channel note isolation, per-note pitch/pressure/timbre with MPE instruments (Wavetable, Drift), and clean Guitar bend return to centre.
- **Protocol Switching Resilience:** Switching between MIDI 1.0 $\leftrightarrow$ MIDI 2.0 with active sounding notes without hung notes, stuck expression, or memory leaks.
- **Panic & Recovery:** Global MIDI Panic reliably recovers destinations across all 16 channels on all 6 ports.
- **Repeated Allocation & Stealing:** Round-robin voice-stealing under heavy polyphonic strumming without dropped note-offs.

### Planned compatibility work

- carry genuinely high-resolution expression through live `AppState.applyExpression` callers before MIDI 2 encoding (#15);
- evaluate native MIDI 2 per-note pitch/controllers where they improve instrument techniques (#18);
- UMP Endpoint and Function Block discovery/topology;
- MIDI-CI MPE Profile (`M2-120-UM_v2-0-3`) negotiation using CoreMIDI `MIDICIDevice` / `MIDICIDeviceManager` (#14);
- Profile Configuration or Property Exchange only for concrete interoperability use cases;
- destination profiles for specific instruments and sample libraries;
- configurable keyswitch/CC articulation maps;
- host-specific setup presets and compatibility certification;
- MIDI Clip File (M2-116-U) / SMF2 export for native MIDI 2 performances (#19).

See `MIDI2_ROADMAP.md` for the staged MIDI 2.0 / MIDI-CI plan and compliance-language boundary.

