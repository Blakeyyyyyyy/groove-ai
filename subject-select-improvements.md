# Subject Select Screen — Conversion Improvements

## Conversion Analysis

- **No interactivity signal:** Cards looked like decorative images. No labels, no affordance cues, no iOS tappability signals. Users could scan and leave without realizing they needed to act.
- **Instructional subtitle killed curiosity:** "Choose your subject" is a command, not a hook. It does nothing to create anticipation about what tapping will actually do. Copy should sell the next moment.
- **No fallback = permanent drop-off:** With zero way forward if users don't tap, any hesitation becomes a lost conversion. The screen must aggressively signal the action within 2 seconds of attention.
- **Equal-weight cards stall decisions:** Both cards competed visually with no focal anchor. No hierarchy means the eye wanders and the tap decision takes longer.
- **Missing iOS tappability conventions:** Scale on tap, label overlays, and pulsing borders are trained signals in iOS apps. Their absence means users don't read the cards as interactive.
- **No curiosity gap:** Users never understand that their tap will generate an AI video of this subject dancing. Telegraphing the payoff drives urgency and faster choices.

## Copy Decisions

- **Subtitle:** `Tap the one that moves you` — active, slightly emotional, implicitly communicates that a tap triggers something
- **Person card label:** `Person`
- **Dog card label:** `Dog`

## Implementation Summary

All changes in `GrooveAI/Onboarding/Views/GrooveSubjectSelectView.swift`.

### 1. Subtitle updated
Changed from `"Choose your subject"` to `"Tap the one that moves you"`.

### 2. Card labels added
Each `SubjectCard` now includes a bottom-anchored overlay: a `LinearGradient` (black 72% opacity → clear, 80pt tall) with a `Text` label in white, semibold, 15pt, 14pt from the bottom. The gradient is applied before `clipShape` so it respects the rounded corners.

### 3. Tap hint
A new `TapHintView` struct renders a 👆 emoji + "Tap a card to begin" in muted white text. It:
- Is hidden by default (opacity 0)
- Fades in after a 1.5s `DispatchQueue` delay via `showTapHint` state
- Pulses between 0.4–1.0 opacity on a 0.9s easeInOut loop using a `@State var pulseOpacity`
- Disappears instantly when any card is tapped via `@State var tapped = true` (animated 0.35s easeInOut fade)

### 4. Border shimmer pulse
A `@State var borderPulse` drives a recursive `startBorderPulseLoop()` function:
- Fires 1s after `onAppear`
- Animates `borderPulse = true` (border opacity 0.08 → 0.55, lineWidth 1 → 1.5) over 0.3s
- Returns to `false` after another 0.3s
- Loops every 3 seconds, gated by `guard !tapped else { return }` so it stops cleanly on selection

### State added to GrooveSubjectSelectView
| Variable | Purpose |
|---|---|
| `tapped` | Hides hint and stops border loop on tap |
| `showTapHint` | Controls delayed appearance of hint |
| `borderPulse` | Drives the shimmer animation on both cards |
