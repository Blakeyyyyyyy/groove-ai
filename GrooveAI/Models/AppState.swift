import SwiftUI
import SwiftData

// MARK: - Generation State
enum GenerationPhase: Equatable {
    case idle
    case generating(startTime: Date, jobId: String)
    case complete(videoID: String)
    case failed(message: String)
}

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

    // MARK: - Server-Synced Coins

    /// Server-authoritative coin balance. Falls back to local if not synced yet.
    var serverCoins: Int? = nil

    var coinsUsed: Int {
        get { UserDefaults.standard.integer(forKey: "creditsUsed") }
        set { UserDefaults.standard.set(newValue, forKey: "creditsUsed") }
    }

    let coinsTotal: Int = 150
    let coinCostPerGeneration: Int = 60

    /// Use server coins if available, otherwise local calculation
    var coinsRemaining: Int {
        if let server = serverCoins { return server }
        return max(0, coinsTotal - coinsUsed)
    }

    var hasEnoughCoins: Bool {
        coinsRemaining >= coinCostPerGeneration
    }

    // MARK: - User ID (from Supabase Auth)

    var userId: String? {
        get { UserDefaults.standard.string(forKey: "userId") }
        set { UserDefaults.standard.set(newValue, forKey: "userId") }
    }

    // Generation state — state-driven flow (BUG-004 fix)
    var generationPhase: GenerationPhase = .idle

    var isGenerating: Bool {
        if case .generating = generationPhase { return true }
        return false
    }

    var generationFailed: Bool {
        if case .failed = generationPhase { return true }
        return false
    }

    var generationStartTime: Date? {
        if case .generating(let startTime, _) = generationPhase { return startTime }
        return nil
    }

    var generatingVideoID: String? {
        switch generationPhase {
        case .generating(_, let jobId): return jobId
        case .complete(let videoID): return videoID
        default: return nil
        }
    }

    // Navigation
    var selectedTab: AppTab = .home
    var showPaywall: Bool = false

    // Push notification
    var hasRequestedNotificationPermission: Bool {
        get { UserDefaults.standard.bool(forKey: "hasRequestedNotificationPermission") }
        set { UserDefaults.standard.set(newValue, forKey: "hasRequestedNotificationPermission") }
    }

    // MARK: - Coins (local fallback — server is authoritative)

    func useCoins() {
        coinsUsed += coinCostPerGeneration
    }

    func refundCoins() {
        coinsUsed = max(0, coinsUsed - coinCostPerGeneration)
    }

    // MARK: - Sync with Server

    func syncWithServer() async {
        do {
            let profile = try await SupabaseService.shared.getUser()
            await MainActor.run {
                self.serverCoins = profile.coins
                self.userId = profile.id
                self.isSubscribed = profile.subscriptionStatus != "free"
            }
        } catch {
            // Offline or not authenticated — use local state
            print("[AppState] Server sync failed: \(error)")
        }
    }

    // MARK: - Generation Flow

    func startGeneration(jobId: String) {
        generationPhase = .generating(startTime: Date(), jobId: jobId)
    }

    func completeGeneration(videoID: String) {
        generationPhase = .complete(videoID: videoID)
    }

    func failGeneration(message: String = "Something went wrong") {
        generationPhase = .failed(message: message)
        // Server handles refund — just refresh balance
        Task { await syncWithServer() }
    }

    func resetGeneration() {
        generationPhase = .idle
    }

    // MARK: - Countdown (BUG-003 fix)

    /// Returns seconds remaining from a 10-minute generation window
    func secondsRemaining(from now: Date = Date()) -> Int {
        guard let startTime = generationStartTime else { return 0 }
        let elapsed = now.timeIntervalSince(startTime)
        let remaining = 600 - elapsed // 10 minutes = 600 seconds
        return max(0, Int(remaining))
    }

    /// Formatted countdown string: "M:SS" or "Almost done..."
    func countdownText(from now: Date = Date()) -> String {
        let seconds = secondsRemaining(from: now)
        if seconds <= 0 { return "almost done" }
        let mins = seconds / 60
        let secs = seconds % 60
        return "\(mins):\(String(format: "%02d", secs))"
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
