import SwiftUI

// Preview-only shim while the full V2 flow is being recovered.
// Keep the current onboarding as the app runtime path.
struct GrooveOnboardingViewV2: View {
    let onComplete: () -> Void

    var body: some View {
        GrooveHeroScrollViewV2(onNext: onComplete)
    }
}
