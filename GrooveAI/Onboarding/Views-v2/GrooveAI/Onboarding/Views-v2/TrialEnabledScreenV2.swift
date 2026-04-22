// TrialEnabledScreen.swift — v2
// Groove AI — Pre-paywall trial activation screen

import SwiftUI

struct TrialEnabledScreenV2: View {
    let onNext: () -> Void

    @State private var isToggled = false
    @State private var showGreenTint = false
    @State private var showText = false
    @State private var showCheckmark = false
    @State private var showCTA = false
    @State private var ctaPulse = false

    var body: some View {
        ZStack {
            Color.black
                .overlay(
                    Color(red: 0.19, green: 0.82, blue: 0.34)
                        .opacity(showGreenTint ? 0.08 : 0)
                        .animation(.easeInOut(duration: 0.4), value: showGreenTint)
                )
                .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                Toggle("", isOn: $isToggled)
                    .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.19, green: 0.82, blue: 0.34)))
                    .labelsHidden()
                    .scaleEffect(1.8)
                    .disabled(true)
                    .allowsHitTesting(false)

                VStack(spacing: 16) {
                    if showText {
                        Text("7-day free trial enabled")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }

                    if showCheckmark {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(Color(red: 0.19, green: 0.82, blue: 0.34))
                            .transition(.scale(scale: 0.4).combined(with: .opacity))
                    }
                }
                .frame(height: 100)

                Spacer()

                if showCTA {
                    VStack(spacing: 0) {
                        Text("Continue")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                Color(red: 0.19, green: 0.82, blue: 0.34)
                                    .opacity(ctaPulse ? 1.0 : 0.85)
                            )
                            .clipShape(Capsule())
                            .scaleEffect(ctaPulse ? 1.02 : 1.0)
                            .animation(
                                .easeInOut(duration: 0.55).repeatForever(autoreverses: true),
                                value: ctaPulse
                            )
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 52)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .onAppear {
            runAnimationSequence()
        }
    }

    private func runAnimationSequence() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
                isToggled = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            showGreenTint = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                showGreenTint = false
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.3)) {
                showText = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) {
                showCheckmark = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation(.easeOut(duration: 0.35)) {
                showCTA = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                ctaPulse = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.8) {
            onNext()
        }
    }
}
