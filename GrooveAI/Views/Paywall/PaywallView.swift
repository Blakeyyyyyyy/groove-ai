import SwiftUI
import RevenueCat

struct PaywallView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var showExitOffer = false
    @State private var selectedPlan: PricingPlan = .annual
    @State private var isPurchasing = false
    @State private var purchaseError: String?

    enum PricingPlan: CaseIterable {
        case weekly, annual

        var displayTitle: String {
            switch self {
            case .weekly: return "Weekly"
            case .annual: return "Yearly"
            }
        }

        var mainPrice: String {
            switch self {
            case .weekly: return "$9.99/week"
            case .annual: return "$1.92/week"
            }
        }

        var secondaryPrice: String {
            switch self {
            case .weekly: return "billed weekly"
            case .annual: return "$99.99/year"
            }
        }

        var savings: String? {
            switch self {
            case .weekly: return nil
            case .annual: return "SAVE 80%"
            }
        }

        var trialText: String {
            return "first week $7.99"
        }
    }

    var body: some View {
        ZStack {
            // Background
            Color.bgPrimary
                .ignoresSafeArea()

            // Subtle radial glow
            RadialGradient(
                colors: [Color.accentStart.opacity(0.06), Color.clear],
                center: .top,
                startRadius: 50,
                endRadius: 400
            )
            .ignoresSafeArea()

            // Main content - NO ScrollView, single-screen layout
            VStack(spacing: 12) {
                // Top bar with dismiss + restore
                HStack {
                    // Dismiss button - top-left
                    Button {
                        showExitOffer = true
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.medium))
                            .foregroundStyle(Color.textSecondary)
                            .frame(width: 44, height: 44)
                    }

                    Spacer()

                    // Restore link - top-right
                    Button("Restore") {
                        Task {
                            let restored = try? await RevenueCatService.shared.restorePurchases()
                            if restored == true {
                                appState.isSubscribed = true
                                appState.showPaywall = false
                            }
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(Color.textTertiary)
                    .frame(width: 44, height: 44)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.xs)

                // OUTPUT COLLAGE HERO - 30% screen height
                outputCollageHero
                    .frame(height: UIScreen.main.bounds.height * 0.30)

                // HEADLINE + SUBHEADLINE
                VStack(spacing: 8) {
                    Text("Make Anyone Dance")
                        .font(.title.bold())
                        .foregroundStyle(Color.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("Upload a photo of your pet, baby, or anyone — watch them dance to any style.")
                        .font(.subheadline)
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }

                // FEATURE BULLETS - max 4, 2 columns
                featureBulletsGrid

                // PRICING PLAN CARDS - 2 cards only
                pricingPlanCards

                Spacer(minLength: 0)
            }

            // Sticky bottom CTA zone - overlays content
            VStack {
                Spacer()

                VStack(spacing: 12) {
                    // Primary CTA button
                    Button {
                        handleSubscribe()
                    } label: {
                        HStack(spacing: Spacing.sm) {
                            if isPurchasing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("$7.99 to Start")
                                    .font(.headline.bold())
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(LinearGradient.accent)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                    }
                    .disabled(isPurchasing)
                    .sensoryFeedback(.success, trigger: selectedPlan)

                    // Reassurance + legal
                    VStack(spacing: 4) {
                        Text("✓ No payment due now · Cancel anytime")
                            .font(.caption)
                            .foregroundStyle(Color.textSecondary)

                        Text("Terms of Service · Privacy Policy")
                            .font(.caption2)
                            .foregroundStyle(Color.textTertiary)
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.lg) // Above home indicator
                .background(
                    Color.bgPrimary
                        .opacity(0.95)
                        .background(.ultraThinMaterial)
                )
            }
        }
        .fullScreenCover(isPresented: $showExitOffer) {
            GrooveExitOfferView(
                onSubscribe: {
                    showExitOffer = false
                    handleSubscribe()
                },
                onSkip: {
                    showExitOffer = false
                    appState.showPaywall = false
                }
            )
        }
    }

    // MARK: - Output Collage Hero

    private var outputCollageHero: some View {
        VStack(spacing: 0) {
            HStack(spacing: Spacing.md) {
                // Card 1 - Pet
                collageCard(
                    icon: "dog.fill",
                    label: "Dog",
                    gradient: [Color(red: 0.18, green: 0.04, blue: 0.18), Color(red: 0.10, green: 0.04, blue: 0.10)]
                )

                // Card 2 - Baby
                collageCard(
                    icon: "figure.and.child.holding",
                    label: "Baby",
                    gradient: [Color(red: 0.04, green: 0.10, blue: 0.18), Color(red: 0.04, green: 0.04, blue: 0.10)]
                )

                // Card 3 - Person
                collageCard(
                    icon: "figure.dance",
                    label: "Hip Hop",
                    gradient: [Color(red: 0.10, green: 0.10, blue: 0.04), Color(red: 0.04, green: 0.04, blue: 0.04)]
                )
            }
        }
        .padding(.horizontal, Spacing.lg)
    }

    @ViewBuilder
    private func collageCard(icon: String, label: String, gradient: [Color]) -> some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: Radius.lg)
                .fill(
                    LinearGradient(colors: gradient, startPoint: .top, endPoint: .bottom)
                )

            // Subtle glow halo
            RoundedRectangle(cornerRadius: Radius.lg)
                .stroke(
                    LinearGradient(
                        colors: [Color.accentStart.opacity(0.3), Color.accentEnd.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )

            VStack(spacing: Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundStyle(.white.opacity(0.6))
            }

            // Label pill at bottom
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Text(label)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xxs)
                        .background(.black.opacity(0.4))
                        .clipShape(Capsule())
                }
            }
            .padding(Spacing.sm)
        }
    }

    // MARK: - Feature Bullets Grid (max 4, 2 columns)

    private var featureBulletsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: Spacing.md),
            GridItem(.flexible(), spacing: Spacing.md)
        ], spacing: Spacing.md) {
            featureBullet(icon: "wand.and.stars", label: "AI Dance Videos")
            featureBullet(icon: "photo", label: "Any Photo Works")
            featureBullet(icon: "music.note", label: "20+ Dance Styles")
            featureBullet(icon: "square.and.arrow.up", label: "Share Instantly")
        }
        .padding(.horizontal, Spacing.lg)
    }

    @ViewBuilder
    private func featureBullet(icon: String, label: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.body.weight(.medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.accentStart, Color.accentEnd],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text(label)
                .font(.footnote)
                .foregroundStyle(Color.textPrimary)
        }
    }

    // MARK: - Pricing Plan Cards

    private var pricingPlanCards: some View {
        VStack(spacing: Spacing.sm) {
            ForEach(PricingPlan.allCases, id: \.self) { plan in
                planCard(plan: plan)
            }
        }
        .padding(.horizontal, Spacing.lg)
    }

    @ViewBuilder
    private func planCard(plan: PricingPlan) -> some View {
        let isSelected = selectedPlan == plan

        Button {
            withAnimation(AppAnimation.snappy) {
                selectedPlan = plan
            }
        } label: {
            HStack {
                // Left content
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(plan.displayTitle)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color.textPrimary)

                    Text(plan.secondaryPrice)
                        .font(.subheadline)
                        .foregroundStyle(Color.textSecondary)
                }

                Spacer()

                // Right content
                VStack(alignment: .trailing, spacing: Spacing.xs) {
                    Text(plan.mainPrice)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color.textPrimary)

                    if let savings = plan.savings {
                        Text(savings)
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, Spacing.xxs)
                            .background(LinearGradient.accent)
                            .clipShape(Capsule())
                    }
                }

                // Selection indicator
                Circle()
                    .fill(isSelected ? Color.accentStart : Color.clear)
                    .frame(width: 20, height: 20)
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
            .background(Color.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg)
                    .stroke(
                        isSelected ? Color.accentStart : Color.bgElevated,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: selectedPlan)
    }

    // MARK: - Subscribe Action

    private func handleSubscribe() {
        guard !isPurchasing else { return }
        isPurchasing = true
        purchaseError = nil

        Task {
            do {
                let rc = RevenueCatService.shared
                await rc.fetchOfferings()

                let package: Package? = selectedPlan == .annual ? rc.annualPackage() : rc.weeklyPackage()

                guard let pkg = package else {
                    // Fallback: if offerings not loaded, mark subscribed for onboarding flow
                    await MainActor.run {
                        appState.isSubscribed = true
                        appState.hasCompletedOnboarding = true
                        appState.showPaywall = false
                        isPurchasing = false
                    }
                    return
                }

                let success = try await rc.purchase(package: pkg)

                await MainActor.run {
                    if success {
                        appState.isSubscribed = true
                        appState.hasCompletedOnboarding = true
                        appState.showPaywall = false
                    }
                    isPurchasing = false
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

#Preview {
    PaywallView()
        .environment(AppState())
}