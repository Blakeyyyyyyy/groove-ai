import Foundation
import CoreGraphics
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
    @Published var activeSubscriptionProductID: String?
    @Published var subscriptionRenewalDate: Date?
    @Published var coinProducts: [String: Product] = [:]
    private var configuredAppUserId: String?
    private var hasConfigured = false
    
    // Coin balance (local only - synced with AppState)
    @Published var coinBalance: Int = 0

    // Product IDs from ASC — prices are set in App Store Connect, never hardcoded
    private enum ProductID {
        // Weekly Subscriptions (with weekly coin allocation)
        static let weeklyBasic = "grooveai_weekly_300"      // 300 coins/week
        static let weeklyStandard = "grooveai_weekly_550"   // 550 coins/week
        static let weeklyPremium = "grooveai_weekly_1200"   // 1200 coins/week
        
        // Annual Subscription
        static let annual = "grooveai_annual_9999"
        
        // Coins (one-time purchases)
        static let coinsSmall = "grooveai_coins_small"    // 100 coins
        static let coinsMedium = "grooveai_coins_medium"  // 300 coins
        static let coinsLarge = "grooveai_coins_large"    // 600 coins
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
    
    /// Returns true if the RevenueCat SDK has been configured with an API key.
    var isConfigured: Bool {
        hasConfigured && !apiKey.isEmpty
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

    @MainActor
    private func applyCustomerInfo(_ customerInfo: CustomerInfo) {
        let premiumIsActive = premiumEntitlement(from: customerInfo)?.isActive == true
        isSubscribed = premiumIsActive
        activeSubscriptionProductID = Array(customerInfo.activeSubscriptions).first
        subscriptionRenewalDate = customerInfo.latestExpirationDate
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
            applyCustomerInfo(customerInfo)
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
            await MainActor.run {
                self.applyCustomerInfo(customerInfo)
            }
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

            print("[RevenueCat] 📋 fetchOfferings completed")
            print("[RevenueCat]    offerings.current = \(offerings.current?.identifier ?? "nil")")
            print("[RevenueCat]    currentPackages count = \(self.currentPackages.count)")
            if !self.currentPackages.isEmpty {
                let ids = self.currentPackages.map { $0.storeProduct.productIdentifier }.joined(separator: ", ")
                print("[RevenueCat]    product IDs: \(ids)")
            }
        } catch {
            print("[RevenueCat] Error fetching offerings: \(error)")
        }
    }

    @MainActor
    func fetchCoinProducts() async {
        do {
            let products = try await Product.products(for: [
                ProductID.coinsSmall,
                ProductID.coinsMedium,
                ProductID.coinsLarge
            ])
            var mapped: [String: Product] = [:]
            for product in products {
                mapped[product.id] = product
            }
            coinProducts = mapped
        } catch {
            print("[RevenueCat] Error fetching coin products: \(error)")
        }
    }

    // MARK: - Package Helpers (per spec product IDs)
    
    /// Returns weekly package with intro discount (if available).
    /// Prefers grooveai_weekly_799 (Special Offer with intro discount)
    func weeklyPackage() -> Package? {
        print("[RevenueCat] 🔍 weeklyPackage() called")
        print("[RevenueCat]    currentPackages count = \(currentPackages.count)")
        print("[RevenueCat]    looking for targetProductID: grooveai_weekly_799")

        let targetProductID = "grooveai_weekly_799"

        // 1. Exact product ID match (preferred)
        if let exact = currentPackages.first(where: {
            $0.storeProduct.productIdentifier == targetProductID
        }) {
            print("[RevenueCat]    ✅ Found exact: \(exact.storeProduct.productIdentifier)")
            print("[WeeklyPkg] ✅ Exact match: \(exact.storeProduct.productIdentifier) | intro: \(exact.storeProduct.introductoryDiscount?.price ?? -1) | base: \(exact.storeProduct.price)")
            return exact
        }
        // 2. Fallback: any weekly package with intro discount
        if let withIntro = currentPackages.first(where: {
            $0.storeProduct.introductoryDiscount != nil && $0.packageType == .weekly
        }) {
            print("[RevenueCat]    ⚠️ Found intro weekly: \(withIntro.storeProduct.productIdentifier)")
            print("[WeeklyPkg] ⚠️ Fallback intro weekly: \(withIntro.storeProduct.productIdentifier) | intro: \(withIntro.storeProduct.introductoryDiscount?.price ?? -1) | base: \(withIntro.storeProduct.price)")
            return withIntro
        }
        // 3. Fallback: any weekly package
        let fallback = currentPackages.first { $0.packageType == .weekly }
        if let fallback = fallback {
            print("[RevenueCat]    ⚠️ Generic fallback: \(fallback.storeProduct.productIdentifier)")
        } else {
            print("[RevenueCat]    ❌ No weekly packages found")
        }
        print("[WeeklyPkg] ⚠️ Generic weekly fallback: \(fallback?.storeProduct.productIdentifier ?? "nil") | base: \(fallback?.storeProduct.price ?? -1)")
        return fallback
    }
    
    /// Returns the Special Offer package (grooveai_weekly_special) used by the
    /// exit-intent modal (GrooveSpecialOfferPaywallV2). Falls back to the
    /// standard weekly package if the special-offer SKU isn't loaded.
    func specialOfferPackage() -> Package? {
        let targetProductID = "grooveai_weekly_special"
        print("[RevenueCat] 🎁 specialOfferPackage() called, looking for: \(targetProductID)")

        if let exact = currentPackages.first(where: {
            $0.storeProduct.productIdentifier == targetProductID
        }) {
            print("[RevenueCat]    ✅ Found special offer: \(exact.storeProduct.productIdentifier)")
            return exact
        }

        print("[RevenueCat]    ⚠️ \(targetProductID) not in offerings — falling back to weeklyPackage()")
        return weeklyPackage()
    }

    /// Returns annual package if available.
    func annualPackage() -> Package? {
        print("[RevenueCat] 🔍 annualPackage() called, currentPackages count = \(currentPackages.count)")

        if let annual = currentPackages.first(where: { $0.packageType == .annual }) {
            print("[RevenueCat]    ✅ Found annual: \(annual.storeProduct.productIdentifier)")
            return annual
        }

        print("[RevenueCat]    ❌ No annual package found")
        return nil
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
            applyCustomerInfo(result.customerInfo)
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
        applyCustomerInfo(customerInfo)
        return isSubscribed
    }
    
    // MARK: - Weekly Subscription Package Helpers
    
    /// Weekly Basic: 300 coins per week. Returns nil if product not found.
    func weeklyBasicPackage() -> Package? {
        currentPackages.first { $0.storeProduct.productIdentifier == ProductID.weeklyBasic }
    }
    
    /// Weekly Standard: 550 coins per week (recommended). Returns nil if product not found.
    func weeklyStandardPackage() -> Package? {
        currentPackages.first { $0.storeProduct.productIdentifier == ProductID.weeklyStandard }
    }
    
    /// Weekly Premium: 1200 coins per week. Returns nil if product not found.
    func weeklyPremiumPackage() -> Package? {
        currentPackages.first { $0.storeProduct.productIdentifier == ProductID.weeklyPremium }
    }
    
    /// Legacy aliases for backward compatibility
    func basicWeeklyPackage() -> Package? {
        weeklyBasicPackage()
    }
    
    func goldWeeklyPackage() -> Package? {
        weeklyStandardPackage()
    }
    
    func vipWeeklyPackage() -> Package? {
        weeklyPremiumPackage()
    }

    func package(for tier: PlanTier) -> Package? {
        switch tier {
        case .weeklyStarter300:
            return weeklyBasicPackage()
        case .weeklyPro550:
            return weeklyStandardPackage()
        case .weeklyMax1200:
            return weeklyPremiumPackage()
        case .annual:
            return annualPackage()
        }
    }

    /// Returns the StoreKit localized title for this tier, or nil if the package isn't loaded.
    func localizedDisplayName(for tier: PlanTier) -> String? {
        guard let title = package(for: tier)?.storeProduct.localizedTitle
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !title.isEmpty else {
            return nil
        }
        return title
    }

    /// Returns just the localized price amount, or nil if unavailable.
    func localizedPriceOnly(for tier: PlanTier) -> String? {
        package(for: tier)?.storeProduct.localizedPriceString
    }

    /// Returns localized price with period suffix derived from StoreKit subscription period, or nil if unavailable.
    func localizedPrice(for tier: PlanTier) -> String? {
        guard let pkg = package(for: tier) else { return nil }
        let price = pkg.storeProduct.localizedPriceString
        if let period = pkg.storeProduct.subscriptionPeriod {
            switch period.unit {
            case .day: return "\(price)/day"
            case .week: return "\(price)/wk"
            case .month: return "\(price)/mo"
            case .year: return "\(price)/yr"
            @unknown default: return price
            }
        }
        return price
    }

    /// Returns the localized display price for a coin package, or nil if the StoreKit product isn't loaded.
    func localizedPriceOnly(for package: CoinPackage) -> String? {
        coinProducts[package.productID]?.displayPrice
    }

    /// Returns the localized display price for a coin package, or nil if the StoreKit product isn't loaded.
    func localizedPrice(for package: CoinPackage) -> String? {
        localizedPriceOnly(for: package)
    }
    
    // MARK: - Coin Purchases (StoreKit consumables)
    
    /// Purchase coin pack - uses StoreKit 2 directly
    func purchaseCoins(_ package: CoinPackage) async throws -> (success: Bool, jws: String?) {
        let products = try await Product.products(for: [package.productID])
        guard let product = products.first else {
            throw PurchaseError.productNotFound
        }

        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try verification.payloadValue
            // Extract the JWS token (jwsRepresentation) from the verification result
            let jws = verification.jwsRepresentation
            await transaction.finish()
            return (success: true, jws: jws)
        case .userCancelled:
            return (success: false, jws: nil)
        case .pending:
            throw PurchaseError.pendingApproval
        @unknown default:
            return (success: false, jws: nil)
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

    var subscriptionPlanName: String {
        switch activeSubscriptionProductID {
        case ProductID.annual:
            return "Annual"
        case ProductID.weeklyBasic, ProductID.weeklyStandard, ProductID.weeklyPremium:
            return "Weekly"
        default:
            return "Subscription"
        }
    }

    var subscriptionStatusLine: String {
        guard isSubscribed else { return "Inactive" }
        guard let renewalDate = subscriptionRenewalDate else { return "Active" }
        return "Active • Renews \(Self.subscriptionDateFormatter.string(from: renewalDate))"
    }

    var refillStatusLine: String {
        guard let renewalDate = subscriptionRenewalDate else { return "Refill date unavailable" }
        let days = Self.daysUntil(renewalDate)

        if days <= 0 { return "Your plan refills today" }
        if days == 1 { return "Your plan refills in 1 day" }
        return "Your plan refills in \(days) days"
    }

    var refillCountdownLabel: String? {
        guard let renewalDate = subscriptionRenewalDate else { return nil }
        let days = Self.daysUntil(renewalDate)
        return days <= 0 ? "Today" : "\(days)d"
    }

    var refillProgressFraction: CGFloat {
        guard let renewalDate = subscriptionRenewalDate else { return 0 }
        let cycleDays: Double = activeSubscriptionProductID == ProductID.annual ? 365 : 7
        let secondsRemaining = max(0, renewalDate.timeIntervalSinceNow)
        let progress = 1 - min(1, secondsRemaining / (cycleDays * 24 * 60 * 60))
        return CGFloat(progress)
    }

    private static func daysUntil(_ date: Date) -> Int {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfTarget = calendar.startOfDay(for: date)
        return calendar.dateComponents([.day], from: startOfToday, to: startOfTarget).day ?? 0
    }

    private static let subscriptionDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}

// MARK: - Coin Package Model

/// CoinPackage is an ID-only model for looking up StoreKit products.
/// Display prices MUST come from StoreKit — never hardcoded here.
enum CoinPackage: CaseIterable {
    case small   // 100 coins
    case medium  // 300 coins (pre-select)
    case large   // 600 coins
    
    var productID: String {
        switch self {
        case .small:  return "grooveai_coins_small"
        case .medium: return "grooveai_coins_medium"
        case .large:  return "grooveai_coins_large"
        }
    }
    
    /// Internal coin amount — app-defined, not a store price.
    var coins: Int {
        switch self {
        case .small:  return 100
        case .medium: return 300
        case .large:  return 600
        }
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
