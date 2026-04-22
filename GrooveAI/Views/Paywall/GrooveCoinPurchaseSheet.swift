// GrooveCoinPurchaseSheet.swift
// Groove AI — Coins & Packages Store
// Two-tab: Top Up (coin packs) / Plans (subscription tiers)
// Follows coins-packages-spec.md

import SwiftUI
import RevenueCat

struct GrooveCoinPurchaseSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var rcService = RevenueCatService.shared

    var onPurchaseComplete: (() -> Void)?

    enum PackageTab: String, CaseIterable {
        case topUp = "Top Up"
        case plans = "Plans"
    }

    @State private var selectedTab: PackageTab = .topUp
    @State private var selectedCoinPackage: CoinPackage = .medium
    @State private var selectedPlanTier: PlanTier = .weeklyPro550
    @State private var isPurchasing = false
    @State private var purchaseError: String?
    @State private var showCoinsInfo = false

    // Colors from spec
    private let surfaceColor = Color(hex: 0x1C1C1E)
    private let surfaceElevated = Color(hex: 0x2C2C2E)
    private let surfaceActive = Color(hex: 0x3A3A3C)
    private let textSecondarySpec = Color(hex: 0x8E8E93)
    private let textTertiary = Color(hex: 0x636366)
    private let accentBlue = Color(hex: 0x007AFF)
    private let accentPurple = Color(hex: 0xAF52DE)
    private let accentAmber = Color(hex: 0xFF9F0A)
    private let accentIndigo = Color(hex: 0x5E5CE6)
    private let accentGreen = Color(hex: 0x30D158)

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Nav bar
                navBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Hero coin
                        heroSection
                            .padding(.top, 24)

                        // Headline
                        Text(selectedTab == .topUp ? "Top Up Your Coins" : "Choose Your Plan")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.top, 16)

                        // Tab toggle
                        tabToggle
                            .padding(.top, 20)

                        // Content
                        if selectedTab == .topUp {
                            topUpContent
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        } else {
                            plansContent
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }
                }

                // Error
                if let error = purchaseError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(Color.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 4)
                }

                // CTA
                ctaButton
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                // Legal footer
                legalFooter
                    .padding(.top, 12)
                    .padding(.bottom, 8)
            }
        }
        .task {
            await rcService.fetchOfferings()
            await rcService.fetchCoinProducts()
        }
        .sheet(isPresented: $showCoinsInfo) {
            coinsInfoSheet
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(surfaceColor)
        }
    }

    // MARK: - Nav Bar

    private var navBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.5))
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Circle())
            }

            Spacer()

            Button { showCoinsInfo = true } label: {
                Text("What are coins?")
                    .font(.system(size: 14))
                    .foregroundStyle(textSecondarySpec)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Hero

    private var heroSection: some View {
        ZStack {
            Circle()
                .fill(Color(hex: 0xF59E0B).opacity(0.12))
                .frame(width: 100, height: 100)
                .blur(radius: 20)

            Text("🪙")
                .font(.system(size: 72))
                .shadow(color: .black.opacity(0.6), radius: 8, y: 4)
        }
        .frame(width: 88, height: 88)
    }

    // MARK: - Tab Toggle

    private var tabToggle: some View {
        HStack(spacing: 0) {
            ForEach(PackageTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        selectedTab = tab
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(selectedTab == tab ? .white : textSecondarySpec)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(
                            selectedTab == tab ? surfaceActive : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 19))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .frame(width: 220)
        .background(surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 19))
    }

    // MARK: - Top Up Content

    private var topUpContent: some View {
        VStack(spacing: 0) {
            // Balance info card
            coinBalanceCard
                .padding(.top, 24)
                .padding(.horizontal, 16)

            // Package cards
            packageCardsRow
                .padding(.top, 24)
                .padding(.horizontal, 16)

        }
    }

    // MARK: - Coin Balance Card

    private var coinBalanceCard: some View {
        VStack(spacing: 0) {
            // Balance row
            HStack {
                Text("Your Coins")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)

                Spacer()

                // Balance pill
                HStack(spacing: 4) {
                    Text("🪙")
                        .font(.system(size: 18))
                    Text("\(coinBalance)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color(hex: 0x1C1C1E))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(hex: 0xF5F5F0))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Divider
            Rectangle()
                .fill(surfaceElevated)
                .frame(height: 1)
                .padding(.top, 14)

            // Context text
            VStack(spacing: 6) {
                Text("Running low? Top up to keep creating.")
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                if appState.isSubscribed {
                    Text("Your weekly coins refill every Monday.")
                        .font(.system(size: 13))
                        .foregroundStyle(textSecondarySpec)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.top, 14)
        }
        .padding(18)
        .background(surfaceColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var coinBalance: Int {
        appState.serverCoins ?? rcService.coinBalance
    }

    // MARK: - Package Cards Row

    private var packageCardsRow: some View {
        HStack(spacing: 10) {
            ForEach(CoinPackage.allCases, id: \.self) { pkg in
                packageCard(pkg)
            }
        }
    }

    @ViewBuilder
    private func packageCard(_ pkg: CoinPackage) -> some View {
        let isSelected = selectedCoinPackage == pkg
        let cardWidth = (UIScreen.main.bounds.width - 32 - 20) / 3

        Button {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                selectedCoinPackage = pkg
            }
        } label: {
            VStack(spacing: 0) {
                // Coin icon
                Text(pkg.coinEmoji)
                    .font(.system(size: 28))
                    .padding(.top, 14)

                // Amount
                Text("\(pkg.coins)")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.top, 6)

                Text("coins")
                    .font(.system(size: 13))
                    .foregroundStyle(textSecondarySpec)
                    .padding(.top, 2)

                // Divider
                Rectangle()
                    .fill(surfaceElevated)
                    .frame(height: 1)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)

                // Price
                Group {
                    if let price = rcService.localizedPrice(for: pkg) {
                        Text(price)
                    } else {
                        Text("$X.XX")
                            .redacted(reason: .placeholder)
                    }
                }
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)

                Text("one-time")
                    .font(.system(size: 12))
                    .foregroundStyle(textSecondarySpec)
                    .padding(.top, 2)
                    .padding(.bottom, 16)
            }
            .frame(width: cardWidth, height: 180)
            .background(surfaceColor)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected ? accentBlue : surfaceElevated,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .shadow(
                color: isSelected ? accentBlue.opacity(0.4) : .clear,
                radius: isSelected ? 6 : 0
            )
            .overlay(alignment: .top) {
                // Badge
                if let badge = pkg.specBadge {
                    Text(badge.text)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(badge.color)
                        .clipShape(Capsule())
                        .offset(y: -12)
                }
            }
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: isSelected)
    }

    // MARK: - Plans Content

    private var plansContent: some View {
        VStack(spacing: 0) {
            // Header subtext
            Text("Upgrade your plan to get more weekly coins")
                .font(.system(size: 15))
                .foregroundStyle(textSecondarySpec)
                .multilineTextAlignment(.center)
                .padding(.top, 16)
                .padding(.bottom, 24)

            // Plan cards
            VStack(spacing: 12) {
                ForEach(PlanTier.weeklyTiers, id: \.self) { tier in
                    planCard(tier)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private func planCard(_ tier: PlanTier) -> some View {
        let isSelected = selectedPlanTier == tier

        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                selectedPlanTier = tier
            }
        } label: {
            HStack(spacing: 12) {
                // Plan info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        let displayName = rcService.localizedDisplayName(for: tier)
                        Text(displayName ?? "Plan")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .redacted(reason: displayName == nil ? .placeholder : [])

                        if tier == .weeklyPro550 {
                            Text("POPULAR")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    LinearGradient(
                                        colors: [accentBlue, accentPurple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .clipShape(Capsule())
                        }
                    }

                    Text(tier.coinSummaryLabel)
                        .font(.system(size: 14))
                        .foregroundStyle(textSecondarySpec)
                }

                Spacer()

                // Price
                VStack(alignment: .trailing, spacing: 2) {
                    let priceStr = rcService.localizedPrice(for: tier)
                    Text(priceStr ?? "$XX.XX")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .redacted(reason: priceStr == nil ? .placeholder : [])
                }

                // Selection radio
                Circle()
                    .fill(isSelected ? accentBlue : Color.clear)
                    .frame(width: 22, height: 22)
                    .overlay(
                        Circle()
                            .stroke(isSelected ? accentBlue : surfaceElevated, lineWidth: 2)
                    )
                    .overlay {
                        if isSelected {
                            Circle()
                                .fill(.white)
                                .frame(width: 8, height: 8)
                        }
                    }
            }
            .padding(18)
            .background(surfaceColor)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected ? accentBlue : surfaceElevated,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .shadow(
                color: isSelected ? accentBlue.opacity(0.4) : .clear,
                radius: isSelected ? 6 : 0
            )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: isSelected)
    }

    // MARK: - CTA Button

    private var ctaButton: some View {
        Button {
            handlePurchase()
        } label: {
            VStack(spacing: 2) {
                if isPurchasing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(ctaLabel)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)

                    Text(ctaSubtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.white.opacity(0.75))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                LinearGradient(
                    colors: [accentBlue, accentPurple],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(isPurchasing)
    }

    private var ctaLabel: String {
        switch selectedTab {
        case .topUp:
            return "Get \(selectedCoinPackage.coins) Coins"
        case .plans:
            let name = rcService.localizedDisplayName(for: selectedPlanTier) ?? "Plan"
            return "Upgrade to \(name)"
        }
    }

    private var ctaSubtitle: String {
        switch selectedTab {
        case .topUp:
            return rcService.localizedPrice(for: selectedCoinPackage) ?? "Loading..."
        case .plans:
            return rcService.localizedPrice(for: selectedPlanTier) ?? "Loading..."
        }
    }

    // MARK: - Legal Footer

    private var legalFooter: some View {
        VStack(spacing: 8) {
            Text(selectedTab == .topUp
                 ? "One-time purchase. Coins don't expire."
                 : "Subscription billed automatically until canceled.")
                .font(.system(size: 12))
                .foregroundStyle(textTertiary)
                .multilineTextAlignment(.center)

            HStack(spacing: 4) {
                Text("Terms")
                    .font(.system(size: 13))
                    .foregroundStyle(textTertiary)
                Text("·")
                    .foregroundStyle(textTertiary)
                Text("Privacy")
                    .font(.system(size: 13))
                    .foregroundStyle(textTertiary)
                Text("·")
                    .foregroundStyle(textTertiary)
                Button("Restore Purchases") {
                    Task {
                        let _ = await rcService.restorePurchasesAsync()
                    }
                }
                .font(.system(size: 13))
                .foregroundStyle(textTertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Coins Info Sheet

    private var coinsInfoSheet: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("What are Coins?")
                .font(.title2.bold())
                .foregroundStyle(.white)
                .padding(.top, 24)

            infoRow(icon: "circle.fill", color: Color(hex: 0xF59E0B), text: "Coins are used for premium creation features")
            infoRow(icon: "wand.and.stars", color: accentBlue, text: "Top up anytime to keep creating")
            infoRow(icon: "arrow.clockwise", color: accentGreen, text: "Subscribers get weekly coin refills every Monday")
            infoRow(icon: "infinity", color: accentPurple, text: "Purchased coins never expire")

            Spacer()
        }
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private func infoRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
                .frame(width: 28)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.white)
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
                case .topUp:
                    let success = try await RevenueCatService.shared.purchaseCoins(selectedCoinPackage)
                    guard success else {
                        await MainActor.run {
                            isPurchasing = false
                        }
                        return
                    }

                    guard let userId = appState.userId else {
                        await MainActor.run {
                            purchaseError = "Purchase succeeded, but no user ID was available to sync coins."
                            isPurchasing = false
                        }
                        return
                    }

                    _ = try await SupabaseService.shared.addCoins(
                        userId: userId,
                        amount: selectedCoinPackage.coins,
                        type: "purchase"
                    )
                    let updatedCoins = try await CoinsService.getBalance(userId: userId)

                    await MainActor.run {
                        RevenueCatService.shared.setCoinBalance(updatedCoins)
                        appState.serverCoins = updatedCoins
                        isPurchasing = false
                        onPurchaseComplete?()
                        dismiss()
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

// MARK: - CoinPackage Spec Extensions

extension CoinPackage {
    struct BadgeSpec {
        let text: String
        let color: Color
    }

    var specBadge: BadgeSpec? {
        switch self {
        case .small:  return nil
        case .medium: return BadgeSpec(text: "Best Value", color: Color(hex: 0xFF9F0A))
        case .large:  return BadgeSpec(text: "Most Coins", color: Color(hex: 0x5E5CE6))
        }
    }

    var coinEmoji: String {
        switch self {
        case .small:  return "🪙"
        case .medium: return "🪙🪙"
        case .large:  return "🪙🪙🪙"
        }
    }
}

#Preview {
    GrooveCoinPurchaseSheet()
        .environment(AppState())
}
