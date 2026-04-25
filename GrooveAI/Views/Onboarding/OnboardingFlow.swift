import SwiftUI
import AVKit

// MARK: - Onboarding Flow (Build #4 — Hybrid A+B, 5 screens)
struct OnboardingFlow: View {
    @Environment(AppState.self) private var appState
    @State private var currentScreen = 0
    @State private var selectedSubject: OnboardingSubject?
    @State private var selectedStyle: OnboardingDanceStyle?

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            TabView(selection: $currentScreen) {
                // Screen 1: The Hook
                OnboardingHookView {
                    withAnimation(.easeInOut(duration: 0.35)) { currentScreen = 1 }
                }
                .tag(0)

                // Screen 2: Subject Picker
                SubjectPickerView(selectedSubject: $selectedSubject) {
                    withAnimation(.easeInOut(duration: 0.35)) { currentScreen = 2 }
                }
                .tag(1)

                // Screen 3: Dance Style Picker
                DanceStylePickerView(
                    subject: selectedSubject ?? .pet,
                    selectedStyle: $selectedStyle
                ) {
                    withAnimation(.easeInOut(duration: 0.35)) { currentScreen = 3 }
                }
                .tag(2)

                // Screen 4: Simulated Result
                SimulatedResultView(
                    subject: selectedSubject ?? .pet,
                    style: selectedStyle
                ) {
                    appState.showPaywall = true
                }
                .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
            .gesture(DragGesture()) // Disable swipe — forward only
        }
        .fullScreenCover(isPresented: Binding(
            get: { appState.showPaywall },
            set: { appState.showPaywall = $0 }
        )) {
            GroovePaywallScreen(
                onPurchaseSuccess: {
                    appState.showPaywall = false
                },
                onDismiss: {
                    appState.showPaywall = false
                }
            )
        }
    }
}

#Preview {
    OnboardingFlow()
        .environment(AppState())
}
