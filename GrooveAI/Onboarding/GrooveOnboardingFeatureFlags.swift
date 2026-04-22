import Foundation

enum GrooveOnboardingFeatureFlags {
    // Premium loader + transition can be reverted by flipping this to false.
    static let usePremiumMagicResultFlow = true

    // ──────────── Onboarding Flow Switch ────────────────
    enum OnboardingFlow {
        case current // Original GrooveOnboardingView
        case v2 // New redesigned GrooveOnboardingViewV2
    }

    // Toggle between current and v2 onboarding flows
    // Keep `.current` as the runtime-safe default while V2 is preview-only.
    static let activeOnboardingFlow: OnboardingFlow = .current
}