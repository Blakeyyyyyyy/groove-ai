import Foundation

/// Manages credit balance. In production, syncs with Supabase.
/// For now, uses UserDefaults with weekly reset logic.
enum CreditsService {
    static let weeklyAllowance = 150
    static let costPerGeneration = 60

    /// Check if credits should reset (every Monday)
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
            // Reset credits
            UserDefaults.standard.set(0, forKey: "creditsUsed")
            UserDefaults.standard.set(now, forKey: "lastCreditsReset")
        }
    }
}
