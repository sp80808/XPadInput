---
name: gamepad-mpe-mapping
description: Guidelines and patterns for mapping GameController hardware inputs, polar coordinates, MPE expression, and haptic feedback.
---

# Gamepad & MPE Mapping Skill

## 1. Controller Normalization Rules
- **Circular Clamp**: Always calculate radial magnitude $r = \sqrt{x^2 + y^2}$. Apply deadzone correction:
  $$r_{\text{normalized}} = \max\left(0, \frac{r - \text{deadzone}}{1.0 - \text{deadzone}}\right)$$
- **Angle Alignment**: GameController $Y$-axis points up ($+1.0$ at top). Standard polar math has angle 0 at East $(1, 0)$ and $+\pi/2$ at North $(0, 1)$.

## 2. MPE Channel Dispatching
- Master Channel is Channel 1 (`0x00` in 0-indexed byte representation).
- Member Channels are Channels 2–15 (`0x01` through `0x0E`).
- When sending pitch bend, normalize semitone range to $[-1.0, 1.0]$ mapped to 14-bit unsigned integer $[0, 16383]$ centered at $8192$.
- When allocating an MPE voice, always reset pitch bend to center (0.0 semitones) on that member channel *before* transmitting the `NoteOn` byte.

## 3. Testing with Simulated Controls
- Use `ControllerManager.injectSimulatedState { state in ... }` in unit tests or UI keyboard previews when no physical controller is attached.
