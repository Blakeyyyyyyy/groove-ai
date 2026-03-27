import SwiftUI

struct PaywallView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var showExitPopup = false
    @State private var selectedPlan: PricingPlan = .annual

    enum PricingPlan {
        case weekly, annual

        var price: String {
            switch self {
            case .weekly: "$9.99"
            case .annual: "$99.99"
            }
        }

        var ctaLabel: String {
            switch self {
            case .weekly: "Start Dancing — $9.99"
            case .annual: "Start Dancing — $99.99/year"
            }
        }

        var billingNote: String {
            switch self {
            case .weekly: "Billed weekly · Cancel anytime in Settings"
            case .annual: "Billed annually · Cancel anytime in Settings"
            }
        }
    }

    var body: some View {
        ZStack {
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
                    socialProofThumbnails

                    // Headline — v3 copy
                    VStack(spacing: Spacing.sm) {
                        Text("See anyone dance.")
                            .font(.title.bold())
                            .foregroundStyle(Color.textPrimary)

                        Text("Video ready in minutes.")
                            .font(.subheadline)
                            .foregroundStyle(Color.textSecondary)
                    }

                    // Plan cards
                    planCards

                    // CTA
                    GradientCTAButton(selectedPlan.ctaLabel) {
                        handleSubscribe()
                    }

                    // Fine print
                    Text(selectedPlan.billingNote)
                        .font(.caption2)
                        .foregroundStyle(Color.textTertiary)
                        .multilineTextAlignment(.center)

                    // Review card
                    HStack {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text("\"2M views on my first dog video\"")
                                .font(.subheadline.italic())
                                .foregroundStyle(Color.textPrimary)
                            Text("— Jamie, Texas")
                                .font(.caption)
                                .foregroundStyle(Color.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(Spacing.lg)
                    .background(Color.bgSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                    .padding(.horizontal, Spacing.lg)

                    // Legal
                    VStack(spacing: Spacing.xs) {
                        Button("Restore Purchases") {
                            // TODO: RevenueCat restore
                        }
                        .font(.footnote)
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
                    dismiss()
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.hidden)
            .presentationBackground(Color.bgSecondary)
        }
    }

    // MARK: - Social Proof Thumbnails

    private var socialProofThumbnails: some View {
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
                .fill(
                    LinearGradient(colors: gradient, startPoint: .top, endPoint: .bottom)
                )

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
            // Weekly
            planCard(
                title: "Weekly",
                price: "$9.99/week",
                subtitle: nil,
                badge: nil,
                isSelected: selectedPlan == .weekly
            ) {
                withAnimation(AppAnimation.snappy) { selectedPlan = .weekly }
            }

            // Annual — highlighted by default
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
                        Text("★")
                            .font(.caption.bold())
                            .foregroundStyle(Color.coinGold)
                        Text("Best Value")
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

                // Radio indicator
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
                                Circle()
                                    .fill(.white)
                                    .frame(width: 8, height: 8)
                            }
                        }
                }
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, minHeight: 180, alignment: .topLeading)
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

    // MARK: - Subscribe

    private func handleSubscribe() {
        // TODO: RevenueCat purchase flow
        appState.isSubscribed = true
        appState.hasCompletedOnboarding = true
        appState.showPaywall = false
    }
}

#Preview {
    PaywallView()
        .environment(AppState())
}
