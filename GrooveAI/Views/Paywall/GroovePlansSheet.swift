import SwiftUI
import RevenueCat

/// Standalone plan upgrade sheet for settings or direct access.
struct GroovePlansSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var rcService = RevenueCatService.shared

    var onPurchaseComplete: (() -> Void)?

    @State private var selectedTier: PlanTier = .weeklyPro550
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var purchaseError: String?

    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.bgElevated)
                .frame(width: 40, height: 5)
                .padding(.top, Spacing.md)

            // Header
            VStack(spacing: Spacing.sm) {
                Text("Choose Your Plan")
                    .font(.title2.bold())
                    .foregroundStyle(Color.textPrimary)

                Text("Unlock unlimited dance videos")
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
            }
            .padding(.top, Spacing.xl)

            // Plan tiers
            ScrollView(showsIndicators: false) {
                VStack(spacing: Spacing.md) {
                    ForEach(PlanTier.allCases, id: \.self) { tier in
                        planCard(tier)
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.xl)
            }

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
            Button {
                handleSubscribe()
            } label: {
                HStack(spacing: Spacing.sm) {
                    if isPurchasing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        let name = rcService.localizedDisplayName(for: selectedTier) ?? "Plan"
                        let price = rcService.localizedPrice(for: selectedTier) ?? "..."
                        let prefix = selectedTier == .annual ? "Start" : "Upgrade to"
                        Text("\(prefix) \(name) \u{2014} \(price)")
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
            .allowsHitTesting(!isPurchasing && rcService.localizedPrice(for: selectedTier) != nil)
            .opacity(rcService.localizedPrice(for: selectedTier) != nil ? 1.0 : 0.5)
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.lg)

            // Billing note
            Text(billingNote)
                .font(.caption2)
                .foregroundStyle(Color.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.top, Spacing.sm)

            // Restore
            Button {
                handleRestore()
            } label: {
                HStack(spacing: Spacing.xs) {
                    if isRestoring {
                        ProgressView()
                            .tint(Color.textTertiary)
                            .scaleEffect(0.7)
                    }
                    Text("Already subscribed? Restore")
                        .font(.footnote)
                        .foregroundStyle(Color.textTertiary)
                }
            }
            .frame(minHeight: 44)
            .padding(.bottom, Spacing.lg)
        }
        .background(Color.bgPrimary)
        .task {
            await rcService.fetchOfferings()
        }
    }

    // MARK: - Plan Card

    @ViewBuilder
    private func planCard(_ tier: PlanTier) -> some View {
        let isSelected = selectedTier == tier
        let displayName = rcService.localizedDisplayName(for: tier)
        let priceStr = rcService.localizedPrice(for: tier)
        let isLoading = priceStr == nil

        Button {
            withAnimation(AppAnimation.snappy) {
                selectedTier = tier
            }
        } label: {
            HStack(spacing: Spacing.md) {
                // Plan info
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    HStack(spacing: Spacing.sm) {
                        Text(displayName ?? "Plan")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(Color.textPrimary)
                            .redacted(reason: isLoading ? .placeholder : [])

                        if tier == .weeklyPro550 {
                            Text("RECOMMENDED")
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(LinearGradient.accent)
                                .clipShape(Capsule())
                        }

                        if tier == .annual {
                            Text("BEST VALUE")
                                .font(.caption2.bold())
                                .foregroundStyle(Color.coinGold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.coinGold.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }

                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 6))
                            .foregroundStyle(Color.coinGold)
                        Text(tier.coinSummaryLabel)
                            .font(.caption)
                            .foregroundStyle(Color.textSecondary)
                    }
                }

                Spacer()

                // Price
                VStack(alignment: .trailing, spacing: Spacing.xxs) {
                    Text(priceStr ?? "$XX.XX")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color.textPrimary)
                        .redacted(reason: isLoading ? .placeholder : [])
                }

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

    private var billingNote: String {
        switch selectedTier {
        case .annual:
            return "Auto-renews yearly \u{00B7} cancel anytime in Settings"
        default:
            return "Auto-renews weekly \u{00B7} cancel anytime in Settings"
        }
    }

    // MARK: - Subscribe

    private func handleSubscribe() {
        guard !isPurchasing else { return }
        isPurchasing = true
        purchaseError = nil

        Task {
            do {
                let rc = RevenueCatService.shared
                await rc.fetchOfferings()

                let package = selectedTier.resolvePackage(from: rc)
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
            } catch {
                await MainActor.run {
                    purchaseError = error.localizedDescription
                    isPurchasing = false
                }
            }
        }
    }

    // MARK: - Restore

    private func handleRestore() {
        guard !isRestoring else { return }
        isRestoring = true
        purchaseError = nil

        Task {
            let restored = await RevenueCatService.shared.restorePurchasesAsync()
            await MainActor.run {
                isRestoring = false
                if restored {
                    appState.isSubscribed = true
                    onPurchaseComplete?()
                    dismiss()
                } else {
                    purchaseError = "No active subscription found."
                }
            }
        }
    }
}

#Preview {
    GroovePlansSheet()
        .environment(AppState())
}
