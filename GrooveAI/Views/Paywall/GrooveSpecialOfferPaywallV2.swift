// GrooveSpecialOfferPaywallV2.swift
// Groove AI — 2-Page Special Offer Modal (April 2026)
//
// DESIGN:
// Page 1: Surprise offer with gift box animation + sparkles + confetti
// Page 2: Discount reveal with pricing card + forever section
//
// ANIMATIONS: Sparkles, bobbing gift, button shine, confetti float
// INTEGRATION: RevenueCat purchase + countdown timer (10 min default)
//
// NOTE: This is an exit-intent modal shown when user dismisses PaywallView
// It offers a limited-time discount (37% off first week) to convert
// Disappears after purchase, CTA, or timeout.

import SwiftUI
import RevenueCat

struct GrooveSpecialOfferPaywallV2: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    var onPurchaseComplete: () -> Void
    var onDismiss: () -> Void

    @State private var currentPage: Int = 1  // 1 = splash, 2 = reveal
    @State private var secondsRemaining: Int = 600  // 10 minutes
    @State private var countdownTimer: Timer?
    @State private var isPurchasing = false
    @State private var purchaseError: String?

    // Pricing state
    @State private var hasLoadedPricing = false
    @State private var discountPrice: String = "$4.99"
    @State private var fullPrice: String = "$7.99"
    @State private var timerTickKey = UUID()  // Force re-render on countdown change

    private func log(_ msg: String) { print("[SpecialOfferV2] \(msg)") }

    private func formatCountdown() -> String {
        let minutes = secondsRemaining / 60
        let seconds = secondsRemaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func startCountdownTimer() {
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if secondsRemaining > 0 {
                secondsRemaining -= 1
                timerTickKey = UUID()  // Trigger view update
            } else {
                countdownTimer?.invalidate()
                onDismiss()
            }
        }
    }

    private func stopCountdownTimer() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }

    private func loadPricing() {
        Task {
            let rc = RevenueCatService.shared
            await rc.fetchOfferings()

            await MainActor.run {
                // Get the special offer pricing — targets grooveai_weekly_special
                if let offerPkg = rc.specialOfferPackage() {
                    if let intro = offerPkg.storeProduct.introductoryDiscount {
                        discountPrice = intro.localizedPriceString
                    }
                    fullPrice = offerPkg.storeProduct.localizedPriceString
                }
                hasLoadedPricing = true
            }
        }
    }

    private func handleClaimOffer() {
        guard !isPurchasing else { return }
        isPurchasing = true
        purchaseError = nil

        Task {
            do {
                let rc = RevenueCatService.shared
                await rc.fetchOfferings()

                // Target the special-offer SKU: grooveai_weekly_special
                guard let pkg = rc.specialOfferPackage() else {
                    await MainActor.run {
                        purchaseError = "Offer not available. Please try again."
                        isPurchasing = false
                    }
                    return
                }

                print("[SpecialOfferV2] Purchasing product: \(pkg.storeProduct.productIdentifier)")
                let success = try await rc.purchase(package: pkg)

                await MainActor.run {
                    isPurchasing = false
                    if success {
                        appState.isSubscribed = true
                        stopCountdownTimer()
                        onPurchaseComplete()
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

    var body: some View {
        ZStack {
            // Background with glow
            backgroundView

            // Page 1: Splash
            if currentPage == 1 {
                splashPageView
                    .transition(.opacity)
            }

            // Page 2: Discount Reveal
            if currentPage == 2 {
                discountPageView
                    .transition(.opacity)
            }
        }
        .onAppear {
            log("Modal appeared, starting countdown")
            loadPricing()
            startCountdownTimer()
        }
        .onDisappear {
            stopCountdownTimer()
        }
    }

    // MARK: - Background with glow

    private var backgroundView: some View {
        ZStack {
            // Dark base
            Color(hex: 0x07070C)
                .ignoresSafeArea()

            // Subtle radial glow — purple/blue centered
            if currentPage == 1 {
                RadialGradient(
                    colors: [
                        Color(hex: 0x4A3F7F).opacity(0.08),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: 600
                )
                .ignoresSafeArea()
            } else {
                RadialGradient(
                    colors: [
                        Color(hex: 0x2A1F5F).opacity(0.06),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: 500
                )
                .ignoresSafeArea()
            }

            // Floating confetti (page 1: 18 pieces, page 2: 22 pieces)
            if currentPage == 1 {
                confettiLayer(count: 18)
            } else {
                confettiLayer(count: 22)
            }

            // Sparkles layer
            sparklesLayer(count: 18)
        }
    }

    // MARK: - CONFETTI PIECES (floating animation)

    private func confettiLayer(count: Int) -> some View {
        ZStack {
            ForEach(0..<count, id: \.self) { idx in
                let color = confettiColor(index: idx)
                let duration = Double.random(in: 2.4...4.4)
                let delay = Double(idx) * 0.08
                let xOffset = confettiXPosition(index: idx)
                let yStart = confettiYStart(index: idx)

                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                    .offset(x: xOffset, y: yStart)
                    .modifier(FloatingConfettiModifier(duration: duration, delay: delay))
            }
        }
        .ignoresSafeArea()
    }

    private func confettiColor(index: Int) -> Color {
        let colors: [Color] = [
            Color(hex: 0xFF6B6B),  // red
            Color(hex: 0x4ECDC4),  // cyan
            Color(hex: 0xFFE66D),  // yellow
            Color(hex: 0x95E1D3),  // mint
            Color(hex: 0xF38181),  // coral
            Color(hex: 0xAA96DA),  // purple
        ]
        return colors[index % colors.count]
    }

    private func confettiXPosition(index: Int) -> CGFloat {
        let seeded = Double(index) * 1.618  // Golden ratio for pseudo-randomness
        let normalized = seeded.truncatingRemainder(dividingBy: 1.0)
        return (normalized - 0.5) * UIScreen.main.bounds.width
    }

    private func confettiYStart(index: Int) -> CGFloat {
        let seeded = Double(index) * 2.414
        let normalized = seeded.truncatingRemainder(dividingBy: 1.0)
        return (normalized * 0.3 - 0.15) * UIScreen.main.bounds.height - 400
    }

    struct FloatingConfettiModifier: ViewModifier {
        let duration: Double
        let delay: Double

        @State private var isAnimating = false

        func body(content: Content) -> some View {
            content
                .offset(y: isAnimating ? 800 : 0)
                .rotationEffect(.degrees(isAnimating ? 360 : 0))
                .opacity(isAnimating ? 0 : 1)
                .onAppear {
                    withAnimation(.linear(duration: duration).delay(delay)) {
                        isAnimating = true
                    }
                }
        }
    }

    // MARK: - SPARKLES (twinkling animation)

    private func sparklesLayer(count: Int) -> some View {
        ZStack {
            ForEach(0..<count, id: \.self) { idx in
                let duration = Double.random(in: 2.0...4.0)
                let delay = Double(idx) * 0.12
                let xPos = sparkleXPosition(index: idx)
                let yPos = sparkleYPosition(index: idx)

                Image(systemName: "star.fill")
                    .font(.system(size: 3))
                    .foregroundStyle(Color.white.opacity(0.6))
                    .position(x: xPos, y: yPos)
                    .modifier(TwinkleModifier(duration: duration, delay: delay))
            }
        }
        .ignoresSafeArea()
    }

    private func sparkleXPosition(index: Int) -> CGFloat {
        let seeded = Double(index) * 3.14159
        let normalized = seeded.truncatingRemainder(dividingBy: 1.0)
        return normalized * UIScreen.main.bounds.width
    }

    private func sparkleYPosition(index: Int) -> CGFloat {
        let seeded = Double(index) * 1.732
        let normalized = seeded.truncatingRemainder(dividingBy: 1.0)
        return normalized * UIScreen.main.bounds.height
    }

    struct TwinkleModifier: ViewModifier {
        let duration: Double
        let delay: Double

        @State private var isAnimating = false

        func body(content: Content) -> some View {
            content
                .opacity(isAnimating ? 0.1 : 0.8)
                .scaleEffect(isAnimating ? 0.5 : 1.0)
                .onAppear {
                    withAnimation(.easeInOut(duration: duration / 2).delay(delay).repeatForever(autoreverses: true)) {
                        isAnimating = true
                    }
                }
        }
    }

    // MARK: - PAGE 1: SPLASH VIEW

    private var splashPageView: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 40)

            // Gift box (centered)
            VStack(spacing: 24) {
                // Gift box with bobbing animation
                giftBoxView
                    .frame(width: 160, height: 160)
                    .modifier(BobbingModifier())
            }

            Spacer()

            // Content section
            VStack(spacing: 12) {
                // Headline
                Text("Surprise offer")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.white, Color(hex: 0xD9C4FF)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .multilineTextAlignment(.center)

                // Subheading
                Text("We saved something just for you. Tap to see what's inside.")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            Spacer(minLength: 40)

            // CTAs
            VStack(spacing: 12) {
                // Primary CTA
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentPage = 2
                    }
                } label: {
                    Text("See what's inside")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(hex: 0x4A7CFF),
                                    Color(hex: 0x8B5CFF),
                                    Color(hex: 0xB14BFF)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                        )
                        .modifier(ShineOverlayModifier())
                }

                // Secondary CTA
                Button {
                    stopCountdownTimer()
                    onDismiss()
                } label: {
                    Text("Not now")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Gift Box Component

    private var giftBoxView: some View {
        ZStack {
            // Box body (gradient)
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: 0x4A7CFF),
                            Color(hex: 0x8B5CFF)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Glow shadow
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(hex: 0x4A7CFF).opacity(0.3))
                .blur(radius: 16)
                .offset(y: 20)

            // Ribbon (cross)
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white)
                    .frame(height: 6)
                    .padding(.vertical, 77)
            }

            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white)
                    .frame(width: 6)
                    .padding(.horizontal, 77)
            }

            // Bow on top
            VStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 16, height: 16)

                    Circle()
                        .fill(Color.white)
                        .frame(width: 16, height: 16)
                }
                .padding(.top, 12)

                Spacer()
            }
        }
    }

    struct BobbingModifier: ViewModifier {
        @State private var isAnimating = false

        func body(content: Content) -> some View {
            content
                .offset(y: isAnimating ? 12 : -12)
                .onAppear {
                    withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
                        isAnimating = true
                    }
                }
        }
    }

    // MARK: - PAGE 2: DISCOUNT REVEAL VIEW

    private var discountPageView: some View {
        VStack(spacing: 0) {
            // Top bar with back + timer
            HStack {
                // Back button
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentPage = 1
                    }
                } label: {
                    ZStack {
                        Circle()
                            .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                            .frame(width: 32, height: 32)

                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 44, height: 44)
                }

                Spacer()

                // Countdown timer
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(hex: 0xFFD700))
                        .frame(width: 8, height: 8)

                    Text("ENDS IN \(formatCountdown())")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color(hex: 0xFFD700))
                        .id(timerTickKey)  // Force re-render on tick
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Spacer(minLength: 20)

            // Content
            VStack(spacing: 16) {
                // Badge
                Text("SPECIAL OFFER UNLOCKED")
                    .font(.system(size: 11, weight: .bold, design: .default))
                    .foregroundStyle(Color(hex: 0x8B5CFF))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(hex: 0x8B5CFF).opacity(0.15))
                    .clipShape(Capsule())

                // Big discount (37%)
                Text("37%")
                    .font(.system(size: 88, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.white, Color(hex: 0xC9B8FF)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color(hex: 0x4A7CFF).opacity(0.3), radius: 8)

                // Headline
                Text("OFF Your First Week")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color.white)

                // One-time note
                Text("One-time offer. Disappears when you close this screen.")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)

            Spacer(minLength: 24)

            // Pricing card (glassmorphic)
            pricingCard
                .padding(.horizontal, 20)

            Spacer(minLength: 16)

            // Forever section
            foreverSection
                .padding(.horizontal, 20)

            Spacer(minLength: 24)

            // Fine print
            Text("$\(discountPrice.dropFirst()) first week, then $\(fullPrice.dropFirst())/week. No commitment. Cancel anytime.")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            Spacer(minLength: 20)

            // CTAs
            VStack(spacing: 12) {
                // Primary CTA
                Button {
                    handleClaimOffer()
                } label: {
                    ZStack {
                        if isPurchasing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            HStack(spacing: 8) {
                                Text("Claim Offer")
                                    .font(.system(size: 16, weight: .semibold))

                                Text("—")
                                    .font(.system(size: 16, weight: .semibold))

                                Text("\(discountPrice) This Week")
                                    .font(.system(size: 16, weight: .bold))
                            }
                            .foregroundStyle(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(hex: 0x4A7CFF),
                                Color(hex: 0x8B5CFF),
                                Color(hex: 0xB14BFF)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .modifier(ShineOverlayModifier())
                }
                .disabled(isPurchasing)

                // Secondary CTA
                Button {
                    stopCountdownTimer()
                    onDismiss()
                } label: {
                    Text("No thanks, I'd rather pay full price")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.6))
                        .underline()
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Pricing Card (glassmorphic)

    private var pricingCard: some View {
        HStack(alignment: .center, spacing: 0) {
            // Left section: Was price
            VStack(alignment: .leading, spacing: 4) {
                Text("Was")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.6))

                HStack(spacing: 0) {
                    Text(fullPrice)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.5))

                    Text("/wk")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.4))
                }
                .strikethrough()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 16)
            .padding(.vertical, 16)

            // Divider
            Divider()
                .frame(height: 48)
                .overlay(Color.white.opacity(0.1))

            // Right section: Now price
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Text("Now")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.6))

                    Text("First week")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color(hex: 0xFFD700))
                }

                HStack(spacing: 0) {
                    Text(discountPrice)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.white)

                    Text("/wk")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.6))
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 16)
            .padding(.vertical, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.04))
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.clear)
                        .blur(radius: 8)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Forever Section (green-themed)

    private var foreverSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                HStack(spacing: 12) {
                    Image(systemName: "infinity")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x2ECC71))
                        .frame(width: 28, alignment: .center)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Then 20% off forever")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.white)

                        Text("Just \(fullPrice)/wk every week after")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(Color.white.opacity(0.6))
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 0) {
                    Text("SAVE $2/wk")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(hex: 0x2ECC71))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: 0x2ECC71).opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color(hex: 0x2ECC71).opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Button Shine Animation

    struct ShineOverlayModifier: ViewModifier {
        @State private var isAnimating = false

        func body(content: Content) -> some View {
            content
                .overlay(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0),
                            Color.white.opacity(0.3),
                            Color.white.opacity(0)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .offset(x: isAnimating ? 300 : -300)
                    .onAppear {
                        withAnimation(.linear(duration: 2.6).repeatForever(autoreverses: false)) {
                            isAnimating = true
                        }
                    }
                )
        }
    }
}

#Preview {
    GrooveSpecialOfferPaywallV2(
        onPurchaseComplete: {},
        onDismiss: {}
    )
    .environment(AppState())
}
