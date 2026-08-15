# Instrument Techniques — XPI: Game Controller MIDI

> **Status:** Canonical semantic contract for instrument-aware performance.
>
> “Implemented” in this document means the source path exists. It does not imply that controller feel, haptic delivery, audible technique quality, or DAW compatibility has been manually proven.

## 1. Semantic Boundary

XPI interprets a player’s intent before deciding how to encode it.

```text
controller state
→ processed gesture
→ active InstrumentProfile + MusicalContext
→ MusicalTechnique
→ InstrumentPerformanceEvent
→ MIDI/MPE, internal synth, recording, visual, and haptic adapters
```

PLAY speaks in techniques such as **Bend**, **Slide**, **Hammer-On**, and **Pressure**. MIDI packet types, CC numbers, member channels, bend ranges, and fallback strategies belong in MAP or diagnostics.

The core and theory layers remain deterministic. Views consume semantic performance state; they must not independently reinterpret raw controller values.

## 2. Instrument Profiles

`InstrumentProfile` owns family-level musical behaviour:

- instrument family and display name;
- monophonic, polyphonic, or MPE behaviour;
- preferred musical bend range and downward-bend permission;
- supported techniques;
- pressure, articulation, slide, curve, vibrato, and gesture defaults;
- instrument-specific thresholds and contextual HUD labels.

The family vocabulary includes Guitar, Bass, Keys, Synth Lead, Synth Poly, Strings, Brass, Woodwind, Plucked, Percussion, and Generic MPE. The current concrete profile list exposes Guitar, Keys, and Synth Lead; only Guitar is the end-to-end vertical slice. A family existing in the model does not mean that its complete performance mode is finished.

### Implemented vertical-slice profile: Guitar

The canonical Guitar defaults are:

- expressive MPE polyphony;
- a ±2-semitone musical bend range;
- downward bends allowed;
- an expressive bend curve with Light pitch assist;
- MPE pressure, MPE pitch for slides, and MPE timbre as preferred translations;
- lateral right-stick bend while a note is sustained;
- right-stick Y strum when the bend gesture does not own the stick;
- L2 damping/palm mute, R2 sustained pressure, R1 technique modifier, and gyro/micro-motion vibrato;
- chord-tone face-button roles and guitar-specific legato/string constraints.

These are musical defaults. A destination can advertise a wider MIDI bend range without making the physical Guitar gesture bend by that full amount.

## 3. Technique Grammar

`MusicalTechnique` is independent of MIDI and audio implementation. The grammar covers:

- attack and duration: Normal, Accent, Staccato, Sustain;
- connection: Legato, Hammer-On, Pull-Off, Slide Up, Slide Down, Portamento;
- pitch expression: Bend, Pre-Bend, Release Bend, Vibrato;
- pressure and damping: Aftertouch, Poly Pressure, Palm Mute;
- articulation and ornament: Harmonic, Pinch Harmonic, Ghost Note, Tremolo, Trill, Grace Note.

Profiles declare which techniques are idiomatic. Unsupported techniques must not silently acquire unrelated controller meanings.

## 4. Performance Event Contract

`InstrumentPerformanceEvent` carries musical meaning across output boundaries. Its stable concepts are:

- source note and optional target note;
- optional chord-tone role and previous-note context where required;
- semantic lifecycle phase: Began, Changed, or Ended;
- technique and attack velocity;
- pitch offset in semitones;
- normalized pressure, timbre, damping, brightness, and vibrato dimensions;
- timestamp.

Normalized dimensions are clamped to `0...1`; invalid numeric input resolves to a safe neutral value. Pitch remains in semitones until a destination translator applies its configured range.

This event may feed the internal synth, `TechniqueMIDITranslator`, recording, MAP diagnostics, or restrained PLAY feedback without exposing MIDI implementation details to the gesture engine.

## 5. Contextual Guitar Bend

The implemented vertical slice follows this contract:

1. A note must be sustained and the active profile must support bend.
2. Lateral right-stick movement owns the bend gesture; conflicting strum interpretation is suppressed.
3. The stick deadzone and expressive curve provide fine control around centre.
4. The Guitar range clamps the musical result to ±2 semitones.
5. `MusicalContext` supplies key, scale, chord, previous/current note, register, chromatic mode, and pitch-assist mode.
6. Candidate destinations are ranked with chord tones ahead of scale tones and chromatic landmarks, while common one-, two-, and three-semitone gestures receive an idiomatic bias when they fit the range.
7. Off, Light, and Strong assist alter a soft attraction field. Attraction never hard-snaps or forbids pitch between targets.
8. The semantic state exposes bend amount, nearest target, target proximity, a transient display label, and a one-shot target-crossing detent request.
9. Returning the stick to centre springs pitch back to zero; the visual and MIDI paths must also return to neutral.

Typical PLAY copy is `Guitar · Bend +2 → G`. Raw 14-bit values and member channels remain diagnostic information.

## 6. Pressure, Timbre, and Vibrato

Attack velocity and sustained pressure are separate dimensions.

The pressure envelope tracks attack pressure, sustained pressure, delta, release pressure, velocity, smoothing, and the resulting 7-bit value. Profile response curves shape the normalized input before destination translation.

For MPE, sustained pressure is channel pressure on the note’s member channel. Destination fallback order is capability-driven:

- preferred MPE pressure → Poly Pressure → Channel Pressure → CC11;
- preferred Poly Pressure → MPE Pressure → Channel Pressure → CC11;
- preferred Channel Pressure → MPE Pressure → CC11.

Timbre uses per-note CC74 when supported. If CC74 is unavailable, articulation translation may fall back to a velocity/filter approximation and must surface that fallback in MAP diagnostics.

Vibrato is a small, separate pitch modulation that may be inferred from gyro, stick micro-motion, or trigger micro-variation. It can be superimposed over a broader bend but must remain instrument-scaled.

## 7. Legato, Slides, and Articulations

The deterministic legato interpreter considers previous/current note, overlap, elapsed time, pick attack, direction, instrument profile, realism, virtual-string relationship, and prepared lower-note state.

Current precedence is:

1. Pinch Harmonic
2. Harmonic
3. Slide / Portamento
4. Bend
5. Hammer-On / Pull-Off
6. Palm Mute
7. Vibrato
8. Pressure
9. Strum
10. Normal

The Guitar string model is deliberately lightweight. It provides standard tuning, fret assignment, same-string checks, and practical interval constraints; it is not a physical guitar simulator.

Slide translation resolves by destination capability:

- MPE pitch when MPE is available;
- channel pitch bend as the conventional fallback;
- CC portamento when supported;
- legato retrigger when portamento support is absent.

Harmonic articulation can resolve to MPE timbre, a harmonic MIDI note, a keyswitch, a configured CC, or a velocity/timbre approximation. No commercial sample-library convention is hard-coded as universal.

## 8. PLAY, MAP, and Feedback Responsibilities

PLAY shows only:

- current instrument;
- current note/chord and key/scale context;
- active technique when it is not Normal;
- bend target/proximity while bending;
- contextual labels for the controls relevant to the active profile;
- brief, dismissible discovery hints.

MAP owns:

- destination capability profile;
- bend range and pressure mode;
- articulation and slide translation strategy;
- physical input processing;
- fallback diagnostics and packet-level monitoring.

Visual and haptic feedback must be restrained and semantic. One musical event produces at most one haptic event; continuous pressure or vibrato must never cause continuous vibration.

## 9. Delivery and Proof Status

### Implemented in source

- semantic instrument, technique, context, target, expression, and destination-capability models;
- Guitar family defaults and contextual control labels;
- sustained-note right-stick bend with soft target attraction and return-to-centre state;
- pressure smoothing, vibrato state, legato classification, lightweight string state, slides, and technique priority;
- technique-to-MIDI fallback decisions and internal-synth expression entry points;
- six branded virtual ports and lower-zone MPE allocation/lifecycle support.

### Automated proof boundary

Focused deterministic tests cover profile distinctions, technique labels, expression normalization, contextual target ranking, soft attraction, return to centre, pressure smoothing, legato decisions, slide interpolation, translation fallbacks, channel isolation, and pitch-bend lifecycle. A green `swift test` result must still be recorded with the implementation handoff; this document does not itself certify the current checkout’s complete test gate.

### Manual proof still required

- feel and ergonomics with real DualSense, Xbox, Switch Pro, and generic controllers;
- physical haptic delivery and detent subtlety;
- audible distinction of palm mute, harmonic, and pinch-harmonic synthesis;
- active Ableton Live, Logic Pro, and Bitwig MPE routing;
- destination bend-range agreement and stuck-note recovery under real performance load.

### Planned or incomplete depth

- production tuning for Bass, Keys, Synth Lead, Strings, and the remaining families;
- commercial-library articulation profiles and keyswitch maps;
- editable recorded technique curves and complete technique-aware SMF export;
- per-controller ergonomic tuning, accessibility alternatives, and host compatibility certification.
