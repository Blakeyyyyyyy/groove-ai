// GrooveResultView.swift
// PAGE 4 — "Your video is ready" result screen with Share + Create Another CTAs.

import SwiftUI

struct GrooveResultView: View {
    @ObservedObject var state: GrooveOnboardingState
    let onComplete:     () -> Void   // leads to main app / paywall
    let onCreateAnother: () -> Void  // loops back to subject select

    var body: some View {
        ZStack {
            GrooveOnboardingTheme.background.ignoresSafeArea()
            GrooveOnboardingTheme.radialGlow

            VStack(spacing: 0) {
                Spacer()

                // Video result placeholder (replace with AVPlayer or real thumbnail)
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: 0x1A1A28), Color(hex: 0x0F0F18)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )

                    VStack(spacing: 16) {
                        Text(state.subjectEmoji())
                            .font(.system(size: 80))

                        Text("Video ready")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.4))
                            .textCase(.uppercase)
                            .tracking(1.5)
                    }
                }
                .frame(width: 220, height: 390)

                Spacer().frame(height: 32)

                // Copy
                VStack(spacing: 8) {
                    Text("Your video is ready")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Text("Share it before anyone else")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.horizontal, 30)

                Spacer()

                // CTAs
                VStack(spacing: 12) {
                    Button(action: onComplete) {
                        Text("Share Now 🚀")
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

                    Button(action: onCreateAnother) {
                        Text("Create Another")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(GrooveOnboardingTheme.blueAccent)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .overlay(
                                Capsule()
                                    .stroke(GrooveOnboardingTheme.blueAccent.opacity(0.4), lineWidth: 1.5)
                            )
                    }
                }
                .padding(.horizontal, GrooveOnboardingTheme.ctaHorizontalPadding)
                .padding(.bottom, GrooveOnboardingTheme.ctaBottomPadding)
            }
        }
    }
}
