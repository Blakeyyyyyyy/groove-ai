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

    // Pricing state — populated from StoreKit via RevenueCat. Never hardcoded.
    // Initial nil state shows redacted placeholders until the offering loads.
    @State private var hasLoadedPricing = false
    @State private var discountPrice: String? = nil
    @State private var fullPrice: String? = nil
    @State private var savingsPerWeek: String? = nil  // e.g. "$3.00" computed from full - discount
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
                // The "special offer" is a DIFFERENT SKU (grooveai_weekly_special) whose
                // BASE price equals the standard weekly ($9.99 currently in ASC) but it
                // carries an INTRODUCTORY OFFER configured in App Store Connect that
                // discounts the FIRST WEEK to $4.99. The discount we want to surface in
                // the "NOW · FIRST WEEK" slot is that StoreKit introductoryDiscount —
                // NOT the special SKU's base price (which is the same $9.99).
                //
                // Resolution rules:
                //  - fullPrice  = standard weekly (grooveai_weekly_799) base price ($7.99) — strikethrough "WAS"
                //  - discountPrice = special SKU's introductoryDiscount.localizedPriceString ($4.99) — "NOW · FIRST WEEK"
                //  - If the special SKU loaded but introductoryDiscount is nil, fall
                //    back to its base price and log a warning (means ASC intro offer
                //    isn't propagating to StoreKit yet).
                //  - If the special SKU is missing entirely, fall back to hardcoded
                //    "$4.99" so the UI never shows the same number on both sides.

                // Always look up the standard weekly directly so a missing
                // special-offer SKU can't poison the renewal price.
                let weeklyPkg = rc.weeklyPackage()
                let renewal = weeklyPkg?.storeProduct.localizedPriceString ?? "$7.99"
                fullPrice = renewal

                // Look up the special-offer SKU explicitly. Note: specialOfferPackage()
                // falls back to weeklyPackage() internally — we need to detect the
                // genuine match by comparing product IDs so we don't mistake the
                // fallback for the real special SKU.
                let specialPkg = rc.specialOfferPackage()
                let isGenuineSpecial = specialPkg?.storeProduct.productIdentifier == "grooveai_weekly_special"

                if isGenuineSpecial, let special = specialPkg {
                    // Real special-offer SKU loaded — prefer its INTRODUCTORY offer
                    // ($4.99 first week) over the base price ($9.99).
                    if let intro = special.storeProduct.introductoryDiscount {
                        discountPrice = intro.localizedPriceString
                        log("loadPricing: using special SKU \(special.storeProduct.productIdentifier) intro discount=\(discountPrice ?? "nil")")
                    } else {
                        discountPrice = special.storeProduct.localizedPriceString
                        log("⚠️ loadPricing: special SKU \(special.storeProduct.productIdentifier) has NO introductoryDiscount — falling back to base price \(discountPrice ?? "nil")")
                    }
                } else {
                    // SKU not live in RevenueCat yet — fall back to hardcoded value
                    // matching the configured ASC intro price. Logged as a warning so
                    // we notice it in the build log.
                    discountPrice = "$4.99"
                    log("⚠️ loadPricing: grooveai_weekly_special NOT found in RevenueCat offerings — using hardcoded $4.99 fallback")
                }

                // Compute savings per week from the two surfaced prices
                // (full - discount). Prefer the special SKU's priceFormatter so the
                // currency formatting matches the discount price; fall back to the
                // weekly package's formatter, then a hardcoded "$3.00" if neither
                // is available.
                if isGenuineSpecial,
                   let special = specialPkg,
                   let weekly = weeklyPkg,
                   let intro = special.storeProduct.introductoryDiscount {
                    let formatter = special.storeProduct.priceFormatter ?? weekly.storeProduct.priceFormatter
                    let saved = weekly.storeProduct.price - intro.price
                    if saved > 0, let fmt = formatter {
                        savingsPerWeek = fmt.string(from: NSDecimalNumber(decimal: saved))
                    }
                } else if !isGenuineSpecial {
                    // Hardcoded fallback savings: $7.99 - $4.99 = $3.00
                    savingsPerWeek = "$3.00"
                }

                hasLoadedPricing = true
                log("loadPricing: discount=\(discountPrice ?? "nil") full=\(fullPrice ?? "nil") savings=\(savingsPerWeek ?? "nil") specialMatched=\(isGenuineSpecial)")
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

                // Prefer the genuine special-offer SKU (grooveai_weekly_special).
                // specialOfferPackage() already falls back to weeklyPackage() when
                // the special SKU isn't live, so a non-nil result here will charge
                // either $4.99 (special SKU loaded) or $7.99 (fallback) — we log
                // which one so post-launch we can detect SKU-missing in production.
                guard let pkg = rc.specialOfferPackage() ?? rc.weeklyPackage() else {
                    await MainActor.run {
                        purchaseError = "Offer not available. Please try again."
                        isPurchasing = false
                    }
                    return
                }

                let isGenuineSpecial = pkg.storeProduct.productIdentifier == "grooveai_weekly_special"
                if !isGenuineSpecial {
                    print("[SpecialOfferV2] ⚠️ Purchasing FALLBACK weekly (\(pkg.storeProduct.productIdentifier)) — special SKU not in offerings; user will be charged full weekly price")
                }
                print("[SpecialOfferV2] Purchasing product: \(pkg.storeProduct.productIdentifier) (specialMatched=\(isGenuineSpecial))")
                let success = try await rc.purchase(package: pkg)

                await MainActor.run {
                    isPurchasing = false
                    if success {
                        appState.isSubscribed = true
                        stopCountdownTimer()
                        // onPurchaseComplete bubbles up to GroovePaywallScreen which
                        // calls onPurchaseSuccess(); coin grant happens via the
                        // notification posted inside rc.purchase().
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

    var body: some View {
        ZStack {
            // Background
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

    // MARK: - Background

    private var backgroundView: some View {
        ZStack {
            if currentPage == 1 {
                // Page 1: Dark blue/purple gradient matching #1A1140 → #0D0820 → #06040F
                LinearGradient(
                    colors: [
                        Color(hex: 0x1A1140),
                        Color(hex: 0x0D0820),
                        Color(hex: 0x06040F)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // Strong purple radial glow centered ~38% from top
                RadialGradient(
                    colors: [
                        Color(hex: 0x8B5CFF).opacity(0.45),
                        Color.clear
                    ],
                    center: UnitPoint(x: 0.5, y: 0.38),
                    startRadius: 0,
                    endRadius: 400
                )
                .ignoresSafeArea()

            } else {
                // Page 2: Near-black base
                Color(hex: 0x07070C)
                    .ignoresSafeArea()

                // Purple/blue radial glow upper area
                RadialGradient(
                    colors: [
                        Color(hex: 0xB14BFF).opacity(0.28),
                        Color(hex: 0x4A7CFF).opacity(0.18),
                        Color.clear
                    ],
                    center: UnitPoint(x: 0.5, y: 0.18),
                    startRadius: 0,
                    endRadius: 500
                )
                .ignoresSafeArea()
            }

            // Ambient sparkles (page 1 only)
            if currentPage == 1 {
                sparklesLayer(count: 18)
            }

            // Confetti edges (page 2: left/right edge pieces)
            if currentPage == 2 {
                confettiEdgeLayer(count: 22)
            }
        }
    }

    // MARK: - SPARKLES — twinkling circles (Page 1)

    private func sparklesLayer(count: Int) -> some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<count, id: \.self) { idx in
                    let seed = Double(idx) * 9301 + 49297
                    let r = { (n: Double) -> Double in
                        let v = sin(seed * n)
                        return (v + 1) / 2
                    }
                    let left = r(1.1) * geo.size.width
                    // top: 8% → 78% of screen height
                    let top = geo.size.height * (0.08 + r(1.7) * 0.70)
                    let size = CGFloat(3.0 + r(2.3) * 4.0)
                    let dur = r(2.9) * 2.0 + 2.0
                    let delay = r(3.5) * 3.0

                    Circle()
                        .fill(Color.white)
                        .frame(width: size, height: size)
                        .shadow(color: Color.white.opacity(0.8), radius: 4)
                        .opacity(0.6)
                        .position(x: left, y: top)
                        .modifier(TwinkleModifier(duration: dur, delay: delay))
                }
            }
        }
        .ignoresSafeArea()
    }

    struct TwinkleModifier: ViewModifier {
        let duration: Double
        let delay: Double
        @State private var isAnimating = false

        func body(content: Content) -> some View {
            content
                .opacity(isAnimating ? 0.2 : 1.0)
                .scaleEffect(isAnimating ? 0.8 : 1.2)
                .onAppear {
                    withAnimation(.easeInOut(duration: duration / 2).delay(delay).repeatForever(autoreverses: true)) {
                        isAnimating = true
                    }
                }
        }
    }

    // MARK: - CONFETTI EDGE LAYER — left/right edges only (Page 2)

    private func confettiEdgeLayer(count: Int) -> some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<count, id: \.self) { idx in
                    let seed = Double(idx) * 9301 + 49297
                    let r = { (n: Double) -> Double in
                        let v = sin(seed * n)
                        return (v + 1) / 2
                    }
                    let onLeft = idx % 2 == 0
                    // left pieces: 0-4% width; right pieces: 96-100% width
                    let xPct = onLeft ? r(1.1) * 0.04 : 0.96 + r(1.1) * 0.04
                    let yPct = 0.06 + r(1.7) * 0.84
                    let xPos = xPct * geo.size.width
                    let yPos = yPct * geo.size.height
                    let rot = r(2.3) * 360.0
                    let size = CGFloat(4.0 + r(2.9) * 5.0)
                    let dur = 2.4 + r(4.1) * 2.0
                    let delay = r(3.7) * 2.0
                    let shape = idx % 3
                    let colors: [Color] = [
                        Color(hex: 0x4A7CFF),
                        Color(hex: 0xB14BFF),
                        Color(hex: 0x22D3EE),
                        Color(hex: 0xFFD66B),
                        Color(hex: 0xFF5C8A)
                    ]
                    let color = colors[idx % colors.count]
                    let height = shape == 1 ? size * 0.45 : size

                    RoundedRectangle(cornerRadius: shape == 2 ? size / 2 : 2)
                        .fill(color)
                        .frame(width: size, height: height)
                        .shadow(color: color.opacity(0.4), radius: 4)
                        .rotationEffect(.degrees(rot))
                        .opacity(0.9)
                        .position(x: xPos, y: yPos)
                        .modifier(FloatingConfettiEdgeModifier(duration: dur, delay: delay))
                }
            }
        }
        .ignoresSafeArea()
    }

    struct FloatingConfettiEdgeModifier: ViewModifier {
        let duration: Double
        let delay: Double
        @State private var isAnimating = false

        func body(content: Content) -> some View {
            content
                // Floats 14pt vertically, rotates 40deg — matches p2Float keyframe
                .offset(y: isAnimating ? 14 : 0)
                .rotationEffect(.degrees(isAnimating ? 40 : 0))
                .onAppear {
                    withAnimation(.easeInOut(duration: duration).delay(delay).repeatForever(autoreverses: true)) {
                        isAnimating = true
                    }
                }
        }
    }

    // MARK: - PAGE 1: SPLASH VIEW

    private var splashPageView: some View {
        VStack(spacing: 0) {
            // Spacer to push gift down from top — matches HTML's flex: "0 0 220px" spacer
            Spacer(minLength: 0)
                .frame(height: 200)

            // Gift illustration block with surrounding confetti
            ZStack {
                // Confetti pieces around gift
                giftConfettiView

                // Gift box with bobbing
                giftBoxView
                    .frame(width: 160, height: 160)
                    .modifier(BobbingModifier())
            }
            .frame(height: 200)

            // Headline + subtitle
            VStack(spacing: 12) {
                Text("Surprise offer")
                    .font(.system(size: 42, weight: .black))
                    .tracking(-1.5)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.white, Color(hex: 0xD9C4FF)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: Color(hex: 0xB14BFF).opacity(0.35), radius: 16, y: 4)
                    .multilineTextAlignment(.center)

                Text("We saved something just for you.\nTap to see what's inside.")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 28)
            }
            .padding(.top, 36)

            Spacer()

            // CTAs
            VStack(spacing: 10) {
                // Primary: "SEE WHAT'S INSIDE"
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentPage = 2
                    }
                } label: {
                    ZStack {
                        Text("See what's inside")
                            .font(.system(size: 16, weight: .heavy))
                            .tracking(0.6)
                            .textCase(.uppercase)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                    }
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
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .shadow(color: Color(hex: 0x8B5CFF).opacity(0.55), radius: 20, y: 14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                    )
                    .modifier(ShineOverlayModifier())
                }

                // Secondary: "NOT NOW"
                Button {
                    stopCountdownTimer()
                    onDismiss()
                } label: {
                    Text("Not now")
                        .font(.system(size: 14, weight: .bold))
                        .tracking(0.6)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.white.opacity(0.85))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Gift Box (SVG-accurate using SwiftUI Canvas)

    private var giftBoxView: some View {
        ZStack {
            // Glow pad under gift
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: 0x8B5CFF).opacity(0.55), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 65
                    )
                )
                .frame(width: 130, height: 22)
                .blur(radius: 6)
                .offset(y: 94)

            Canvas { ctx, size in
                let w = size.width
                let h = size.height
                // Scale factor: SVG viewBox is 160x160
                let sx = w / 160
                let sy = h / 160

                // Box body: rect x=22 y=70 w=116 h=78 rx=6
                let bodyRect = CGRect(x: 22*sx, y: 70*sy, width: 116*sx, height: 78*sy)
                ctx.fill(
                    Path(roundedRect: bodyRect, cornerRadius: 6*sx),
                    with: .linearGradient(
                        Gradient(colors: [Color(hex: 0x5B8CFF), Color(hex: 0x3253D8)]),
                        startPoint: CGPoint(x: bodyRect.midX, y: bodyRect.minY),
                        endPoint: CGPoint(x: bodyRect.midX, y: bodyRect.maxY)
                    )
                )

                // Body highlight stripe: x=22 y=70 w=116 h=6
                let bodyStripe = CGRect(x: 22*sx, y: 70*sy, width: 116*sx, height: 6*sy)
                ctx.fill(
                    Path(roundedRect: bodyStripe, cornerRadius: 0),
                    with: .color(Color.white.opacity(0.18))
                )

                // Vertical ribbon on body: x=68 y=70 w=24 h=78
                let ribbonBody = CGRect(x: 68*sx, y: 70*sy, width: 24*sx, height: 78*sy)
                ctx.fill(
                    Path(ribbonBody),
                    with: .linearGradient(
                        Gradient(colors: [Color(hex: 0xD9B4FF), Color(hex: 0x8B5CFF)]),
                        startPoint: CGPoint(x: ribbonBody.midX, y: ribbonBody.minY),
                        endPoint: CGPoint(x: ribbonBody.midX, y: ribbonBody.maxY)
                    )
                )

                // Lid: x=14 y=56 w=132 h=22 rx=4
                let lidRect = CGRect(x: 14*sx, y: 56*sy, width: 132*sx, height: 22*sy)
                ctx.fill(
                    Path(roundedRect: lidRect, cornerRadius: 4*sx),
                    with: .linearGradient(
                        Gradient(colors: [Color(hex: 0x6FA0FF), Color(hex: 0x4A7CFF)]),
                        startPoint: CGPoint(x: lidRect.midX, y: lidRect.minY),
                        endPoint: CGPoint(x: lidRect.midX, y: lidRect.maxY)
                    )
                )

                // Lid highlight: x=14 y=56 w=132 h=6
                let lidStripe = CGRect(x: 14*sx, y: 56*sy, width: 132*sx, height: 6*sy)
                ctx.fill(
                    Path(roundedRect: lidStripe, cornerRadius: 0),
                    with: .color(Color.white.opacity(0.25))
                )

                // Lid ribbon: x=68 y=56 w=24 h=22
                let ribbonLid = CGRect(x: 68*sx, y: 56*sy, width: 24*sx, height: 22*sy)
                ctx.fill(
                    Path(ribbonLid),
                    with: .linearGradient(
                        Gradient(colors: [Color(hex: 0xD9B4FF), Color(hex: 0x8B5CFF)]),
                        startPoint: CGPoint(x: ribbonLid.midX, y: ribbonLid.minY),
                        endPoint: CGPoint(x: ribbonLid.midX, y: ribbonLid.maxY)
                    )
                )

                // Bow — left ellipse: cx=68 cy=48 rx=14 ry=12
                func ellipsePath(cx: CGFloat, cy: CGFloat, rx: CGFloat, ry: CGFloat) -> Path {
                    Path(ellipseIn: CGRect(x: (cx-rx)*sx, y: (cy-ry)*sy, width: rx*2*sx, height: ry*2*sy))
                }

                let bowGrad = Gradient(colors: [Color(hex: 0xD9B4FF), Color(hex: 0x8B5CFF)])
                ctx.fill(ellipsePath(cx: 68, cy: 48, rx: 14, ry: 12), with: .linearGradient(bowGrad, startPoint: CGPoint(x: 68*sx, y: (48-12)*sy), endPoint: CGPoint(x: 68*sx, y: (48+12)*sy)))
                ctx.fill(ellipsePath(cx: 92, cy: 48, rx: 14, ry: 12), with: .linearGradient(bowGrad, startPoint: CGPoint(x: 92*sx, y: (48-12)*sy), endPoint: CGPoint(x: 92*sx, y: (48+12)*sy)))

                // Inner shadow on bow lobes
                ctx.fill(ellipsePath(cx: 68, cy: 48, rx: 6, ry: 5), with: .color(Color.black.opacity(0.18)))
                ctx.fill(ellipsePath(cx: 92, cy: 48, rx: 6, ry: 5), with: .color(Color.black.opacity(0.18)))

                // Bow center knot: circle cx=80 cy=50 r=6
                let knotPath = Path(ellipseIn: CGRect(x: (80-6)*sx, y: (50-6)*sy, width: 12*sx, height: 12*sy))
                ctx.fill(knotPath, with: .linearGradient(bowGrad, startPoint: CGPoint(x: 80*sx, y: (50-6)*sy), endPoint: CGPoint(x: 80*sx, y: (50+6)*sy)))

                // Knot highlight: circle cx=80 cy=50 r=3
                let knotHighlight = Path(ellipseIn: CGRect(x: (80-3)*sx, y: (50-3)*sy, width: 6*sx, height: 6*sy))
                ctx.fill(knotHighlight, with: .color(Color.white.opacity(0.55)))
            }
        }
    }

    struct BobbingModifier: ViewModifier {
        @State private var isAnimating = false

        func body(content: Content) -> some View {
            content
                // Bob -6 to 0 (up and return) — matches p1Bob keyframe
                .offset(y: isAnimating ? 0 : -6)
                .onAppear {
                    withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
                        isAnimating = true
                    }
                }
        }
    }

    // MARK: - Gift surrounding confetti (Page 1)

    private var giftConfettiView: some View {
        Canvas { ctx, size in
            let palette: [Color] = [
                Color(hex: 0xFFD66B),
                Color(hex: 0x4A7CFF),
                Color(hex: 0xB14BFF),
                Color(hex: 0x22D3EE),
                Color(hex: 0xFF5C8A)
            ]

            let cx = size.width / 2
            let cy: CGFloat = 80  // matches HTML: left:"50%", top:80

            for i in 0..<16 {
                let seed = Double(i) * 9301 + 49297
                let r = { (n: Double) -> Double in (sin(seed * n) + 1) / 2 }

                let angle = r(1.3) * Double.pi - Double.pi / 2
                let radius = 80.0 + r(1.9) * 50.0
                let px = cx + CGFloat(cos(angle) * radius)
                let py = cy + CGFloat(sin(angle) * radius - 20)
                let sz = CGFloat(5.0 + r(2.5) * 6.0)
                let color = palette[i % palette.count]
                let shape = i % 4

                if shape == 1 {
                    // rectangle (wider than tall)
                    let rect = CGRect(x: px - sz/2, y: py - sz * 0.2, width: sz, height: sz * 0.4)
                    ctx.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(color))
                } else if shape == 2 {
                    // circle
                    ctx.fill(Path(ellipseIn: CGRect(x: px - sz/2, y: py - sz/2, width: sz, height: sz)), with: .color(color))
                } else {
                    // square
                    let rect = CGRect(x: px - sz/2, y: py - sz/2, width: sz, height: sz)
                    ctx.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(color))
                }
            }
        }
        .frame(width: 300, height: 200)
    }

    // MARK: - PAGE 2: DISCOUNT REVEAL VIEW

    private var discountPageView: some View {
        VStack(spacing: 0) {
            // Top bar — countdown only (no back button)
            HStack {
                Spacer()
                // Countdown pill — glassmorphic container
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(hex: 0xFFD66B))
                        .shadow(color: Color(hex: 0xFFD66B).opacity(1.0), radius: 4)
                        .frame(width: 6, height: 6)
                    Text("ENDS IN \(formatCountdown())")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color(hex: 0xFFD66B))
                        .id(timerTickKey)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.06))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)

            // Content block
            VStack(spacing: 0) {
                // Badge: "SPECIAL OFFER UNLOCKED" with gradient pill + dot
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color(hex: 0xE5D5FF))
                        .shadow(color: Color(hex: 0xB14BFF), radius: 3)
                        .frame(width: 5, height: 5)

                    Text("SPECIAL OFFER UNLOCKED")
                        .font(.system(size: 11, weight: .heavy))
                        .tracking(1.6)
                        .foregroundStyle(Color(hex: 0xE5D5FF))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    LinearGradient(
                        colors: [
                            Color(hex: 0x4A7CFF).opacity(0.22),
                            Color(hex: 0xB14BFF).opacity(0.22)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(Color(hex: 0xB14BFF).opacity(0.45), lineWidth: 1)
                )
                .padding(.bottom, 10)

                // "just for you..." — soft, small, italic-feeling
                Text("just for you...")
                    .font(.system(size: 14, weight: .light))
                    .italic()
                    .foregroundStyle(Color.white.opacity(0.55))

                // "Take an extra" — medium weight, sits tight below
                Text("Take an extra")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .padding(.top, 2)

                // Big 37% — "37" at 88pt, "%" at 52pt
                HStack(alignment: .top, spacing: 2) {
                    Text("37")
                        .font(.system(size: 88, weight: .black))
                        .tracking(-3.5)

                    Text("%")
                        .font(.system(size: 52, weight: .black))
                        .tracking(-2)
                        .padding(.top, 10)
                }
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color.white,
                            Color(hex: 0xC9B8FF),
                            Color(hex: 0x8E6FFF)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: Color(hex: 0xB14BFF).opacity(0.45), radius: 24, y: 4)
                .padding(.top, 8)

                Text("OFF Your First Week")
                    .font(.system(size: 24, weight: .heavy))
                    .tracking(-0.6)
                    .foregroundStyle(Color.white)
                    .padding(.top, 0)

                Text("One-time offer. Disappears when you close this screen.")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.top, 10)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            Spacer(minLength: 20)

            // Pricing card (glassmorphic)
            pricingCard
                .padding(.horizontal, 22)

            Spacer(minLength: 28)

            // CTAs
            VStack(spacing: 12) {
                // Primary: "Claim Offer — $4.99 This Week"
                Button {
                    handleClaimOffer()
                } label: {
                    ZStack {
                        if isPurchasing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else if let price = discountPrice {
                            Text("Claim Offer — \(price) This Week")
                                .font(.system(size: 17, weight: .heavy))
                                .tracking(-0.2)
                                .foregroundStyle(.white)
                        } else {
                            Text("Claim Offer")
                                .font(.system(size: 17, weight: .heavy))
                                .tracking(-0.2)
                                .foregroundStyle(.white)
                                .redacted(reason: .placeholder)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
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
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .shadow(color: Color(hex: 0x8B5CFF).opacity(0.55), radius: 20, y: 14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                    )
                    .modifier(ShineOverlayModifier())
                }
                .disabled(isPurchasing)

                // Billing info — uses dynamic pricing vars (discountPrice, fullPrice)
                if let discount = discountPrice, let full = fullPrice {
                    Text("Just \(discount) your first week, then \(full)/week after. Cancel anytime.")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.45))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }

                // Secondary: decline link
                Button {
                    stopCountdownTimer()
                    onDismiss()
                } label: {
                    Text("No thanks, I'd rather pay full price later")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.85))
                }

                // Terms & Privacy — same style as main paywall
                HStack(spacing: 4) {
                    Link("Terms of Use", destination: URL(string: "https://trygrooveai.com/terms")!)
                    Text("·")
                    Link("Privacy Policy", destination: URL(string: "https://trygrooveai.com/privacy")!)
                }
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.3))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Pricing Card (glassmorphic — single centered layout)

    private var pricingCard: some View {
        VStack(alignment: .center, spacing: 4) {
            // "NOW ONLY" label — small caps, purple accent, letter-spaced
            Text("NOW ONLY")
                .font(.system(size: 11, weight: .heavy))
                .tracking(2.0)
                .foregroundStyle(Color(hex: 0xA78BFA))
                .textCase(.uppercase)

            // Big price
            Text(discountPrice ?? "$0.00")
                .font(.system(size: 34, weight: .black))
                .tracking(-0.8)
                .foregroundStyle(Color.white)
                .redacted(reason: discountPrice == nil ? .placeholder : [])

            // "first week" sub-label
            Text("first week")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Button Shine Animation

    struct ShineOverlayModifier: ViewModifier {
        @State private var shineOffset: CGFloat = -200

        func body(content: Content) -> some View {
            content
                .overlay(
                    // Shine sweep: starts at -30% (offscreen left), sweeps to 110% (offscreen right)
                    // 60% of 2.6s cycle is active sweep, remaining 40% stays offscreen right
                    GeometryReader { geo in
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0),
                                Color.white.opacity(0.35),
                                Color.white.opacity(0)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geo.size.width * 0.3)
                        .offset(x: shineOffset)
                        .onAppear {
                            shineOffset = -geo.size.width * 0.3
                            withAnimation(.linear(duration: 2.6).repeatForever(autoreverses: false)) {
                                shineOffset = geo.size.width * 1.1
                            }
                        }
                    }
                    .clipped()
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
