import SwiftUI
import RevenueCat

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @State private var showSplash = true
    @State private var showNotificationPrimer = false

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
        .task {
            // Safety net: force-dismiss splash after 8s if the normal dismiss
            // was starved (e.g. RC processing a large backlog of sandbox renewals).
            try? await Task.sleep(for: .seconds(4))
            if showSplash {
                withAnimation(.easeInOut(duration: 0.4)) { showSplash = false }
            }
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
                    // Conditionally show notification primer ONLY for annual free trial users.
                    // Weekly buyers and paywall-dismissers get no primer and no permission request.
                    Task {
                        guard let customerInfo = try? await Purchases.shared.customerInfo() else { return }
                        let isAnnualTrial = customerInfo.entitlements.active.values
                            .first(where: { $0.productIdentifier == "grooveai_annual_9999" })?
                            .periodType == .trial
                        if isAnnualTrial {
                            try? await Task.sleep(for: .seconds(1.5))
                            await MainActor.run { showNotificationPrimer = true }
                        }
                    }
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
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("GrooveOpenCreateTab"))) { _ in
            appState.hasCompletedOnboarding = true
            appState.selectedTab = .home
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
        .sheet(isPresented: $showNotificationPrimer) {
            NotificationPrimerView(onAccept: {
                showNotificationPrimer = false
                Task {
                    let granted = await NotificationService.requestPermission()
                    if granted {
                        NotificationService.scheduleTrialReminder()
                    }
                }
            }, onDecline: {
                showNotificationPrimer = false
            })
            .presentationDetents([.height(320)])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color(red: 0.09, green: 0.09, blue: 0.12))
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

private struct NotificationPrimerView: View {
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 32)

            Text("🔔")
                .font(.system(size: 44))

            Spacer().frame(height: 16)

            Text("Want a heads-up?")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)

            Spacer().frame(height: 10)

            Text("We'll send you one reminder the day\nbefore your trial ends — so you don't miss it.")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(.white.opacity(0.65))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer().frame(height: 32)

            Button(action: onAccept) {
                Text("Remind me")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color(red: 0.22, green: 0.49, blue: 1.0))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 24)

            Button(action: onDecline) {
                Text("No thanks")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.white.opacity(0.45))
                    .frame(height: 44)
            }
            .padding(.top, 4)

            Spacer().frame(height: 16)
        }
        .frame(maxWidth: .infinity)
        .background(Color(red: 0.09, green: 0.09, blue: 0.12))
    }
}

#Preview {
    ContentView()
        .environment(AppState())
        .modelContainer(for: GeneratedVideo.self, inMemory: true)
}