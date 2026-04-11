// PlanTier.swift
// Groove AI — Subscription plan tiers

import Foundation
import RevenueCat

enum PlanTier: String, CaseIterable, Hashable {
    case basic
    case pro
    case annual

    var name: String {
        switch self {
        case .basic:  return "Starter"
        case .pro:    return "Pro"
        case .annual: return "Annual"
        }
    }

    var priceLabel: String {
        switch self {
        case .basic:  return "$9.99/wk"
        case .pro:    return "$9.99/wk"
        case .annual: return "$79.99/yr"
        }
    }

    var coinsPerWeek: Int {
        switch self {
        case .basic:  return 150
        case .pro:    return 300
        case .annual: return 500
        }
    }

    var ctaLabel: String {
        switch self {
        case .basic:  return "Start Starter — \(priceLabel)"
        case .pro:    return "Start Pro — \(priceLabel)"
        case .annual: return "Start Annual — \(priceLabel)"
        }
    }

    /// Weekly-only tiers for the coin purchase plans tab
    static var weeklyTiers: [PlanTier] {
        [.basic, .pro]
    }

    func resolvePackage(from rc: RevenueCatService) -> Package? {
        switch self {
        case .basic:  return rc.weeklyPackage()
        case .pro:    return rc.weeklyPackage()
        case .annual: return rc.annualPackage()
        }
    }
}
