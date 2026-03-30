// GrooveReassuranceView.swift
// Pre-paywall reassurance screen — animated bell, "We've Got You Covered".
// Ported directly from Glow AI's ReassuranceView.swift.
// Sits between GrooveResultView and GroovePaywallScreen in the flow.

import SwiftUI

struct GrooveReassuranceView: View {
    let onNext: () -> Void
    @State private var bellRotation: Double = 0

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x1E90FF), Color(hex: 0x0055FF)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Animated bell icon
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 94))
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(bellRotation))
                    .padding(.bottom, 32)
                    .onAppear {
                        withAnimation(
                            Animation.easeInOut(duration: 0.8)
                                .repeatForever(autoreverses: true)
                        ) {
                            bellRotation = 15
                        }
                    }

                // Headline
                Text("We've Got You Covered")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)

                // Sub
                Text("We'll remind you before your trial ends.")
                    .font(.system(size: 22))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 12)

                Spacer()

                // Trust line
                HStack(spacing: 8) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Text("No payment due now")
                        .font(.system(size: 17))
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(.bottom, 16)

                // CTA
                Button(action: onNext) {
                    Text("Continue for FREE")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: GrooveOnboardingTheme.ctaButtonHeight)
                        .background(Color.white)
                        .clipShape(Capsule())
                        .shadow(radius: 10)
                }
                .padding(.horizontal, GrooveOnboardingTheme.ctaHorizontalPadding)
                .padding(.bottom, GrooveOnboardingTheme.ctaBottomPadding)
            }
        }
    }
}
