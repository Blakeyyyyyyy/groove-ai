import Foundation
import RevenueCat

/// RevenueCat subscription management
/// Handles purchases, entitlement checks, and subscription sync with Supabase
final class RevenueCatService: ObservableObject {
    static let shared = RevenueCatService()

    @Published var isSubscribed = false
    @Published var offerings: Offerings?
    @Published var currentPackages: [Package] = []

    private let apiKey = "test_asPwPLcWptxFPXSHMcdieXUETYM"

    private init() {}

    // MARK: - Configuration

    func configure() {
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: apiKey)

        // Listen for subscription changes
        Task {
            await refreshSubscriptionStatus()
        }
    }

    func configureWithUserId(_ userId: String) {
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: apiKey, appUserID: userId)

        Task {
            await refreshSubscriptionStatus()
        }
    }

    // MARK: - Subscription Status

    @MainActor
    func refreshSubscriptionStatus() async {
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            isSubscribed = customerInfo.entitlements["premium"]?.isActive == true
        } catch {
            print("[RevenueCat] Error fetching customer info: \(error)")
        }
    }

    func checkPremium() async -> Bool {
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            return customerInfo.entitlements["premium"]?.isActive ?? false
        } catch {
            print("[RevenueCat] Error checking premium: \(error)")
            return false
        }
    }

    // MARK: - Offerings

    @MainActor
    func fetchOfferings() async {
        do {
            let offerings = try await Purchases.shared.offerings()
            self.offerings = offerings

            if let current = offerings.current {
                self.currentPackages = current.availablePackages
            }
        } catch {
            print("[RevenueCat] Error fetching offerings: \(error)")
        }
    }

    func weeklyPackage() -> Package? {
        currentPackages.first { $0.packageType == .weekly }
    }

    func annualPackage() -> Package? {
        currentPackages.first { $0.packageType == .annual }
    }

    // MARK: - Purchase

    @MainActor
    func purchase(package: Package) async throws -> Bool {
        let result = try await Purchases.shared.purchase(package: package)

        if result.customerInfo.entitlements["premium"]?.isActive == true {
            isSubscribed = true
            return true
        }

        return false
    }

    // MARK: - Restore

    @MainActor
    func restorePurchases() async throws -> Bool {
        let customerInfo = try await Purchases.shared.restorePurchases()
        isSubscribed = customerInfo.entitlements["premium"]?.isActive == true
        return isSubscribed
    }
}
