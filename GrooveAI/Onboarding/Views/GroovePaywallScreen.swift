// GroovePaywallScreen.swift
// Groove AI — Paywall screen (V3 spec)
// Uses RevenueCatService ONLY (no IAPManager, no CoinStore)

import SwiftUI
import RevenueCat
import UserNotifications

struct GroovePaywallScreen: View {
    let onComplete: () -> Void

    @StateObject private var rcService = RevenueCatService.shared

    enum PaywallPlan { case yearly, weekly }

    @State private var selectedPlan: PaywallPlan = .yearly
    @State private var isPurchasing = false
    @State private var purchaseError: String?
    @State private var showCloseButton = false
    @State private var reviewIndex = 0
    @State private var reviewTimer: Timer?
    @State private var isRestoring = false

    // Pricing constants (per spec)
    private let annualPriceString = "$79.99/year"
    private let annualPerWeekString = "$1.54/week"
    private let weeklyIntroString = "$7.99/week"
    private let weeklyOngoingString = "$9.99/week"
    private let discountBadge = "85% OFF"
    private let trialDays = 3

    var body: some View {
        ZStack {
            GrooveOnboardingTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // MARK: - Header Row with delayed X close
                HStack {
                    Spacer()
                    if showCloseButton {
                        Button(action: { onComplete() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white.opacity(0.35))
                                .padding(12)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Circle())
                        }
                        .padding(.trailing, 16)
                        .padding(.top, 8)
                        .transition(.opacity.animation(.easeIn(duration: 0.4)))
                    }
                }

                // MARK: - Hero Copy (left-aligned per spec)
                VStack(spacing: 8) {
                    Text("Start your \(trialDays)-day FREE trial")
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    Text("No charge today. Cancel anytime.")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.55))
                }
                .padding(.top, showCloseButton ? 8 : 24)
                .padding(.horizontal, 24)

                // MARK: - Timeline (Drops-style: Today → Day 3 → Day 4)
                VStack(alignment: .leading, spacing: 0) {
                    GrooveTimelineItem(
                        icon: "lock.open.fill",
                        iconColor: GrooveOnboardingTheme.blueAccent,
                        title: "Today — Get full access free",
                        subtitle: "All dances, unlimited videos",
                        isActive: true,
                        isLast: false
                    )
                    GrooveTimelineItem(
                        icon: "bell.fill",
                        iconColor: .white.opacity(0.4),
                        title: "Day 2 — Reminder sent",
                        subtitle: "We'll remind you before it ends",
                        isActive: false,
                        isLast: false
                    )
                    GrooveTimelineItem(
                        icon: "creditcard.fill",
                        iconColor: .white.opacity(0.4),
                        title: "Day 4 — Subscription starts",
                        subtitle: "Only if you choose to keep it",
                        isActive: false,
                        isLast: true
                    )
                }
                .padding(.top, 20)
                .padding(.horizontal, 36)

                Spacer(minLength: 16)

                // MARK: - Social Proof (star rating + rotating review)
                VStack(spacing: 10) {
                    HStack(spacing: 4) {
                        ForEach(0..<5) { _ in
                            Image(systemName: "star.fill")
                                .font(.system(size: 16))
                                .foregroundColor(Color(hex: 0xFFD700))
                        }
                        Text("4.8 · 12k ratings")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                            .padding(.leading, 4)
                    }

                    Text(currentReviewText)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 32)
                        .animation(.easeInOut(duration: 0.4), value: reviewIndex)
                }
                .padding(.vertical, 12)

                // MARK: - Plan Selection
                VStack(spacing: 12) {
                    // Annual plan (pre-selected)
                    GroovePlanCard(
                        isSelected: selectedPlan == .yearly,
                        title: "Yearly",
                        priceMain: annualPerWeekString,
                        priceSub: annualPriceString + " billed annually",
                        badgeTop: "3-day free trial",
                        badgeCorner: discountBadge,
                        action: { selectedPlan = .yearly }
                    )

                    // Weekly plan
                    GroovePlanCard(
                        isSelected: selectedPlan == .weekly,
                        title: "Weekly",
                        priceMain: weeklyIntroString,
                        priceSub: "then \(weeklyOngoingString) • cancel anytime",
                        badgeTop: nil,
                        badgeCorner: nil,
                        action: { selectedPlan = .weekly }
                    )
                }
                .padding(.horizontal, 20)

                Spacer(minLength: 8)

                // MARK: - Error
                if let error = purchaseError {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundColor(.red.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 6)
                }

                // MARK: - CTA
                Button(action: performPurchase) {
                    Group {
                        if isPurchasing {
                            ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Start Dancing Free")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(GrooveOnboardingTheme.blueAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: GrooveOnboardingTheme.blueAccent.opacity(0.45), radius: 12, y: 5)
                }
                .disabled(isPurchasing)
                .padding(.horizontal, 20)
                .padding(.top, 8)

                // MARK: - Footer
                VStack(spacing: 10) {
                    Text(selectedPlan == .yearly
                        ? "3 days free, then \(annualPriceString) (\(annualPerWeekString))"
                        : "\(weeklyIntroString) first week, then \(weeklyOngoingString)")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.35))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    HStack(spacing: 20) {
                        Button("Restore") {
                            Task { await performRestore() }
                        }
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.35))

                        Text("·").foregroundColor(.white.opacity(0.2))

                        Link("Privacy", destination: URL(string: "https://yourapp.com/privacy")!)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.35))

                        Text("·").foregroundColor(.white.opacity(0.2))

                        Link("Terms", destination: URL(string: "https://yourapp.com/terms")!)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.35))
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 36)
            }
        }
        .onAppear {
            // Show X close button after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                    showCloseButton = true
                }
            }

            // Start review rotation
            reviewTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { _ in
                reviewIndex = (reviewIndex + 1) % 3
            }

            // Load offerings
            Task {
                await rcService.fetchOfferings()
            }
        }
        .onDisappear {
            reviewTimer?.invalidate()
        }
    }

    // MARK: - Review text rotation
    private let reviewTexts = [
        "pranked my boyfriend and he literally couldn't tell it was AI 😭",
        "used this for my instagram and got 47k views on the first reel",
        "my mum actually believed the photo was real. best app ever!"
    ]

    private var currentReviewText: String {
        reviewTexts[reviewIndex]
    }

    // MARK: - Purchase

    private func performPurchase() {
        purchaseError = nil
        isPurchasing = true

        Task {
            defer { isPurchasing = false }

            let package: Package? = selectedPlan == .yearly
                ? rcService.annualPackage()
                : rcService.weeklyPackage()

            guard let pkg = package else {
                purchaseError = "Unable to load products. Please try again."
                return
            }

            do {
                let success = try await rcService.purchase(package: pkg)
                if success {
                    await MainActor.run { onComplete() }
                } else {
                    purchaseError = "Purchase was not completed."
                }
            } catch {
                purchaseError = error.localizedDescription
            }
        }
    }

    private func performRestore() async {
        isRestoring = true
        purchaseError = nil

        await rcService.restorePurchases()
        let isEntitled = await rcService.checkPremium()

        await MainActor.run {
            isRestoring = false
            if isEntitled {
                onComplete()
            } else {
                purchaseError = "No purchases found to restore."
            }
        }
    }
}

// MARK: - Timeline Item with icon (per spec)

struct GrooveTimelineItem: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let isActive: Bool
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(iconColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.55))
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Plan Card (per spec)

struct GroovePlanCard: View {
    let isSelected: Bool
    let title: String
    let priceMain: String
    let priceSub: String
    let badgeTop: String?
    let badgeCorner: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .top) {
                // Card background
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isSelected ? GrooveOnboardingTheme.blueAccent : Color.white.opacity(0.12),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        // Title + price
                        VStack(alignment: .leading, spacing: 2) {
                            Text(title)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)

                            Text(priceMain)
                                .font(.system(size: 20, weight: .heavy))
                                .foregroundColor(.white)
                        }

                        Spacer()

                        // Checkmark when selected
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(GrooveOnboardingTheme.blueAccent)
                        }
                    }

                    // Subtitle
                    Text(priceSub)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(16)

                // Top badge (e.g., "3-day free trial")
                if let badge = badgeTop {
                    Text(badge)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(GrooveOnboardingTheme.blueAccent)
                        .clipShape(Capsule())
                        .offset(y: -12)
                }

                // Corner badge (e.g., "85% OFF")
                if let badge = badgeCorner, isSelected {
                    Text(badge)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(hex: 0xFF6B6B))
                        .clipShape(Capsule())
                        .offset(x: 100, y: -12)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
