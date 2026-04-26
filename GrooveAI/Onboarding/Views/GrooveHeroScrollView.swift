// GrooveHeroScrollView.swift
// PAGE 1 — Hero with pre-rendered scrolling video wall
// Uses SingleVideoWallView: a single looping MP4 containing the full animated 3-column wall.

import SwiftUI
import UIKit

// MARK: - Public SwiftUI View

struct GrooveHeroScrollView: View {
    let onNext: () -> Void

    @State private var contentVisible = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                GrooveOnboardingTheme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer().frame(height: 24)

                    // 3-column scrolling video wall
                    ZStack {
                        GrooveOnboardingTheme.radialGlow
                            .scaleEffect(1.75)
                            .blur(radius: 30)

                        SingleVideoWallView()

                        // Top fade
                        VStack {
                            LinearGradient(
                                colors: [GrooveOnboardingTheme.background, GrooveOnboardingTheme.background.opacity(0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 42)
                            Spacer()
                        }
                        .allowsHitTesting(false)

                        // Bottom fade
                        VStack {
                            Spacer()
                            LinearGradient(
                                colors: [GrooveOnboardingTheme.background.opacity(0), GrooveOnboardingTheme.background],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 92)
                        }
                        .allowsHitTesting(false)
                    }
                    .frame(height: min(geo.size.height * 0.58, 500))
                    .clipped()

                    Spacer().frame(height: 22)

                    VStack(spacing: 12) {
                        Text("Make Anyone Drop the Beat")
                            .font(.system(size: 36, weight: .heavy))
                            .tracking(-0.5)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineSpacing(-4)

                        Text("Upload a photo. Pick a dance. Watch it come alive.")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(GrooveOnboardingTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 300)
                    }
                    .padding(.horizontal, 24)
                    .opacity(contentVisible ? 1 : 0)
                    .offset(y: contentVisible ? 0 : 16)

                    Spacer().frame(height: 28)

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
                    .opacity(contentVisible ? 1 : 0)
                    .offset(y: contentVisible ? 0 : 18)

                    Spacer().frame(height: GrooveOnboardingTheme.ctaBottomPadding)
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeOut(duration: 0.35).delay(0.08)) {
                contentVisible = true
            }
        }
    }
}

struct CTAPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
