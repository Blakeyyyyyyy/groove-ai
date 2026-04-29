import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @State private var showSplash = true

    var body: some View {
        ZStack {
            if showSplash {
                GrooveSplashView {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        showSplash = false
                    }
                }
                .transition(.opacity)
                .zIndex(1)
            } else {
                mainContent
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showSplash)
        .onAppear {
            #if DEBUG
            print("[ContentView] 🎬 onAppear — checking onboarding state: hasCompletedOnboarding=\(appState.hasCompletedOnboarding)")
            #endif
            appState.verifyPersistence()
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        @Bindable var state = appState

        Group {
            if !appState.hasCompletedOnboarding {
                GrooveOnboardingView(onComplete: {
                    #if DEBUG
                    print("[ContentView] GrooveOnboardingView.onComplete fired — before: hasCompletedOnboarding=\(appState.hasCompletedOnboarding), selectedTab=\(appState.selectedTab)")
                    #endif
                    appState.hasCompletedOnboarding = true
                    appState.selectedTab = .home
                    #if DEBUG
                    print("[ContentView] GrooveOnboardingView.onComplete finished — after: hasCompletedOnboarding=\(appState.hasCompletedOnboarding), selectedTab=\(appState.selectedTab)")
                    #endif
                })
            } else {
                mainTabView
            }
        }
        .onChange(of: appState.hasCompletedOnboarding) { _, newValue in
            #if DEBUG
            print("[ContentView] hasCompletedOnboarding changed -> \(newValue)")
            #endif
        }
        .onChange(of: appState.showPaywall) { _, newValue in
            #if DEBUG
            print("[ContentView] showPaywall changed -> \(newValue)")
            #endif
        }
        .onChange(of: appState.selectedTab) { _, newValue in
            #if DEBUG
            print("[ContentView] selectedTab changed -> \(newValue)")
            #endif
        }
        .alert("Image Issue", isPresented: Binding(
            get: { appState.errorAlertMessage != nil },
            set: { if !$0 { appState.errorAlertMessage = nil } }
        )) {
            if appState.errorAlertIsPoseIssue {
                Button("Try Again") {
                    appState.errorAlertMessage = nil
                    appState.errorAlertIsPoseIssue = false
                    appState.resetGeneration()
                    appState.selectedTab = .home
                }
                Button("Cancel", role: .cancel) {
                    appState.errorAlertMessage = nil
                    appState.errorAlertIsPoseIssue = false
                }
            } else {
                Button("OK", role: .cancel) {
                    appState.errorAlertMessage = nil
                    appState.errorAlertIsPoseIssue = false
                }
            }
        } message: {
            if let msg = appState.errorAlertMessage {
                Text(msg)
            }
        }
    }

    private var mainTabView: some View {
        @Bindable var state = appState

        return ZStack(alignment: .top) {
            TabView(selection: $state.selectedTab) {
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
            .tint(.white)
            .toolbar(.hidden, for: .tabBar)

            // GeneratingPill positioned ABOVE where tab bar would be
            if appState.isGenerating {
                VStack {
                    Spacer()
                    GeneratingPill(
                        onTap: {
                            if appState.generationFailed {
                                appState.resetGeneration()
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
                    .padding(.horizontal, Spacing.lg)
                    // Position pill above the hidden tab bar area
                    .padding(.bottom, 60) // Leave space for where tab bar was
                }
            }

            // In-app "Video Ready" popup — slides in from top
            if appState.showVideoReadyPopup {
                VideoReadyPopup(
                    onTap: {
                        appState.showVideoReadyPopup = false
                        appState.selectedTab = .myVideos
                    },
                    onDismiss: {
                        withAnimation(AppAnimation.gentle) {
                            appState.showVideoReadyPopup = false
                        }
                    }
                )
                .padding(.top, Spacing.xxxl + Spacing.xl)
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(AppAnimation.bouncy, value: appState.showVideoReadyPopup)
                .zIndex(100)
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(AppState())
        .modelContainer(for: GeneratedVideo.self, inMemory: true)
}