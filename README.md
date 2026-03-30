# Groove AI — Onboarding Flow

Swift/SwiftUI onboarding screens for the Groove AI app.
Designed to match the Glow AI onboarding system exactly (same theme, layout constants, CTA style, typewriter mechanic).

## File Map

```
GrooveAI/Onboarding/
├── GrooveOnboardingView.swift       ← ROOT: page coordinator + progress dots
├── GrooveOnboardingTheme.swift      ← Design tokens (colours, sizes, constants)
├── GrooveOnboardingState.swift      ← Shared ObservableObject passed through flow
├── GrooveDancePreset.swift          ← Preset dance styles (pill titles + prompt text)
└── Views/
    ├── GrooveHeroScrollView.swift   ← Page 1: dual auto-scroll card rows + CTA
    ├── GrooveSubjectSelectView.swift ← Page 2: Dog / Person tap-to-select cards
    ├── GrooveDanceSelectView.swift  ← Page 3: Hero preview + dance pills + typewriter + generation
    └── GrooveResultView.swift       ← Page 4: "Video ready" + Share / Create Another
```

## Integration Steps

1. **Add all files** from `GrooveAI/Onboarding/` into your Xcode project (drag into navigator, tick "Add to target").

2. **Remove the `Color(hex:)` extension** in `GrooveOnboardingTheme.swift` if your project already has one.

3. **Wire up the entry point.** Wherever your app currently shows onboarding (e.g. `ContentView`, `RootShellView`, or `@main`), replace it with:
   ```swift
   GrooveOnboardingView(onComplete: {
       // mark onboarding done, navigate to main app
   })
   ```

4. **Swap emoji placeholders** for real images/videos once assets exist:
   - In `GrooveSubjectSelectView`: replace `Text(emoji)` with `Image("subject_dog")` / `Image("subject_person")`
   - In `GrooveDanceSelectView`: set `heroAssetName` to a real asset name after generation
   - In `GrooveResultView`: swap the emoji ZStack for an `AVPlayer` or thumbnail image

## Design Tokens (same as Glow AI)

| Token | Value |
|---|---|
| Background | `#0B0B0F` |
| Accent (blue) | `#1E90FF` |
| CTA height | `64pt` |
| CTA horizontal padding | `24pt` |
| CTA bottom padding | `50pt` |
| Hero image size | `310 × 440pt` |
| Hero corner radius | `24pt` |
| Hero top padding | `80pt` |
