import SwiftUI
import SwiftData

@Observable
final class AppState {
    var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") }
        set { UserDefaults.standard.set(newValue, forKey: "hasCompletedOnboarding") }
    }

    var isSubscribed: Bool {
        get { UserDefaults.standard.bool(forKey: "isSubscribed") }
        set { UserDefaults.standard.set(newValue, forKey: "isSubscribed") }
    }

    var creditsUsed: Int {
        get { UserDefaults.standard.integer(forKey: "creditsUsed") }
        set { UserDefaults.standard.set(newValue, forKey: "creditsUsed") }
    }

    let creditsTotal: Int = 150
    let creditCostPerGeneration: Int = 60

    var creditsRemaining: Int {
        max(0, creditsTotal - creditsUsed)
    }

    var hasEnoughCredits: Bool {
        creditsRemaining >= creditCostPerGeneration
    }

    // Generation state
    var isGenerating: Bool = false
    var generatingVideoID: String? = nil
    var minutesRemaining: Int = 10
    var generationFailed: Bool = false

    // Navigation
    var selectedTab: AppTab = .home
    var showPaywall: Bool = false

    // Push notification
    var hasRequestedNotificationPermission: Bool {
        get { UserDefaults.standard.bool(forKey: "hasRequestedNotificationPermission") }
        set { UserDefaults.standard.set(newValue, forKey: "hasRequestedNotificationPermission") }
    }

    func useCredits() {
        creditsUsed += creditCostPerGeneration
    }

    func refundCredits() {
        creditsUsed = max(0, creditsUsed - creditCostPerGeneration)
    }
}

enum AppTab: Int, CaseIterable {
    case home = 0
    case myVideos = 1
    case settings = 2

    var title: String {
        switch self {
        case .home: "Home"
        case .myVideos: "My Videos"
        case .settings: "Settings"
        }
    }

    var icon: String {
        switch self {
        case .home: "house.fill"
        case .myVideos: "film.stack.fill"
        case .settings: "gearshape.fill"
        }
    }
}
