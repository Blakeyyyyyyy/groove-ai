// GrooveHeroScrollView.swift
// PAGE 1 — Two auto-scrolling card rows (one RTL, one LTR) + CTA.
// Mirrors HeroTransformationView from Glow AI with 2 rows instead of 1.

import SwiftUI
import Combine

// ─── Data ────────────────────────────────────────────────────────────────────

struct GrooveScrollCard: Identifiable {
    let id    = UUID()
    let emoji: String
    let label: String
}

private let row1Cards: [GrooveScrollCard] = [
    .init(emoji: "🕺", label: "Hip Hop"),
    .init(emoji: "💃", label: "Salsa"),
    .init(emoji: "🩰", label: "Ballet"),
    .init(emoji: "🎉", label: "Party"),
    .init(emoji: "🤖", label: "Robot"),
    .init(emoji: "🌀", label: "Spin"),
]

private let row2Cards: [GrooveScrollCard] = [
    .init(emoji: "🐕", label: "Dog"),
    .init(emoji: "👩", label: "Person"),
    .init(emoji: "🦁", label: "Lion"),
    .init(emoji: "🧑‍🎤", label: "Pop Star"),
    .init(emoji: "🦊", label: "Fox"),
    .init(emoji: "🧒", label: "Kid"),
]

// ─── View ─────────────────────────────────────────────────────────────────────

struct GrooveHeroScrollView: View {
    let onNext: () -> Void

    var body: some View {
        ZStack {
            GrooveOnboardingTheme.background.ignoresSafeArea()
            GrooveOnboardingTheme.radialGlow

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 10) {
                    Text("Make Anyone\nDrop the Beat")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Text("Pick a photo. Pick a dance. Watch the magic.")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 60)
                .padding(.horizontal, 24)

                Spacer()

                // ── Two infinite scroll rows ──────────────────────────────────
                VStack(spacing: 16) {
                    InfiniteScrollRow(cards: row1Cards, speed: 1.2, reversed: false)
                        .frame(height: 180)

                    InfiniteScrollRow(cards: row2Cards, speed: 1.5, reversed: true)
                        .frame(height: 180)
                }
                .clipped()

                Spacer()

                // Bottom gradient fade
                LinearGradient(
                    colors: [GrooveOnboardingTheme.background.opacity(0), GrooveOnboardingTheme.background],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 80)
                .allowsHitTesting(false)

                // CTA
                Button(action: onNext) {
                    Text("Let's Begin")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: GrooveOnboardingTheme.ctaButtonHeight)
                        .background(GrooveOnboardingTheme.blueAccent)
                        .clipShape(Capsule())
                        .shadow(
                            color: GrooveOnboardingTheme.blueAccent.opacity(0.4),
                            radius: 10, y: 5
                        )
                }
                .padding(.horizontal, GrooveOnboardingTheme.ctaHorizontalPadding)
                .padding(.bottom, GrooveOnboardingTheme.ctaBottomPadding)
            }
        }
    }
}

// ─── Infinite scroll row ───────────────────────────────────────────────────────

struct InfiniteScrollRow: View {
    let cards:    [GrooveScrollCard]
    let speed:    CGFloat          // points per tick
    let reversed: Bool

    @State private var offset: CGFloat = 0
    @State private var timer: AnyCancellable?

    private let cardWidth:  CGFloat = 140
    private let cardGap:    CGFloat = 16

    private var unitWidth: CGFloat {
        CGFloat(cards.count) * (cardWidth + cardGap)
    }

    var body: some View {
        GeometryReader { _ in
            HStack(spacing: cardGap) {
                // Triplicate for smooth looping
                ForEach(0..<30, id: \.self) { idx in
                    let card = cards[idx % cards.count]
                    GrooveScrollCardView(card: card)
                        .frame(width: cardWidth, height: 160)
                }
            }
            .offset(x: offset)
        }
        .onAppear { startScroll() }
        .onDisappear { timer?.cancel() }
    }

    private func startScroll() {
        timer = Timer.publish(every: 0.016, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                if reversed {
                    offset += speed
                    if offset >= unitWidth { offset -= unitWidth }
                } else {
                    offset -= speed
                    if offset <= -unitWidth { offset += unitWidth }
                }
            }
    }
}

// ─── Single card ─────────────────────────────────────────────────────────────

struct GrooveScrollCardView: View {
    let card: GrooveScrollCard

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0x1A1A28), Color(hex: 0x0F0F18)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )

            VStack(spacing: 8) {
                Text(card.emoji)
                    .font(.system(size: 44))
                Text(card.label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                    .textCase(.uppercase)
                    .tracking(1.2)
            }
        }
        .cornerRadius(20)
    }
}
