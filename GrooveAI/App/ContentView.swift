import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState

        if !appState.hasCompletedOnboarding {
            OnboardingFlow()
                .fullScreenCover(isPresented: $state.showPaywall) {
                    PaywallView()
                }
        } else {
            mainTabView
        }
    }

    private var mainTabView: some View {
        @Bindable var state = appState

        return TabView(selection: $state.selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(AppTab.home)

            MyVideosView()
                .tabItem {
                    Label("My Videos", systemImage: "film.stack.fill")
                }
                .tag(AppTab.myVideos)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(AppTab.settings)
        }
        .tint(Color.accentStart)
        .safeAreaInset(edge: .bottom) {
            // Generating pill — sits ABOVE tab bar, persists across all tabs
            if appState.isGenerating {
                GeneratingPill(
                    minutesRemaining: appState.minutesRemaining,
                    isFailed: appState.generationFailed,
                    onTap: {
                        if appState.generationFailed {
                            // Navigate back to upload to retry
                            appState.generationFailed = false
                            appState.isGenerating = false
                            appState.selectedTab = .home
                        }
                    }
                )
                .transition(
                    .asymmetric(
                        insertion: .offset(y: 80).combined(with: .opacity),
                        removal: .offset(y: 80).combined(with: .opacity)
                    )
                )
                .animation(AppAnimation.bouncy, value: appState.isGenerating)
                .padding(.bottom, Spacing.sm)
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(AppState())
        .modelContainer(for: GeneratedVideo.self, inMemory: true)
}
