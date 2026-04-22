import SwiftUI
import RevenueCat

// MARK: - Screen 5: Onboarding Paywall
// At peak emotional moment after simulated result
// All prices come from RevenueCat — no hardcoded values.
struct OnboardingPaywallView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var rcService = RevenueCatService.shared
    @State private var selectedPlan: SelectedPlan = .annual
    @State private var showExitPopup = false
    @State private var isPurchasing = false
    @State private var purchaseError: String?

    private enum SelectedPlan {
        case weekly, annual
    }

    private func log(_ message: String) {
        print("[OnboardingPaywallView] \(message)")
    }

    // MARK: - StoreKit-backed pricing

    private var weeklyPackage: Package? { rcService.weeklyPackage() }
    private var annualPackage: Package? { rcService.annualPackage() }
    private var hasProductData: Bool { weeklyPackage != nil || annualPackage != nil }

    private var weeklyPrice: String? { weeklyPackage?.storeProduct.localizedPriceString }
    private var annualPrice: String? { annualPackage?.storeProduct.localizedPriceString }

    private var annualWeeklyEquivalent: String? {
        guard let annual = annualPackage else { return nil }
        let weeklyEq = NSDecimalNumber(decimal: annual.storeProduct.price / 52).doubleValue
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = annual.storeProduct.priceFormatter?.locale ?? .current
        return formatter.string(from: NSNumber(value: weeklyEq))
    }

    private var savingsPercent: Int? {
        guard let weeklyRaw = weeklyPackage?.storeProduct.price,
              let annualRaw = annualPackage?.storeProduct.price,
              weeklyRaw > 0 else { return nil }
        let pct = (1 - (annualRaw / 52) / weeklyRaw) * 100
        let rounded = Int(NSDecimalNumber(decimal: pct).doubleValue.rounded())
        return rounded > 0 ? rounded : nil
    }

    private var trialText: String? {
        let pkg: Package? = selectedPlan == .annual ? annualPackage : weeklyPackage
        guard let intro = pkg?.storeProduct.introductoryDiscount else {
            // No intro offer — show billing period
            guard let price = (selectedPlan == .annual ? annualPrice : weeklyPrice) else { return nil }
            let period = selectedPlan == .annual ? "year" : "week"
            return "\(price)/\(period) \u{00B7} cancel anytime"
        }
        let introPrice = intro.localizedPriceString
        guard let basePrice = (selectedPlan == .annual ? annualPrice : weeklyPrice) else { return nil }
        let period = selectedPlan == .annual ? "year" : "week"
        let trialDays = intro.subscriptionPeriod.value * (intro.subscriptionPeriod.unit == .day ? 1 : intro.subscriptionPeriod.unit == .week ? 7 : 30)
        return "\(trialDays)-day trial \u{00B7} then \(basePrice)/\(period) \u{00B7} cancel anytime"
    }

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            // Subtle radial glow
            RadialGradient(
                colors: [Color.accentStart.opacity(0.06), Color.clear],
                center: .top,
                startRadius: 50,
                endRadius: 400
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: Spacing.xl) {
                    // Close button
                    HStack {
                        Spacer()
                        Button {
                            if !GrooveSpecialOfferView.hasBeenShown {
                                log("Close tapped — presenting special offer")
                                GrooveSpecialOfferView.markShown()
                                showExitPopup = true
                            } else {
                                log("Close tapped — special offer already shown, skipping paywall")
                                appState.showPaywall = false
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.title3)
                                .foregroundStyle(Color.textSecondary)
                                .frame(width: 44, height: 44)
                        }
                    }
                    .padding(.horizontal, Spacing.lg)

                    // Social proof thumbnails
                    socialProofSection

                    // Headline
                    VStack(spacing: Spacing.sm) {
                        Text("See anyone dance.")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(Color.textPrimary)

                        Text("Video ready in minutes.")
                            .font(.subheadline)
                            .foregroundStyle(Color.textSecondary)
                    }

                    // Trial CTA
                    VStack(spacing: Spacing.sm) {
                        GradientCTAButton("Start Free Trial") {
                            handleSubscribe()
                        }
                        .disabled(isPurchasing || !hasProductData)
                        .opacity(hasProductData ? 1.0 : 0.5)

                        if let trial = trialText {
                            Text(trial)
                                .font(.caption)
                                .foregroundStyle(Color.textSecondary)
                        } else {
                            Text("Loading pricing...")
                                .font(.caption)
                                .foregroundStyle(Color.textSecondary)
                                .redacted(reason: .placeholder)
                        }
                    }

                    // Error
                    if let error = purchaseError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(Color.error)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Spacing.lg)
                    }

                    // Plan cards
                    planCards

                    // Fine print
                    VStack(spacing: Spacing.xs) {
                        Text("Cancel anytime")
                            .font(.caption2)
                            .foregroundStyle(Color.textTertiary)

                        Button("Restore Purchases") {
                            Task {
                                let restored = await rcService.restorePurchasesAsync()
                                if restored {
                                    appState.isSubscribed = true
                                    appState.hasCompletedOnboarding = true
                                    appState.showPaywall = false
                                    appState.selectedTab = .home
                                }
                            }
                        }
                        .font(.caption2)
                        .foregroundStyle(Color.textTertiary)
                        .frame(minHeight: 44)
                    }

                    Spacer().frame(height: Spacing.lg)
                }
            }
        }
        .task {
            await rcService.fetchOfferings()
        }
        .fullScreenCover(isPresented: $showExitPopup) {
            GrooveSpecialOfferView(
                onPurchaseComplete: {
                    log("Special offer purchase complete callback")
                    showExitPopup = false
                    appState.isSubscribed = true
                    appState.hasCompletedOnboarding = true
                    appState.showPaywall = false
                    appState.selectedTab = .home
                },
                onDismiss: {
                    log("Special offer dismiss callback")
                    showExitPopup = false
                    skipPaywall()
                }
            )
        }
    }

    // MARK: - Social Proof Thumbnails
    private var socialProofSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.md) {
                demoThumbnail(icon: "cat.fill", label: "Cat Dancing", gradient: [Color(red: 0.18, green: 0.04, blue: 0.18), Color(red: 0.10, green: 0.04, blue: 0.10)])
                demoThumbnail(icon: "figure.dance", label: "Baby Dancing", gradient: [Color(red: 0.04, green: 0.10, blue: 0.18), Color(red: 0.04, green: 0.04, blue: 0.10)])
                demoThumbnail(icon: "dog.fill", label: "Dog Dancing", gradient: [Color(red: 0.10, green: 0.10, blue: 0.04), Color(red: 0.04, green: 0.04, blue: 0.04)])
            }
            .padding(.horizontal, Spacing.lg)
        }
    }

    @ViewBuilder
    private func demoThumbnail(icon: String, label: String, gradient: [Color]) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radius.lg)
                .fill(LinearGradient(colors: gradient, startPoint: .top, endPoint: .bottom))

            VStack(spacing: Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundStyle(.white.opacity(0.6))
                Text(label)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .frame(width: 120, height: 180)
    }

    // MARK: - Plan Cards (prices from RevenueCat)
    private var planCards: some View {
        HStack(spacing: Spacing.md) {
            // Weekly card
            planCard(
                title: weeklyPackage?.storeProduct.localizedTitle,
                price: weeklyPrice,
                subtitle: nil,
                savingsBadge: nil,
                isSelected: selectedPlan == .weekly
            ) {
                withAnimation(AppAnimation.snappy) { selectedPlan = .weekly }
            }

            // Annual card
            planCard(
                title: annualPackage?.storeProduct.localizedTitle,
                price: annualPrice,
                subtitle: annualWeeklyEquivalent.map { "= \($0)/week" },
                savingsBadge: savingsPercent.map { "SAVE \($0)%" },
                isSelected: selectedPlan == .annual
            ) {
                withAnimation(AppAnimation.snappy) { selectedPlan = .annual }
            }
        }
        .padding(.horizontal, Spacing.lg)
    }

    @ViewBuilder
    private func planCard(
        title: String?,
        price: String?,
        subtitle: String?,
        savingsBadge: String?,
        isSelected: Bool,
        onTap: @escaping () -> Void
    ) -> some View {
        let isLoading = price == nil
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    if savingsBadge != nil {
                        Text("\u{2605} Best Value")
                            .font(.caption.bold())
                            .foregroundStyle(Color.coinGold)
                    }
                    Spacer()
                }

                Text(title ?? "Plan")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.textPrimary)
                    .redacted(reason: isLoading ? .placeholder : [])

                Text(price ?? "$XX.XX")
                    .font(.headline.bold())
                    .foregroundStyle(Color.textPrimary)
                    .redacted(reason: isLoading ? .placeholder : [])

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.textSecondary)
                }

                if let badge = savingsBadge {
                    Text(badge)
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(LinearGradient.accent)
                        .clipShape(Capsule())
                }

                Spacer()

                HStack {
                    Spacer()
                    Circle()
                        .fill(isSelected ? Color.accentStart : Color.clear)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Circle()
                                .stroke(isSelected ? Color.accentStart : Color.bgElevated, lineWidth: 2)
                        )
                        .overlay {
                            if isSelected {
                                Circle().fill(.white).frame(width: 8, height: 8)
                            }
                        }
                }
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
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
        .disabled(isLoading)
    }

    // MARK: - Actions
    private func handleSubscribe() {
        guard !isPurchasing else { return }
        isPurchasing = true
        purchaseError = nil

        Task {
            do {
                let rc = RevenueCatService.shared
                let package: Package? = selectedPlan == .annual ? annualPackage : weeklyPackage

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
                        log("Purchase succeeded")
                        appState.isSubscribed = true
                        appState.hasCompletedOnboarding = true
                        appState.showPaywall = false
                        appState.selectedTab = .home
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

    private func skipPaywall() {
        log("skipPaywall()")
        appState.hasCompletedOnboarding = true
        appState.showPaywall = false
        appState.selectedTab = .home
    }
}

#Preview {
    OnboardingPaywallView()
        .environment(AppState())
}
