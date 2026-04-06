// GroovePaywallScreen.swift
// Groove AI — Single-screen no-scroll paywall
// NO ScrollView — fits above fold on iPhone Pro
// Pricing: $7.99 first week, then $9.99/week (no free trial)

import SwiftUI
import RevenueCat

struct GroovePaywallScreen: View {
    let onComplete: () -> Void

    @StateObject private var rcService = RevenueCatService.shared

    enum PaywallPlan: String, CaseIterable { case weekly, yearly }

    @State private var selectedPlan: PaywallPlan = .weekly
    @State private var isPurchasing = false
    @State private var purchaseError: String?
    @State private var showExitPopup = false
    @State private var isRestoring = false

    // Colors
    private let bgColor = Color(hex: 0x0F172A)
    private let cardBg = Color(hex: 0x1E293B)
    private let accentBlue = Color(hex: 0x3B82F6)
    private let textPrimary = Color(hex: 0xF1F5F9)
    private let textSecondary = Color(hex: 0x94A3B8)
    private let textTertiary = Color(hex: 0x64748B)
    private let borderIdle = Color(hex: 0x2B3750)

    // MARK: - Body

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            // Main content — NO ScrollView
            VStack(spacing: 0) {
                // Top bar spacer
                Spacer().frame(height: 44)

                // Hero collage
                heroCollage
                    .frame(height: UIScreen.main.bounds.height * 0.28)
                    .padding(.top, 4)

                // Headline + Subheadline
                VStack(spacing: 6) {
                    Text("Make Anyone Dance")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(textPrimary)
                        .lineLimit(1)

                    Text("Upload a photo of your pet, baby, or anyone and watch them dance to any style.")
                        .font(.system(size: 14))
                        .foregroundColor(textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)

                // Plan cards
                planCardsSection
                    .padding(.horizontal, 16)
                    .padding(.top, 20)

                Spacer(minLength: 0)
            }

            // Sticky bottom CTA zone
            VStack {
                Spacer()
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
            Task { await rcService.fetchOfferings() }
        }
        .sheet(isPresented: $showExitPopup) {
            ExitPopupView(
                onSubscribe: {
                    showExitPopup = false
                    performPurchase()
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

    // MARK: - Dismiss Button

    private var dismissButton: some View {
        Button(action: { showExitPopup = true }) {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(textSecondary)
                .frame(width: 44, height: 44)
                .background(Color(hex: 0x2B3750).opacity(0.6))
                .clipShape(Circle())
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

            // Label pill
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

    // MARK: - Plan Cards (Weekly first, selected; Yearly second)

    private var planCardsSection: some View {
        VStack(spacing: 8) {
            // Weekly card (selected by default)
            planCard(
                plan: .weekly,
                title: "Weekly",
                priceMain: "$9.99/week",
                priceSub: "first week $7.99",
                badge: nil,
                isSelected: selectedPlan == .weekly
            )

            // Yearly card
            planCard(
                plan: .yearly,
                title: "Yearly",
                priceMain: "$1.92/week",
                priceSub: "$99.99/year",
                badge: "SAVE 80%",
                isSelected: selectedPlan == .yearly
            )
        }
    }

    private func planCard(
        plan: PaywallPlan,
        title: String,
        priceMain: String,
        priceSub: String,
        badge: String?,
        isSelected: Bool
    ) -> some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                selectedPlan = plan
            }
        } label: {
            HStack(spacing: 12) {
                // Left: radio indicator
                ZStack {
                    Circle()
                        .stroke(
                            isSelected ? accentBlue : borderIdle,
                            lineWidth: 2
                        )
                        .frame(width: 22, height: 22)

                    if isSelected {
                        Circle()
                            .fill(accentBlue)
                            .frame(width: 22, height: 22)

                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }
                }

                // Center-left: title + badge + sub price
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(textPrimary)

                        if let badge = badge {
                            Text(badge)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(accentBlue)
                                .clipShape(Capsule())
                        }
                    }

                    Text(priceSub)
                        .font(.system(size: 13))
                        .foregroundColor(textSecondary)
                }

                Spacer()

                // Right: main price
                Text(priceMain)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(textPrimary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(height: 68)
            .background(cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected ? accentBlue : borderIdle,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sticky Bottom CTA Zone

    private var bottomCTAZone: some View {
        VStack(spacing: 8) {
            // CTA Button — solid blue, 56pt, full-width
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

            // Reassurance
            Text("first week $7.99, then $9.99/week \u{00B7} cancel anytime")
                .font(.system(size: 12))
                .foregroundColor(textSecondary)

            // Legal links
            HStack(spacing: 4) {
                Link("Terms", destination: URL(string: "https://yourapp.com/terms")!)
                    .font(.system(size: 11))
                    .foregroundColor(textTertiary)

                Text("\u{00B7}")
                    .font(.system(size: 11))
                    .foregroundColor(textTertiary.opacity(0.5))

                Link("Privacy", destination: URL(string: "https://yourapp.com/privacy")!)
                    .font(.system(size: 11))
                    .foregroundColor(textTertiary)
            }
        }
        .padding(.bottom, 12)
        .padding(.top, 12)
        .background(
            LinearGradient(
                colors: [bgColor.opacity(0), bgColor],
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
                    purchaseError = "Unable to load products. Please try again."
                    isPurchasing = false
                }
                return
            }

            do {
                let success = try await rcService.purchase(package: pkg)
                if success {
                    await MainActor.run { onComplete() }
                } else {
                    await MainActor.run { purchaseError = "Purchase was not completed." }
                }
            } catch {
                await MainActor.run { purchaseError = error.localizedDescription }
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
                    if isEntitled { onComplete() }
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
