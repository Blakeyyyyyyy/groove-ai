import SwiftUI
import SwiftData
import UIKit

@main
struct GrooveAIApp: App {
    @State private var appState = AppState()

    init() {
        Self.configureTabBarAppearance()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .preferredColorScheme(.dark)
                .task {
                    if let userId = appState.userId {
                        RevenueCatService.shared.configureWithUserId(userId)
                    } else {
                        RevenueCatService.shared.configure()
                    }

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

    private static func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        appearance.backgroundColor = UIColor.clear
        appearance.shadowColor = UIColor.clear

        let selectedAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.white
        ]
        let normalAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.white.withAlphaComponent(0.58)
        ]

        let stacked = appearance.stackedLayoutAppearance
        stacked.selected.iconColor = .white
        stacked.selected.titleTextAttributes = selectedAttributes
        stacked.normal.iconColor = UIColor.white.withAlphaComponent(0.58)
        stacked.normal.titleTextAttributes = normalAttributes

        let inline = appearance.inlineLayoutAppearance
        inline.selected.iconColor = .white
        inline.selected.titleTextAttributes = selectedAttributes
        inline.normal.iconColor = UIColor.white.withAlphaComponent(0.58)
        inline.normal.titleTextAttributes = normalAttributes

        let compactInline = appearance.compactInlineLayoutAppearance
        compactInline.selected.iconColor = .white
        compactInline.selected.titleTextAttributes = selectedAttributes
        compactInline.normal.iconColor = UIColor.white.withAlphaComponent(0.58)
        compactInline.normal.titleTextAttributes = normalAttributes

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().unselectedItemTintColor = UIColor.white.withAlphaComponent(0.58)
    }
}
