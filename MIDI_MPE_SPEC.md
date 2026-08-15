# MIDI / MPE Specification — XPI: Game Controller MIDI

> **Status:** Canonical wire and lifecycle contract for the implemented contextual-expression slice.
>
> This specification distinguishes source implementation from automated and manual proof. It is not a declaration that every DAW or instrument has been certified.

## 1. Public CoreMIDI Sources

When virtual MIDI is enabled, the XPI CoreMIDI client creates these six MIDI 1.0 virtual sources:

1. `XPI Main`
2. `XPI Chords`
3. `XPI Melody`
4. `XPI Bass`
5. `XPI Drums`
6. `XPI Expression (MPE)`

`VirtualPort` is the source of truth for these public names. Swift package, target, and module identifiers remain `XPadInput` / `XPad*`.

The first five ports provide role-oriented routing. Per-note expression and lower-zone MPE traffic use `XPI Expression (MPE)`.

## 2. Channel Numbering and Zone

The lower MPE zone is:

| Role | User-visible MIDI channel | Internal zero-based channel |
|---|---:|---:|
| Zone master | 1 | 0 |
| Member voices | 2...15 | 1...14 |
| Unused by the allocator | 16 | 15 |

All per-note pitch, pressure, timbre, note-on, and note-off messages for an MPE voice use that voice’s member channel.

### Zone configuration

`sendMPEZoneConfiguration()` sends the lower-zone configuration on master Channel 1:

- RPN MSB `CC101 = 0`;
- RPN LSB `CC100 = 6`;
- Data Entry MSB `CC6 = 14`, declaring fourteen member channels;
- RPN null reset: `CC101 = 127`, `CC100 = 127`.

The destination must receive this configuration before relying on lower-zone semantics.

## 3. Bend-Range Contract

The musical range and destination range are separate:

- the **instrument range** limits the gesture in musically meaningful semitones; Guitar defaults to ±2;
- the **destination range** determines 14-bit pitch-bend encoding and the RPN range advertised to the receiver; Generic MPE and the internal synth default to ±48.

Changing the configured MPE bend range re-sends Pitch Bend Sensitivity RPN `0,0` on every member channel:

- `CC101 = 0`;
- `CC100 = 0`;
- `CC6` = whole semitones, clamped to `1...96`;
- `CC38` = fractional cents, clamped to `0...99`;
- RPN null reset with `CC101 = 127`, `CC100 = 127`.

The pitch engine, translator, MPE manager, and destination instrument must agree on the destination range. A Guitar bend of +2 semitones inside a ±48 destination range is encoded as a small offset from centre, not as full-scale bend.

## 4. 14-Bit Pitch Bend

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

Pitch assist operates before this encoding. It provides soft attraction to a target but never converts continuous bend into discrete note snapping.

## 5. Member-Voice Lifecycle

`MPEManager` allocates member channels deterministically in round-robin order across internal channels `1...14`.

### Allocation

Before every member-channel `NoteOn`, send neutral expression on the allocated channel in this order:

1. Pitch Bend = `8192`;
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
2. reset Pitch Bend to `8192`;
3. reset Channel Pressure to `0`;
4. reset CC74 Timbre to `64`;
5. only then make the channel available for reuse.

`stopAllNotes()` releases active voices in deterministic channel order. The global MIDI panic additionally sends tracked note-offs and `CC123 All Notes Off` on all sixteen channels of every public virtual port.

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

Normalized pressure is converted to `0...127`. Release/channel reuse resets MPE Channel Pressure to `0`.

Any fallback description must be retained in `MIDITranslationResult` and shown in MAP/diagnostics rather than silently changing musical behaviour.

## 7. Timbre / CC74

Per-note timbre is CC74 on the active member channel:

- normalized semantic timbre maps to `0...127`;
- `64` is the neutral allocation/release value;
- a non-neutral value is sent only when the destination advertises CC74 support.

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

## 9. Recording and Export Boundary

The semantic recorder retains technique-level events and note durations before MIDI flattening. `SMFExporter.encodeTechniques` writes a Type 0 file containing:

- tempo;
- pitch-bend sensitivity RPN (`CC101/100 = 0`, `CC6` = destination range);
- note on/off on the allocated member channel;
- pitch-bend, channel pressure, and CC74 when those dimensions are active;
- a return-to-centre pitch-bend at note-off.

Complete curve editing and DAW import proof remain planned. Byte-level tests currently verify header structure and the presence of pitch-bend status bytes.

## 10. Diagnostics

MAP diagnostics should identify:

- technique and note;
- one-based MIDI channel;
- velocity;
- signed pitch-bend distance from centre;
- pressure and CC74 values;
- strategy used;
- any capability fallback or blocked unsafe bend.

PLAY must not expose packet numbers or channel bookkeeping during normal performance.

## 11. Delivery and Proof Status

### Implemented in source

- all six branded `VirtualPort` cases and dynamic CoreMIDI source creation;
- MIDI 1.0 note, CC, poly-pressure, channel-pressure, CC74, and 14-bit bend encoding;
- lower-zone configuration for master Channel 1 and members Channels 2...15;
- deterministic allocation, voice stealing, pre-note reset, release reset, stop-all, and panic paths;
- configurable member-channel bend-range RPN messages;
- destination pressure, slide, articulation, and conventional-bend fallback rules;
- bounded diagnostic message logging.

### Automated proof boundary

Focused tests cover the six port names, member-channel isolation, pre-note pitch reset, note-off/reset lifecycle, bend centre/endpoints, pressure fallback, unsafe conventional-chord bend blocking, and basic SMF structure. Full byte-order coverage for every reset dimension and RPN message is still desirable. A green `swift test` result must be reported separately; this specification does not convert source presence into a passing release gate.

### Manual proof still required

- six sources appearing correctly in macOS Audio MIDI Setup and each supported DAW;
- host recognition of the lower MPE zone and advertised bend range;
- active-controller bend return without audible stepping or stuck notes;
- correct pressure and CC74 response in real destination instruments;
- haptic detent delivery and ergonomic feel;
- repeated allocation/voice-steal stress under live performance.

### Planned compatibility work

- destination profiles for specific instruments and sample libraries;
- configurable keyswitch/CC articulation maps;
- host-specific setup presets and compatibility certification;
- complete technique-aware SMF export and import round-trip tests.
