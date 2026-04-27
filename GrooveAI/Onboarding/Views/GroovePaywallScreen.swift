// GroovePaywallScreen.swift
// Groove AI — Single-screen no-scroll paywall
// Pure black background, minimal premium design
// All pricing dynamic from RevenueCat

import SwiftUI
import RevenueCat

private enum OnboardingPaywallImageLoader {
    private static let workspaceRoot = "/Users/blakeyyyclaw/.openclaw/workspace/groove-ai"

    static func load(_ name: String, fallbackPaths: [String]) -> UIImage? {
        if let image = UIImage(named: name) {
            return image
        }

        for path in ([name] + fallbackPaths) {
            let absolutePath = path.hasPrefix("/") ? path : "\(workspaceRoot)/\(path)"
            if let image = UIImage(contentsOfFile: absolutePath) {
                return image
            }
        }

        return nil
    }
}

private struct PaywallCollageItem: Identifiable {
    let id = UUID()
    let urlString: String
    let rotation: Double
    let verticalOffset: CGFloat
}

private let paywallCollageBase = "https://videos.trygrooveai.com/presets"
private let paywallCollageItems: [PaywallCollageItem] = [
    .init(urlString: "\(paywallCollageBase)/big-guy-V5-AI.mp4", rotation: -7, verticalOffset: -12),
    .init(urlString: "\(paywallCollageBase)/c-walk-V5-AI.mp4", rotation: 4, verticalOffset: -18),
    .init(urlString: "\(paywallCollageBase)/baby-boombastic.mp4", rotation: -5, verticalOffset: 10),
    .init(urlString: "\(paywallCollageBase)/milkshake-V5-AI.mp4", rotation: 6, verticalOffset: 8),
    .init(urlString: "\(paywallCollageBase)/trag-V5-AI.mp4", rotation: -4, verticalOffset: -4),
    .init(urlString: "\(paywallCollageBase)/ophelia-ai.mp4", rotation: 5, verticalOffset: 12)
]

struct GroovePaywallScreen: View {
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

    private let accentBlue = Color(hex: 0x3B82F6)
    private let textPrimary = Color.white
    private let textSecondary = Color.white.opacity(0.5)
    private let textTertiary = Color.white.opacity(0.35)

    private func log(_ message: String) {
        print("[GroovePaywallScreen] \(message)")
    }

    private var weeklyPkg: Package? { rcService.weeklyPackage() }
    private var annualPkg: Package? { rcService.annualPackage() }

    /// Whether StoreKit product data has loaded.
    private var hasProductData: Bool {
        weeklyPkg != nil || annualPkg != nil
    }

    private var weeklyIntroPrice: String? {
        if let intro = weeklyPkg?.storeProduct.introductoryDiscount {
            return intro.localizedPriceString
        }
        return weeklyPkg?.localizedPriceString
    }

    private var weeklyRenewalPrice: String? {
        weeklyPkg?.localizedPriceString
    }

    private var annualPriceString: String? {
        guard let price = annualPkg?.localizedPriceString else { return nil }
        return "\(price) / year"
    }

    private var savingsPercent: Int {
        guard let weeklyRenewalDecimal = weeklyPkg?.storeProduct.price,
              let annualPriceDecimal = annualPkg?.storeProduct.price else { return 0 }
        let weeklyAnnualized = weeklyRenewalDecimal * 52
        guard weeklyAnnualized > 0 else { return 0 }
        let saved = ((weeklyAnnualized - annualPriceDecimal) / weeklyAnnualized) * 100
        return Int(NSDecimalNumber(decimal: saved).doubleValue.rounded())
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            RadialGradient(
                colors: [Color.clear, Color.black.opacity(0.3)],
                center: .center,
                startRadius: UIScreen.main.bounds.height * 0.3,
                endRadius: UIScreen.main.bounds.height * 0.6
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 113)

                heroCollage
                    .frame(height: UIScreen.main.bounds.height * 0.22)
                    .padding(.top, 4)

                Spacer(minLength: 0)

                Text("Make Anyone Dance")
                    .font(.system(size: 27, weight: .bold))
                    .foregroundColor(textPrimary)
                    .lineLimit(1)
                    .padding(.horizontal, 16)

                Spacer(minLength: 0)

                planCardsSection
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)

                bottomCTAZone
            }

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
            GrooveSpecialOfferPaywallV2(
                onPurchaseComplete: {
                    log("V2 Special offer purchase complete — calling onPurchaseSuccess()")
                    onPurchaseSuccess()
                },
                onDismiss: {
                    log("V2 Special offer dismissed — calling onDismiss()")
                    onDismiss()
                }
            )
        }
    }

    private var dismissButton: some View {
        Button(action: {
            log("Dismiss tapped — presenting special offer V2")
            showExitPopup = true
        }) {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.white.opacity(0.25))
                .frame(width: 44, height: 44)
        }
    }

    private var restoreButton: some View {
        Button(action: { Task { await performRestore() } }) {
            Text("Restore")
                .font(.system(size: 12))
                .foregroundColor(textTertiary)
                .frame(height: 44)
        }
        .disabled(isRestoring)
    }

    private var heroCollage: some View {
        Group {
            if let collage = UIImage(named: "paywall-collage") {
                Image(uiImage: collage)
                    .resizable()
                    .scaledToFill()
            } else {
                GrooveOnboardingTheme.surfaceL1
            }
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 16)
    }

    private var planCardsSection: some View {
        VStack(spacing: 10) {
            planCard(
                plan: .weekly,
                titleLine: weeklyIntroPrice.map { "Just \($0)/week" },
                subtitle: "No commitment \u{00B7} Cancel anytime",
                badge: "Popular",
                isSelected: selectedPlan == .weekly
            )

            planCard(
                plan: .yearly,
                titleLine: annualPriceString,
                subtitle: "Billed annually",
                badge: savingsPercent > 0 ? "Save \(savingsPercent)%" : nil,
                isSelected: selectedPlan == .yearly
            )
        }
    }

    @State private var shimmerPhase: CGFloat = 0

    private func planCard(
        plan: PaywallPlan,
        titleLine: String?,
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
                VStack(alignment: .leading, spacing: 4) {
                    Text(titleLine ?? "Loading...")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(textPrimary)
                        .redacted(reason: titleLine == nil ? .placeholder : [])

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
            .overlay(alignment: .topTrailing) {
                if plan != .yearly, let badge = badge {
                    savingsBadge(badge)
                        .offset(x: -20, y: -12)
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

    private var bottomCTAZone: some View {
        VStack(spacing: 8) {
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
            .disabled(isPurchasing || !hasProductData)
            .opacity(hasProductData ? 1.0 : 0.5)
            .sensoryFeedback(.success, trigger: isPurchasing)
            .padding(.horizontal, 16)

            Group {
                if selectedPlan == .weekly, let intro = weeklyIntroPrice, let renewal = weeklyRenewalPrice {
                    Text("First week \(intro), then \(renewal)/week \u{00B7} cancel anytime")
                } else {
                    Text("No commitment \u{00B7} Cancel anytime")
                }
            }
            .font(.system(size: 12))
            .foregroundColor(Color.white.opacity(0.85))

            HStack(spacing: 4) {
                Link("Terms", destination: URL(string: "https://trygrooveai.com/terms")!)
                    .font(.system(size: 11))
                    .foregroundColor(.white)

                Text("·")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.5))

                Link("Privacy", destination: URL(string: "https://trygrooveai.com/privacy")!)
                    .font(.system(size: 11))
                    .foregroundColor(.white)
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
