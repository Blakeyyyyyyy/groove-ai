## GrooveAI Onboarding Handoff

This branch is for rebuilding the **live onboarding flow** only.

### Live onboarding entry path

- `GrooveAI/GrooveAI/App/ContentView.swift`
- `GrooveAI/GrooveAI/Onboarding/GrooveOnboardingView.swift`

The app runtime currently uses:

`ContentView -> GrooveOnboardingView -> GrooveAI/GrooveAI/Onboarding/Views/*.swift`

### Files in scope

Core onboarding:

- `GrooveAI/GrooveAI/Onboarding/GrooveOnboardingView.swift`
- `GrooveAI/GrooveAI/Onboarding/GrooveOnboardingFeatureFlags.swift`
- `GrooveAI/GrooveAI/Onboarding/GrooveOnboardingState.swift`
- `GrooveAI/GrooveAI/Onboarding/GrooveOnboardingTheme.swift`
- `GrooveAI/GrooveAI/Onboarding/GrooveDancePreset.swift`

Current live onboarding screens:

- `GrooveAI/GrooveAI/Onboarding/Views/GrooveHeroScrollView.swift`
- `GrooveAI/GrooveAI/Onboarding/Views/GrooveSubjectSelectView.swift`
- `GrooveAI/GrooveAI/Onboarding/Views/GrooveDanceSelectView.swift`
- `GrooveAI/GrooveAI/Onboarding/Views/GrooveMagicMomentView.swift`
- `GrooveAI/GrooveAI/Onboarding/Views/GroovePremiumMagicResultFlowView.swift`
- `GrooveAI/GrooveAI/Onboarding/Views/GrooveResultCTAView.swift`
- `GrooveAI/GrooveAI/Onboarding/Views/TrialEnabledScreen.swift`
- `GrooveAI/GrooveAI/Onboarding/Views/GroovePaywallScreen.swift`

Likely shared dependencies used by onboarding:

- `GrooveAI/GrooveAI/Views/Components/LoopingVideoView.swift`
- `GrooveAI/GrooveAI/Views/Components/RemoteVideoThumbnail.swift`
- `GrooveAI/GrooveAI/Views/Components/GradientCTAButton.swift`
- `GrooveAI/GrooveAI/Views/Components/OnboardingCard.swift`
- `GrooveAI/GrooveAI/Views/Components/PageIndicatorDots.swift`
- `GrooveAI/GrooveAI/Design/DesignTokens.swift`
- `GrooveAI/GrooveAI/Models/AppState.swift`

### Explicitly out of scope

Do **not** use these as the active onboarding flow:

- `GrooveAI/GrooveAI/Views/Onboarding/*`  
  This is the older unused onboarding path.

- `GrooveAI/GrooveAI/Onboarding/Views-v2/*`
- `GrooveAI/GrooveAI/Onboarding/GrooveOnboardingViewV2.swift`
- `GrooveAI/GrooveAI/Onboarding/OnboardingV2PreviewGallery.swift`

The V2 files are experimental recovery artifacts, not the production onboarding path.

### Constraints

- Keep the current runtime onboarding path intact unless explicitly switching after approval.
- Prefer rebuilding the existing live screens in place.
- Preserve current onboarding state flow and completion behavior unless there is a deliberate design change.
- Avoid touching unrelated paywall/home/settings code unless a live onboarding screen directly depends on it.

### Working approach

1. Rebuild the live onboarding screens under `GrooveAI/GrooveAI/Onboarding/Views/`.
2. Keep `ContentView.swift` pointed at `GrooveOnboardingView`.
3. Use previews for iteration where possible.
4. Build before handoff.

### Validation

- Build the app.
- Verify `ContentView` still launches the current onboarding path.
- Keep changes scoped to the files above.
