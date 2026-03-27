import Foundation

/// Manages coin balance. In production, syncs with Supabase.
/// For now, uses UserDefaults with weekly reset logic.
enum CoinsService {
    static let weeklyAllowance = 150
    static let costPerGeneration = 60

    /// Check if coins should reset (every Monday)
    static func checkWeeklyReset() {
        let lastReset = UserDefaults.standard.object(forKey: "lastCreditsReset") as? Date ?? .distantPast
        let calendar = Calendar.current

        // Find the most recent Monday
        let now = Date()
        guard let thisWeekMonday = calendar.nextDate(
            after: now,
            matching: DateComponents(weekday: 2),
            matchingPolicy: .previousTimePreservingSmallerComponents,
            direction: .backward
        ) else { return }

        if lastReset < thisWeekMonday {
            // Reset coins
            UserDefaults.standard.set(0, forKey: "creditsUsed")
            UserDefaults.standard.set(now, forKey: "lastCreditsReset")
        }
    }
}
