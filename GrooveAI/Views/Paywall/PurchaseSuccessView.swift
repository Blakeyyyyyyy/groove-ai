// PurchaseSuccessView.swift
// Groove AI — Post-purchase confirmation screen (NEW — was missing entirely)
//
// PSYCHOLOGY: User just bought. Peak dopamine. Confirm the moment.
// Don't just go home silently — celebrate. Create the emotional payoff.
//
// PATTERN: GrowPal "You're Premium" screen (33565b47), The Outsiders unlock animation
// TIMING: Shows for ~2.5s minimum, then user taps "Start Dancing" → home
//
// Builder note: Call this from PaywallView after successful purchase,
// then navigate to home. Example:
//
//   .fullScreenCover(isPresented: $showSuccess) {
//       PurchaseSuccessView { appState.selectedTab = .create }
//   }

import SwiftUI

struct PurchaseSuccessView: View {
    let onContinue: () -> Void

    @State private var checkmarkScale: CGFloat = 0
    @State private var contentOpacity: CGFloat = 0
    @State private var buttonOpacity: CGFloat = 0
    @State private var ringsScale: [CGFloat] = [0, 0, 0]

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            // Layered pulse rings — celebratory effect
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [Color.accentStart.opacity(0.18 - Double(i) * 0.05),
                                         Color.accentEnd.opacity(0.08 - Double(i) * 0.02)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                        .frame(width: 140 + CGFloat(i) * 60, height: 140 + CGFloat(i) * 60)
                        .scaleEffect(ringsScale[i])
                        .opacity(ringsScale[i] > 0 ? 1 : 0)
                }
            }

            VStack(spacing: 0) {
                Spacer()

                // Checkmark
                ZStack {
                    // Glow behind checkmark
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.accentStart.opacity(0.3), Color.clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 70
                            )
                        )
                        .frame(width: 120, height: 120)
                        .blur(radius: 20)

                    // Checkmark circle
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [Color.accentStart, Color.accentEnd],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 80, height: 80)
                            .shadow(color: Color.accentStart.opacity(0.5), radius: 20, x: 0, y: 0)

                        Image(systemName: "checkmark")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .scaleEffect(checkmarkScale)
                }

                // Headline
                VStack(spacing: 10) {
                    Text("You're In!")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(Color.textPrimary)

                    Text("Groove AI is unlocked.\nTime to make your first dance video.")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                }
                .padding(.top, 28)
                .padding(.horizontal, 40)
                .opacity(contentOpacity)

                // Feature confirmation pills
                HStack(spacing: 10) {
                    confirmPill(icon: "infinity", text: "Unlimited")
                    confirmPill(icon: "music.note.list", text: "All Styles")
                    confirmPill(icon: "square.and.arrow.up.fill", text: "HD Share")
                }
                .padding(.top, 28)
                .opacity(contentOpacity)

                Spacer()

                // CTA
                Button {
                    onContinue()
                } label: {
                    Text("Start Dancing →")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(LinearGradient.accent)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.xl))
                        .shadow(color: Color.accentStart.opacity(0.4), radius: 12, x: 0, y: 4)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, 40)
                .opacity(buttonOpacity)
            }
        }
        .onAppear { animateIn() }
    }

    @ViewBuilder
    private func confirmPill(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.accentStart)
            Text(text)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.textPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color.bgSecondary)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(Color.bgElevated, lineWidth: 1))
    }

    private func animateIn() {
        // Rings expand outward — celebratory pulse
        for i in 0..<3 {
            withAnimation(
                .spring(response: 0.5, dampingFraction: 0.65)
                .delay(Double(i) * 0.12)
            ) {
                ringsScale[i] = 1
            }
        }

        // Checkmark pops in
        withAnimation(.spring(response: 0.4, dampingFraction: 0.55).delay(0.15)) {
            checkmarkScale = 1
        }

        // Content fades in
        withAnimation(.easeOut(duration: 0.35).delay(0.35)) {
            contentOpacity = 1
        }

        // CTA appears last
        withAnimation(.easeOut(duration: 0.3).delay(0.6)) {
            buttonOpacity = 1
        }
    }
}

#Preview {
    PurchaseSuccessView { }
        .environment(AppState())
}
