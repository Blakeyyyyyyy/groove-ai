import SwiftUI
import RevenueCat

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openURL) private var openURL
    @ObservedObject private var rcService = RevenueCatService.shared

    @State private var isRestoring = false
    @State private var restoreAlertTitle = ""
    @State private var restoreAlertMessage = ""
    @State private var showRestoreAlert = false
    @State private var showPaywall = false
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var showDeleteErrorAlert = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: Spacing.xl) {
                    GrooveCoinBalanceView()
                        .padding(.top, Spacing.sm)

                    subscriptionCard

                    supportSection

                    restoreCard

                    accountSection

                    VStack(spacing: Spacing.xs) {
                        Text("Groove AI v1.0")
                            .font(.caption)
                            .foregroundStyle(Color.textTertiary)
                        Text("Made with ♥")
                            .font(.caption)
                            .foregroundStyle(Color.textTertiary)
                    }
                    .padding(.top, Spacing.lg)
                    .padding(.bottom, 100)
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
            .alert(restoreAlertTitle, isPresented: $showRestoreAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(restoreAlertMessage)
            }
            .alert("Delete Account", isPresented: $showDeleteConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task {
                        isDeleting = true
                        let ok = await appState.deleteAccount()
                        isDeleting = false
                        if !ok { showDeleteErrorAlert = true }
                    }
                }
            } message: {
                Text("This will permanently delete your account and all your data, including generated videos and coin balance. This cannot be undone.")
            }
            .alert("Couldn't delete account", isPresented: $showDeleteErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Something went wrong. Check your connection and try again.")
            }
            .fullScreenCover(isPresented: $showPaywall) {
                GroovePaywallScreen(
                    onPurchaseSuccess: {
                        appState.isSubscribed = true
                        showPaywall = false
                    },
                    onDismiss: { showPaywall = false }
                )
            }
        }
    }

    // MARK: - Subscription Card

    @ViewBuilder
    private var subscriptionCard: some View {
        if appState.isSubscribed {
            NavigationLink(destination: ManagePlanView()) {
                subscriptionCardContent(
                    icon: "crown.fill",
                    iconColor: Color.accentStart,
                    title: "Groove AI \(rcService.subscriptionPlanName)",
                    subtitle: rcService.subscriptionStatusLine,
                    label: "Manage"
                )
            }
            .buttonStyle(.plain)
        } else {
            Button { showPaywall = true } label: {
                subscriptionCardContent(
                    icon: "sparkles",
                    iconColor: Color.accentStart,
                    title: "Get Groove AI Pro",
                    subtitle: "Start creating AI dance videos",
                    label: "Upgrade"
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func subscriptionCardContent(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        label: String
    ) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(iconColor)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.textPrimary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()

            Text(label)
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
            guard !isRestoring else { return }
            isRestoring = true
            Task {
                let restored = await RevenueCatService.shared.restorePurchasesAsync()
                await MainActor.run {
                    isRestoring = false
                    if restored {
                        appState.isSubscribed = true
                        restoreAlertTitle = "Purchases restored"
                        restoreAlertMessage = "Your subscription is now active."
                    } else {
                        restoreAlertTitle = "Nothing to restore"
                        restoreAlertMessage = "No active subscription was found for this Apple ID."
                    }
                    showRestoreAlert = true
                }
            }
        } label: {
            HStack {
                Text("Restore Purchases")
                    .font(.body)
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                if isRestoring {
                    ProgressView()
                        .tint(Color.textTertiary)
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.textTertiary)
                }
            }
            .frame(minHeight: 44)
            .padding(.horizontal, Spacing.lg)
            .background(Color.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: Radius.xl))
        }
        .buttonStyle(.plain)
        .disabled(isRestoring)
    }

    // MARK: - Account Section

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("ACCOUNT")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.textTertiary)
                .padding(.leading, Spacing.xs)

            Button {
                guard !isDeleting else { return }
                showDeleteConfirm = true
            } label: {
                HStack {
                    Text("Delete Account")
                        .font(.body)
                        .foregroundStyle(.red)
                    Spacer()
                    if isDeleting {
                        ProgressView()
                            .tint(Color.textTertiary)
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.textTertiary)
                    }
                }
                .frame(minHeight: 44)
                .padding(.horizontal, Spacing.lg)
                .background(Color.bgSecondary)
                .clipShape(RoundedRectangle(cornerRadius: Radius.xl))
            }
            .buttonStyle(.plain)
            .disabled(isDeleting)
        }
    }
}

#Preview {
    SettingsView()
        .environment(AppState())
}
