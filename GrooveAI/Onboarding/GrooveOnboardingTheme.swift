// GrooveOnboardingTheme.swift
// Groove AI — mirrors OnboardingTheme from Glow AI exactly.
// Background, accent, radial glow, and all layout constants are identical.

import SwiftUI

struct GrooveOnboardingTheme {
    // ── Colours ────────────────────────────────────────────────────────────────
    static let background  = Color(hex: 0x0B0B0F)
    static let blueAccent  = Color(hex: 0x1E90FF)

    static var radialGlow: RadialGradient {
        RadialGradient(
            gradient: Gradient(colors: [
                Color(hex: 0x1E90FF).opacity(0.15),
                Color.clear
            ]),
            center: .center,
            startRadius: 50,
            endRadius: 400
        )
    }

    // ── Hero image ─────────────────────────────────────────────────────────────
    static let heroImageSize      = CGSize(width: 310, height: 440)
    static let heroCornerRadius: CGFloat = 24
    static let heroImageTopPadding: CGFloat = 80

    // ── Layout ─────────────────────────────────────────────────────────────────
    static let progressDotsHeight: CGFloat   = 60
    static let ctaButtonHeight: CGFloat      = 64
    static let ctaHorizontalPadding: CGFloat = 24
    static let ctaBottomPadding: CGFloat     = 50
}

// MARK: - Color(hex:) convenience (add only if not already in project)
extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8)  & 0xFF) / 255
        let b = Double( hex        & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
