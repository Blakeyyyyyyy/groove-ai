import SwiftUI
import AVKit
import SuperwallKit

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
                    Superwall.shared.register(placement: "onboarding_paywall") {
                        appState.hasCompletedOnboarding = true
                    }
                }
                .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
            .gesture(DragGesture()) // Disable swipe — forward only
        }
        .onAppear {
            // Track entry into onboarding (screen_1 = OnboardingHookView)
            SupabaseService.shared.trackEvent(step: "screen_1")
        }
        .onChange(of: currentScreen) { oldValue, newValue in
            if newValue < oldValue {
                // Block backward navigation
                currentScreen = oldValue
                return
            }
            let steps = ["screen_1", "screen_2", "screen_3", "screen_4"]
            if newValue < steps.count {
                SupabaseService.shared.trackEvent(step: steps[newValue])
            }
        }
    }
}

#Preview {
    OnboardingFlow()
        .environment(AppState())
}
