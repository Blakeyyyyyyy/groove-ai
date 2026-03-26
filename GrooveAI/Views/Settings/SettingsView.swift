import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: Spacing.xl) {
                    // Credits Card
                    creditsCard
                        .padding(.top, Spacing.sm)

                    // Subscription Card
                    subscriptionCard

                    // Support Section
                    supportSection

                    // Restore Purchases
                    restoreCard

                    // Version
                    VStack(spacing: Spacing.xs) {
                        Text("Groove AI v1.0")
                            .font(.caption)
                            .foregroundStyle(Color.textTertiary)
                        Text("Made with ♥")
                            .font(.caption)
                            .foregroundStyle(Color.textTertiary)
                    }
                    .padding(.top, Spacing.lg)
                    .padding(.bottom, 100) // tab bar
                }
                .padding(.horizontal, Spacing.lg)
            }
            .background(Color.bgPrimary)
            .navigationTitle("Settings")
            .toolbarBackground(Color.bgPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    // MARK: - Credits Card
    private var creditsCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("💳")
                Text("Credits")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.textPrimary)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: Radius.full)
                        .fill(Color.bgElevated)
                        .frame(height: 8)

                    // Fill
                    RoundedRectangle(cornerRadius: Radius.full)
                        .fill(progressGradient)
                        .frame(
                            width: geo.size.width * progressFraction,
                            height: 8
                        )
                }
            }
            .frame(height: 8)

            HStack {
                if appState.creditsRemaining < 20 {
                    Text("⚠️ Low credits — \(appState.creditsUsed) / \(appState.creditsTotal) used")
                        .font(.subheadline)
                        .foregroundStyle(Color.warning)
                } else {
                    Text("\(appState.creditsUsed) / \(appState.creditsTotal) credits used this week")
                        .font(.subheadline)
                        .foregroundStyle(Color.textPrimary)
                }
            }

            Text("Resets Monday")
                .font(.caption)
                .foregroundStyle(Color.textTertiary)
        }
        .padding(Spacing.lg)
        .background(Color.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: Radius.xl))
    }

    private var progressFraction: CGFloat {
        guard appState.creditsTotal > 0 else { return 0 }
        return min(1.0, CGFloat(appState.creditsUsed) / CGFloat(appState.creditsTotal))
    }

    private var progressGradient: LinearGradient {
        if appState.creditsRemaining < 20 {
            return LinearGradient(colors: [Color.error, Color.error], startPoint: .leading, endPoint: .trailing)
        }
        return LinearGradient.accent
    }

    // MARK: - Subscription Card
    private var subscriptionCard: some View {
        Button {
            // TODO: RevenueCat CustomerCenter
        } label: {
            HStack {
                Image(systemName: "crown.fill")
                    .foregroundStyle(Color.accentStart)

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Groove AI Pro")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color.textPrimary)
                    Text("$9.99/week")
                        .font(.subheadline)
                        .foregroundStyle(Color.textSecondary)
                }

                Spacer()

                Text("Manage Subscription")
                    .font(.caption)
                    .foregroundStyle(Color.textTertiary)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(Spacing.lg)
            .background(Color.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: Radius.xl))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Support Section
    private var supportSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("SUPPORT")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.textTertiary)
                .padding(.leading, Spacing.xs)

            VStack(spacing: 0) {
                SettingsRow(icon: nil, label: "Help & FAQ") {}
                Divider().overlay(Color.bgElevated)
                SettingsRow(icon: nil, label: "Contact Support") {}
                Divider().overlay(Color.bgElevated)
                SettingsRow(icon: nil, label: "Privacy Policy") {}
                Divider().overlay(Color.bgElevated)
                SettingsRow(icon: nil, label: "Terms of Service") {}
            }
            .padding(.horizontal, Spacing.lg)
            .background(Color.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: Radius.xl))
        }
    }

    // MARK: - Restore Card
    private var restoreCard: some View {
        Button {
            // TODO: RevenueCat restore
        } label: {
            HStack {
                Text("Restore Purchases")
                    .font(.body)
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.textTertiary)
            }
            .frame(minHeight: 44)
            .padding(.horizontal, Spacing.lg)
            .background(Color.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: Radius.xl))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SettingsView()
        .environment(AppState())
}
