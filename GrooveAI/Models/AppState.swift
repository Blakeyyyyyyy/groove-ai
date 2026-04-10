import SwiftUI
import SwiftData
import Security

// MARK: - Keychain Helper

/// Simple Keychain wrapper for storing sensitive data like user ID
enum KeychainHelper {
    private static let service = "com.grooveai.app"
    
    static func save(_ value: String, forKey key: String) {
        guard let data = value.data(using: .utf8) else { return }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        // Delete existing item first
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("[Keychain] Failed to save \(key): \(status)")
        }
    }
    
    static func get(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return value
    }
    
    static func delete(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

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
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding") }
    }

    var isSubscribed: Bool {
        didSet { UserDefaults.standard.set(isSubscribed, forKey: "isSubscribed") }
    }

    // MARK: - Server-Synced Coins

    /// Server-authoritative coin balance. Falls back to local if not synced yet.
    var serverCoins: Int? = nil

    var coinsUsed: Int {
        get { UserDefaults.standard.integer(forKey: "creditsUsed") }
        set { UserDefaults.standard.set(newValue, forKey: "creditsUsed") }
    }

    let coinsTotal: Int = 0
    let coinCostPerGeneration: Int = 60

    /// Use server coins if available, otherwise local calculation
    var coinsRemaining: Int {
        if let server = serverCoins { return server }
        return max(0, coinsTotal - coinsUsed)
    }

    var hasEnoughCoins: Bool {
        coinsRemaining >= coinCostPerGeneration
    }

    // MARK: - User ID (auto-generated on first access, persisted in Keychain for security)

    var userId: String? {
        get {
            // First check Keychain (preferred)
            if let keychainId = KeychainHelper.get(forKey: "userId") {
                return keychainId
            }
            // Fallback: check UserDefaults for migration from older versions
            if let existing = UserDefaults.standard.string(forKey: "userId") {
                // Migrate to Keychain and remove from UserDefaults (less secure store)
                KeychainHelper.save(existing, forKey: "userId")
                UserDefaults.standard.removeObject(forKey: "userId")
                return existing
            }
            // Auto-generate a stable userId on first access
            let newId = UUID().uuidString
            KeychainHelper.save(newId, forKey: "userId")
            print("[AppState] 🆔 Generated new userId: \(newId)")
            return newId
        }
        set {
            if let value = newValue {
                KeychainHelper.save(value, forKey: "userId")
            } else {
                KeychainHelper.delete(forKey: "userId")
            }
        }
    }

    // Generation state — state-driven flow (BUG-004 fix)
    var generationPhase: GenerationPhase = .idle

    /// Photo thumbnail data from the current generation (for generating pill)
    var generatingPhotoData: Data?

    /// Flag: in-app "video ready" popup should be shown
    var showVideoReadyPopup: Bool = false

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

    // Error alert state
    var errorAlertMessage: String? = nil
    var errorAlertIsPoseIssue: Bool = false

    // Push notification
    var hasRequestedNotificationPermission: Bool {
        didSet { UserDefaults.standard.set(hasRequestedNotificationPermission, forKey: "hasRequestedNotificationPermission") }
    }

    init() {
        let defaults = UserDefaults.standard
        hasCompletedOnboarding = defaults.bool(forKey: "hasCompletedOnboarding")
        isSubscribed = defaults.bool(forKey: "isSubscribed")
        hasRequestedNotificationPermission = defaults.bool(forKey: "hasRequestedNotificationPermission")
        
        // Listen for purchase completions to force-refresh coins from server
        NotificationCenter.default.addObserver(forName: .revenueCatPurchaseCompleted, object: nil, queue: nil) { [weak self] _ in
            guard let self else { return }
            print("[AppState] 🔔 Purchase completed notification — syncing with server")
            Task { await self.syncWithServer() }
        }
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
        guard let userId = userId else {
            print("[AppState] ⚠️ syncWithServer skipped: no userId")
            return
        }
        print("[AppState] 🔄 Syncing with server for userId: \(userId)")
        do {
            let profile = try await SupabaseService.shared.getUser(id: userId)
            await MainActor.run {
                self.serverCoins = profile["coins"] as? Int
                self.isSubscribed = (profile["subscription_status"] as? String ?? "free") != "free"
                print("[AppState] ✅ Server sync complete — coins: \(self.serverCoins ?? -1), subscribed: \(self.isSubscribed)")
            }
        } catch {
            print("[AppState] ⚠️ Server sync failed (using local state): \(error)")
        }
    }

    // MARK: - Generation Flow

    func startGeneration(jobId: String, photoData: Data? = nil) {
        generationPhase = .generating(startTime: Date(), jobId: jobId)
        generatingPhotoData = photoData
    }

    func completeGeneration(videoID: String) {
        generationPhase = .complete(videoID: videoID)
        showVideoReadyPopup = true
        generatingPhotoData = nil
    }

    func failGeneration(message: String = "Something went wrong") {
        generationPhase = .failed(message: message)
        // Server handles refund — just refresh balance
        Task { await syncWithServer() }
    }

    func resetGeneration() {
        generationPhase = .idle
        generatingPhotoData = nil
        showVideoReadyPopup = false
    }

    // MARK: - Countdown (BUG-003 fix)

    /// Returns seconds remaining from a 10-minute generation window
    func secondsRemaining(from now: Date = Date()) -> Int {
        guard let startTime = generationStartTime else { return 0 }
        let elapsed = now.timeIntervalSince(startTime)
        let remaining = 600 - elapsed // 10 minutes = 600 seconds
        return max(0, Int(remaining))
    }

    /// Formatted countdown string: "~Xm" or "Almost done..."
    func countdownText(from now: Date = Date()) -> String {
        let seconds = secondsRemaining(from: now)
        if seconds <= 30 { return "almost done" }
        let mins = Int(ceil(Double(seconds) / 60.0))
        return "~\(mins)m"
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
