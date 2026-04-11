// GrooveOnboardingTheme.swift
// Groove AI — Premium design system per onboarding-design-spec.md

import SwiftUI

struct GrooveOnboardingTheme {
    // ── Colours ────────────────────────────────────────────────────────────────
    static let background      = Color(hex: 0x080A0F)   // near-black blue tint (was 0x0B0B0F)
    static let surfaceL1       = Color(hex: 0x111318)    // cards, containers
    static let surfaceL2       = Color(hex: 0x1A1D24)    // elevated cards, selection states
    static let surfaceL3       = Color(hex: 0x242830)    // hover/active states

    static let blueAccent      = Color(hex: 0x3D7FFF)    // premium blue (was 0x1E90FF system blue)
    static let blueAccentGlow  = Color(hex: 0x3D7FFF).opacity(0.20)

    static let textPrimary     = Color.white
    static let textSecondary   = Color(hex: 0x8A8F9C)    // cooler secondary text
    static let textTertiary    = Color(hex: 0x4E5260)

    static let borderSubtle    = Color.white.opacity(0.08)
    static let badgeBG         = Color(hex: 0x1A2A4A)
    static let badgeText       = Color(hex: 0x6EA8FF)

    // ── Radial Glow ────────────────────────────────────────────────────────────
    static var radialGlow: RadialGradient {
        RadialGradient(
            gradient: Gradient(colors: [
                blueAccent.opacity(0.15),
                Color.clear
            ]),
            center: .center,
            startRadius: 50,
            endRadius: 400
        )
    }

    // ── Button Tokens ──────────────────────────────────────────────────────────
    static let ctaButtonHeight: CGFloat      = 58     // was 64
    static let ctaCornerRadius: CGFloat      = 29     // fully pill
    static let ctaHorizontalPadding: CGFloat = 24
    static let ctaBottomPadding: CGFloat     = 40     // was 50
    static let ctaFontSize: CGFloat          = 18
    static let ctaShadow = Color(hex: 0x3D7FFF).opacity(0.35)

    // ── Layout ─────────────────────────────────────────────────────────────────
    static let heroImageSize      = CGSize(width: 310, height: 440)
    static let heroCornerRadius: CGFloat = 24
    static let heroImageTopPadding: CGFloat = 80
    static let progressDotsHeight: CGFloat  = 60

    // ── Spacing Scale ──────────────────────────────────────────────────────────
    static let spacingXS:  CGFloat = 4
    static let spacingSM:  CGFloat = 8
    static let spacingMD:  CGFloat = 16
    static let spacingLG:  CGFloat = 24
    static let spacingXL:  CGFloat = 32
    static let spacing2XL: CGFloat = 48
    static let spacing3XL: CGFloat = 64

    // ── Badge Colors ───────────────────────────────────────────────────────────
    static let badgeTrending = Color(hex: 0xFF4D1A)
    static let badgeHot      = Color(hex: 0xFF6B35)
    static let badgeFanFave  = Color(hex: 0x8B5CF6)
    static let badgeNew      = Color(hex: 0x3D7FFF)

    // ── Spring Animation ───────────────────────────────────────────────────────
    static let screenTransition = Animation.interpolatingSpring(
        mass: 1.0, stiffness: 200, damping: 22, initialVelocity: 0
    )
    static let screenTransitionDuration: Double = 0.38
}

// MARK: - Color(hex:) convenience
extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8)  & 0xFF) / 255
        let b = Double( hex        & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
