// TrialEnabledScreen.swift
// Groove AI — Pre-paywall trial activation screen
// Pure black, centered toggle auto-animates ON, then transitions to paywall
// NO user interaction — fully automatic animation

import SwiftUI

struct TrialEnabledScreen: View {
    let onNext: () -> Void

    @State private var isToggled = false
    @State private var showText = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Toggle("", isOn: $isToggled)
                    .toggleStyle(SwitchToggleStyle(tint: Color(hex: 0x30D158)))
                    .labelsHidden()
                    .scaleEffect(1.8)
                    .disabled(true)
                    .allowsHitTesting(false)

                if showText {
                    Text("7 day trial enabled")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                        .transition(.opacity)
                }

                Spacer()
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.85, dampingFraction: 0.78)) {
                    isToggled = true
                }

                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeOut(duration: 0.25)) {
                    showText = true
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                onNext()
            }
        }
    }
}
