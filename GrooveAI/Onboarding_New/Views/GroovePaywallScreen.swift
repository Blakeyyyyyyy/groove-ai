// GroovePaywallScreen.swift
// Simplified paywall screen for Groove AI onboarding flow.
// Uses RevenueCatService (existing) instead of IAPManager/CoinStore.

import SwiftUI
import RevenueCat
import UserNotifications

struct GroovePaywallScreen: View {
    let onComplete: () -> Void
    @Environment(AppState.self) private var appState
    
    enum PaywallPlan { case yearly, weekly }

    @State private var selectedPlan: PaywallPlan = .yearly
    @State private var isPurchasing = false
    @State private var purchaseError: String?
    @State private var showExitSheet = false
    @State private var reviewIndex: Int = 0
    @State private var reviewTimer: Timer? = nil
    @State private var isRestoring = false
    @State private var showRestoreAlert = false
    @State private var restoreAlertMessage = ""

    var body: some View {
        ZStack {
            GrooveOnboardingTheme.background.ignoresSafeArea()
            GrooveOnboardingTheme.radialGlow.opacity(0.5)

            VStack(spacing: 0) {
                // MARK: - Close Button
                HStack {
                    Button(action: { showExitSheet = true }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.2))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                    }
                    Spacer()
                }

                // MARK: - Timeline
                VStack(alignment: .leading, spacing: 0) {
                    GrooveTimelineItem(
                        title: "Today: Start 3-Day Free Trial",
                        subtitle: "Get instant full access",
                        isActive: true,
                        isLast: false
                    )
                    GrooveTimelineItem(
                        title: "Day 3: Trial Ends",
                        subtitle: "We'll send a reminder",
                        isActive: false,
                        isLast: false
                    )
                    GrooveTimelineItem(
                        title: "Day 4: First Payment",
                        subtitle: "Subscription begins",
                        isActive: false,
                        isLast: true
                    )
                }
                .padding(.top, 0)
                .padding(.leading, 40)

                Spacer(minLength: 40)

                // MARK: - Header + Reviews
                VStack(spacing: 16) {
                    Text(paywallHeaderText)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)

                    HStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { index in
                            GrooveReviewProgressDot(isActive: index == reviewIndex)
                        }
                    }
                    .animation(.easeInOut(duration: 0.3), value: reviewIndex)

                    TabView(selection: $reviewIndex) {
                        ForEach(0..<3) { index in
                            VStack(spacing: 8) {
                                HStack(spacing: 6) {
                                    ForEach(0..<5) { _ in
                                        Image(systemName: "star.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(Color(hex: 0xFFD700))
                                    }
                                }
                                Text(reviewText(for: index))
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)
                                    .padding(.horizontal, 20)
                                Text(reviewHandle(for: index))
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .tag(index)
                        }
                    }
                    .frame(height: 100)
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.easeInOut(duration: 0.3), value: reviewIndex)
                }

                Spacer(minLength: 32)

                // MARK: - Plan Selection
                VStack(spacing: 16) {
                    GroovePlanOptionButton(
                        isSelected: selectedPlan == .yearly,
                        title: yearlyTitle,
                        subtitle: nil,
                        badgeText: "3-day free trial",
                        discountBadgeText: "81% OFF",
                        action: { selectedPlan = .yearly }
                    )
                    GroovePlanOptionButton(
                        isSelected: selectedPlan == .weekly,
                        title: weeklyTitleMain,
                        subtitle: nil,
                        badgeText: nil,
                        discountBadgeText: nil,
                        action: { selectedPlan = .weekly }
                    )
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)

                // MARK: - Error
                if let error = purchaseError {
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundColor(.red.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 8)
                }

                // MARK: - Trust line
                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    Text(selectedPlan == .yearly ? "No Payment Due Now" : "No commitment. Cancel anytime.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.bottom, 12)

                // MARK: - CTA
                Button(action: performPurchase) {
                    HStack {
                        if isPurchasing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text(selectedPlan == .yearly ? "Start My 3-Day FREE Trial" : "Continue")
                                .font(.system(size: 20, weight: .bold))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(GrooveOnboardingTheme.blueAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: GrooveOnboardingTheme.blueAccent.opacity(0.4), radius: 10, y: 4)
                }
                .disabled(isPurchasing)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

                // MARK: - Footer
                VStack(spacing: 16) {
                    Text(yearlyBillingDescription)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .opacity(selectedPlan == .yearly ? 1 : 0)

                    Button("Restore") {
                        Task {
                            isRestoring = true
                            purchaseError = nil
                            let restored = try? await RevenueCatService.shared.restorePurchases()
                            isRestoring = false

                            if restored == true {
                                appState.isSubscribed = true
                                restoreAlertMessage = "Purchases restored successfully!"
                                showRestoreAlert = true
                                onComplete()
                            } else {
                                restoreAlertMessage = "No purchases found to restore."
                                showRestoreAlert = true
                            }
                        }
                    }
                    .disabled(isRestoring)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
                    .underline()
                }
                .padding(.bottom, 36)
            }
        }
        .onAppear {
            Task {
                await RevenueCatService.shared.fetchOfferings()
                reviewTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { _ in
                    reviewIndex = (reviewIndex + 1) % 3
                }
            }
        }
        .onDisappear { reviewTimer?.invalidate() }
        .sheet(isPresented: $showExitSheet) {
            GrooveExitSheet(
                isPurchasing: $isPurchasing,
                onDismiss: { showExitSheet = false },
                onComplete: onComplete
            )
        }
        .alert("Restore Purchases", isPresented: $showRestoreAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(restoreAlertMessage)
        }
    }

    // MARK: - Dynamic labels

    private var paywallHeaderText: String {
        selectedPlan == .yearly ? "Start your 3-day FREE trial" : "Get started with Groove AI"
    }

    private var yearlyTitle: String {
        "Yearly — $1.92/week"
    }

    private var yearlyBillingDescription: String {
        "3 days free, then $99.99/year ($1.92/week)"
    }

    private var weeklyTitleMain: String {
        "Weekly — $9.99/week"
    }

    private func reviewText(for index: Int) -> String {
        switch index {
        case 0: return "pranked my boyfriend and he literally couldn't tell it was AI 😭 the results are insane"
        case 1: return "used this for my instagram and got 47k views on the first reel. so easy to use"
        case 2: return "my mum actually believed the photo was real. best app I've downloaded this year"
        default: return ""
        }
    }

    private func reviewHandle(for index: Int) -> String {
        switch index {
        case 0: return "@sarahm_"
        case 1: return "@jakefit_"
        case 2: return "@chloe.creates"
        default: return ""
        }
    }

    private func performPurchase() {
        purchaseError = nil
        isPurchasing = true
        Task {
            defer { isPurchasing = false }
            
            let rc = RevenueCatService.shared
            await rc.fetchOfferings()
            
            let package: Package? = selectedPlan == .yearly ? rc.annualPackage() : rc.weeklyPackage()
            
            guard let pkg = package else {
                // Fallback: allow through for onboarding
                await MainActor.run {
                    appState.isSubscribed = true
                    appState.hasCompletedOnboarding = true
                    onComplete()
                }
                return
            }
            
            do {
                let success = try await rc.purchase(package: pkg)
                await MainActor.run {
                    if success {
                        appState.isSubscribed = true
                        appState.hasCompletedOnboarding = true
                    }
                    onComplete()
                }
            } catch {
                purchaseError = error.localizedDescription
            }
        }
    }
}

// MARK: - Timeline Item

struct GrooveTimelineItem: View {
    let title: String
    let subtitle: String
    let isActive: Bool
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 19) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .stroke(isActive ? GrooveOnboardingTheme.blueAccent : Color.gray.opacity(0.5), lineWidth: 2)
                        .frame(width: 29, height: 29)
                    if isActive {
                        Circle()
                            .fill(GrooveOnboardingTheme.blueAccent)
                            .frame(width: 17, height: 17)
                    }
                }
                if !isLast {
                    Rectangle()
                        .fill(isActive ? GrooveOnboardingTheme.blueAccent : Color.gray.opacity(0.3))
                        .frame(width: 2, height: 19)
                }
            }
            .frame(width: 29)

            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(isActive ? .white : .white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, isLast ? 0 : 8)
            }
        }
    }
}

// MARK: - Review Progress Dot

struct GrooveReviewProgressDot: View {
    let isActive: Bool

    var body: some View {
        Capsule()
            .fill(isActive ? GrooveOnboardingTheme.blueAccent : Color.white.opacity(0.3))
            .frame(width: isActive ? 24 : 8, height: 8)
            .scaleEffect(isActive ? 1.0 : 0.8)
            .animation(.easeInOut(duration: 0.3), value: isActive)
    }
}

// MARK: - Plan Option Button

struct GroovePlanOptionButton: View {
    let isSelected: Bool
    let title: String
    let subtitle: String?
    let badgeText: String?
    let discountBadgeText: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .top) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(isSelected ? GrooveOnboardingTheme.blueAccent : Color.white.opacity(0.1))
                            .frame(width: 24, height: 24)
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                        if let subtitle = subtitle {
                            Text(subtitle)
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .padding(.leading, 8)
                    Spacer()
                    if let badge = discountBadgeText {
                        Text(badge)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(hex: 0xFF6B6B))
                            .clipShape(Capsule())
                    }
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color(hex: 0x1E1E2E)))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? GrooveOnboardingTheme.blueAccent : Color.clear, lineWidth: 2)
                )

                if let badge = badgeText {
                    Text(badge)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(GrooveOnboardingTheme.blueAccent)
                        .clipShape(Capsule())
                        .offset(y: -12)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Exit Sheet

struct GrooveExitSheet: View {
    @Binding var isPurchasing: Bool
    let onDismiss: () -> Void
    let onComplete: () -> Void

    @State private var purchaseError: String?

    var body: some View {
        ZStack {
            GrooveOnboardingTheme.background.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 12) {
                    Text("Not ready to commit?")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    Text("Start with a 3-day free trial on our weekly plan instead.")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }

                HStack {
                    ZStack {
                        Circle()
                            .fill(GrooveOnboardingTheme.blueAccent)
                            .frame(width: 24, height: 24)
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Weekly — $9.99/week")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.leading, 8)
                    Spacer()
                    Text("3-day free trial")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(GrooveOnboardingTheme.blueAccent)
                        .clipShape(Capsule())
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color(hex: 0x1E1E2E)))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(GrooveOnboardingTheme.blueAccent, lineWidth: 2)
                )
                .padding(.horizontal, 24)

                if let error = purchaseError {
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundColor(.red.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                Button(action: performWeeklyPurchase) {
                    HStack {
                        if isPurchasing {
                            ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Start FREE trial")
                                .font(.system(size: 20, weight: .bold))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(GrooveOnboardingTheme.blueAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: GrooveOnboardingTheme.blueAccent.opacity(0.4), radius: 10, y: 4)
                }
                .disabled(isPurchasing)
                .padding(.horizontal, 24)

                Button(action: { onDismiss(); onComplete() }) {
                    Text("No thanks →")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.bottom, 40)
            }
        }
    }

    private func performWeeklyPurchase() {
        purchaseError = nil
        isPurchasing = true
        Task {
            defer { isPurchasing = false }
            
            let rc = RevenueCatService.shared
            await rc.fetchOfferings()
            
            guard let pkg = rc.weeklyPackage() else {
                // Fallback: allow through
                await MainActor.run {
                    onComplete()
                }
                return
            }
            
            do {
                let success = try await rc.purchase(package: pkg)
                await MainActor.run {
                    if success {
                        onComplete()
                    }
                }
            } catch {
                purchaseError = error.localizedDescription
            }
        }
    }
}
