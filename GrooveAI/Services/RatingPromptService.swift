import StoreKit
import UIKit

/// Drives App Store rating prompts at high-signal moments.
///
/// Triggers:
///   1. Post-purchase — on next launch after first subscription
///   2. Post-first generation — immediately after first video completes
///   3. Post-second generation — if user hasn't rated yet
///
/// Guards:
///   - Max 3 prompts total (Apple caps SKStoreReviewController at 3/year anyway)
///   - 24h cooldown between prompts (avoid spamming session)
///   - Each trigger fires once (tracked via UserDefaults)
final class RatingPromptService {

    static let shared = RatingPromptService()
    private init() {}

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let promptCount          = "ratingPrompt_count"
        static let lastPromptDate       = "ratingPrompt_lastDate"
        static let pendingPostPurchase  = "ratingPrompt_pendingPostPurchase"
        static let didPromptPostFirst   = "ratingPrompt_didPromptPostFirst"
        static let didPromptPostSecond  = "ratingPrompt_didPromptPostSecond"
        static let generationCount      = "ratingPrompt_generationCount"
    }

    private let maxPrompts = 3
    private let cooldownSeconds: TimeInterval = 24 * 60 * 60 // 24h

    // MARK: - Public Triggers

    /// Call this immediately after a successful subscription purchase.
    /// Sets a flag so we show the prompt on next app launch (feels more natural).
    func didSubscribe() {
        guard promptCount < maxPrompts else { return }
        UserDefaults.standard.set(true, forKey: Keys.pendingPostPurchase)
        print("[Rating] 🏷️ Post-purchase flag set — will prompt on next launch")
    }

    /// Call this on app launch (inside .task in GrooveAIApp).
    /// Shows prompt if a post-purchase flag is pending.
    @MainActor
    func checkPostPurchasePrompt() {
        guard UserDefaults.standard.bool(forKey: Keys.pendingPostPurchase) else { return }
        UserDefaults.standard.set(false, forKey: Keys.pendingPostPurchase)
        requestReview(trigger: "post_purchase")
    }

    /// Call this every time a video generation succeeds.
    /// Prompts after the 1st and 2nd generation if quota allows.
    @MainActor
    func didCompleteGeneration() {
        let count = generationCount + 1
        setGenerationCount(count)
        print("[Rating] 🎬 Generation count: \(count)")

        if count == 1, !UserDefaults.standard.bool(forKey: Keys.didPromptPostFirst) {
            UserDefaults.standard.set(true, forKey: Keys.didPromptPostFirst)
            // Slight delay so the result screen is fully visible
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                requestReview(trigger: "post_first_generation")
            }
            return
        }

        if count == 2, !UserDefaults.standard.bool(forKey: Keys.didPromptPostSecond) {
            UserDefaults.standard.set(true, forKey: Keys.didPromptPostSecond)
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                requestReview(trigger: "post_second_generation")
            }
        }
    }

    // MARK: - Core Prompt Logic

    @MainActor
    private func requestReview(trigger: String) {
        guard promptCount < maxPrompts else {
            print("[Rating] ⛔ Max prompts reached (\(maxPrompts)) — skipping \(trigger)")
            return
        }

        if let last = lastPromptDate,
           Date().timeIntervalSince(last) < cooldownSeconds {
            print("[Rating] ⏱️ Cooldown active — skipping \(trigger)")
            return
        }

        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else {
            print("[Rating] ⚠️ No active window scene — skipping \(trigger)")
            return
        }

        print("[Rating] ⭐ Requesting review — trigger: \(trigger), count: \(promptCount + 1)/\(maxPrompts)")
        SKStoreReviewController.requestReview(in: windowScene)

        // Track
        setPromptCount(promptCount + 1)
        UserDefaults.standard.set(Date(), forKey: Keys.lastPromptDate)
    }

    // MARK: - Accessors

    private var promptCount: Int {
        UserDefaults.standard.integer(forKey: Keys.promptCount)
    }

    private func setPromptCount(_ value: Int) {
        UserDefaults.standard.set(value, forKey: Keys.promptCount)
    }

    private var lastPromptDate: Date? {
        UserDefaults.standard.object(forKey: Keys.lastPromptDate) as? Date
    }

    var generationCount: Int {
        UserDefaults.standard.integer(forKey: Keys.generationCount)
    }

    private func setGenerationCount(_ value: Int) {
        UserDefaults.standard.set(value, forKey: Keys.generationCount)
    }
}
