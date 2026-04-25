// GroovePaywallScreen.swift
// Groove AI — Single-screen no-scroll paywall
// Pure black background, minimal premium design
// All pricing dynamic from RevenueCat

import SwiftUI
import RevenueCat

struct GroovePaywallScreenV2: View {
    let onPurchaseSuccess: () -> Void
    let onDismiss: () -> Void

    @Environment(AppState.self) private var appState
    @StateObject private var rcService = RevenueCatService.shared

    enum PaywallPlan: String, CaseIterable { case weekly, yearly }

    @State private var selectedPlan: PaywallPlan = .weekly
    @State private var isPurchasing = false
    @State private var purchaseError: String?
    @State private var showExitPopup = false
    @State private var isRestoring = false
    @State private var showProductError = false

    // Colors — pure black + minimal accents
    private let accentBlue = Color(hex: 0x3B82F6)
    private let textPrimary = Color.white
    private let textSecondary = Color.white.opacity(0.5)
    private let textTertiary = Color.white.opacity(0.35)

    private func log(_ message: String) {
        print("[GroovePaywallScreen] \(message)")
    }

    // MARK: - Dynamic Pricing Helpers

    private var weeklyPkg: Package? { rcService.weeklyPackage() }
    private var annualPkg: Package? { rcService.annualPackage() }

    /// Strip currency symbols (USD, $, etc.) from price string
    private func stripCurrency(_ priceString: String) -> String {
        // Remove $, USD, US$, currency symbols, and whitespace
        var cleaned = priceString
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: "USD", with: "")
            .replacingOccurrences(of: "US$", with: "")
            .replacingOccurrences(of: "€", with: "")
            .replacingOccurrences(of: "£", with: "")
            .replacingOccurrences(of: "¥", with: "")
            .trimmingCharacters(in: .whitespaces)
        return cleaned
    }

    /// Weekly intro price (e.g. "7.99") — dynamically from RevenueCat package
    private var weeklyIntroPrice: String {
        // Get intro discount price from package, strip currency symbols
        if let intro = weeklyPkg?.storeProduct.introductoryDiscount {
            let price = intro.localizedPriceString
            return stripCurrency(price)
        }
        // Fallback: use the package's base price if no intro discount
        return stripCurrency(weeklyPkg?.localizedPriceString ?? "7.99")
    }

    /// Weekly renewal price (e.g. "9.99") — stripped of currency symbols
    private var weeklyRenewalPrice: String {
        stripCurrency(weeklyPkg?.localizedPriceString ?? "9.99")
    }

    /// Weekly intro price as Decimal
    private var weeklyIntroPriceDecimal: Decimal {
        if let intro = weeklyPkg?.storeProduct.introductoryDiscount {
            return intro.price
        }
        return weeklyPkg?.storeProduct.price ?? 7.99
    }

    /// Weekly renewal as Decimal
    private var weeklyRenewalDecimal: Decimal {
        weeklyPkg?.storeProduct.price ?? 9.99
    }

    /// Annual price string (e.g. "79.99/year") — stripped of currency symbols
    private var annualPriceString: String {
        let price = stripCurrency(annualPkg?.localizedPriceString ?? "79.99")
        return "\(price)/year"
    }

    /// Annual price as Decimal
    private var annualPriceDecimal: Decimal {
        annualPkg?.storeProduct.price ?? 79.99
    }

    /// Weekly equivalent for annual (annual / 52) — stripped of currency symbols
    private var annualWeeklyEquivalent: String {
        let weekly = NSDecimalNumber(decimal: annualPriceDecimal / 52).doubleValue
        return String(format: "%.2f/week", weekly)
    }

    /// Percentage saved vs weekly renewal
    private var savingsPercent: Int {
        let weeklyAnnualized = weeklyRenewalDecimal * 52
        guard weeklyAnnualized > 0 else { return 0 }
        let saved = ((weeklyAnnualized - annualPriceDecimal) / weeklyAnnualized) * 100
        return Int(NSDecimalNumber(decimal: saved).doubleValue.rounded())
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Pure black background
            Color.black.ignoresSafeArea()

            // Optional subtle vignette
            RadialGradient(
                colors: [Color.clear, Color.black.opacity(0.3)],
                center: .center,
                startRadius: UIScreen.main.bounds.height * 0.3,
                endRadius: UIScreen.main.bounds.height * 0.6
            )
            .ignoresSafeArea()

            // Main content — NO ScrollView
            VStack(spacing: 0) {
                Spacer().frame(height: 44)

                // Hero collage
                heroCollage
                    .frame(height: UIScreen.main.bounds.height * 0.28)
                    .padding(.top, 4)

                // Headline only — no subtext
                Text("Make Anyone Dance")
                    .font(.system(size: 27, weight: .bold))
                    .foregroundColor(textPrimary)
                    .lineLimit(1)
                    .padding(.horizontal, 16)
                    .padding(.top, 20)

                Spacer(minLength: 0)

                // Plan cards directly above CTA
                planCardsSection
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)

                bottomCTAZone
            }

            // Dismiss X (top-left) + Restore (top-right)
            VStack {
                HStack {
                    dismissButton
                    Spacer()
                    restoreButton
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                Spacer()
            }
        }
        .onAppear {
            log("appeared")
            Task { await rcService.fetchOfferings() }
        }
        .onDisappear {
            log("disappeared")
        }
        .alert("Unable to Load Subscription", isPresented: $showProductError) {
            Button("Retry") {
                Task { await rcService.fetchOfferings() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please check your connection and try again.")
        }
        .fullScreenCover(isPresented: $showExitPopup) {
            GrooveSpecialOfferView(
                onPurchaseComplete: {
                    log("Special offer purchase complete callback — calling onPurchaseSuccess()")
                    // Complete onboarding directly — removes entire onboarding
                    // view tree including this fullScreenCover
                    onPurchaseSuccess()
                },
                onDismiss: {
                    log("Special offer dismiss callback — calling onDismiss()")
                    // "No thanks" — complete onboarding to go straight to home.
                    // Don't just dismiss the cover (that reveals the paywall).
                    // Calling onDismiss() lets the caller decide how to exit this flow.
                    onDismiss()
                }
            )
        }
    }

    // MARK: - Dismiss Button

    private var dismissButton: some View {
        Button(action: {
            // Fire special offer ONCE per user, then skip to dismiss
            if !GrooveSpecialOfferView.hasBeenShown {
                log("Dismiss tapped — presenting special offer")
                GrooveSpecialOfferView.markShown()
                showExitPopup = true
            } else {
                log("Dismiss tapped — special offer already shown, calling onDismiss()")
                onDismiss()
            }
        }) {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.white.opacity(0.25))
                .frame(width: 44, height: 44)
        }
    }

    // MARK: - Restore Button

    private var restoreButton: some View {
        Button(action: { Task { await performRestore() } }) {
            Text("Restore")
                .font(.system(size: 12))
                .foregroundColor(textTertiary)
                .frame(height: 44)
        }
        .disabled(isRestoring)
    }

    // MARK: - Hero Collage

    private var heroCollage: some View {
        HStack(spacing: 10) {
            heroCard(
                label: "Dog",
                colors: [Color(hex: 0x3B82F6), Color(hex: 0x60A5FA)]
            )
            heroCard(
                label: "Baby",
                colors: [Color(hex: 0x818CF8), Color(hex: 0xA78BFA)]
            )
            heroCard(
                label: "Hip Hop",
                colors: [Color(hex: 0x67E8F9), Color(hex: 0xA5F3FC)]
            )
        }
        .padding(.horizontal, 16)
    }

    private func heroCard(label: String, colors: [Color]) -> some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: colors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.black.opacity(0.35))
                .clipShape(Capsule())
                .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Plan Cards

    private var planCardsSection: some View {
        VStack(spacing: 10) {
            // Weekly card (selected by default)
            planCard(
                plan: .weekly,
                titleLine: "Just \(weeklyIntroPrice)/week",
                subtitle: "No commitment \u{00B7} Cancel anytime",
                badge: "Popular",
                isSelected: selectedPlan == .weekly
            )

            // Yearly card
            planCard(
                plan: .yearly,
                titleLine: "Yearly \u{2013} \(stripCurrency(annualPkg?.localizedPriceString ?? "79.99"))/year",
                subtitle: "Just \(annualWeeklyEquivalent)",
                badge: savingsPercent > 0 ? "Save \(savingsPercent)%" : nil,
                isSelected: selectedPlan == .yearly
            )
        }
    }

    // Purple shimmer phase for badge animation
    @State private var shimmerPhase: CGFloat = 0

    private func planCard(
        plan: PaywallPlan,
        titleLine: String,
        subtitle: String,
        badge: String?,
        isSelected: Bool
    ) -> some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                selectedPlan = plan
            }
        } label: {
            HStack(spacing: 0) {
                // Left: title + subtitle
                VStack(alignment: .leading, spacing: 4) {
                    Text(titleLine)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(textPrimary)

                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(Color.white.opacity(0.85))
                }
                .padding(.leading, 16)

                Spacer()

                if plan == .yearly, let badge = badge {
                    savingsBadge(badge)
                        .padding(.trailing, 16)
                }
            }
            .frame(height: 72)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.black)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        isSelected ? accentBlue : Color.white.opacity(0.15),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            // Badge on top border line, left-aligned
            .overlay(alignment: .topTrailing) {
                if plan != .yearly, let badge = badge {
                    savingsBadge(badge)
                        .offset(x: -20, y: -12) // Right-aligned, half above/below top border
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func savingsBadge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: 0x7B2FBE),
                                Color(hex: 0xA855F7),
                                Color(hex: 0xC084FC),
                                Color(hex: 0xA855F7),
                                Color(hex: 0x7B2FBE)
                            ],
                            startPoint: UnitPoint(x: shimmerPhase - 0.5, y: 0),
                            endPoint: UnitPoint(x: shimmerPhase + 0.5, y: 1)
                        )
                    )
            )
            .shadow(color: Color(hex: 0xA855F7).opacity(0.5), radius: 6, y: 2)
            .onAppear {
                withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                    shimmerPhase = 1.5
                }
            }
    }

    // MARK: - Sticky Bottom CTA Zone

    private var bottomCTAZone: some View {
        VStack(spacing: 8) {
            // CTA Button — solid blue, no gradient
            Button(action: performPurchase) {
                Group {
                    if isPurchasing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Continue")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(accentBlue)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .scaleEffect(isPurchasing ? 0.98 : 1.0)
                .animation(.spring(response: 0.2), value: isPurchasing)
            }
            .disabled(isPurchasing)
            .sensoryFeedback(.success, trigger: isPurchasing)
            .padding(.horizontal, 16)

            // Below CTA — context-sensitive renewal info
            Group {
                if selectedPlan == .weekly {
                    Text("First week \(weeklyIntroPrice), then \(weeklyRenewalPrice)/week \u{00B7} cancel anytime")
                } else {
                    Text("No commitment \u{00B7} Cancel anytime")
                }
            }
            .font(.system(size: 12))
            .foregroundColor(Color.white.opacity(0.85))

            // Legal links
            HStack(spacing: 4) {
                Link("Terms", destination: URL(string: "https://grooveai.app/terms")!)
                    .font(.system(size: 11))
                    .foregroundColor(textTertiary)

                Text("\u{00B7}")
                    .font(.system(size: 11))
                    .foregroundColor(textTertiary.opacity(0.5))

                Link("Privacy", destination: URL(string: "https://grooveai.app/privacy")!)
                    .font(.system(size: 11))
                    .foregroundColor(textTertiary)
            }
        }
        .padding(.bottom, 12)
        .padding(.top, 12)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0), Color.black],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.3)
            )
            .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - Purchase Logic

    private func performPurchase() {
        guard !isPurchasing else { return }
        purchaseError = nil
        isPurchasing = true

        Task {
            defer { Task { @MainActor in isPurchasing = false } }

            let package: Package? = selectedPlan == .yearly
                ? rcService.annualPackage()
                : rcService.weeklyPackage()

            guard let pkg = package else {
                await MainActor.run {
                    isPurchasing = false
                    showProductError = true
                }
                return
            }

            do {
                let success = try await rcService.purchase(package: pkg)
                log("performPurchase result success=\(success) selectedPlan=\(selectedPlan.rawValue) product=\(pkg.storeProduct.productIdentifier)")
                if success {
                    await MainActor.run {
                        appState.isSubscribed = true
                        log("performPurchase success path — calling onPurchaseSuccess()")
                        onPurchaseSuccess()
                    }
                } else {
                    await MainActor.run {
                        log("performPurchase returned false — setting purchaseError")
                        purchaseError = "Purchase was not completed."
                    }
                }
            } catch {
                await MainActor.run {
                    log("performPurchase error=\(error.localizedDescription)")
                    purchaseError = error.localizedDescription
                }
            }
        }
    }

    private func performRestore() async {
        isRestoring = true
        purchaseError = nil

        do {
            let restored = try await rcService.restorePurchases()
            if restored {
                let isEntitled = await rcService.checkPremium()
                await MainActor.run {
                    isRestoring = false
                    if isEntitled {
                        appState.isSubscribed = true
                        onPurchaseSuccess()
                    }
                    else { purchaseError = "No purchases found to restore." }
                }
            } else {
                await MainActor.run {
                    isRestoring = false
                    purchaseError = "No purchases found to restore."
                }
            }
        } catch {
            await MainActor.run {
                isRestoring = false
                purchaseError = "Restore failed: \(error.localizedDescription)"
            }
        }
    }
}
