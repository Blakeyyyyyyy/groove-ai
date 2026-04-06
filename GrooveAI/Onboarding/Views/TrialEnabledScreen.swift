// TrialEnabledScreen.swift
// Groove AI — Pre-paywall trial activation screen
// User clicks toggle button to enable trial, then auto-transitions to paywall

import SwiftUI

struct TrialEnabledScreen: View {
    let onNext: () -> Void

    @State private var isToggled = false
    @State private var showConfirmText = false

    private let bgColor = Color(hex: 0x0F172A)
    private let accentBlue = Color(hex: 0x3478F6)
    private let accentGreen = Color(hex: 0x30D158)
    private let textPrimary = Color(hex: 0xF1F5F9)
    private let textSecondary = Color(hex: 0x94A3B8)

    // Toggle dimensions
    private let toggleWidth: CGFloat = 240
    private let toggleHeight: CGFloat = 64
    private let thumbSize: CGFloat = 54
    private let thumbPadding: CGFloat = 5

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            // Subtle glow when activated
            if isToggled {
                RadialGradient(
                    colors: [accentGreen.opacity(0.08), Color.clear],
                    center: .center,
                    startRadius: 20,
                    endRadius: 300
                )
                .ignoresSafeArea()
                .transition(.opacity)
            }

            VStack(spacing: 0) {
                Spacer()

                // Icon
                ZStack {
                    Circle()
                        .fill(accentBlue.opacity(0.1))
                        .frame(width: 80, height: 80)

                    Image(systemName: "gift.fill")
                        .font(.system(size: 32))
                        .foregroundColor(accentBlue)
                }
                .padding(.bottom, 24)

                // Title
                Text("Start Your Free Trial")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(textPrimary)
                    .padding(.bottom, 8)

                Text("7 days free, cancel anytime")
                    .font(.system(size: 16))
                    .foregroundColor(textSecondary)
                    .padding(.bottom, 40)

                // Custom toggle button
                toggleButton
                    .padding(.bottom, 24)

                // Confirmation text
                if showConfirmText {
                    VStack(spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(accentGreen)

                            Text("Your 7-day trial is enabled")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(textPrimary)
                        }

                        Text("You won't be charged today")
                            .font(.system(size: 14))
                            .foregroundColor(textSecondary)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                Spacer()
                Spacer()
            }
        }
    }

    // MARK: - Custom Toggle Button

    private var toggleButton: some View {
        Button {
            guard !isToggled else { return }
            activateTrial()
        } label: {
            ZStack(alignment: isToggled ? .trailing : .leading) {
                // Track
                Capsule()
                    .fill(isToggled ? accentGreen : Color(hex: 0x1E293B))
                    .frame(width: toggleWidth, height: toggleHeight)
                    .overlay(
                        Capsule()
                            .stroke(isToggled ? accentGreen.opacity(0.3) : Color(hex: 0x334155), lineWidth: 1.5)
                    )

                // Label text on the opposite side of thumb
                HStack {
                    if isToggled {
                        Text("ENABLED")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.leading, 24)
                        Spacer()
                    } else {
                        Spacer()
                        Text("Enable 7-Day Trial")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(textSecondary)
                            .padding(.trailing, 20)
                    }
                }
                .frame(width: toggleWidth)

                // Thumb
                Circle()
                    .fill(.white)
                    .frame(width: thumbSize, height: thumbSize)
                    .shadow(color: Color.black.opacity(0.2), radius: 4, y: 2)
                    .overlay(
                        Image(systemName: isToggled ? "checkmark" : "power")
                            .font(.system(size: isToggled ? 20 : 18, weight: .semibold))
                            .foregroundColor(isToggled ? accentGreen : Color(hex: 0x64748B))
                    )
                    .padding(thumbPadding)
            }
            .frame(width: toggleWidth, height: toggleHeight)
        }
        .buttonStyle(.plain)
        .disabled(isToggled)
        // Glow effect when activated
        .shadow(color: isToggled ? accentGreen.opacity(0.4) : Color.clear, radius: 16, y: 0)
    }

    // MARK: - Activation

    private func activateTrial() {
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        // Animate toggle to ON
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            isToggled = true
        }

        // Success haptic
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let success = UINotificationFeedbackGenerator()
            success.notificationOccurred(.success)
        }

        // Show confirmation text
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeOut(duration: 0.3)) {
                showConfirmText = true
            }
        }

        // Auto-transition to paywall after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            onNext()
        }
    }
}
