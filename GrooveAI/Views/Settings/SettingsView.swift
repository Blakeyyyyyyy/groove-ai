import SwiftUI
import RevenueCat

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openURL) private var openURL
    @ObservedObject private var rcService = RevenueCatService.shared
    @State private var showPlansSheet = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: Spacing.xl) {
                    // Coins Balance Card (new component)
                    GrooveCoinBalanceView()
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
            .task {
                await rcService.refreshSubscriptionStatus()
            }
            .sheet(isPresented: $showPlansSheet) {
                GroovePlansSheet()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(Color.bgPrimary)
            }
        }
    }

    // MARK: - Subscription Card
    private var subscriptionCard: some View {
        Button {
            showPlansSheet = true
        } label: {
            HStack {
                Image(systemName: "crown.fill")
                    .foregroundStyle(Color.accentStart)

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Groove AI \(rcService.subscriptionPlanName)")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color.textPrimary)
                    Text(rcService.subscriptionStatusLine)
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
                SettingsRow(icon: nil, label: "Help & FAQ") { openURL(URL(string: "https://trygrooveai.com/contact.html")!) }
                Divider().overlay(Color.bgElevated)
                SettingsRow(icon: nil, label: "Contact Support") { openURL(URL(string: "https://trygrooveai.com/contact.html")!) }
                Divider().overlay(Color.bgElevated)
                SettingsRow(icon: nil, label: "Privacy Policy") { openURL(URL(string: "https://trygrooveai.com/privacy.html")!) }
                Divider().overlay(Color.bgElevated)
                SettingsRow(icon: nil, label: "Terms of Service") { openURL(URL(string: "https://trygrooveai.com/terms.html")!) }
            }
            .padding(.horizontal, Spacing.lg)
            .background(Color.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: Radius.xl))
        }
    }

    // MARK: - Restore Card
    private var restoreCard: some View {
        Button {
            Task {
                let restored = await RevenueCatService.shared.restorePurchasesAsync()
                if restored {
                    appState.isSubscribed = true
                }
            }
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
