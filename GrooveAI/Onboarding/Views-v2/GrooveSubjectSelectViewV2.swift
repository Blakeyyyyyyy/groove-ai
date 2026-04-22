// GrooveSubjectSelectView.swift — v2
// PAGE 2 — Subject selection
// v2 changes:
//   • VStack layout (vertical stack) instead of HStack
//   • Full-width landscape cards (350×200pt)
//   • Tap card = auto-advance (spring + haptic) — no Next button
//   • Removed hint text ("Tap to see your preview")
//   • Labels updated to be clear and distinct

import SwiftUI

// ─── Subject Data ────────────────────────────────────────────────────────────

private struct SubjectOption: Identifiable {
    let id: String
    let label: String
    let subtitle: String
    let videoURL: String
}

private let r2Base = "https://videos.trygrooveai.com/presets"

private let subjectOptions: [SubjectOption] = [
    SubjectOption(
        id: "person",
        label: "A Person",
        subtitle: "Anyone can groove",
        videoURL: "\(r2Base)/baby-boombastic.mp4"
    ),
    SubjectOption(
        id: "dog",
        label: "My Pet",
        subtitle: "Watch them bust a move",
        videoURL: "\(r2Base)/big-guy-V5-AI.mp4"
    ),
]

// ─── View ─────────────────────────────────────────────────────────────────────

struct GrooveSubjectSelectViewV2: View {
    @ObservedObject var state: GrooveOnboardingState
    let onNext: () -> Void

    @State private var cardsAppeared = false

    var body: some View {
        ZStack {
            Color(hex: 0x0A0A0A).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 96) // below progress dots

                // "✨ Try it free" badge
                Text("✨ Try it free")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(GrooveOnboardingTheme.badgeText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(GrooveOnboardingTheme.badgeBG)
                    .clipShape(Capsule())
                    .opacity(cardsAppeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.2), value: cardsAppeared)

                Spacer().frame(height: 16)

                // Header
                VStack(spacing: 8) {
                    Text("Who's dancing?")
                        .font(.system(size: 34, weight: .bold))
                        .tracking(-0.5)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .opacity(cardsAppeared ? 1 : 0)

                    Text("Pick your subject")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(GrooveOnboardingTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .opacity(cardsAppeared ? 1 : 0)
                }
                .padding(.horizontal, 30)

                Spacer().frame(height: 28)

                // Subject cards — vertical stack, full-width landscape
                VStack(spacing: 14) {
                    ForEach(Array(subjectOptions.enumerated()), id: \.element.id) { index, option in
                        SubjectLandscapeCard(
                            option: option,
                            isSelected: state.selectedSubjectId == option.id
                        ) {
                            handleSelect(option.id)
                        }
                        .offset(y: cardsAppeared ? 0 : 24)
                        .opacity(cardsAppeared ? 1 : 0)
                        .animation(
                            .spring(response: 0.4, dampingFraction: 0.8)
                                .delay(Double(index) * 0.07),
                            value: cardsAppeared
                        )
                    }
                }
                .padding(.horizontal, 20)

                Spacer()
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                cardsAppeared = true
            }
        }
    }

    private func handleSelect(_ id: String) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            state.selectedSubjectId = id
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            onNext()
        }
    }
}

// ─── Landscape subject card (350×200pt equivalent, full width) ─────────────────

private struct SubjectLandscapeCard: View {
    let option: SubjectOption
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
                // Video thumbnail fills card
                RemoteVideoThumbnail(urlString: option.videoURL, cornerRadius: 20)

                // Gradient fade — bottom-weighted
                VStack {
                    Spacer()
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color(hex: 0x0A0A0A).opacity(0.75),
                            Color(hex: 0x0A0A0A).opacity(0.92)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 90)
                }
                .clipShape(RoundedRectangle(cornerRadius: 20))

                // Text — bottom left
                VStack(alignment: .leading, spacing: 4) {
                    Text(option.label)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)

                    Text(option.subtitle)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.white.opacity(0.70))
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 16)
            }
            // Landscape: full-width, fixed 200pt height
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        isSelected
                            ? GrooveOnboardingTheme.blueAccent
                            : Color.white.opacity(0.10),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .shadow(
                color: isSelected ? GrooveOnboardingTheme.blueAccent.opacity(0.20) : .clear,
                radius: 16
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.65), value: isSelected)
    }
}
