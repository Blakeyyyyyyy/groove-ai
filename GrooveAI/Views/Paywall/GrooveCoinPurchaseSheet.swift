import SwiftUI
import RevenueCat

/// Bottom sheet for purchasing coins or upgrading plans.
/// Presented when user has insufficient coins for generation.
struct GrooveCoinPurchaseSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab: PurchaseTab = .coins
    @State private var selectedCoinPackage: CoinPackage = .medium
    @State private var selectedPlanTier: PlanTier = .pro
    @State private var isPurchasing = false
    @State private var purchaseError: String?

    /// Called after a successful purchase (coins or plan)
    var onPurchaseComplete: (() -> Void)?

    enum PurchaseTab: String, CaseIterable {
        case coins = "Coins"
        case plans = "Plans"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.bgElevated)
                .frame(width: 40, height: 5)
                .padding(.top, Spacing.md)

            // Header
            Text("Need More Coins")
                .font(.title2.bold())
                .foregroundStyle(Color.textPrimary)
                .padding(.top, Spacing.lg)

            // Segmented control
            segmentedControl
                .padding(.top, Spacing.lg)
                .padding(.horizontal, Spacing.lg)

            // Content
            ScrollView(showsIndicators: false) {
                switch selectedTab {
                case .coins:
                    coinsContent
                case .plans:
                    plansContent
                }
            }
            .padding(.top, Spacing.lg)

            // Error
            if let error = purchaseError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Color.error)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.sm)
            }

            // CTA
            ctaButton
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.lg)

            // Dismiss
            Button("Not Now") {
                dismiss()
            }
            .font(.subheadline)
            .foregroundStyle(Color.textTertiary)
            .frame(minHeight: 44)
            .padding(.bottom, Spacing.lg)
        }
        .background(Color.bgPrimary)
    }

    // MARK: - Segmented Control

    private var segmentedControl: some View {
        HStack(spacing: 0) {
            ForEach(PurchaseTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(AppAnimation.snappy) {
                        selectedTab = tab
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(selectedTab == tab ? .white : Color.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(
                            selectedTab == tab
                                ? AnyShapeStyle(LinearGradient.accent)
                                : AnyShapeStyle(Color.clear)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md + 3))
    }

    // MARK: - Coins Content

    private var coinsContent: some View {
        VStack(spacing: Spacing.md) {
            ForEach(CoinPackage.allCases, id: \.self) { pkg in
                coinPackageCard(pkg)
            }
        }
        .padding(.horizontal, Spacing.lg)
    }

    @ViewBuilder
    private func coinPackageCard(_ pkg: CoinPackage) -> some View {
        let isSelected = selectedCoinPackage == pkg

        Button {
            withAnimation(AppAnimation.snappy) {
                selectedCoinPackage = pkg
            }
        } label: {
            HStack(spacing: Spacing.md) {
                // Coin icon + amount
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "circle.fill")
                            .font(.caption)
                            .foregroundStyle(Color.coinGold)

                        Text("\(pkg.coins) coins")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(Color.textPrimary)

                        if let badge = pkg.badge {
                            Text(badge)
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(LinearGradient.accent)
                                .clipShape(Capsule())
                        }
                    }


                }

                Spacer()

                // Price
                Text(pkg.price)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.textPrimary)

                // Radio
                Circle()
                    .fill(isSelected ? Color.accentStart : Color.clear)
                    .frame(width: 22, height: 22)
                    .overlay(
                        Circle()
                            .stroke(isSelected ? Color.accentStart : Color.bgElevated, lineWidth: 2)
                    )
                    .overlay {
                        if isSelected {
                            Circle()
                                .fill(.white)
                                .frame(width: 8, height: 8)
                        }
                    }
            }
            .padding(Spacing.lg)
            .background(isSelected ? Color.bgSecondary : Color.bgSecondary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg)
                    .stroke(
                        isSelected ? Color.accentStart.opacity(0.8) : Color.bgElevated,
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
    }

    // MARK: - Plans Content

    private var plansContent: some View {
        VStack(spacing: Spacing.md) {
            ForEach(PlanTier.weeklyTiers, id: \.self) { tier in
                planTierCard(tier)
            }
        }
        .padding(.horizontal, Spacing.lg)
    }

    @ViewBuilder
    private func planTierCard(_ tier: PlanTier) -> some View {
        let isSelected = selectedPlanTier == tier

        Button {
            withAnimation(AppAnimation.snappy) {
                selectedPlanTier = tier
            }
        } label: {
            HStack(spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    HStack(spacing: Spacing.sm) {
                        Text(tier.name)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(Color.textPrimary)

                        if tier == .pro {
                            Text("POPULAR")
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(LinearGradient.accent)
                                .clipShape(Capsule())
                        }
                    }

                    Text("\(tier.coinsPerWeek) coins/week")
                        .font(.caption)
                        .foregroundStyle(Color.textSecondary)
                }

                Spacer()

                Text(tier.priceLabel)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.textPrimary)

                Circle()
                    .fill(isSelected ? Color.accentStart : Color.clear)
                    .frame(width: 22, height: 22)
                    .overlay(
                        Circle()
                            .stroke(isSelected ? Color.accentStart : Color.bgElevated, lineWidth: 2)
                    )
                    .overlay {
                        if isSelected {
                            Circle()
                                .fill(.white)
                                .frame(width: 8, height: 8)
                        }
                    }
            }
            .padding(Spacing.lg)
            .background(isSelected ? Color.bgSecondary : Color.bgSecondary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg)
                    .stroke(
                        isSelected ? Color.accentStart.opacity(0.8) : Color.bgElevated,
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
    }

    // MARK: - CTA Button

    @ViewBuilder
    private var ctaButton: some View {
        Button {
            handlePurchase()
        } label: {
            HStack(spacing: Spacing.sm) {
                if isPurchasing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(ctaLabel)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(LinearGradient.accent)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        }
        .buttonStyle(ScaleButtonStyle())
        .allowsHitTesting(!isPurchasing)
    }

    private var ctaLabel: String {
        switch selectedTab {
        case .coins:
            return "Add \(selectedCoinPackage.coins) Coins for \(selectedCoinPackage.price)"
        case .plans:
            return "Upgrade to \(selectedPlanTier.name)"
        }
    }

    // MARK: - Purchase

    private func handlePurchase() {
        guard !isPurchasing else { return }
        isPurchasing = true
        purchaseError = nil

        Task {
            do {
                switch selectedTab {
                case .coins:
                    let success = try await RevenueCatService.shared.purchaseCoins(selectedCoinPackage)
                    await MainActor.run {
                        isPurchasing = false
                        if success {
                            // Sync coin balance with AppState
                            appState.serverCoins = RevenueCatService.shared.coinBalance
                            onPurchaseComplete?()
                            dismiss()
                        }
                    }

                case .plans:
                    let rc = RevenueCatService.shared
                    await rc.fetchOfferings()

                    let package = selectedPlanTier.resolvePackage(from: rc)
                    guard let pkg = package else {
                        await MainActor.run {
                            purchaseError = "Plan not available. Please try again."
                            isPurchasing = false
                        }
                        return
                    }

                    let success = try await rc.purchase(package: pkg)
                    await MainActor.run {
                        isPurchasing = false
                        if success {
                            appState.isSubscribed = true
                            onPurchaseComplete?()
                            dismiss()
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    purchaseError = error.localizedDescription
                    isPurchasing = false
                }
            }
        }
    }
}

// MARK: - Plan Tier Model

enum PlanTier: CaseIterable, Hashable {
    case starter    // $14.99/wk → 250 coins/wk
    case pro        // $24.99/wk → 500 coins/wk
    case ultimate   // $34.99/wk → 800 coins/wk
    case annual     // $79.99/yr → 150 coins/wk

    /// Weekly tiers only (for coin purchase sheet plans tab)
    static var weeklyTiers: [PlanTier] {
        [.starter, .pro, .ultimate]
    }

    var name: String {
        switch self {
        case .starter:  return "Starter"
        case .pro:      return "Pro"
        case .ultimate: return "Ultimate"
        case .annual:   return "Annual"
        }
    }

    var priceLabel: String {
        switch self {
        case .starter:  return "$14.99/wk"
        case .pro:      return "$24.99/wk"
        case .ultimate: return "$34.99/wk"
        case .annual:   return "$79.99/yr"
        }
    }

    var coinsPerWeek: Int {
        switch self {
        case .starter:  return 250
        case .pro:      return 500
        case .ultimate: return 800
        case .annual:   return 150
        }
    }

    var ctaLabel: String {
        switch self {
        case .annual: return "Start Free Trial"
        default:      return "Start 3-Day Free Trial"
        }
    }

    /// Resolve to a RevenueCat Package.
    /// For now maps to existing products; update when tiered products are added to ASC.
    func resolvePackage(from rc: RevenueCatService) -> Package? {
        switch self {
        case .starter:
            // Maps to weekly intro ($7.99) as closest match for now
            return rc.currentPackages.first { $0.storeProduct.productIdentifier == "grooveai_weekly_799" }
                ?? rc.weeklyPackage()
        case .pro:
            // Maps to standard weekly ($9.99)
            return rc.weeklyPackage()
        case .ultimate:
            // Maps to weekly for now — will be separate product
            return rc.weeklyPackage()
        case .annual:
            return rc.annualPackage()
        }
    }
}

#Preview {
    GrooveCoinPurchaseSheet()
        .environment(AppState())
}
