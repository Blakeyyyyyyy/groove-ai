import Foundation
import RevenueCat

/// PlanTier is an ID-only model for looking up RevenueCat packages.
/// Display names and prices MUST come from RevenueCat/StoreKit — never hardcoded here.
enum PlanTier: String, CaseIterable, Hashable {
    case weeklyStarter300
    case weeklyPro550
    case weeklyMax1200
    case annual

    /// Internal coin allocation per billing cycle.
    /// These are app-defined feature quotas, NOT store prices.
    var coinAmount: Int {
        switch self {
        case .weeklyStarter300: return 300
        case .weeklyPro550: return 550
        case .weeklyMax1200: return 1200
        case .annual: return 250
        }
    }

    var coinSummaryLabel: String {
        switch self {
        case .annual:
            return "\(coinAmount) coins / year"
        default:
            return "\(coinAmount) coins / week"
        }
    }

    /// Number of coin emojis to display in plan cards (1/2/3 matching tier level).
    var coinCount: Int {
        switch self {
        case .weeklyStarter300: return 1
        case .weeklyPro550:     return 2
        case .weeklyMax1200:    return 3
        case .annual:           return 1
        }
    }

    static var weeklyTiers: [PlanTier] {
        [.weeklyStarter300, .weeklyPro550, .weeklyMax1200]
    }

    func resolvePackage(from rc: RevenueCatService) -> Package? {
        switch self {
        case .weeklyStarter300:
            return rc.weeklyBasicPackage()
        case .weeklyPro550:
            return rc.weeklyStandardPackage()
        case .weeklyMax1200:
            return rc.weeklyPremiumPackage()
        case .annual:
            return rc.annualPackage()
        }
    }
}
