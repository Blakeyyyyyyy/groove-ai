import SwiftUI
import SwiftData
import Security
import RevenueCat
import SuperwallKit

// MARK: - API Response Models

/// Response from POST /api/register
struct RegisterResponse: Codable {
    let user_id: String
    let coins: Int
    let subscription_status: String
}

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
            #if DEBUG
            print("[Keychain] Failed to save \(key): \(status)")
            #endif
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
        didSet {
            UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding")
            UserDefaults.standard.synchronize()
            #if DEBUG
            print("[AppState] 💾 hasCompletedOnboarding persisted to UserDefaults: \(hasCompletedOnboarding)")
            #endif
        }
    }

    var isSubscribed: Bool {
        didSet { UserDefaults.standard.set(isSubscribed, forKey: "isSubscribed") }
    }

    /// True once the user has ever held a paid subscription (active or expired).
    /// Once flipped to true, never resets to false — used to route expired
    /// subscribers to the coin packages paywall instead of the onboarding paywall.
    var hasHadSubscription: Bool = false {
        didSet { UserDefaults.standard.set(hasHadSubscription, forKey: "hasHadSubscription") }
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

    // MARK: - User ID (server-generated on first launch, persisted in Keychain for security)

    var userId: String? {
        get {
            // First check Keychain (preferred)
            if let keychainId = KeychainHelper.get(forKey: "userId") {
                return keychainId
            }
            // Fallback: check UserDefaults for migration from older versions (pre-security-fix)
            if let existing = UserDefaults.standard.string(forKey: "userId") {
                // Migrate to Keychain and remove from UserDefaults (less secure store)
                KeychainHelper.save(existing, forKey: "userId")
                UserDefaults.standard.removeObject(forKey: "userId")
                return existing
            }
            // No user ID found — must call /api/register to get server-generated UUID
            // This is now a blocking async operation handled in AppState.initializeUser()
            #if DEBUG
            print("[AppState] ⚠️ userId requested but not in Keychain — call initializeUser() to register")
            #endif
            return nil
        }
        set {
            if let value = newValue {
                KeychainHelper.save(value, forKey: "userId")
            } else {
                KeychainHelper.delete(forKey: "userId")
            }
        }
    }

    // MARK: - User Registration (server-generated IDs)

    /// Call this once at app launch to ensure user is registered.
    /// If user_id already exists in Keychain, syncs with server.
    /// If not, calls /api/register to get a server-generated UUID and stores it.
    func initializeUser() async {
        if let existingId = KeychainHelper.get(forKey: "userId"),
           KeychainHelper.get(forKey: "authToken") != nil {
            // Both userId AND authToken present — existing user, .task in
            // GrooveAIApp handles the sync.
            #if DEBUG
            print("[AppState] 👤 User already initialized: \(existingId). Syncing server state.")
            #endif
            _ = existingId
            return
        }

        // Either no userId, or userId exists but no authToken (pre-JWT install
        // where Keychain survived a clean build). Wipe the stale userId so
        // performRegistration() starts clean and we get a fresh token pair.
        if KeychainHelper.get(forKey: "userId") != nil {
            #if DEBUG
            print("[AppState] 🆕 Stale userId without authToken — clearing and re-registering fresh user")
            #endif
            KeychainHelper.delete(forKey: "userId")
        } else {
            #if DEBUG
            print("[AppState] 🆕 No valid session found — registering fresh user")
            #endif
        }

        // Prevent concurrent registrations (e.g. from parallel syncWithServer 404 handlers)
        let alreadyRegistering = await MainActor.run {
            if self.isRegistering { return true }
            self.isRegistering = true
            return false
        }
        guard !alreadyRegistering else {
            #if DEBUG
            print("[AppState] ⏭ initializeUser skipped — registration already in progress")
            #endif
            return
        }

        await performRegistration()
    }

    /// Performs the actual registration HTTP call and post-registration setup.
    /// Caller MUST have already set `isRegistering = true` and verified no other
    /// registration is in flight. This function clears `isRegistering` itself.
    private func performRegistration() async {
        // First launch — call /api/register to get server-generated UUID
        #if DEBUG
        print("[AppState] 🔄 Registering with backend...")
        #endif
        do {
            let (newUserId, initialCoins) = try await SupabaseService.shared.register()
            KeychainHelper.save(newUserId, forKey: "userId")
            // Identify this user to Superwall the moment the ID exists, so first-launch
            // users (who land in performRegistration before any other identify call)
            // are attributed correctly on their first paywall view.
            await MainActor.run {
                Superwall.shared.identify(userId: newUserId)
            }
            await MainActor.run {
                self.serverCoins = initialCoins
                self.isRegistering = false
                // Reset stale state from any previous user whose values survived
                // in UserDefaults. syncWithServer below restores the real values.
                self.isSubscribed = false
                self.hasHadSubscription = false
                self.coinsUsed = 0
            }
            #if DEBUG
            print("[AppState] ✅ User registered: user_id=\(newUserId), coins=\(initialCoins)")
            #endif

            // Link the RevenueCat anonymous session to the Supabase userId.
            // RC may have been configured anonymously before registration completed.
            // logIn migrates any anonymous purchases to this known user so the
            // backend webhook can correctly attribute them.
            await RevenueCatService.shared.loginUser(userId: newUserId)

            // If a purchase completed while we were re-registering, push the
            // subscription expiry now that userId is saved.
            let rcService = RevenueCatService.shared
            if await MainActor.run(body: { rcService.isSubscribed }),
               let expiresAt = await MainActor.run(body: { rcService.subscriptionRenewalDate }) {
                #if DEBUG
                print("[AppState] 🔄 Post-registration: pushing pending subscription expiry")
                #endif
                await SupabaseService.shared.updateSubscriptionExpiry(expiresAt)
            }
            // Always sync so server state (coins, subscription_status) overwrites
            // any stale UserDefaults left from a previous account.
            await syncWithServer()
        } catch {
            #if DEBUG
            print("[AppState] ❌ Registration failed: \(error.localizedDescription)")
            #endif
            await MainActor.run {
                self.isRegistering = false
                self.errorAlertMessage = "Failed to create account. Please restart the app."
            }
        }
    }

    // Prevents concurrent /register calls when multiple syncWithServer() calls race on 404
    private var isRegistering: Bool = false

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
        let storedIsSubscribed = defaults.bool(forKey: "isSubscribed")
        hasCompletedOnboarding = defaults.bool(forKey: "hasCompletedOnboarding")
        isSubscribed = storedIsSubscribed
        // If we already know they're subscribed locally, they've had a subscription.
        hasHadSubscription = defaults.bool(forKey: "hasHadSubscription") || storedIsSubscribed
        hasRequestedNotificationPermission = defaults.bool(forKey: "hasRequestedNotificationPermission")

        #if DEBUG
        print("[AppState] 🔧 Initialized: hasCompletedOnboarding=\(hasCompletedOnboarding), isSubscribed=\(isSubscribed), hasHadSubscription=\(hasHadSubscription)")
        #endif

        // Register user on first launch (server generates UUID, stored in Keychain)
        Task { await self.initializeUser() }

        // Listen for purchase completions to force-refresh coins from server
        NotificationCenter.default.addObserver(forName: .revenueCatPurchaseCompleted, object: nil, queue: nil) { [weak self] notification in
            guard let self else { return }
            Task {
                // Flip the routing flag immediately so the user isn't bounced
                // back to the onboarding paywall during the 3s webhook delay.
                await MainActor.run {
                    self.hasHadSubscription = true
                }
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                for _ in 0..<10 {
                    if KeychainHelper.get(forKey: "userId") != nil { break }
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                }
                let rcService = RevenueCatService.shared
                let isSubscribed = await MainActor.run { rcService.isSubscribed }
                let expiresAt = await MainActor.run { rcService.subscriptionRenewalDate }
                if isSubscribed, let expiresAt {
                    await SupabaseService.shared.updateSubscriptionExpiry(expiresAt)
                }
                if let userId = KeychainHelper.get(forKey: "userId") {
                    await RevenueCatService.shared.loginUser(userId: userId)
                }
                await self.syncWithServer()
            }
        }
    }

    // MARK: - Coins (local fallback — server is authoritative)

    /// Optimistic deduction for instant UI feedback. Server response from
    /// /api/generate-video reconciles `serverCoins` to the authoritative value.
    /// Decrements both the legacy local counter (coinsUsed) and the
    /// server-synced balance (serverCoins) so the user sees the drop the
    /// moment they tap Generate, instead of waiting for the full pipeline.
    func useCoins() {
        coinsUsed += coinCostPerGeneration
        if let current = serverCoins {
            serverCoins = max(0, current - coinCostPerGeneration)
        }
    }

    /// Optimistic refund (mirrors useCoins). Used when generation is rejected
    /// locally before any server call. Server-side refunds go through
    /// SupabaseService.refundCoins and write the authoritative value back.
    func refundCoins() {
        coinsUsed = max(0, coinsUsed - coinCostPerGeneration)
        if let current = serverCoins {
            serverCoins = current + coinCostPerGeneration
        }
    }

    // MARK: - Sync with Server

    func syncWithServer() async {
        // Get user_id from Keychain (userId property may trigger nil if not properly initialized)
        guard let userId = KeychainHelper.get(forKey: "userId") else {
            #if DEBUG
            print("[AppState] ⚠️ syncWithServer skipped: user not registered yet")
            #endif
            return
        }

        #if DEBUG
        print("[AppState] 🔄 Syncing with server for userId: \(userId)")
        #endif
        do {
            let profile = try await SupabaseService.shared.getUser(id: userId)
            // Capture the RevenueCat-side state OFF the main actor before
            // hopping over — avoids reading @Published while we mutate state.
            let revenueCatSaysSubscribed = await MainActor.run {
                RevenueCatService.shared.isSubscribed
            }

            await MainActor.run {
                // RACE GUARD: If a generation is in flight, skip overwriting
                // serverCoins. The /generate-video response is the authoritative
                // post-deduction value; a concurrent GET /user can return the
                // pre-deduction balance and cause a 90 → 150 → 90 flash.
                // Other fields (subscription status etc.) are still safe to sync.
                if self.isGenerating {
                    #if DEBUG
                    print("[AppState] ⏸ syncWithServer: generation in flight — skipping serverCoins overwrite (would have set: \(profile["coins"] as? Int ?? -1))")
                    #endif
                } else {
                    self.serverCoins = profile["coins"] as? Int
                }

                let subscriptionStatus = profile["subscription_status"] as? String ?? "free"
                let serverSaysSubscribed = subscriptionStatus == "active"

                // Subscription truth: server is authoritative when active.
                // RC is authoritative when server hasn't caught up (webhook race,
                // or re-registration where the new row starts as "free").
                // Only demote when BOTH sources agree the user is not subscribed.
                if serverSaysSubscribed {
                    self.isSubscribed = true
                    self.hasHadSubscription = true
                } else if revenueCatSaysSubscribed {
                    // RC sees a live entitlement but Supabase row is "free" —
                    // webhook hasn't landed yet, or this is a fresh row after
                    // re-registration. RC is authoritative: promote.
                    self.isSubscribed = true
                    self.hasHadSubscription = true
                    #if DEBUG
                    print("[AppState] ⬆️ Promoting — RC=subscribed, server=free (webhook race or re-registration)")
                    #endif
                } else {
                    self.isSubscribed = false
                }

                // hasHadSubscription also latches on server-side evidence
                // (status != "free" covers "expired" rows).
                if subscriptionStatus != "free" {
                    self.hasHadSubscription = true
                }

                #if DEBUG
                print("[AppState] ✅ Server sync complete — coins: \(self.serverCoins ?? -1), subscribed: \(self.isSubscribed) (server=\(serverSaysSubscribed), rc=\(revenueCatSaysSubscribed), status=\(subscriptionStatus), hasHadSubscription=\(self.hasHadSubscription))")
                #endif
            }
        } catch let error as NSError {
            let isUnauthorized = error.domain == "SupabaseService" && error.code == 401
            let is404 = error.domain == "SupabaseService" && error.code == 404

            if isUnauthorized {
                // Stale or invalid JWT. Do NOT wipe Keychain before registration succeeds —
                // if register() fails (network down, rate-limited), the old credentials must
                // survive so the user can retry on next launch. register() overwrites both
                // keys on success, so no pre-deletion needed.
                let shouldRegister = await MainActor.run {
                    guard !self.isRegistering else { return false }
                    self.isRegistering = true
                    return true
                }
                guard shouldRegister else {
                    #if DEBUG
                    print("[AppState] ⏭ Re-registration already in progress — skipping duplicate")
                    #endif
                    return
                }
                #if DEBUG
                print("[AppState] ⚠️ 401 on sync — stale token, re-registering (old keys preserved until success)")
                #endif
                await performRegistration()
            } else if is404 {
                // Only treat as "user deleted from backend" if the response body
                // explicitly says so. Generic 404s (e.g. Render cold-start, route
                // misconfig) must NOT nuke the Keychain — that would orphan
                // legitimate users and trigger a re-register storm.
                let body = error.localizedDescription.lowercased()
                let isUserNotFound = body.contains("user not found")
                    || body.contains("user_not_found")
                    || body.contains("no user")
                guard isUserNotFound else {
                    #if DEBUG
                    print("[AppState] ⚠️ Generic 404 from server (not 'user not found') — keeping userId, skipping re-register: \(error.localizedDescription)")
                    #endif
                    return
                }

                // User deleted from backend — both keys are now useless.
                let shouldRegister = await MainActor.run {
                    guard !self.isRegistering else { return false }
                    self.isRegistering = true
                    KeychainHelper.delete(forKey: "authToken")
                    KeychainHelper.delete(forKey: "userId")
                    return true
                }
                guard shouldRegister else {
                    #if DEBUG
                    print("[AppState] ⏭ Re-registration already in progress — skipping duplicate")
                    #endif
                    return
                }
                #if DEBUG
                print("[AppState] ⚠️ User not found on server — clearing stale ID and re-registering")
                #endif
                await performRegistration()
            } else {
                #if DEBUG
                print("[AppState] ⚠️ Server sync failed (using local state): \(error)")
                #endif
            }
        } catch {
            #if DEBUG
            print("[AppState] ⚠️ Server sync failed (using local state): \(error)")
            #endif
        }
    }

    // MARK: - Account Deletion

    /// Deletes the user's account on the server, then wipes local state so the
    /// next launch starts as a fresh install. App Store guideline 5.1.1(v).
    /// Returns true on success, false if the server delete failed (local state
    /// is untouched in that case so the user can retry).
    @MainActor
    func deleteAccount() async -> Bool {
        guard let userId = KeychainHelper.get(forKey: "userId") else {
            // No server-side account exists — just wipe local state.
            await wipeLocalAccountState()
            return true
        }
        do {
            let ok = try await SupabaseService.shared.deleteAccount(userId: userId)
            guard ok else { return false }
        } catch {
            #if DEBUG
            print("[AppState] ⚠️ deleteAccount failed: \(error.localizedDescription)")
            #endif
            return false
        }
        await wipeLocalAccountState()
        return true
    }

    /// Clears every persisted bit of identity / progress so the next launch
    /// behaves like a fresh install. Called only after the server confirms the
    /// account is gone (or when there's nothing on the server to delete).
    @MainActor
    private func wipeLocalAccountState() async {
        KeychainHelper.delete(forKey: "userId")
        KeychainHelper.delete(forKey: "authToken")

        let defaults = UserDefaults.standard
        for key in ["userId", "isSubscribed", "hasHadSubscription", "hasCompletedOnboarding",
                    "hasRequestedNotificationPermission", "creditsUsed", "groove_coins"] {
            defaults.removeObject(forKey: key)
        }
        defaults.synchronize()

        do {
            _ = try await Purchases.shared.logOut()
        } catch {
            // Non-fatal — anonymous users cannot log out.
            #if DEBUG
            print("[AppState] ℹ️ Purchases.logOut() skipped: \(error.localizedDescription)")
            #endif
        }

        isSubscribed = false
        hasHadSubscription = false
        hasCompletedOnboarding = false
        hasRequestedNotificationPermission = false
        serverCoins = 0
        coinsUsed = 0
        generationPhase = .idle
        generatingPhotoData = nil
        showVideoReadyPopup = false
        showPaywall = false
        errorAlertMessage = nil
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

    // MARK: - Debug Utilities

    func verifyPersistence() -> [String: Any] {
        let defaults = UserDefaults.standard
        let onboarding = defaults.bool(forKey: "hasCompletedOnboarding")
        let subscribed = defaults.bool(forKey: "isSubscribed")
        let notifPerms = defaults.bool(forKey: "hasRequestedNotificationPermission")

        let state: [String: Any] = [
            "hasCompletedOnboarding_memory": hasCompletedOnboarding,
            "hasCompletedOnboarding_disk": onboarding,
            "isSubscribed_memory": isSubscribed,
            "isSubscribed_disk": subscribed,
            "hasRequestedNotificationPermission_memory": hasRequestedNotificationPermission,
            "hasRequestedNotificationPermission_disk": notifPerms
        ]

        #if DEBUG
        print("[AppState] 📋 Persistence Check: \(state)")
        #endif
        return state
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
