import Foundation
import RevenueCat
import StoreKit

extension Notification.Name {
    static let revenueCatPurchaseCompleted = Notification.Name("revenueCatPurchaseCompleted")
}

/// RevenueCat subscription management
/// Handles purchases, entitlement checks, and subscription sync with Supabase
final class RevenueCatService: ObservableObject {
    static let shared = RevenueCatService()
    private let premiumEntitlementID = "premium"

    @Published var isSubscribed = false
    @Published var offerings: Offerings?
    @Published var currentPackages: [Package] = []
    private var configuredAppUserId: String?
    private var hasConfigured = false
    
    // Coin balance (local only - synced with AppState)
    @Published var coinBalance: Int = 0

    // Product IDs from ASC (correct IDs as of API check)
    private enum ProductID {
        // Subscriptions - Correct RevenueCat IDs
        // Intro weekly: grooveai_weekly_799 → prodbe0274a44a (Weekly with intro)
        // Weekly (no intro): grooveai_weekly_999 → prodbe0274a44a  
        // Annual: grooveai_annual_9999 → prod7b6b006573 (Annual 85% Off)
        static let weeklyIntro = "grooveai_weekly_799"
        static let weekly = "grooveai_weekly_999"
        static let annual = "grooveai_annual_9999"
        
        // Coins (consumables)
        static let coinsSmall = "grooveai_coins_small"
        static let coinsMedium = "grooveai_coins_medium"
        static let coinsLarge = "grooveai_coins_large"
    }

    // RevenueCat public key - loaded from environment/build config
    // Note: RevenueCat public keys are designed to be safe in client-side code
    private var apiKey: String {
        // Check Info.plist first (recommended for production)
        if let rcKey = Bundle.main.object(forInfoDictionaryKey: "RevenueCatAPIKey") as? String, !rcKey.isEmpty {
            return rcKey
        }
        // Fallback: environment variable (CI/debug builds)
        if let envKey = ProcessInfo.processInfo.environment["REVENUECAT_API_KEY"], !envKey.isEmpty {
            return envKey
        }
        // Fallback: hardcoded public key (safe - RevenueCat designed for client-side)
        // This key is the public SDK key, not a secret
        return "appl_dmOLXuPKMXatwKYxDHjLyYfULfu"
    }
    
    /// Returns true if RevenueCat is properly configured with an API key
    var isConfigured: Bool {
        !apiKey.isEmpty
    }

    private init() {
        loadCoinBalance()
    }

    private func premiumEntitlement(from customerInfo: CustomerInfo) -> EntitlementInfo? {
        if let exactMatch = customerInfo.entitlements[premiumEntitlementID] {
            return exactMatch
        }

        return customerInfo.entitlements.all.first { key, _ in
            key.caseInsensitiveCompare(premiumEntitlementID) == .orderedSame
        }?.value
    }
    
    // MARK: - Coin Balance
    
    func loadCoinBalance() {
        coinBalance = UserDefaults.standard.integer(forKey: "groove_coins")
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

    func setCoinBalance(_ amount: Int) {
        coinBalance = amount
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
        guard !apiKey.isEmpty else {
            print("[RevenueCat] ⚠️ Skipping configuration - no API key configured")
            return
        }
        guard !hasConfigured else { return }
        
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: apiKey)
        hasConfigured = true

        // Listen for subscription changes
        Task {
            await refreshSubscriptionStatus()
        }
    }

    func configureWithUserId(_ userId: String) {
        guard !apiKey.isEmpty else {
            print("[RevenueCat] ⚠️ Skipping configuration - no API key configured")
            return
        }
        guard !(hasConfigured && configuredAppUserId == userId) else { return }
        
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: apiKey, appUserID: userId)
        configuredAppUserId = userId
        hasConfigured = true

        Task {
            await refreshSubscriptionStatus()
        }
    }

    // MARK: - Subscription Status

    @MainActor
    func refreshSubscriptionStatus() async {
        guard isConfigured else {
            print("[RevenueCat] Skipping refresh - not configured")
            return
        }
        
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            let activeEntitlementKeys = customerInfo.entitlements.active.keys.sorted()
            let premiumIsActive = premiumEntitlement(from: customerInfo)?.isActive == true
            print("[RevenueCat] refreshSubscriptionStatus activeEntitlements=\(activeEntitlementKeys) premiumActive=\(premiumIsActive)")
            isSubscribed = premiumIsActive
        } catch {
            print("[RevenueCat] Error fetching customer info: \(error)")
        }
    }

    func checkPremium() async -> Bool {
        guard isConfigured else {
            print("[RevenueCat] Skipping premium check - not configured")
            return false
        }
        
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            let activeEntitlementKeys = customerInfo.entitlements.active.keys.sorted()
            let premiumIsActive = premiumEntitlement(from: customerInfo)?.isActive ?? false
            print("[RevenueCat] checkPremium activeEntitlements=\(activeEntitlementKeys) premiumActive=\(premiumIsActive)")
            return premiumIsActive
        } catch {
            print("[RevenueCat] Error checking premium: \(error)")
            return false
        }
    }

    // MARK: - Offerings

    @MainActor
    func fetchOfferings() async {
        guard isConfigured else {
            print("[RevenueCat] Skipping offerings fetch - not configured")
            return
        }
        
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
    
    /// Returns weekly package with intro discount ($7.99 intro, then $9.99/week)
    /// Prefers grooveai_weekly_799 (Special Offer with intro discount)
    func weeklyPackage() -> Package? {
        let targetProductID = "grooveai_weekly_799"
        
        // 1. Exact product ID match (preferred)
        if let exact = currentPackages.first(where: {
            $0.storeProduct.productIdentifier == targetProductID
        }) {
            print("[WeeklyPkg] ✅ Exact match: \(exact.storeProduct.productIdentifier) | intro: \(exact.storeProduct.introductoryDiscount?.price ?? -1) | base: \(exact.storeProduct.price)")
            return exact
        }
        // 2. Fallback: any weekly package with intro discount
        if let withIntro = currentPackages.first(where: { 
            $0.storeProduct.introductoryDiscount != nil && $0.packageType == .weekly 
        }) {
            print("[WeeklyPkg] ⚠️ Fallback intro weekly: \(withIntro.storeProduct.productIdentifier) | intro: \(withIntro.storeProduct.introductoryDiscount?.price ?? -1) | base: \(withIntro.storeProduct.price)")
            return withIntro
        }
        // 3. Fallback: any weekly package
        let fallback = currentPackages.first { $0.packageType == .weekly }
        print("[WeeklyPkg] ⚠️ Generic weekly fallback: \(fallback?.storeProduct.productIdentifier ?? "nil") | base: \(fallback?.storeProduct.price ?? -1)")
        return fallback
    }
    
    /// Returns annual package ($79.99/year)
    func annualPackage() -> Package? {
        currentPackages.first { $0.packageType == .annual }
    }
    
    // MARK: - Purchase

    @MainActor
    func purchase(package: Package) async throws -> Bool {
        guard isConfigured else {
            print("[RevenueCat] Skipping purchase - not configured")
            return false
        }

        print("[RevenueCat] Starting purchase package=\(package.identifier) product=\(package.storeProduct.productIdentifier)")
        let result = try await Purchases.shared.purchase(package: package)
        let activeEntitlementKeys = result.customerInfo.entitlements.active.keys.sorted()
        let premiumIsActive = premiumEntitlement(from: result.customerInfo)?.isActive == true
        let activeSubscriptions = result.customerInfo.activeSubscriptions.sorted()

        print("[RevenueCat] Purchase completed product=\(package.storeProduct.productIdentifier) activeEntitlements=\(activeEntitlementKeys) activeSubscriptions=\(activeSubscriptions) premiumActive=\(premiumIsActive)")

        if premiumIsActive {
            isSubscribed = true
            print("[RevenueCat] Purchase returning success=true — posting sync notification")
            
            // Notify AppState to force-refresh coins from server
            // AppState listens for this and calls syncWithServer()
            NotificationCenter.default.post(name: .revenueCatPurchaseCompleted, object: nil)
            
            return true
        }

        print("[RevenueCat] Purchase returning success=false")
        return false
    }

    // MARK: - Restore

    @MainActor
    func restorePurchases() async throws -> Bool {
        guard isConfigured else {
            print("[RevenueCat] Skipping restore - not configured")
            return false
        }

        let customerInfo = try await Purchases.shared.restorePurchases()
        let activeEntitlementKeys = customerInfo.entitlements.active.keys.sorted()
        let premiumIsActive = premiumEntitlement(from: customerInfo)?.isActive == true
        print("[RevenueCat] restorePurchases activeEntitlements=\(activeEntitlementKeys) premiumActive=\(premiumIsActive)")
        isSubscribed = premiumIsActive
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
