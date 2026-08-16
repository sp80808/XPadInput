# DESIGN.md — XPI: Game Controller MIDI Product & Interaction Design System

> **Status:** Authoritative design direction for XPI UI, interaction, feedback, and controller ergonomics.
>
> XPI: Game Controller MIDI is not a MIDI-mapping utility with a gamepad skin. It is a **native macOS musical instrument whose physical vocabulary happens to be a modern game controller**.

---

## 1. Purpose

This document defines how XPI should **look, feel, teach, respond, and behave** as development continues.

It exists to prevent three common failure modes:

1. turning the app into a generic dark “music-tech dashboard” full of meters and cards;
2. treating controller inputs as raw parameters rather than embodied musical gestures;
3. allowing individual workspaces or agents to invent incompatible UI patterns.

The design system must preserve a simple causal chain:

**gesture → musical behaviour → visual / audible / tactile feedback**

The player should gradually stop thinking in implementation terms such as “L2 sends 0…1” or “right-stick Y determines velocity” and instead think:

- **I damp the strings.**
- **I strum harder.**
- **I move through harmony.**
- **I push further out for more harmonic risk.**

That mental shift is the core design objective.

---

## 2. Current Product Context

The repository already establishes a strong product foundation:

- a five-workspace model: **PLAY, HARMONY, SEQUENCE, MAP, LIBRARY**;
- gamepad capability profiling and support for standard, rhythm, and niche controllers;
- harmonic-wheel navigation and harmonic-risk radius;
- physical right-stick strumming;
- analog triggers, motion, touch, MPE, MIDI routing, gesture recording, and built-in audio;
- a dark green `XTheme` design system;
- controller glyphs and controller-specific visualisers;
- alternate/newer workspace components under `Sources/XPadUI`.

### Design-system convergence rule

The repository currently contains more than one UI idiom: the `XTheme` / environment-driven app views and a second family of `Sources/XPadUI/*WorkspaceView` components using separate materials, colours, and visual language.

**Do not create a third design system.**

Future work should consolidate useful components into one visual and interaction system. The exact file-layout refactor can be incremental, but all new UI should follow this document.

`XTheme` should evolve from a colour palette into the canonical semantic design-token layer, while reusable controller visualisers and specialist workspace components should be adapted to consume those tokens.

---

## 3. Research-Informed Design Principles

### 3.1 Preserve learned gamepad motor expertise

Dual-analog controllers are valuable as musical interfaces partly because many users already possess deep sensorimotor familiarity with them. Research into dual-analog gamepads as live-electronics instruments specifically highlights self-centering continuous controls, tactile physical controls, portability, and the ability to transfer existing game-controller skill into musical control.

Design consequence:

- left thumb should usually handle **navigation / selection spaces**;
- right thumb should usually handle **action / expression spaces**;
- index fingers should handle **pressure and held modifiers**;
- face buttons should handle **rapid discrete musical events**;
- D-pad should favour **discrete state navigation**, not primary expressive gestures.

Avoid mappings that deliberately contradict familiar hand roles unless they create a clearly superior musical gesture.

### 3.2 Legibility matters as much as capability

Research on gestural musical mappings repeatedly identifies **control, legibility, and sound** as core design concerns. A mapping should be understandable to the performer and, where possible, visibly correlated with the resulting sound.

Design consequence:

The UI should not merely show raw controller state. It should reveal musical causality.

Bad:

`Right Stick Y: -0.81`

Better:

- the stick trajectory crosses six virtual strings;
- the strings illuminate in crossing order;
- a short velocity pulse communicates attack strength;
- the sounding chord and articulation update at the same moment.

### 3.3 Use physical metaphors where they are strong

Gesture-controlled DMI research shows value in intuitive physical metaphors such as striking, bowing, pushing, tilting, and damping.

Use them when the physical relationship is convincing:

- **sweep → strum**;
- **pressure → damping / expression**;
- **tilt → bend / vibrato / spatial movement**;
- **radius → intensity / risk / density**;
- **rotation → harmonic or rhythmic navigation**.

Do not force metaphor when a straightforward control is more understandable.

### 3.4 Design the instrument as a bidirectional relationship

Recent DMI research cautions against thinking of mapping as a static one-way connection from sensor to parameter. The performer continuously adapts to what the instrument gives back.

XPI should therefore treat feedback as part of the mapping itself:

**input → interpretation → sound → visual state → haptic state → performer adaptation**

Haptics and visuals must not be decorative afterthoughts.

### 3.5 Haptics communicate state, not spectacle

Research on haptic DMIs finds consistent value in perceived usability, expressivity, and playing experience, although objective performance gains depend on task and implementation.

Use haptics to communicate:

- sensor / gesture boundaries;
- musical-state changes;
- discrete confirmations;
- temporal landmarks.

Do not continuously vibrate simply because the controller supports it.

### 3.6 Adaptability is a core feature

Research on accessible digital musical instruments repeatedly identifies adaptability, customisation, iterative prototyping, and participation as important design qualities.

For XPI this means that:

- deadzones are adjustable;
- response curves are adjustable;
- travel can be reduced;
- motion can be disabled;
- mappings can be remapped;
- alternative controls exist when a hardware capability is missing;
- UI feedback never depends on colour alone.

Accessibility settings should be presented as **instrument personalisation**, not isolated as a secondary “special needs” feature.

---

## 4. Product Personality

XPI should feel:

- **native** — unmistakably at home on macOS;
- **musical** — the interface is organised around sound and gesture, not engineering telemetry;
- **tactile** — controls visibly react as physical things;
- **precise** — animation and visual feedback feel tightly coupled to input;
- **deep but calm** — substantial capability without visual noise;
- **professional** — suitable beside Logic, Ableton, Bitwig, or a live set;
- **playful in behaviour, not toy-like in presentation**.

Avoid the visual clichés of both extremes:

- not a grey enterprise utility;
- not a neon RGB “gamer” dashboard.

### One-sentence visual target

**Logic Pro restraint + Apple-native hierarchy + the immediacy of a performance instrument + restrained phosphorescent musical feedback.**

---

## 5. macOS Design Language

### 5.1 Native first

Prefer native macOS patterns whenever they solve the problem well:

- system typography;
- SF Symbols;
- toolbars;
- menus and contextual menus;
- inspectors;
- popovers;
- keyboard shortcuts;
- drag and drop;
- system focus and accessibility behaviour;
- native window resizing and titlebar conventions.

Do not reproduce system controls manually merely for visual novelty.

### 5.2 Liquid Glass placement

Follow current Apple guidance: Liquid Glass belongs primarily to a **functional control/navigation layer**, visually separated from the content layer.

Appropriate areas:

- navigation/sidebar chrome;
- toolbar controls;
- transient floating controls;
- active popovers;
- compact transport overlays where separation is useful.

Avoid covering core musical surfaces in glass.

The Harmonic Compass, sequencer, chord blocks, controller visualiser, waveform/gesture displays, and mapping surfaces need stable backgrounds so performers can read them at a glance.

### 5.3 Materials

Use material semantically, not as a colour-generation trick.

Suggested hierarchy:

1. **Window / content background** — stable deep neutral-green surface.
2. **Content surface** — slightly raised opaque/semi-opaque panels.
3. **Interactive control layer** — native material / glass where appropriate.
4. **Active musical feedback** — luminous accents, motion, geometry.

### 5.4 Light and dark appearance

Dark mode remains the primary artistic presentation, but the design system must not assume that dark appearance is the only technically valid appearance.

Keep tokens semantic so a future light appearance can be supported without rewriting components.

Do not hard-code `.black` / `.white` where semantic theme tokens should be used.

---

## 6. Colour System

The existing green identity is strong enough to keep, but should become more disciplined.

### 6.1 Primary accent

Use the XPI green as the application identity and positive musical activity accent.

Green should indicate things such as:

- connected / ready;
- active mapping;
- MIDI activity;
- selected tonic / stable state;
- primary focus.

Do not make every active control equally bright green.

### 6.2 Harmonic semantic colours

Retain the current tension spectrum concept:

- **Stable** — green;
- **Natural / subdominant** — green-cyan;
- **Strong / dominant** — amber;
- **Colourful / modal** — violet;
- **Outside / high tension** — warm red.

This is a *secondary encoding*. Every state must also be expressed through at least one of:

- text;
- position;
- shape;
- ring thickness;
- icon;
- motion.

### 6.3 Controller branding

PlayStation / Xbox / Nintendo / specialist-controller colours can appear in controller glyphs and hardware-specific visualisation, but must not recolour the entire application.

The app owns the environment; the connected controller owns its glyph vocabulary.

### 6.4 Recording

Recording red is reserved for recording and destructive / urgent musical state.

Do not reuse recording red for generic “outside harmony” alerts in places where confusion is possible.

---

## 7. Typography

Use system fonts.

Recommended hierarchy:

- **Hero musical state** — 32–40 pt, bold / rounded where expressive; e.g. current chord.
- **Workspace title** — native title/headline scale.
- **Section title** — headline / semibold.
- **Control label** — 11–13 pt.
- **Secondary metadata** — 10–11 pt.
- **Diagnostics** — monospaced only where numeric alignment is useful.

Use monospaced text sparingly for:

- MIDI values;
- coordinates;
- time / bar-beat counters;
- raw diagnostic data.

Do not style musical theory as engineering output. Roman numerals and chord symbols should look musical and deliberate, not like logs.

---

## 8. Spacing & Geometry

Build around a compact 4 pt rhythm.

Suggested spacing tokens:

- 4 — micro relationship;
- 8 — tight controls;
- 12 — component internals;
- 16 — standard card spacing;
- 20 / 24 — workspace grouping;
- 32 — major visual separation.

Maintain existing approximate corner-radius hierarchy:

- small: 6 pt;
- medium: 10 pt;
- large: 16 pt;
- hero / controller cards: up to 20–24 pt where justified.

Avoid excessive nested rounded rectangles. If every object is a card, nothing has hierarchy.

---

## 9. Motion System

Motion must communicate state or causality.

### 9.1 Good motion

- stick cursor physically follows input;
- a short fading trajectory shows the gesture just made;
- chord sector settles into selection;
- a string vibrates immediately after crossing;
- a trigger visibly compresses with physical travel;
- velocity briefly expands a pulse;
- a modifier transforms nearby control labels;
- recording state gains a restrained pulse.

### 9.2 Bad motion

- decorative particles;
- ambient pulsing unrelated to sound;
- bouncing cards;
- large spring animations every time a numerical value changes;
- delayed easing on live-controller position.

### 9.3 Timing

Separate **musical input latency** from **visual smoothing**.

- input and musical scheduling must use the freshest state available;
- controller-position visuals should feel effectively immediate;
- semantic transitions may use short 120–220 ms easing;
- layout transitions can use restrained springs;
- telemetry may be throttled independently from the audio/MIDI path.

### 9.4 Reduced Motion

Respect Reduce Motion.

When enabled:

- replace nonessential spatial transitions with fades;
- remove glow breathing / looping motion;
- reduce trajectory persistence if necessary;
- keep immediate control-position feedback because it conveys essential state.

---

## 10. App Shell & Information Architecture

The five-workspace model remains appropriate.

### Persistent elements

The shell should make these states available without dominating the screen:

- current workspace;
- connected controller;
- key / scale;
- tempo;
- transport;
- record state;
- MIDI destination/activity;
- audio engine state.

### Sidebar

The compact icon sidebar is a good pattern.

Requirements:

- 5 primary destinations only;
- clear selection state;
- text labels remain visible rather than icon-only ambiguity;
- controller connection indicator at the bottom;
- keyboard shortcuts for workspace switching.

Do not put deep settings, documentation, routing, and every secondary tool into the primary sidebar.

### Transport

The transport should remain globally reachable but visually quiet when idle.

Primary order:

**record | stop/play | loop | tempo | metronome | harmonic context (key & scale) | instrument profile | MIDI/audio status**

#### Compact XTheme Context Selectors

To avoid bulky macOS SwiftUI `.menu` pickers breaking the compact visual layout:
- **Unified Control Language:** `InstrumentSelectorView`, `KeySelectorView`, and `ScaleSelectorView` share a consistent compact presentation (`XTheme.surfaceCard` background, subtle rounded border, single primary text value, concise chevron indicator).
- **No Duplicated Information:** The selected instrument, key, or scale is rendered once within the control. Status labels (e.g. green technique hints) convey real-time expressive state rather than repeating static selection text.
- **Fixed Height Budget:** Context controls adhere to a standard ~28px height, ensuring the transport footer and chord display remain slim without clipping at narrow macOS window widths.
- **Full Accessibility:** Preserve keyboard navigation, VoiceOver accessibility traits/labels, and state mutation through `AppState`.

Where screen width is constrained, low-priority routing/status can collapse into an inspector/popover.

---

## 11. PLAY Workspace

PLAY is the heart of XPI.

It must answer three questions instantly:

1. **What am I playing?**
2. **What will my hands do?**
3. **What did my gesture just cause?**

### 11.1 Layout priority

The current split — harmony on one side, physical controller / articulation on the other — is fundamentally sound.

Prefer roughly:

- 55–60% musical space;
- 40–45% performance/controller space.

Do not let numeric telemetry steal space from the instrument.

### 11.2 Current chord

The current chord is a hero state.

Show:

- chord symbol;
- Roman numeral;
- compact harmonic-character badge;
- optional note spelling;
- current key and scale.

The chord should update immediately with a restrained content transition.

### 11.3 Harmonic Compass

The Harmonic Compass is not a pie chart.

It should feel spatial and physical.

Required visual layers:

1. **centre/rest zone**;
2. **harmonic sectors**;
3. **risk/intensity radius**;
4. **current processed stick location**;
5. **selected sector**;
6. **optional suggested next sectors**;
7. **brief trajectory** when helpful.

Selection behaviour should visually reflect angular hysteresis. Near a sector boundary, the UI should not flicker if the musical interpretation remains locked.

### 11.4 Harmonic risk

Radius should be communicated as a physical expansion from stable to adventurous harmony.

Prefer:

- widening / brighter outer rings;
- increasing tension labels;
- subtle sector complexity.

Avoid a permanent numerical “risk 0.73” display in PLAY.

### 11.5 Controller Performance HUD

Replace the feeling of separate mini meters with one coherent controller-shaped performance object.

The player should see the same hand geography they feel.

Display only controls relevant to the active instrument/layer at full emphasis; fade secondary controls.

#### Left stick

Show:

- centre/deadzone;
- processed position;
- selected harmonic sector relationship;
- optional short trajectory;
- role label.

#### Right stick

For strumming, emphasise:

- vertical sweep;
- trajectory;
- virtual strings crossed;
- current strum direction;
- attack velocity.

Raw X/Y numerics belong in MAP/diagnostics.

#### Triggers

Do not use generic `ProgressView` bars as the primary representation.

Render trigger-like controls whose physical travel changes on screen.

For L2 palm mute:

- trigger compresses with pressure;
- virtual strings become shorter/darker/damped;
- attack strength may briefly pulse around the trigger.

For R2 expression:

- trigger compresses;
- associated timbre/expression state visibly opens or intensifies.

#### Shoulders

Shoulders are mode/modifier controls.

When held, show the resulting layer change immediately in surrounding labels.

Example:

`L1: Colour`

When pressed, nearby chord/action labels transition to colour/extension functions.

### 11.6 Strum display

Strumming should be visualised as **cause and effect**, not merely a velocity meter.

A good strum response combines:

- right-stick trajectory;
- sequential string activation;
- short attack pulse;
- direction arrow;
- optional transient `Vel 94` label for advanced users.

### 11.7 Performance mode

Add or preserve the ability to minimise nonessential chrome.

A performer should be able to make PLAY visually stage-safe:

- large chord;
- Harmonic Compass;
- controller HUD;
- minimal transport;
- no configuration clutter.


### 11.8 Instrument-Aware Bend Feedback

A bend is a playing technique, not a generic slider or exposed MIDI value.

The active `InstrumentProfile` owns both the gesture meaning and its adjacent HUD label. Guitar may present `Strum / Bend`, while Synth Lead presents `Bend / Timbre` and Keys must not inherit a guitar bend metaphor. Changing profiles updates those semantics without rebuilding PLAY.

Canonical PLAY behaviour:

- only interpret lateral right-stick movement as bend while a note is sustained and the active instrument profile supports bending;
- preserve continuous pitch movement while applying only soft attraction toward context-ranked chord, scale, or chromatic targets;
- deform the active note or string toward the target and reveal a compact target label only while the bend is active;
- make target proximity visible through firmness, opacity, or geometry rather than colour alone;
- emit at most one subtle haptic detent when an exact target is crossed, then re-arm only after leaving that target zone;
- suppress conflicting strum feedback while the lateral bend gesture owns the right stick;
- require MPE or an otherwise isolated voice for independent pitch; a shared-channel conventional MIDI chord must be blocked and explained in MAP;
- return the visual state cleanly to neutral as pitch returns to centre, including under Reduce Motion.

PLAY must describe the musical result, such as `Bend +2 → G`. Raw 14-bit pitch-bend values, member-channel allocation, destination range, and fallback diagnostics belong in MAP.

Instrument selection lives in the PLAY transport as a compact family picker (Guitar, Bass, Keys, Lead, Strings, Generic MPE). Changing the profile updates HUD labels, gesture interpretation, MIDI translation, haptics, and theory assistance without rebuilding the workspace.

**Implemented slice:** the Guitar profile, sustained-note lateral bend interpretation, contextual target/proximity state, restrained label state, and return-to-centre contract exist in the semantic performance path. Physical-controller feel, haptic delivery, and destination-specific DAW behaviour still require manual proof.

---

## 12. HARMONY Workspace

HARMONY should feel like a theory-aware composition surface, not a spreadsheet of chords.

### Main regions

- progression / chord blocks;
- context inspector;
- harmonic suggestion area;
- optional keyboard/fretboard/pitch-class visualisation.

### Chord blocks

A chord block should prioritise:

1. chord symbol;
2. Roman numeral;
3. duration;
4. inversion / voicing only when altered or inspected;
5. harmonic character through secondary colour/marking.

Allow:

- drag/reorder;
- resize duration;
- duplicate;
- audition;
- replace;
- context menu.

### “What Next?”

Suggestions should be categorised by musical intention rather than algorithmic score:

- Familiar;
- Smooth;
- Strong Resolution;
- Brighter;
- Darker;
- Colourful;
- Cinematic;
- Outside.

On hover/inspection, explain *why*:

- shared tones;
- dominant relationship;
- borrowed chord;
- chromatic mediant;
- low voice-leading movement.

Theory explanation is optional guidance, not judgement.

---

## 13. SEQUENCE Workspace

SEQUENCE is a sketching environment, not a full DAW.

Keep the arrangement vocabulary intentionally limited:

- Chords;
- Melody;
- Bass;
- Drums;
- Gesture / Motion;
- Automation where required.

### Visual hierarchy

- horizontal time is dominant;
- scene/section boundaries are strong;
- clips are quiet until selected;
- active recording is unmistakable;
- theory colours remain secondary.

### Gesture clips

Gesture Clips deserve a distinct visual identity from MIDI clips.

Represent them as:

- trajectory / envelope-like forms;
- clear source label (`R Stick`, `Gyro`, `L2`, etc.);
- loop / reverse / scale state.

Do not pretend controller-motion data is conventional note data.

---

## 14. MAP Workspace

MAP is the technical depth layer.

PLAY should feel effortless because MAP absorbs complexity.

### 14.1 Core structure

Use a split layout:

**left: controller and live processed input**

**right: mappings / inspector / response configuration**

### 14.2 Raw → processed → musical

Advanced users should be able to inspect the entire causal pipeline.

For a selected control show:

**Raw**
- hardware value;

**Processed**
- calibration;
- deadzone;
- curve;
- smoothing;
- hysteresis;

**Gesture**
- velocity;
- acceleration;
- direction;

**Musical**
- destination;
- mapped value;
- behaviour / articulation.

Example:

`Left Stick → Hybrid Deadzone → Precision Curve → Harmonic Compass → Fm7 (iv)`

### 14.3 Response-curve editor

Show the curve graphically.

Factory presets:

- Expressive;
- Precision;
- Fast;
- Stable;
- Accessible / Reduced Travel.

Controls:

- inner deadzone;
- outer threshold;
- response curve;
- smoothing;
- axis assistance;
- directional/harmonic magnetism.

Every adjustment should update the live processed cursor immediately.

### 14.4 Raw vs processed cursor

When “Show Input Processing” is enabled:

- raw hardware cursor = subtle / outlined;
- processed musical cursor = prominent / filled;
- deadzone and outer threshold visible;
- short path illustrates transformation when useful.

### 14.5 Mapping rows

Avoid static rows that only say `source → destination → 100%`.

Each mapping row should become an inspectable object with:

- controller glyph;
- source/gesture;
- musical destination;
- response summary;
- enable state;
- disclosure to advanced settings.

### 14.6 Ergonomic conflict warnings

MAP should warn — not block — when mappings are physically questionable.

Examples:

- L3 action requires accurate left-stick positioning at the same time;
- one finger is required to hold two controls;
- two exclusive actions share a gesture;
- a high-frequency performance action is placed on a hard-to-reach menu button.

Warnings should explain the hand/finger conflict in plain language.

---

## 15. LIBRARY Workspace

LIBRARY should organise reusable musical behaviour, not just files.

Primary object types:

- Instrument Preset;
- Controller Profile;
- Harmony Preset;
- Performance Preset;
- Song Sketch / Scene Set;
- Gesture Clip where appropriate.

Cards should communicate the meaningful difference between presets.

Do not rely on cover-art-style decorative thumbnails when a compact semantic preview is more useful.

Useful previews include:

- controller family;
- scale/harmony mode;
- key mapping summary;
- gesture diagram;
- sound/preset name;
- last modified.

---

## 16. Controller Visualisation Language

### 16.1 Visualise a control as its physical type

- stick → circular XY field;
- trigger → travel/compression control;
- shoulder → short held button;
- face button → spatial button cluster;
- touchpad → 2D surface;
- gyro → orientation / motion cue;
- wheel → rotating ring;
- pedal → travel meter shaped like a pedal;
- fret controller → fretboard;
- turntable → rotating platter.

Avoid reducing every controller type to a horizontal progress bar.

### 16.2 Controller-specific glyphs

Use the existing controller icon-pack architecture.

When hardware identity is known, display that controller’s native labels/symbols.

Do not show PlayStation `△ ○ ✕ □` glyphs for Xbox hardware.

### 16.3 Press / travel states

Every interactive controller element needs an obvious live state.

Use combinations of:

- displacement;
- fill;
- outline weight;
- scale;
- brief glow;
- role label;
- haptic/audio reinforcement.

Apple guidance for controls reinforces the importance of visible/tactile interaction states; XPI should extend that principle to its performance HUD.

---

## 17. Velocity & Dynamics Visual Language

Velocity is transient. Its UI should be transient too.

Do not permanently fill the interface with velocity numbers.

### Soft

- small pulse;
- short/low-intensity glow;
- narrow string displacement.

### Medium

- medium pulse;
- stronger string displacement.

### Hard

- larger, faster-decaying pulse;
- stronger physical visual response.

An optional transient numeric value (`94`) may appear for advanced feedback, then fade.

The same visual language should apply across:

- strums;
- trigger attacks;
- drum hits;
- face-button velocity emulation;
- niche-controller strikes.

---

## 18. Haptic Design Language

Build a small, learnable vocabulary.

### Micro tick

Use for:

- crossing a Harmonic Compass sector;
- entering a rhythmic division;
- small detent-like selection.

### Soft confirmation

Use for:

- latching a chord;
- changing inversion;
- committing a mapping.

### Strong confirmation

Use for:

- recording start;
- scene launch where tactile certainty matters.

### Double pulse

Use for:

- recording stop;
- loop capture completion.

### Warning

Use sparingly for:

- controller disconnect during performance;
- MIDI panic / unrecoverable routing state.

### Rules

- one musical event → at most one semantic haptic event;
- no repeated haptic while remaining inside the same harmonic sector;
- haptics are optional;
- expose global strength;
- never make critical information haptic-only.

---

## 19. First-Run Experience

The first launch must demonstrate the instrument before teaching the application.

Preferred flow:

1. XPI opens into PLAY.
2. “Connect a controller” appears only if none is present.
3. Controller is automatically recognised.
4. A comfortable default sound and scale load.
5. Left-stick movement visibly selects chords.
6. Right-stick movement visibly crosses strings and produces sound.
7. One concise contextual hint introduces L2/R2 expression.
8. User is playing before seeing a settings form.

Teach through action.

Do not begin with:

- account creation;
- long controller calibration;
- MIDI-routing setup;
- a feature tour carousel.

Calibration should be offered later or only when input quality suggests it is useful.

---

## 20. Empty, Loading & Error States

### No controller

Keep the app useful.

Show:

- controller connection guidance;
- keyboard/mouse audition fallback;
- Bluetooth/USB hint;
- supported-controller examples.

Do not block navigation to Harmony/Sequence/Library.

### Controller disconnected mid-performance

- stop/latch musical state safely;
- immediately surface a small but unmistakable warning;
- send stuck-note prevention / panic where appropriate;
- preserve session state;
- automatically recover when controller reconnects.

### Unsupported capability

Do not show dead controls.

If a Switch Pro lacks analog triggers, for example, either:

- hide trigger-travel UI;
- show the assigned fallback gesture;
- explain the adaptation in MAP.

---

## 21. Accessibility & Personalisation

### Never rely on colour alone

Harmonic state, connection, recording, and selection must always have another signal.

### Keyboard and pointer access

A controller-centric instrument still needs complete macOS navigation.

Provide:

- keyboard shortcuts;
- focusable controls;
- menu commands;
- pointer audition for relevant musical elements.

### VoiceOver

Controller visual elements need meaningful descriptions.

Examples:

- “Left trigger, palm mute, 63 percent.”
- “Left stick, harmonic compass, G minor, degree four.”
- “Right stick strum, last attack velocity 92.”

Do not read constantly changing raw telemetry unless the user focuses the control.

### Mobility / control personalisation

Offer:

- per-stick inner deadzone;
- reduced physical travel;
- outer threshold;
- independent X/Y sensitivity;
- one-axis assistance;
- tremor/noise filtering;
- motion disable;
- alternate control bindings;
- latch modes.

### Reduced motion

See Motion System above.

---

## 22. Window & Responsive Behaviour

XPI is a desktop instrument, but users will run it beside a DAW.

Design for at least three useful widths:

### Full

All major PLAY regions visible.

### Split-screen / DAW companion

- collapse sidebar to compact form if necessary;
- keep chord, compass, controller status, and transport usable;
- move secondary theory metadata into inspector/popover.

### Compact utility

Allow a compact performance view containing:

- chord;
- key/scale;
- small compass;
- controller / MIDI status;
- transport.

Do not simply shrink every component until text becomes unreadable.

---

## 23. Design Tokens to Add/Evolve

`XTheme` should grow toward semantic tokens rather than per-view constants.

Suggested categories:

### Colour

- `background`
- `surface`
- `surfaceElevated`
- `controlMaterial`
- `border`
- `borderActive`
- `textPrimary`
- `textSecondary`
- `textTertiary`
- `musicalPrimary`
- `recording`
- semantic harmonic colours

### Spacing

- `spaceXS = 4`
- `spaceS = 8`
- `spaceM = 12`
- `spaceL = 16`
- `spaceXL = 24`
- `spaceXXL = 32`

### Geometry

- `radiusSmall`
- `radiusMedium`
- `radiusLarge`
- `strokeSubtle`
- `strokeActive`

### Motion

- `feedbackFast`
- `transitionShort`
- `springStandard`
- reduced-motion alternatives

### Performance

Keep live position/trajectory update timing outside decorative animation tokens.

---

## 24. Component Architecture

Prefer small reusable semantic components rather than giant workspace files.

Priority components include:

- `ControllerPerformanceHUD`
- `AnalogStickHUD`
- `AnalogTriggerHUD`
- `VelocityPulse`
- `TrajectoryTrail`
- `HarmonicCompassView`
- `RhythmCompassView`
- `ControllerGlyphView`
- `MappingRow`
- `InputCurvePreview`
- `DeadzonePreview`
- `HapticEventIndicator`
- `ChordBlock`
- `TheoryReasonBadge`
- `PerformanceTransport`

Components should receive **processed semantic state** where possible.

Do not make view code independently reinterpret raw hardware data.

---

## 25. UI State Architecture

Keep a clean distinction between:

### Hardware state

Raw controller values.

### Processed input state

Calibrated/deadzoned/curved/smoothed values and gesture derivatives.

### Musical state

Chord, notes, articulation, MPE pressure, rhythmic subdivision, scene.

### Display state

Transient velocity pulse, trajectory trail, hover/selection, animation phase.

This prevents UI animation concerns from leaking into musical processing.

---

## 26. Performance Requirements for UI

The visual instrument must never compromise the musical instrument.

Rules:

- no large allocation-heavy arrays created on every controller callback;
- trajectory history uses bounded ring buffers;
- raw high-frequency controller events should not invalidate the whole SwiftUI tree;
- publish or derive compact display state at an appropriate rendering cadence;
- audio/MIDI scheduling never waits for SwiftUI animation;
- avoid gratuitous blur/shadow layers on rapidly updating objects;
- Canvas/Metal/custom drawing may be preferable for dense live visualisation.

A beautiful 30 Hz controller cursor with added audio latency is a design failure.

---

## 27. Design Review Checklist

Before merging a new interaction, ask:

### Musical causality

- Can the player tell what their gesture caused?
- Is the visual response describing musical meaning or only raw data?

### Ergonomics

- Which finger performs the action?
- Can that finger simultaneously perform the other required action?
- Does the mapping leverage or fight familiar gamepad technique?

### Learnability

- Is the behaviour discoverable through use?
- Does the player need to memorise an invisible mode?
- When a modifier changes controls, does the UI reveal the new meanings?

### Performance

- Can the player use it without staring at tiny labels?
- Is the critical state readable in peripheral vision?

### Accessibility

- Is colour the only differentiator?
- Is motion essential to understanding?
- Is an alternative input possible?

### Native macOS quality

- Is a custom control genuinely better than a system control here?
- Is glass/material used at the correct hierarchy level?
- Does the UI still make sense when the window is resized?

### Technical quality

- Is display state separated from musical state?
- Does the component avoid unnecessary high-frequency SwiftUI invalidation?

---

## 28. Anti-Patterns

Do not introduce the following without a compelling reason:

- generic `ProgressView` for every analog value;
- permanent raw X/Y/CC numbers in PLAY;
- neon outlines on every active component;
- whole-window Liquid Glass;
- decorative visualisers with no musical meaning;
- a card around every section;
- controller-brand symbols that do not match connected hardware;
- invisible modifier layers;
- colour-only harmonic meaning;
- mouse-first interactions for core performance gestures;
- long modal setup flows before first sound;
- different spacing/radius/font systems per workspace;
- new theme frameworks parallel to `XTheme`.

---

## 29. Near-Term Design Priorities

### P0 — Consolidate the visual system

- make `XTheme` semantic and reusable;
- converge duplicate UI idioms;
- establish canonical spacing, typography, surface, and motion tokens.

### P0 — Performance HUD

- controller-shaped standard-gamepad HUD;
- richer stick visualisation;
- trigger travel;
- dynamic velocity feedback;
- virtual-string cause/effect;
- hardware-specific labels.

### P0 — Input processing visualisation in MAP

- raw vs processed values;
- deadzone / response curve preview;
- profile presets;
- calibration feedback.

### P1 — Harmonic Compass refinement

- hysteresis-aware visual selection;
- risk-radius treatment;
- subtle suggestions;
- haptic sector detents.

### P1 — Workspace completion

Apply the same design language to Harmony, Sequence, Map, and Library as their implementations mature.

### P2 — Compact DAW companion mode

Design a reduced window layout after the main PLAY experience is stable.

---

## 30. Acceptance Criteria for the Design System

The design direction is working when:

1. A first-time user can connect a controller and make a musically intentional sound without opening settings.
2. A player can infer the relationship between left stick, right stick, triggers, and sound from PLAY alone.
3. The same gesture feels visually, sonically, and haptically coherent.
4. Controller movement remains readable without showing raw telemetry.
5. MAP can explain the exact processing pipeline when deeper inspection is needed.
6. A player can use the app beside a DAW without surrendering most of the screen.
7. PlayStation, Xbox, Switch, and specialist controller representations adapt without changing the core app identity.
8. Reduced Motion and non-colour cues preserve all important information.
9. The UI remains smooth without increasing audio/MIDI latency.
10. New features can be reviewed against a shared design vocabulary instead of inventing local rules.

---

## 31. Research Basis & References

This document synthesises the current XPI implementation with the following design and research sources.

### Apple platform guidance

- Apple Human Interface Guidelines — Materials / Liquid Glass: https://developer.apple.com/design/human-interface-guidelines/materials
- Apple Human Interface Guidelines — Game Controls: https://developer.apple.com/design/human-interface-guidelines/game-controls
- Apple Human Interface Guidelines — Designing for Games: https://developer.apple.com/design/human-interface-guidelines/designing-for-games/
- Apple Human Interface Guidelines — Motion: https://developer.apple.com/design/human-interface-guidelines/motion
- Apple Human Interface Guidelines — Playing Haptics: https://developer.apple.com/design/human-interface-guidelines/playing-haptics
- Apple Human Interface Guidelines — Accessibility: https://developer.apple.com/design/human-interface-guidelines/accessibility/

### Musical-interface research

- Christopher Ariza, **The Dual-Analog Gamepad as a Practical Platform for Live Electronics Instrument and Interface Design**, NIME 2012. https://www.nime.org/proceedings/2012/nime2012_73.pdf
- Marcelo M. Wanderley & Philippe Depalle, **Gestural Control of Sound Synthesis**, Proceedings of the IEEE, 2004. DOI: 10.1109/JPROC.2004.825882
- Frederic Anthony Robinson et al., **Gestural control in electronic music performance: sound design based on the ‘striking’ and ‘bowing’ movement metaphors**, Audio Mostly 2015. DOI: 10.1145/2814895.2814901
- **Making Mappings: Design Criteria for Live Performance**, NIME. https://nime.pubpub.org/pub/f1ueovwv/download/pdf
- Andrew P. McPherson, Landon Morrison, Matthew Davison & Marcelo M. Wanderley, **On mapping as a technoscientific practice in digital musical instruments**, Journal of New Music Research 53 (2024), 110–125. https://consensus.app/papers/on-mapping-as-a-technoscientific-practice-in-digital-mcpherson-morrison/fcf4ab73b82554cd890bb4b2ca042b36/
- Emma Frid, **Accessible Digital Musical Instruments — A Review of Musical Interfaces in Inclusive Music Practice**, Multimodal Technologies and Interaction 3 (2019), 57. https://consensus.app/papers/accessible-digital-musical-instruments-a-review-of-frid/7955d0a32d0b5f9f91ab3483c5161449/
- Gareth W. Young, David Murphy & Jeffrey Weeter, **A Functional Analysis of Haptic Feedback in Digital Musical Instrument Interactions**, 2018. https://consensus.app/papers/a-functional-analysis-of-haptic-feedback-in-digital-young-murphy/a44dce433b645245a1d4effddd893e89/
- Stefano Papetti, Hanna Järveläinen & Federico Fontana, **Design and Assessment of Digital Musical Devices Yielding Vibrotactile Feedback**, Arts, 2023.

### Existing XPI documents that remain complementary

- `SOUL.md` — artistic identity and philosophy;
- `PRODUCT_RESEARCH.md` — competitive and product research;
- `TECH_STACK.md` — architectural/performance constraints;
- `ROADMAP.md` — delivery sequencing;
- `INSTRUMENT_TECHNIQUES.md` — semantic technique and instrument-profile contract;
- `MIDI_MPE_SPEC.md` — MIDI/MPE wire, lifecycle, and fallback contract;
- `DESIGN.md` — **authoritative visual, interaction, ergonomic, and feedback rules**.

---

---

## 33. Semantic Control Scheme Architecture & Ergonomics

XPI decouples physical controller input from instrument profiles through an intermediate **Semantic Musical Action** layer:

```text
Physical Controller Input (GameController / GCExtendedGamepad)
            ↓
Controller Hardware Calibration (Rest Center, Drift Radius, Max Reach Radius)
            ↓
Input Processing Pipeline (Deadzones with Hysteresis, Curves: Precise/Balanced/Responsive, Smoothing)
            ↓
Control Scheme (XPI Performance, XPI Classic, Low-Fatigue, One-Hand Left, One-Hand Right, Custom)
            ↓
Semantic Musical Actions (primaryExcitation, pitchExpression, pressureExpression, harmonyNavigate2D...)
            ↓
Instrument Profile (Guitar, Synth Lead, Bass, Strings, Keys, Drums)
            ↓
Performance Event → MIDI/MPE & Audio Synthesizer
```

### 33.1 Built-in Schemes
1. **XPI Performance (Recommended Default)**: Balanced two-hand layout. Left thumb navigates the Harmonic Wheel; Right thumb performs Pitch Expression ($X$) and Strum Excitation ($Y$); Triggers govern Palm Mute Damping (L2) and Pressure Swell (R2); Bumpers govern Legato Technique (L1) and Ringing Sustain Latch (R1); Face buttons articulate direct chord voices or solo notes.
2. **XPI Classic (Compatibility)**: Exact legacy XPadInput mapping layout.
3. **Low-Fatigue Ergonomics**: Eliminates stick clicks, replaces long holds with toggles, and uses light trigger thresholds for low-strain playing.
4. **One-Hand (Left)**: Full single-handed performance on the left side with 6-axis gyro tilt pitch expression.
5. **One-Hand (Right)**: Full single-handed performance on the right side with right-stick expression and face button chord triggers.
6. **Custom Schemes**: User-editable copies with full remapping, axis inversion, and conflict detection.

### 33.2 Single Source of Truth for Control Prompts
All UI tooltips, HUD badges, and onboarding cues query `controllerManager.controlLabel(for: .action)` to dynamically reflect active rebindings and controller hardware glyphs (DualSense $\to$ L2/R2, Xbox $\to$ LT/RT, Switch $\to$ ZL/ZR).

---

## 34. Final Design Principle

> **Do not show the user that a controller value changed. Show them that the instrument responded to their gesture.**

A successful XPI interface should become progressively less necessary to stare at as the player gains skill.

The screen teaches the instrument, confirms the instrument, and reveals its deeper state — but the player’s hands should ultimately be able to make music without asking the screen what to do next.

