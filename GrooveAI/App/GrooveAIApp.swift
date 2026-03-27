import SwiftUI
import SwiftData

@main
struct GrooveAIApp: App {
    @State private var appState = AppState()

    init() {
        // Configure RevenueCat on launch
        RevenueCatService.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .preferredColorScheme(.dark)
                .task {
                    // Sync user data from server
                    await appState.syncWithServer()

                    // Check subscription status via RevenueCat
                    let isPremium = await RevenueCatService.shared.checkPremium()
                    if isPremium {
                        appState.isSubscribed = true
                    }

                    // Check weekly coin reset
                    CoinsService.checkWeeklyReset()
                }
        }
        .modelContainer(for: [GeneratedVideo.self])
    }
}
