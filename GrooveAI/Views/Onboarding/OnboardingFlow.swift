import SwiftUI

struct OnboardingFlow: View {
    @Environment(AppState.self) private var appState
    @State private var currentPage = 0

    var body: some View {
        TabView(selection: $currentPage) {
            OnboardingPage1(
                onContinue: { withAnimation(.easeInOut(duration: 0.35)) { currentPage = 1 } },
                onSkip: { navigateToPaywall() }
            )
            .tag(0)

            OnboardingPage2(
                onContinue: { withAnimation(.easeInOut(duration: 0.35)) { currentPage = 2 } },
                onSkip: { navigateToPaywall() }
            )
            .tag(1)

            OnboardingPage3(
                onContinue: { navigateToPaywall() },
                onSkip: { navigateToPaywall() }
            )
            .tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background(Color.bgPrimary)
        .ignoresSafeArea()
    }

    private func navigateToPaywall() {
        appState.showPaywall = true
    }
}

#Preview {
    OnboardingFlow()
        .environment(AppState())
}
