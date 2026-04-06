// GroovePaywallScreen.swift
// Groove AI — Single-screen no-scroll paywall (visual spec V5)
// NO ScrollView — fits above fold on iPhone Pro
// Pricing: $7.99 first week, then $9.99/week (no free trial)

import SwiftUI
import RevenueCat

struct GroovePaywallScreen: View {
    let onComplete: () -> Void

    @StateObject private var rcService = RevenueCatService.shared

    enum PaywallPlan: String, CaseIterable { case yearly, weekly }

    @State private var selectedPlan: PaywallPlan = .yearly
    @State private var isPurchasing = false
    @State private var purchaseError: String?
    @State private var showExitPopup = false
    @State private var isRestoring = false

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background
            Color(hex: 0x0F172A).ignoresSafeArea()

            // Subtle radial glow
            RadialGradient(
                colors: [Color(hex: 0x8B5CF6).opacity(0.08), Color.clear],
                center: .top,
                startRadius: 40,
                endRadius: 350
            )
            .ignoresSafeArea()

            // Main content — NO ScrollView
            VStack(spacing: 0) {
                // Top bar
                topBar

                // Hero collage — 30% screen height
                heroCollage
                    .frame(height: UIScreen.main.bounds.height * 0.28)
                    .padding(.top, 4)

                // Headline + Subheadline
                VStack(spacing: 6) {
                    Text("Make Anyone Dance")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(Color(hex: 0xF1F5F9))
                        .lineLimit(1)

                    Text("Upload a photo of your pet, baby, or anyone — watch them dance to any style.")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: 0x94A3B8))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)

                // Feature bullets — max 4, 2 columns
                featureBulletsGrid
                    .padding(.horizontal, 16)
                    .padding(.top, 14)

                // Plan cards
                planCardsSection
                    .padding(.horizontal, 16)
                    .padding(.top, 14)

                Spacer(minLength: 0)
            }

            // Sticky bottom CTA zone
            VStack {
                Spacer()
                bottomCTAZone
            }

            // Dismiss X — top-left, absolute positioned
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

    // MARK: - Top Bar (invisible spacer for safe area)

    private var topBar: some View {
        HStack {
            Spacer()
        }
        .frame(height: 44)
    }

    // MARK: - Dismiss Button (top-left, 44pt tap target)

    private var dismissButton: some View {
        Button(action: { showExitPopup = true }) {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(hex: 0x94A3B8))
                .frame(width: 44, height: 44)
                .background(Color(hex: 0x2B3750).opacity(0.6))
                .clipShape(Circle())
        }
    }

    // MARK: - Restore Button (top-right)

    private var restoreButton: some View {
        Button(action: { Task { await performRestore() } }) {
            Text("Restore")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: 0x64748B))
                .frame(height: 44)
        }
        .disabled(isRestoring)
    }

    // MARK: - Hero Output Collage (30% screen)

    private var heroCollage: some View {
        HStack(spacing: 10) {
            heroCard(
                label: "Dog",
                colors: [Color(hex: 0xFF6B9D), Color(hex: 0xFF8FAE)]
            )
            heroCard(
                label: "Baby",
                colors: [Color(hex: 0x3B82F6), Color(hex: 0x6366F1)]
            )
            heroCard(
                label: "Hip Hop",
                colors: [Color(hex: 0x8B5CF6), Color(hex: 0xA78BFA)]
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

            // Subtle glow border
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [Color(hex: 0x8B5CF6).opacity(0.3), Color(hex: 0xFF6B9D).opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
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

    // MARK: - Feature Bullets (2x2 grid, max 4)

    private var featureBulletsGrid: some View {
        let features: [(String, String)] = [
            ("wand.and.stars", "AI Dance Videos"),
            ("photo", "Any Photo Works"),
            ("music.note", "20+ Dance Styles"),
            ("square.and.arrow.up", "Share Instantly"),
        ]

        return LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ],
            spacing: 10
        ) {
            ForEach(features, id: \.0) { icon, label in
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: 0x8B5CF6), Color(hex: 0xFF6B9D)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 20)

                    Text(label)
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: 0xF1F5F9))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Plan Cards (Yearly pre-selected, Weekly)

    private var planCardsSection: some View {
        VStack(spacing: 8) {
            // Yearly card — pre-selected
            planCard(
                plan: .yearly,
                title: "Yearly",
                priceMain: "$1.92/week",
                priceSub: "$99.99/year",
                badge: "SAVE 80%",
                isSelected: selectedPlan == .yearly
            )

            // Weekly card
            planCard(
                plan: .weekly,
                title: "Weekly",
                priceMain: "$9.99/week",
                priceSub: "first week $7.99",
                badge: nil,
                isSelected: selectedPlan == .weekly
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
            ZStack(alignment: .topTrailing) {
                HStack {
                    // Left: plan name + secondary price
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(Color(hex: 0xF1F5F9))

                        Text(priceSub)
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: 0x94A3B8))
                    }

                    Spacer()

                    // Right: main price + selection indicator
                    HStack(spacing: 12) {
                        Text(priceMain)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(Color(hex: 0xF1F5F9))

                        // Radio indicator
                        ZStack {
                            Circle()
                                .stroke(
                                    isSelected
                                        ? Color(hex: 0x8B5CF6)
                                        : Color(hex: 0x2B3750),
                                    lineWidth: 2
                                )
                                .frame(width: 22, height: 22)

                            if isSelected {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(hex: 0x8B5CF6), Color(hex: 0xFF6B9D)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 22, height: 22)

                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                // Badge (top-right corner)
                if let badge = badge {
                    Text(badge)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: 0x8B5CF6), Color(hex: 0xFF6B9D)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                        .offset(x: -8, y: -10)
                }
            }
            .frame(height: 68)
            .background(Color(hex: 0x1E293B))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected
                            ? LinearGradient(
                                colors: [Color(hex: 0x8B5CF6), Color(hex: 0xFF6B9D)],
                                startPoint: .leading,
                                endPoint: .trailing
                              )
                            : LinearGradient(
                                colors: [Color(hex: 0x2B3750), Color(hex: 0x2B3750)],
                                startPoint: .leading,
                                endPoint: .trailing
                              ),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sticky Bottom CTA Zone

    private var bottomCTAZone: some View {
        VStack(spacing: 8) {
            // CTA Button — gradient, 56pt, full-width
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
                        colors: [Color(hex: 0x8B5CF6), Color(hex: 0xFF6B9D)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .scaleEffect(isPurchasing ? 0.98 : 1.0)
                .animation(.spring(response: 0.2), value: isPurchasing)
            }
            .disabled(isPurchasing)
            .sensoryFeedback(.success, trigger: isPurchasing)
            .padding(.horizontal, 16)

            // Reassurance
            Text("first week $7.99 • cancel anytime in Settings")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: 0x94A3B8))

            // Legal links
            HStack(spacing: 4) {
                Link("Terms", destination: URL(string: "https://yourapp.com/terms")!)
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: 0x64748B))

                Text("·")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: 0x64748B).opacity(0.5))

                Link("Privacy", destination: URL(string: "https://yourapp.com/privacy")!)
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: 0x64748B))
            }
        }
        .padding(.bottom, 12)
        .padding(.top, 12)
        .background(
            LinearGradient(
                colors: [Color(hex: 0x0F172A).opacity(0), Color(hex: 0x0F172A)],
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
