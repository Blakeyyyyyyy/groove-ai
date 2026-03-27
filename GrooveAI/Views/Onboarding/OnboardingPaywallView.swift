import SwiftUI

// MARK: - Screen 5: Onboarding Paywall
// At peak emotional moment after simulated result
struct OnboardingPaywallView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPlan: PricingPlan = .annual
    @State private var showExitPopup = false

    enum PricingPlan {
        case weekly, annual

        var price: String {
            switch self {
            case .weekly: "$9.99/week"
            case .annual: "$99.99/year"
            }
        }

        var ctaLabel: String {
            switch self {
            case .weekly: "Start Dancing — $9.99"
            case .annual: "Start Dancing — $99.99/year"
            }
        }

        var trialText: String {
            switch self {
            case .weekly: "3 days free, then $9.99/week"
            case .annual: "3 days free, then $99.99/year"
            }
        }
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
                            showExitPopup = true
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

                        Text(selectedPlan.trialText)
                            .font(.caption)
                            .foregroundStyle(Color.textSecondary)
                    }

                    // Plan cards
                    planCards

                    // Social proof
                    Text("4.9★ · 80k+ videos made")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.textSecondary)

                    // Fine print
                    VStack(spacing: Spacing.xs) {
                        Text("Cancel anytime")
                            .font(.caption2)
                            .foregroundStyle(Color.textTertiary)

                        Button("Restore Purchases") {
                            // TODO: RevenueCat restore
                        }
                        .font(.caption2)
                        .foregroundStyle(Color.textTertiary)
                        .frame(minHeight: 44)
                    }

                    Spacer().frame(height: Spacing.lg)
                }
            }
        }
        .sheet(isPresented: $showExitPopup) {
            ExitPopupView(
                onSubscribe: {
                    showExitPopup = false
                    handleSubscribe()
                },
                onDismiss: {
                    showExitPopup = false
                    skipPaywall()
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.hidden)
            .presentationBackground(Color.bgSecondary)
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

    // MARK: - Plan Cards
    private var planCards: some View {
        HStack(spacing: Spacing.md) {
            planCard(
                title: "Weekly",
                price: "$9.99/week",
                subtitle: nil,
                badge: nil,
                isSelected: selectedPlan == .weekly
            ) {
                withAnimation(AppAnimation.snappy) { selectedPlan = .weekly }
            }

            planCard(
                title: "Annual",
                price: "$99.99/year",
                subtitle: "= $1.92/week",
                badge: "SAVE 81%",
                isSelected: selectedPlan == .annual
            ) {
                withAnimation(AppAnimation.snappy) { selectedPlan = .annual }
            }
        }
        .padding(.horizontal, Spacing.lg)
    }

    @ViewBuilder
    private func planCard(
        title: String,
        price: String,
        subtitle: String?,
        badge: String?,
        isSelected: Bool,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    if badge != nil {
                        Text("★ Best Value")
                            .font(.caption.bold())
                            .foregroundStyle(Color.coinGold)
                    }
                    Spacer()
                }

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.textPrimary)

                Text(price)
                    .font(.headline.bold())
                    .foregroundStyle(Color.textPrimary)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.textSecondary)
                }

                if let badge {
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
    }

    // MARK: - Actions
    private func handleSubscribe() {
        appState.isSubscribed = true
        appState.hasCompletedOnboarding = true
        appState.showPaywall = false
    }

    private func skipPaywall() {
        // User dismissed without subscribing — still complete onboarding
        appState.hasCompletedOnboarding = true
        appState.showPaywall = false
    }
}

#Preview {
    OnboardingPaywallView()
        .environment(AppState())
}
