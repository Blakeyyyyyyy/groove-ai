import SwiftUI
import SuperwallKit

struct ManagePlanView: View {
    @Environment(AppState.self) private var appState
    @ObservedObject private var rcService = RevenueCatService.shared

    @State private var showCoinSheet = false
    @State private var showPaywall = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: Spacing.xl) {
                planCard
                coinCard
                ctaButton
                Spacer().frame(height: 40)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.lg)
        }
        .background(Color.bgPrimary)
        .navigationTitle("Your Plan")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(Color.bgPrimary, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task { await rcService.refreshSubscriptionStatus() }
        .sheet(isPresented: $showCoinSheet) {
            GrooveCoinPurchaseSheet(onPurchaseComplete: {})
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.black)
        }
        .onChange(of: showPaywall) { _, newValue in
            if newValue {
                showPaywall = false
                Superwall.shared.register(placement: "onboarding_trial") {}
            }
        }
    }

    // MARK: - Plan Card

    private var planCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: appState.isSubscribed ? "crown.fill" : "circle.dashed")
                    .font(.title3)
                    .foregroundStyle(appState.isSubscribed ? Color.accentStart : Color.textTertiary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(planTitle)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.textPrimary)
                    Text(planSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(Color.textSecondary)
                }
                Spacer()
            }

            Divider().overlay(Color.bgElevated)

            Text(planDetail)
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.lg)
        .background(Color.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: Radius.xl))
    }

    // MARK: - Coin Card

    private var coinCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Image(systemName: "circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.coinGold)

                Text("\(coinBalance)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.textPrimary)

                Text("coins left")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(Color.textSecondary)
                    .offset(y: 2)
            }

            if appState.isSubscribed {
                Divider().overlay(Color.bgElevated)

                HStack {
                    Text(rcService.refillStatusLine)
                        .font(.subheadline)
                        .foregroundStyle(Color.textSecondary)
                    Spacer()
                    if let countdown = rcService.refillCountdownLabel {
                        Text(countdown)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.accentStart)
                    }
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: Radius.full)
                            .fill(Color.bgElevated)
                            .frame(height: 6)
                        RoundedRectangle(cornerRadius: Radius.full)
                            .fill(Color.accentStart.opacity(0.6))
                            .frame(width: geo.size.width * rcService.refillProgressFraction, height: 6)
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(Spacing.lg)
        .background(Color.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: Radius.xl))
    }

    // MARK: - CTA

    private var ctaButton: some View {
        Button {
            if rcService.isInFreeTrial {
                if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                    UIApplication.shared.open(url)
                }
            } else if appState.isSubscribed {
                showCoinSheet = true
            } else {
                showPaywall = true
            }
        } label: {
            Text(ctaLabel)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(LinearGradient.accent)
                .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Helpers

    private var coinBalance: Int {
        appState.serverCoins ?? rcService.coinBalance
    }

    private var planTitle: String {
        guard appState.isSubscribed else { return "No active plan" }
        return "Groove AI \(rcService.subscriptionPlanName)"
    }

    private var planSubtitle: String {
        guard appState.isSubscribed else { return "Get a plan to unlock dance videos" }
        return rcService.subscriptionStatusLine
    }

    private var planDetail: String {
        guard appState.isSubscribed else {
            return "Subscribe to get weekly coins and unlimited access to all dances."
        }
        if rcService.isInFreeTrial {
            return "You're on a 3-day free trial. Your 150 trial coins expire when the trial ends. If you keep your subscription, you'll get 250 coins every month."
        }
        return rcService.refillStatusLine
    }

    private var ctaLabel: String {
        if rcService.isInFreeTrial { return "Manage subscription" }
        return appState.isSubscribed ? "Get more coins" : "Get started"
    }
}

#Preview {
    NavigationStack {
        ManagePlanView()
    }
    .environment(AppState())
}
