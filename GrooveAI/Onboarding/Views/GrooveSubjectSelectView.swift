// GrooveSubjectSelectView.swift
// PAGE 2 — Two tap-to-select subject cards (Dog / Person).
// Selection auto-advances to Page 3 after a brief highlight delay.

import SwiftUI

struct GrooveSubjectSelectView: View {
    @ObservedObject var state: GrooveOnboardingState
    let onNext: () -> Void

    var body: some View {
        ZStack {
            GrooveOnboardingTheme.background.ignoresSafeArea()
            GrooveOnboardingTheme.radialGlow

            VStack(spacing: 0) {
                Spacer()

                // Header
                VStack(spacing: 8) {
                    Text("Who's dancing?")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Text("Tap one to get started")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.horizontal, 30)

                Spacer().frame(height: 36)

                // Subject cards
                HStack(spacing: 16) {
                    SubjectCard(
                        emoji: "🐕",
                        label: "Dog",
                        isSelected: state.selectedSubjectId == "dog"
                    ) {
                        handleSelect("dog")
                    }

                    SubjectCard(
                        emoji: "👩",
                        label: "Person",
                        isSelected: state.selectedSubjectId == "woman"
                    ) {
                        handleSelect("woman")
                    }
                }
                .padding(.horizontal, 24)

                Spacer()
            }
        }
    }

    private func handleSelect(_ id: String) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            state.selectedSubjectId = id
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            onNext()
        }
    }
}

// ─── Subject card ────────────────────────────────────────────────────────────

private struct SubjectCard: View {
    let emoji:      String
    let label:      String
    let isSelected: Bool
    let onTap:      () -> Void

    var body: some View {
        Button(action: onTap) {
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
                            .stroke(
                                isSelected
                                    ? GrooveOnboardingTheme.blueAccent
                                    : Color.white.opacity(0.12),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
                    .shadow(
                        color: isSelected ? GrooveOnboardingTheme.blueAccent.opacity(0.25) : .clear,
                        radius: 16
                    )

                VStack(spacing: 12) {
                    Text(emoji)
                        .font(.system(size: 64))
                    Text(label)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.03 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}
