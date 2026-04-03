import SwiftUI

/// Coin balance card for Settings tab.
/// Shows current balance, refill info for subscribers, top-up for free users.
struct GrooveCoinBalanceView: View {
    @Environment(AppState.self) private var appState
    @ObservedObject private var rcService = RevenueCatService.shared

    @State private var showCoinPurchaseSheet = false
    @State private var showTransactionHistory = false

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

            // Transaction history (collapsible)
            transactionHistorySection
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
            .presentationBackground(Color.bgPrimary)
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
            let daysUntilRefill = daysUntilNextMonday()

            HStack {
                Text("Your plan refills in \(daysUntilRefill) day\(daysUntilRefill == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)

                Spacer()

                Text("\(daysUntilRefill)d")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentStart)
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
                            width: geo.size.width * refillProgress,
                            height: 6
                        )
                }
            }
            .frame(height: 6)
        }
    }

    private var refillProgress: CGFloat {
        let days = daysUntilNextMonday()
        return CGFloat(7 - days) / 7.0
    }

    private func daysUntilNextMonday() -> Int {
        let calendar = Calendar.current
        let today = calendar.component(.weekday, from: Date())
        // Sunday=1, Monday=2, ... Saturday=7
        let daysUntilMonday = (9 - today) % 7
        return daysUntilMonday == 0 ? 7 : daysUntilMonday
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

    // MARK: - Transaction History

    private var transactionHistorySection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Button {
                withAnimation(AppAnimation.gentle) {
                    showTransactionHistory.toggle()
                }
            } label: {
                HStack {
                    Text("Recent Activity")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.textSecondary)

                    Spacer()

                    Image(systemName: showTransactionHistory ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.textTertiary)
                }
            }
            .buttonStyle(.plain)

            if showTransactionHistory {
                VStack(spacing: Spacing.sm) {
                    transactionRow(icon: "minus.circle.fill", color: .error, label: "Dance generation", coins: -60, time: "Today")
                    transactionRow(icon: "plus.circle.fill", color: .success, label: "Weekly refill", coins: 150, time: "Monday")
                    transactionRow(icon: "minus.circle.fill", color: .error, label: "Dance generation", coins: -60, time: "Yesterday")
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    @ViewBuilder
    private func transactionRow(icon: String, color: Color, label: String, coins: Int, time: String) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)

            Text(label)
                .font(.caption)
                .foregroundStyle(Color.textPrimary)

            Spacer()

            Text(coins > 0 ? "+\(coins)" : "\(coins)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(coins > 0 ? Color.success : Color.textSecondary)

            Text(time)
                .font(.caption2)
                .foregroundStyle(Color.textTertiary)
        }
        .padding(.vertical, Spacing.xs)
    }
}

// MARK: - App Header Coin Pill (updated)

struct AppHeaderCoinPill: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        if appState.isSubscribed {
            // Premium badge
            HStack(spacing: 4) {
                Image(systemName: "crown.fill")
                    .font(.caption2)
                    .foregroundStyle(Color.accentStart)
                Text("Pro")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentStart)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.accentStart.opacity(0.12))
            .clipShape(Capsule())
        } else {
            // Coin balance pill
            CoinsPillView(count: appState.coinsRemaining)
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
