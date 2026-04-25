import Foundation

/// Manages coin balance via the backend.
/// All coin operations go through SupabaseService → Render backend.
enum CoinsService {
    static let costPerGeneration = 60

    /// Legacy: weekly reset is now handled server-side.
    /// Kept as no-op so existing callers compile.
    static func checkWeeklyReset() {
        // No-op — coin resets are managed by the backend
    }

    /// Fetch current coin balance from backend
    static func getBalance(userId: String) async throws -> Int {
        let user = try await SupabaseService.shared.getUser(id: userId)
        return user["coins"] as? Int ?? 0
    }

    /// Deduct coins for a generation via backend
    static func deductForGeneration(userId: String) async throws -> Int {
        let result = try await SupabaseService.shared.deductCoins(userId: userId, amount: costPerGeneration)
        return result["remaining"] as? Int ?? 0
    }

    /// Add coins via backend (e.g., after purchase or weekly reset)
    static func addCoins(userId: String, amount: Int, type: String = "purchase") async throws -> Int {
        let result = try await SupabaseService.shared.addCoins(userId: userId, amount: amount, type: type, appleJWS: nil)
        return result["coins"] as? Int ?? 0
    }
}
