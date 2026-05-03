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
            return "\(coinAmount) coins / month"
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

extension PlanTier {
    /// "month" for annual (coins refill monthly), "week" for weekly tiers.
    var coinPeriodWord: String {
        switch self {
        case .annual: return "month"
        default:      return "week"
        }
    }

    /// Maps a RevenueCat / StoreKit product ID back to the matching PlanTier.
    static func tier(forProductID productID: String?) -> PlanTier? {
        guard let productID else { return nil }
        switch productID {
        case "grooveai_weekly_300":  return .weeklyStarter300
        case "grooveai_weekly_550":  return .weeklyPro550
        case "grooveai_weekly_1200": return .weeklyMax1200
        case "grooveai_annual_9999": return .annual
        default:                     return nil
        }
    }
}
