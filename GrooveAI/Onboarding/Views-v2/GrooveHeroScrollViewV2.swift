// GrooveHeroScrollView.swift — v2
// PAGE 1 — Hero with 3-column symmetric auto-scrolling grid + CTA
// v2 change: removed text overlays from carousel cards (clean video-only cards)

import SwiftUI
import Combine

// ─── Data ────────────────────────────────────────────────────────────────────

struct GrooveScrollCard: Identifiable {
    let id    = UUID()
    let videoURL: String
}

private let r2Base = "https://videos.trygrooveai.com/presets"

private let column1Cards: [GrooveScrollCard] = [
    .init(videoURL: "\(r2Base)/big-guy-V5-AI.mp4"),
    .init(videoURL: "\(r2Base)/trag-V5-AI.mp4"),
    .init(videoURL: "\(r2Base)/c-walk-V5-AI.mp4"),
]

private let column2Cards: [GrooveScrollCard] = [
    .init(videoURL: "\(r2Base)/ophelia-ai.mp4"),
    .init(videoURL: "\(r2Base)/baby-boombastic.mp4"),
    .init(videoURL: "\(r2Base)/jenny-ai.mp4"),
]

private let column3Cards: [GrooveScrollCard] = [
    .init(videoURL: "\(r2Base)/macarena-V5-AI.mp4"),
    .init(videoURL: "\(r2Base)/milkshake-V5-AI.mp4"),
    .init(videoURL: "\(r2Base)/coco-channel-75fcae6c.mp4"),
]

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

                // ── 3-column symmetric grid ─────────────────────────────────────
                ZStack {
                    HStack(spacing: 12) {
                        InfiniteColumnScroll(cards: column1Cards, speed: 0.8, reversed: false)
                        InfiniteColumnScroll(cards: column2Cards, speed: 1.0, reversed: true)
                        InfiniteColumnScroll(cards: column3Cards, speed: 0.9, reversed: false)
                    }
                    .padding(.horizontal, 0)

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

// ─── CTA button press animation ────────────────────────────────────────────────

struct CTAPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// ─── Infinite vertical column scroll ────────────────────────────────────────────

private struct InfiniteColumnScroll: View {
    let cards: [GrooveScrollCard]
    let speed: CGFloat
    let reversed: Bool

    @State private var offset: CGFloat = 0
    @State private var timer: AnyCancellable?

    private let cardHeight: CGFloat = 160
    private let cardGap:    CGFloat = 12

    private var unitHeight: CGFloat {
        CGFloat(cards.count) * (cardHeight + cardGap)
    }

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: cardGap) {
                ForEach(0..<18, id: \.self) { idx in
                    let card = cards[idx % cards.count]
                    GrooveGridCardView(card: card)
                        .frame(height: cardHeight)
                }
            }
            .offset(y: offset)
        }
        .clipped()
        .onAppear { startScroll() }
        .onDisappear { timer?.cancel() }
    }

    private func startScroll() {
        offset = reversed ? 0 : -(unitHeight * 0.5)
        timer = Timer.publish(every: 0.016, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                if reversed {
                    offset += speed
                    if offset >= unitHeight { offset -= unitHeight }
                } else {
                    offset -= speed
                    if offset <= -unitHeight { offset += unitHeight }
                }
            }
    }
}

// ─── Single grid card — v2: NO text overlay, clean video card ─────────────────

private struct GrooveGridCardView: View {
    let card: GrooveScrollCard

    var body: some View {
        ZStack {
            RemoteVideoThumbnail(urlString: card.videoURL, cornerRadius: 16)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(GrooveOnboardingTheme.borderSubtle, lineWidth: 1)
        )
    }
}
