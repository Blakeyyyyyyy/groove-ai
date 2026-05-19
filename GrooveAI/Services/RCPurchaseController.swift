import SuperwallKit
import RevenueCat

final class RCPurchaseController: PurchaseController {

    /// Map RevenueCat's active entitlement IDs into the Set<Entitlement>
    /// SuperwallKit 4.x requires on `SubscriptionStatus.active`.
    private func subscriptionStatus(from customerInfo: RevenueCat.CustomerInfo) -> SubscriptionStatus {
        let activeIds = customerInfo.entitlements.active.keys
        guard !activeIds.isEmpty else { return .inactive }
        let entitlements = Set(activeIds.map { Entitlement(id: $0) })
        return .active(entitlements)
    }

    func syncSubscriptionStatus() {
        Task {
            for await customerInfo in Purchases.shared.customerInfoStream {
                let status = subscriptionStatus(from: customerInfo)
                await MainActor.run {
                    Superwall.shared.subscriptionStatus = status
                    RevenueCatService.shared.applyCustomerInfo(customerInfo)
                }
            }
        }
    }

    @MainActor
    func purchase(product: SuperwallKit.StoreProduct) async -> PurchaseResult {
        guard let sk2Product = product.sk2Product else {
            return .failed(SuperwallPurchaseError.productUnavailable)
        }
        do {
            let (_, customerInfo, userCancelled) = try await Purchases.shared.purchase(
                product: RevenueCat.StoreProduct(sk2Product: sk2Product)
            )
            if userCancelled { return .cancelled }
            guard !customerInfo.entitlements.active.isEmpty else {
                return .failed(SuperwallPurchaseError.unknown)
            }
            NotificationCenter.default.post(name: .purchaseCompleted, object: nil)
            return .purchased
        } catch {
            return .failed(error)
        }
    }

    @MainActor
    func restorePurchases() async -> RestorationResult {
        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            guard !customerInfo.entitlements.active.isEmpty else {
                return .failed(SuperwallPurchaseError.unknown)
            }
            NotificationCenter.default.post(name: .purchaseCompleted, object: nil)
            return .restored
        } catch {
            return .failed(error)
        }
    }
}

extension Notification.Name {
    static let purchaseCompleted = Notification.Name("GrooveAI.purchaseCompleted")
}

enum SuperwallPurchaseError: Error {
    case productUnavailable
    case unknown
}
