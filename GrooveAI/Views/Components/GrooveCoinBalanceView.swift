import SwiftUI

/// Coin balance card for Settings tab.
/// Shows current balance, refill info for subscribers, top-up for free users.
struct GrooveCoinBalanceView: View {
    @Environment(AppState.self) private var appState
    @ObservedObject private var rcService = RevenueCatService.shared

    @State private var showCoinPurchaseSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            // Header row
            HStack {
                Image(systemName: "circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.coinGold)

                Text("\(coinBalance)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.textPrimary)

                Text("coins")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(Color.textSecondary)
                    .offset(y: 2)

                Spacer()

                if appState.isSubscribed {
                    premiumBadge
                }
            }

            // Subscriber refill info
            if appState.isSubscribed {
                subscriberRefillInfo
            }

            // Coin progress bar
            coinProgressBar

            // Low coins warning
            if coinBalance < 60 {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(Color.warning)
                    Text("Not enough coins for a generation")
                        .font(.caption)
                        .foregroundStyle(Color.warning)
                }
            }

            // Action button
            if !appState.isSubscribed {
                Button {
                    showCoinPurchaseSheet = true
                } label: {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "plus.circle.fill")
                            .font(.subheadline)
                        Text("Top Up Coins")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(LinearGradient.accent)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(Spacing.lg)
        .background(Color.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: Radius.xl))
        .sheet(isPresented: $showCoinPurchaseSheet) {
            GrooveCoinPurchaseSheet(onPurchaseComplete: {
                // Balance refreshes automatically via @ObservedObject
            })
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(.black)
        }
    }

    private var coinBalance: Int {
        // Prefer server coins, then RevenueCat local, then AppState
        appState.serverCoins ?? rcService.coinBalance
    }

    // MARK: - Premium Badge

    private var premiumBadge: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "crown.fill")
                .font(.caption2)
            Text("Premium")
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(Color.accentStart)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.accentStart.opacity(0.12))
        .clipShape(Capsule())
    }

    // MARK: - Subscriber Refill Info

    private var subscriberRefillInfo: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
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

            // Refill progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: Radius.full)
                        .fill(Color.bgElevated)
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: Radius.full)
                        .fill(Color.accentStart.opacity(0.6))
                        .frame(
                            width: geo.size.width * rcService.refillProgressFraction,
                            height: 6
                        )
                }
            }
            .frame(height: 6)
        }
    }

    // MARK: - Coin Progress Bar

    private var coinProgressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: Radius.full)
                    .fill(Color.bgElevated)
                    .frame(height: 8)

                RoundedRectangle(cornerRadius: Radius.full)
                    .fill(coinProgressGradient)
                    .frame(
                        width: geo.size.width * coinProgressFraction,
                        height: 8
                    )
            }
        }
        .frame(height: 8)
    }

    private var coinProgressFraction: CGFloat {
        let maxCoins = max(150, coinBalance)
        return min(1.0, CGFloat(coinBalance) / CGFloat(maxCoins))
    }

    private var coinProgressGradient: LinearGradient {
        if coinBalance < 60 {
            return LinearGradient(colors: [Color.error, Color.error], startPoint: .leading, endPoint: .trailing)
        }
        return LinearGradient(colors: [Color.coinGold, Color.coinGold.opacity(0.7)], startPoint: .leading, endPoint: .trailing)
    }

}

// MARK: - App Header Coin Pill (updated)

struct AppHeaderCoinPill: View {
    @Environment(AppState.self) private var appState
    @State private var showCoinsSheet = false
    @State private var showPaywall = false

    private func log(_ message: String) {
        print("[AppHeaderCoinPill] \(message)")
    }

    var body: some View {
        Button {
            log("Coin button tapped. isSubscribed=\(appState.isSubscribed), coinsRemaining=\(appState.coinsRemaining)")
            if appState.isSubscribed {
                log("Presenting upgrade paywall: GrooveCoinPurchaseSheet")
                showCoinsSheet = true
            } else if appState.coinsRemaining <= 0 {
                log("Presenting onboarding paywall: GroovePaywallScreen (0 coins)")
                showPaywall = true
            } else {
                log("Presenting coin purchase sheet (has coins but not subscribed)")
                showCoinsSheet = true
            }
        } label: {
            // Always show coin count — subscribed users get a gold coin icon
            HStack(spacing: 4) {
                Image(systemName: appState.isSubscribed ? "star.circle.fill" : "circle.fill")
                    .font(.caption2)
                    .foregroundStyle(appState.isSubscribed ? Color.coinGold : Color.coinGold)
                Text("\(appState.coinsRemaining)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(appState.isSubscribed ? Color.coinGold : Color.textPrimary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(appState.isSubscribed ? Color.coinGold.opacity(0.12) : Color.bgElevated)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showCoinsSheet) {
            GrooveCoinPurchaseSheet(onPurchaseComplete: {})
                .onAppear {
                    log("GrooveCoinPurchaseSheet appeared from coin button")
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.black)
        }
        .fullScreenCover(isPresented: $showPaywall) {
            GroovePaywallScreen(
                onPurchaseSuccess: {
                    log("GroovePaywallScreen purchase succeeded from coin button")
                    appState.isSubscribed = true
                    appState.selectedTab = .home
                    showPaywall = false
                },
                onDismiss: {
                    log("GroovePaywallScreen dismissed from coin button")
                    appState.selectedTab = .home
                    showPaywall = false
                }
            )
                .onAppear {
                    log("GroovePaywallScreen appeared from coin button")
                }
        }
        .onChange(of: showCoinsSheet) { _, isPresented in
            log("showCoinsSheet changed -> \(isPresented)")
        }
        .onChange(of: showPaywall) { _, isPresented in
            log("showPaywall changed -> \(isPresented)")
        }
    }
}

#Preview {
    ScrollView {
        GrooveCoinBalanceView()
            .padding()
    }
    .background(Color.bgPrimary)
    .environment(AppState())
}
