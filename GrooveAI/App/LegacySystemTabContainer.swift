import SwiftUI

// Backup of the previous system TabView setup so the bottom bar can be reverted cleanly if needed.
struct LegacySystemTabContainer: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState

        TabView(selection: $state.selectedTab) {
            HomeView()
                .tag(AppTab.home)

            MyVideosView()
                .tag(AppTab.myVideos)

            SettingsView()
                .tag(AppTab.settings)
        }
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom) {
            if appState.isGenerating {
                GeneratingPill(
                    onTap: {
                        if appState.generationFailed {
                            appState.resetGeneration()
                            appState.selectedTab = .home
                        }
                    }
                )
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.sm)
            }
        }
    }
}
