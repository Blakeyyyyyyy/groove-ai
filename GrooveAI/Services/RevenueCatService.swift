import Foundation
import RevenueCat
import StoreKit

/// RevenueCat subscription management
/// Handles purchases, entitlement checks, and subscription sync with Supabase
final class RevenueCatService: ObservableObject {
    static let shared = RevenueCatService()

    @Published var isSubscribed = false
    @Published var offerings: Offerings?
    @Published var currentPackages: [Package] = []
    
    // Coin balance (local only - synced with AppState)
    @Published var coinBalance: Int = 150

    // Product IDs from ASC
    private enum ProductID {
        // Subscriptions
        static let weekly = "grooveai_weekly_999"
        static let weeklyIntro = "grooveai_weekly_799"
        static let annual = "grooveai_annual_9999"
        
        // Coins (consumables)
        static let coinsSmall = "grooveai_coins_small"
        static let coinsMedium = "grooveai_coins_medium"
        static let coinsLarge = "grooveai_coins_large"
    }

    private let apiKey = "test_asPwPLcWptxFPXSHMcdieXUETYM"

    private init() {
        loadCoinBalance()
    }
    
    // MARK: - Coin Balance
    
    func loadCoinBalance() {
        coinBalance = UserDefaults.standard.integer(forKey: "groove_coins")
        if coinBalance == 0 {
            coinBalance = 150  // Default starting coins
            saveCoinBalance()
        }
    }
    
    func saveCoinBalance() {
        UserDefaults.standard.set(coinBalance, forKey: "groove_coins")
    }
    
    func getCoinBalance() -> Int {
        return coinBalance
    }
    
    func addCoins(_ amount: Int) {
        coinBalance += amount
        saveCoinBalance()
    }
    
    func spendCoins(_ amount: Int) -> Bool {
        guard coinBalance >= amount else { return false }
        coinBalance -= amount
        saveCoinBalance()
        return true
    }

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

    // MARK: - Package Helpers (per spec product IDs)
    
    /// Returns weekly package ($9.99/week)
    func weeklyPackage() -> Package? {
        currentPackages.first { $0.packageType == .weekly }
    }
    
    /// Returns annual package ($79.99/year)
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
    
    /// Legacy aliases for backward compatibility
    func basicWeeklyPackage() -> Package? {
        // grooveai_weekly_999 → $9.99/week
        currentPackages.first { $0.identifier == ProductID.weekly }
            ?? currentPackages.first { $0.packageType == .weekly }
    }
    
    func goldWeeklyPackage() -> Package? {
        // Currently maps to weekly - in production would be different product
        currentPackages.first { $0.packageType == .weekly }
    }
    
    func vipWeeklyPackage() -> Package? {
        // Currently maps to weekly - in production would be different product
        currentPackages.first { $0.packageType == .weekly }
    }
    
    // MARK: - Coin Purchases (StoreKit consumables)
    
    /// Purchase coin pack - uses StoreKit 2 directly
    func purchaseCoins(_ package: CoinPackage) async throws -> Bool {
        let products = try await Product.products(for: [package.productID])
        guard let product = products.first else {
            throw PurchaseError.productNotFound
        }
        
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try verification.payloadValue
            addCoins(package.coins)
            await transaction.finish()
            return true
        case .userCancelled:
            return false
        case .pending:
            throw PurchaseError.pendingApproval
        @unknown default:
            return false
        }
    }
    
    /// Restore purchases (for subscriptions)
    func restorePurchasesAsync() async -> Bool {
        do {
            return try await restorePurchases()
        } catch {
            print("[RevenueCat] Restore failed: \(error)")
            return false
        }
    }
    
    // MARK: - Entitlements
    
    /// Check if user has active premium subscription
    var isPremium: Bool {
        isSubscribed
    }
}

// MARK: - Coin Package Model

enum CoinPackage: CaseIterable {
    case small   // 180 coins, $9.99
    case medium  // 400 coins, $19.99 (pre-select)
    case large   // 800 coins, $34.99
    
    var productID: String {
        switch self {
        case .small:  return "grooveai_coins_small"
        case .medium: return "grooveai_coins_medium"
        case .large:  return "grooveai_coins_large"
        }
    }
    
    var coins: Int {
        switch self {
        case .small:  return 180
        case .medium: return 400
        case .large:  return 800
        }
    }
    
    var price: String {
        switch self {
        case .small:  return "$9.99"
        case .medium: return "$19.99"
        case .large:  return "$34.99"
        }
    }
    
    var dances: Int {
        coins / 60  // 60 coins per dance
    }
    
    var badge: String? {
        self == .medium ? "BEST VALUE" : nil
    }
}

// MARK: - Purchase Errors

enum PurchaseError: LocalizedError {
    case productNotFound
    case pendingApproval
    case purchaseFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .productNotFound:
            return "Product not available. Please try again."
        case .pendingApproval:
            return "Purchase pending approval."
        case .purchaseFailed(let msg):
            return msg
        }
    }
}
