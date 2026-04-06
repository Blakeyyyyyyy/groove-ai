// GroovePaywallScreen.swift
// Groove AI — Paywall screen (V4 spec - NO FREE TRIAL)
// Uses RevenueCatService ONLY

import SwiftUI
import RevenueCat
import UserNotifications

struct GroovePaywallScreen: View {
    let onComplete: () -> Void

    @StateObject private var rcService = RevenueCatService.shared

    enum PaywallPlan: String, CaseIterable { case yearly, weekly }

    @State private var selectedPlan: PaywallPlan = .yearly
    @State private var isPurchasing = false
    @State private var purchaseError: String?
    @State private var showExitPopup = false
    @State private var heroIndex = 0
    @State private var heroTimer: Timer?
    @State private var isRestoring = false

    // Pricing constants (per spec - NO FREE TRIAL)
    private let annualPrice: String = "$79.99/year"
    private let annualPerWeek: String = "$1.54/week"
    private let weeklyFirstWeek: String = "$7.99 first week"
    private let weeklyOngoing: String = "$9.99/week"

    // Computed discount
    private var discountPercent: Int {
        // (9.99 * 52 - 79.99) / (9.99 * 52) = ~85%
        return 85
    }

    var body: some View {
        ZStack {
            GrooveOnboardingTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // MARK: - Top Bar (X dismiss + Restore)
                HStack {
                    // X dismiss button (top-left, 44pt tap target)
                    Button(action: { showExitPopup = true }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: 0x94A3B8))
                            .frame(width: 44, height: 44)
                            .background(Color(hex: 0x2B3750).opacity(0.6))
                            .clipShape(Circle())
                    }
                    .padding(.leading, 16)
                    .padding(.top, 8)

                    Spacer()

                    // Restore button (top-right)
                    Button(action: { Task { await performRestore() } }) {
                        Text("Restore")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: 0x64748B))
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 8)
                    .disabled(isRestoring)
                }

                VStack(spacing: 12) { // NO-SCROLL - single screen
                    VStack(spacing: 0) {
                        // MARK: - Hero Output Collage (42% screen height)
                        heroSection
                            .frame(height: UIScreen.main.bounds.height * 0.42)

                        // MARK: - Headline + Subheadline
                        VStack(spacing: 8) {
                            Text("Your Photo. Dancing. In Minutes.")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(Color(hex: 0xF1F5F9))
                                .multilineTextAlignment(.center)

                            Text("Upload a photo of your pet, baby, or anyone — watch them dance to any style.")
                                .font(.system(size: 15))
                                .foregroundColor(Color(hex: 0x94A3B8))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 20)

                        // MARK: - Feature Bullets (icon grid)
                        featureBullets
                            .padding(.top, 20)
                            .padding(.horizontal, 16)

                        // MARK: - Pricing Plan Cards
                        pricingSection
                            .padding(.top, 20)
                            .padding(.horizontal, 16)

                        // MARK: - Pricing Timeline (INSTANT · $7.99 · $9.99/wk)
                        pricingTimeline
                            .padding(.top, 16)
                            .padding(.horizontal, 16)

                        Spacer(minLength: 100)
                    }
                }

                // MARK: - Sticky Bottom CTA Zone
                VStack(spacing: 0) {
                    Divider()
                        .background(Color.white.opacity(0.1))

                    VStack(spacing: 8) {
                        // Primary CTA button
                        Button(action: performPurchase) {
                            Group {
                                if isPurchasing {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("$7.99 to Start")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                LinearGradient(
                                    colors: [GrooveOnboardingTheme.blueAccent, Color(hex: 0xFF6B9D)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .disabled(isPurchasing)
                        .padding(.horizontal, 16)

                        // Reassurance text
                        Text("✓ first week $7.99 • cancel anytime in Settings")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: 0x94A3B8))
                            .multilineTextAlignment(.center)

                        // Legal links
                        HStack(spacing: 4) {
                            Link("Terms", destination: URL(string: "https://yourapp.com/terms")!)
                                .font(.system(size: 11))
                                .foregroundColor(Color(hex: 0x64748B))

                            Text("·")
                                .foregroundColor(Color(hex: 0x64748B).opacity(0.5))

                            Link("Privacy", destination: URL(string: "https://yourapp.com/privacy")!)
                                .font(.system(size: 11))
                                .foregroundColor(Color(hex: 0x64748B))
                        }
                    }
                    .padding(.vertical, 16)
                    .background(GrooveOnboardingTheme.background)
                }
            }
        }
        .onAppear {
            // Start hero carousel animation
            heroTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 0.5)) {
                    heroIndex = (heroIndex + 1) % 3
                }
            }

            // Load offerings
            Task {
                await rcService.fetchOfferings()
            }
        }
        .onDisappear {
            heroTimer?.invalidate()
        }
        .sheet(isPresented: $showExitPopup) {
            ExitPopupView(
                onSubscribe: {
                    showExitPopup = false
                    // Could trigger purchase here
                },
                onDismiss: {
                    showExitPopup = false
                    onComplete()
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.hidden)
            .presentationBackground(Color.black.opacity(0.85))
        }
    }

    // MARK: - Hero Output Collage

    private var heroSection: some View {
        ZStack {
            // Background gradient glow
            LinearGradient(
                colors: [
                    GrooveOnboardingTheme.blueAccent.opacity(0.15),
                    Color.clear,
                    Color(hex: 0xFF6B9D).opacity(0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Three dancing output cards (horizontal)
            HStack(spacing: 12) {
                ForEach(0..<3) { index in
                    VStack {
                        // Placeholder for dancing output
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: index == 0 ? [Color(hex: 0xFF6B9D), Color(hex: 0xFF8FAE)] :
                                           index == 1 ? [GrooveOnboardingTheme.blueAccent, Color(hex: 0x6366F1)] :
                                           [Color(hex: 0x8B5CF6), Color(hex: 0xA78BFA)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                VStack {
                                    Spacer()
                                    HStack {
                                        Text(index == 0 ? "🐕 Dog" : index == 1 ? "👶 Baby" : "💃 Hip Hop")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.black.opacity(0.3))
                                            .clipShape(Capsule())
                                    }
                                    .padding(12)
                                },
                                alignment: .bottomLeading
                            )
                            .opacity(heroIndex == index ? 1 : 0.5)
                            .scaleEffect(heroIndex == index ? 1.0 : 0.92)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: heroIndex)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Feature Bullets (Icon Grid)

    private var featureBullets: some View {
        let features: [(icon: String, label: String)] = [
            ("wand.and.stars", "AI Dance Videos"),
            ("photo", "Any Photo Works"),
            ("music.note", "20+ Dance Styles"),
            ("square.and.arrow.up", "Share Instantly"),
            ("bolt.fill", "Ready in Minutes"),
            ("arrow.counterclockwise", "Unlimited Generates")
        ]

        let rows = [
            [features[0], features[1]],
            [features[2], features[3]],
            [features[4], features[5]]
        ]

        return VStack(spacing: 12) {
            ForEach(0..<rows.count, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(0..<rows[row].count, id: \.self) { col in
                        let feature = rows[row][col]
                        HStack(spacing: 8) {
                            Image(systemName: feature.icon)
                                .font(.system(size: 16))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [GrooveOnboardingTheme.blueAccent, Color(hex: 0xFF6B9D)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                            Text(feature.label)
                                .font(.system(size: 13))
                                .foregroundColor(Color(hex: 0xF1F5F9))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    // MARK: - Pricing Section

    private var pricingSection: some View {
        VStack(spacing: 8) {
            // Section label
            Text("Choose Your Plan")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(hex: 0x64748B))
                .frame(maxWidth: .infinity, alignment: .leading)

            // Weekly plan card
            planCard(
                plan: .weekly,
                title: "Weekly",
                priceMain: weeklyOngoing,
                priceSub: "billed weekly",
                badge: nil,
                isSelected: selectedPlan == .weekly
            )

            // Yearly plan card (pre-selected, gradient border)
            planCard(
                plan: .yearly,
                title: "Yearly",
                priceMain: annualPerWeek,
                priceSub: "billed \(annualPrice) annually",
                badge: "\(discountPercent)% OFF",
                isSelected: selectedPlan == .yearly
            )
        }
    }

    private func planCard(plan: PaywallPlan, title: String, priceMain: String, priceSub: String, badge: String?, isSelected: Bool) -> some View {
        Button(action: { withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { selectedPlan = plan } }) {
            ZStack(alignment: .topTrailing) {
                // Card background
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: 0x1E293B))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? Color.clear : Color(hex: 0x2B3750), lineWidth: 1)
                    )

                // Gradient border for selected
                if isSelected {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [GrooveOnboardingTheme.blueAccent, Color(hex: 0xFF6B9D)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 2
                        )
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(title)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(Color(hex: 0xF1F5F9))

                            Text(priceMain)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(Color(hex: 0xF1F5F9))
                        }

                        Spacer()

                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [GrooveOnboardingTheme.blueAccent, Color(hex: 0xFF6B9D)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        }
                    }

                    Text(priceSub)
                        .font(.system(size: 15))
                        .foregroundColor(Color(hex: 0x94A3B8))
                }
                .padding(16)

                // Top-right badge
                if let badge = badge, isSelected {
                    Text(badge)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            LinearGradient(
                                colors: [GrooveOnboardingTheme.blueAccent, Color(hex: 0xFF6B9D)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                        .offset(x: -8, y: -8)
                }
            }
            .frame(height: 72)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Pricing Timeline (INSTANT · $7.99 · $9.99/wk)

    private var pricingTimeline: some View {
        VStack(spacing: 0) {
            Text("How Your Pricing Works")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(hex: 0x64748B))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 12)

            HStack(spacing: 0) {
                // Step 1: Instant
                VStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [GrooveOnboardingTheme.blueAccent, Color(hex: 0xFF6B9D)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    Text("Instant")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(hex: 0xF1F5F9))
                    Text("Access now")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: 0x94A3B8))
                }
                .frame(maxWidth: .infinity)

                // Dashed connector
                Rectangle()
                    .fill(Color(hex: 0x64748B).opacity(0.3))
                    .frame(height: 1)
                    .frame(maxWidth: 40)

                // Step 2: $7.99
                VStack(spacing: 4) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [GrooveOnboardingTheme.blueAccent, Color(hex: 0xFF6B9D)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    Text("$7.99")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(hex: 0xF1F5F9))
                    Text("first week only")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: 0x94A3B8))
                }
                .frame(maxWidth: .infinity)

                // Dashed connector
                Rectangle()
                    .fill(Color(hex: 0x64748B).opacity(0.3))
                    .frame(height: 1)
                    .frame(maxWidth: 40)

                // Step 3: $9.99/wk
                VStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [GrooveOnboardingTheme.blueAccent, Color(hex: 0xFF6B9D)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    Text("Save")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(hex: 0xF1F5F9))
                    Text("85% off annual")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: 0x94A3B8))
                }
                .frame(maxWidth: .infinity)
            }
            .padding(16)
            .background(Color(hex: 0x1E293B))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Purchase Logic

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

        do {
            let restored = try await rcService.restorePurchases()
            if restored {
                let isEntitled = await rcService.checkPremium()
                await MainActor.run {
                    isRestoring = false
                    if isEntitled {
                        onComplete()
                    } else {
                        purchaseError = "No purchases found to restore."
                    }
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
                purchaseError = "Failed to restore: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Array Extension for chunking

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
