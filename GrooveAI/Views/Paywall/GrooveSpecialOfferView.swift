// GrooveSpecialOfferView.swift
// Groove AI — Full-screen exit offer (replaces ExitPopupView + GrooveExitOfferView)
// Fires ONCE per user lifetime. 50% off first week.

import SwiftUI
import RevenueCat

struct GrooveSpecialOfferView: View {
    let onPurchaseComplete: () -> Void
    let onDismiss: () -> Void

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var rcService = RevenueCatService.shared
    @State private var isPurchasing = false
    @State private var purchaseError: String?
    @State private var showContent = false
    @Environment(\.openURL) private var openURL

    // Staggered reveal phases
    @State private var showHero = false
    @State private var showBadgeHeadline = false
    @State private var showPriceBlock = false
    @State private var showCTA = false

    // Spec colors
    private let sheetBg = Color(hex: 0x0D1017)
    private let accentBlue = Color(hex: 0x3D7FFF)
    private let secondaryText = Color.white.opacity(0.91)
    private let tertiaryText = Color.white.opacity(0.78)
    private let footerText = Color.white.opacity(0.65)
    private let dividerText = Color.white.opacity(0.39)

    private func log(_ message: String) {
        print("[SpecialOffer] \(message)")
    }

    // MARK: - One-Time Check

    private static let shownKey = "specialOfferShown_v1"

    static var hasBeenShown: Bool {
        UserDefaults.standard.bool(forKey: shownKey)
    }

    static func markShown() {
        UserDefaults.standard.set(true, forKey: shownKey)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background
            sheetBg.ignoresSafeArea()

            // Subtle accent radial glow
            RadialGradient(
                colors: [accentBlue.opacity(0.08), Color.clear],
                center: .top,
                startRadius: 60,
                endRadius: 400
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Drag handle
                    dragHandle
                        .padding(.top, 12)

                    // Hero visual
                    heroSection
                        .padding(.top, 20)
                        .opacity(showHero ? 1 : 0)
                        .offset(y: showHero ? 0 : 10)

                    // Badge
                    badgeLabel
                        .padding(.top, 20)
                        .opacity(showBadgeHeadline ? 1 : 0)

                    // Headline
                    headlineSection
                        .padding(.top, 16)
                        .opacity(showBadgeHeadline ? 1 : 0)

                    // Subheadline
                    subheadline
                        .padding(.top, 10)
                        .opacity(showBadgeHeadline ? 1 : 0)

                    // Price card (Loóna split pattern)
                    priceCard
                        .padding(.top, 20)
                        .opacity(showPriceBlock ? 1 : 0)
                        .scaleEffect(showPriceBlock ? 1 : 0.96)

                    // Renewal note
                    renewalNote
                        .padding(.top, 8)
                        .opacity(showPriceBlock ? 1 : 0)

                    // Expiry note
                    expiryNote
                        .padding(.top, 12)
                        .opacity(showPriceBlock ? 1 : 0)

                    // CTA
                    ctaButton
                        .padding(.top, 24)
                        .opacity(showCTA ? 1 : 0)

                    // Error
                    if let error = purchaseError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(Color.red)
                            .padding(.top, 8)
                    }

                    // Dismiss link
                    dismissLink
                        .padding(.top, 16)
                        .opacity(showCTA ? 1 : 0)

                    // Legal footer
                    legalFooter
                        .padding(.top, 12)
                        .padding(.bottom, 32)
                        .opacity(showCTA ? 1 : 0)
                }
                .padding(.horizontal, 24)
            }
        }
        .onAppear {
            log("appeared")
            Task { await rcService.fetchOfferings() }
            startStaggeredReveal()
        }
        .onDisappear {
            log("disappeared")
        }
    }

    // MARK: - Staggered Reveal

    private func startStaggeredReveal() {
        withAnimation(.easeOut(duration: 0.2).delay(0.15)) { showHero = true }
        withAnimation(.easeOut(duration: 0.2).delay(0.20)) { showBadgeHeadline = true }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8).delay(0.26)) { showPriceBlock = true }
        withAnimation(.easeOut(duration: 0.2).delay(0.32)) { showCTA = true }
    }

    // MARK: - Drag Handle

    private var dragHandle: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Color.white.opacity(0.125))
            .frame(width: 36, height: 4)
    }

    // MARK: - Hero Section (Gift Box V1)

    private var heroSection: some View {
        ZStack {
            // Glow
            Circle()
                .fill(accentBlue.opacity(0.15))
                .frame(width: 120, height: 120)
                .blur(radius: 30)

            // Gift icon
            Image(systemName: "gift.fill")
                .font(.system(size: 64))
                .foregroundStyle(accentBlue)

            // Sparkles
            Group {
                Image(systemName: "sparkle")
                    .font(.system(size: 14))
                    .foregroundStyle(accentBlue.opacity(0.7))
                    .offset(x: -50, y: -30)

                Image(systemName: "sparkle")
                    .font(.system(size: 10))
                    .foregroundStyle(accentBlue.opacity(0.6))
                    .offset(x: 45, y: -40)

                Image(systemName: "sparkle")
                    .font(.system(size: 12))
                    .foregroundStyle(accentBlue.opacity(0.8))
                    .offset(x: 55, y: 20)
            }
        }
        .frame(height: 140)
    }

    // MARK: - Badge

    private var badgeLabel: some View {
        Text("ONLY FOR YOU")
            .font(.system(size: 11, weight: .bold))
            .tracking(0.8)
            .foregroundStyle(accentBlue)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(accentBlue.opacity(0.094))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(accentBlue.opacity(0.375), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Headline (Option A from spec)

    private var headlineSection: some View {
        VStack(spacing: 6) {
            Text("50% Off.")
                .font(.system(size: 34, weight: .heavy))
                .foregroundStyle(accentBlue)

            Text("Your first week, $4.99.")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
        }
        .multilineTextAlignment(.center)
    }

    // MARK: - Subheadline

    private var subheadline: some View {
        Text("Gone when you leave. Never offered again.")
            .font(.system(size: 14, weight: .regular))
            .foregroundStyle(secondaryText)
            .multilineTextAlignment(.center)
    }

    // MARK: - Price Card (Loóna Split Pattern)

    private var priceCard: some View {
        VStack(spacing: 0) {
            // 50% OFF badge above card
            Text("50% OFF")
                .font(.system(size: 13, weight: .heavy))
                .tracking(0.4)
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(accentBlue)
                .clipShape(Capsule())
                .padding(.bottom, 10)

            // Split card
            HStack(spacing: 0) {
                // Left — Regular price
                VStack(spacing: 6) {
                    Text("Regular price")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(footerText)

                    Text("$9.99/wk")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundStyle(Color.red)
                        .strikethrough(color: Color.red)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)

                // Divider
                Rectangle()
                    .fill(Color.white.opacity(0.07))
                    .frame(width: 1)

                // Right — Your price
                VStack(spacing: 4) {
                    Text("Your price")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(tertiaryText)

                    Text("$4.99")
                        .font(.system(size: 34, weight: .heavy))
                        .foregroundStyle(.white)

                    Text("first week")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(tertiaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .background(Color.white.opacity(0.03))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Renewal Note

    private var renewalNote: some View {
        Text("then $9.99/week after")
            .font(.system(size: 12, weight: .regular))
            .foregroundStyle(secondaryText)
    }

    // MARK: - Expiry Note

    private var expiryNote: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock")
                .font(.system(size: 12))
                .foregroundStyle(tertiaryText)

            Text("This offer disappears when you leave.")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(secondaryText)
        }
    }

    // MARK: - CTA Button

    private var ctaButton: some View {
        Button {
            handlePurchase()
        } label: {
            HStack(spacing: 8) {
                if isPurchasing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Claim 50% Off — $4.99 This Week")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(accentBlue)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: accentBlue.opacity(0.31), radius: 12, y: 4)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(isPurchasing)
        .sensoryFeedback(.impact(weight: .medium), trigger: isPurchasing)
    }

    // MARK: - Dismiss Link

    private var dismissLink: some View {
        Button {
            log("No thanks tapped — before state change: hasCompletedOnboarding=\(appState.hasCompletedOnboarding), showPaywall=\(appState.showPaywall), selectedTab=\(appState.selectedTab)")
            appState.hasCompletedOnboarding = true
            appState.showPaywall = false
            appState.selectedTab = .home
            log("No thanks tapped — after state change: hasCompletedOnboarding=\(appState.hasCompletedOnboarding), showPaywall=\(appState.showPaywall), selectedTab=\(appState.selectedTab)")
            log("Calling onDismiss()")
            onDismiss()
            log("Calling dismiss()")
            dismiss()
        } label: {
            Text("No thanks, I'd rather pay full price later")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(tertiaryText)
        }
        .frame(minHeight: 44)
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }

    // MARK: - Legal Footer

    private var legalFooter: some View {
        VStack(spacing: 12) {
            Text("$4.99 for first week, then $9.99/week. Cancel anytime in App Store settings.")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(tertiaryText)
                .multilineTextAlignment(.center)

            // Restore + Privacy Policy
            HStack(spacing: 16) {
                Button {
                    Task { try? await rcService.restorePurchases() }
                } label: {
                    Text("Restore Purchases")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(footerText)
                }

                Text("·")
                    .font(.system(size: 11))
                    .foregroundStyle(dividerText)

                Button {
                    openURL(URL(string: "https://grooveai.app/privacy")!)
                } label: {
                    Text("Privacy Policy")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(footerText)
                }
            }
        }
    }

    // MARK: - Purchase

    private func handlePurchase() {
        guard !isPurchasing else { return }
        isPurchasing = true
        purchaseError = nil

        Task {
            do {
                // Use the weekly package from RevenueCat
                // Blake will create a separate exit offer product later
                guard let pkg = rcService.weeklyPackage() else {
                    await MainActor.run {
                        purchaseError = "Offer unavailable. Please try again."
                        isPurchasing = false
                    }
                    return
                }

                let success = try await rcService.purchase(package: pkg)

                await MainActor.run {
                    isPurchasing = false
                    if success {
                        log("Purchase complete — calling onPurchaseComplete()")
                        onPurchaseComplete()
                    } else {
                        purchaseError = "Purchase was not completed."
                    }
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
    GrooveSpecialOfferView(
        onPurchaseComplete: {},
        onDismiss: {}
    )
}
