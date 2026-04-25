// GrooveHeroScrollView.swift — v2
// PAGE 1 — Hero with 3-column parallax video wall + CTA
// v3: AVPlayer-based hero video wall with player pooling
// NOTE: Requires HeroVideoCell, AVPlayerPool, HeroVideoColumnView, HeroVideoWallView
//       to be added to Xcode target. See HERO_VIDEO_INTEGRATION.md for setup.

import SwiftUI

// ─── Data ────────────────────────────────────────────────────────────────────

private let videoURLs: [String] = {
    let presetsByID = Dictionary(uniqueKeysWithValues: DancePreset.allPresets.map { ($0.id, $0) })
    let heroPresetIDs = [
        "big-guy",
        "coco-channel",
        "trag",
        "c-walk",
        "boombastic",
        "ophelia",
        "jenny",
        "macarena",
        "milkshake",
        "witch-doctor",
        "cotton-eye-joe",
        "boombastic",
        "big-guy",
        "trag",
        "ophelia",
    ]

    return heroPresetIDs.compactMap { presetID in
        presetsByID[presetID]?.videoURL
    }
}()

// ─── View ─────────────────────────────────────────────────────────────────────

struct GrooveHeroScrollViewV2: View {
    let onNext: () -> Void

    var body: some View {
        ZStack {
            GrooveOnboardingTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Wordmark ────────────────────────────────────────────────────
                Text("GrooveAI")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.70))
                    .padding(.top, 56)

                Spacer().frame(height: 20)

                // ── 3-column parallax video wall (AVPlayer pooling) ────────────
                ZStack {
                    HeroVideoWallView(videoURLs: videoURLs)

                    // Top gradient fade
                    VStack {
                        LinearGradient(
                            colors: [GrooveOnboardingTheme.background, GrooveOnboardingTheme.background.opacity(0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 32)
                        Spacer()
                    }
                    .allowsHitTesting(false)

                    // Bottom gradient fade
                    VStack {
                        Spacer()
                        LinearGradient(
                            colors: [GrooveOnboardingTheme.background.opacity(0), GrooveOnboardingTheme.background],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 80)
                    }
                    .allowsHitTesting(false)
                }
                .clipped()

                Spacer().frame(height: 32)

                // ── Headline + Subline ──────────────────────────────────────────
                VStack(spacing: 10) {
                    Text("Make Anyone Drop the Beat")
                        .font(.system(size: 36, weight: .heavy))
                        .tracking(-0.5)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(-4)

                    Text("Pick a photo. Tap a dance. Watch the magic.")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(GrooveOnboardingTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 280)
                }
                .padding(.horizontal, 24)

                Spacer().frame(height: 28)

                // ── CTA Button with glow shadow ─────────────────────────────────
                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onNext()
                }) {
                    Text("Make yours →")
                        .font(.system(size: GrooveOnboardingTheme.ctaFontSize, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: GrooveOnboardingTheme.ctaButtonHeight)
                        .background(GrooveOnboardingTheme.blueAccent)
                        .clipShape(Capsule())
                        .shadow(color: GrooveOnboardingTheme.ctaShadow, radius: 12, y: 4)
                }
                .buttonStyle(CTAPressStyle())
                .padding(.horizontal, GrooveOnboardingTheme.ctaHorizontalPadding)
                .padding(.bottom, GrooveOnboardingTheme.ctaBottomPadding)
            }
        }
    }
}
