// GrooveSubjectSelectView.swift
// PAGE 2 — Subject selection with premium card design
// Per spec: badge, left-aligned card text, gradient image fade, blue border selection

import SwiftUI

// ─── Subject Data ────────────────────────────────────────────────────────────

private struct SubjectOption: Identifiable {
    let id: String            // "dog" | "person"
    let label: String
    let subtitle: String
    let videoURL: String
}

private let r2Base = "https://pub-7ff4cf5f3d0d431db23366638a4128e0.r2.dev/presets"

private let subjectOptions: [SubjectOption] = [
    SubjectOption(
        id: "dog",
        label: "My Pet",
        subtitle: "Watch them dance",
        videoURL: "\(r2Base)/big-guy-V5-AI.mp4"
    ),
    SubjectOption(
        id: "person",
        label: "A Person",
        subtitle: "Anyone can groove",
        videoURL: "\(r2Base)/baby-boombastic.mp4"
    ),
]

// ─── View ─────────────────────────────────────────────────────────────────────

struct GrooveSubjectSelectView: View {
    @ObservedObject var state: GrooveOnboardingState
    let onNext: () -> Void

    @State private var cardsAppeared = false

    var body: some View {
        ZStack {
            GrooveOnboardingTheme.background.ignoresSafeArea()

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

                    Text("Pick your subject to see the magic")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(GrooveOnboardingTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .opacity(cardsAppeared ? 1 : 0)
                }
                .padding(.horizontal, 30)

                Spacer().frame(height: 28)

                // Subject cards
                HStack(spacing: 12) {
                    ForEach(subjectOptions) { option in
                        SubjectThumbnailCard(
                            option: option,
                            isSelected: state.selectedSubjectId == option.id
                        ) {
                            handleSelect(option.id)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .offset(y: cardsAppeared ? 0 : 20)
                .opacity(cardsAppeared ? 1 : 0)
                .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.1), value: cardsAppeared)

                Spacer()

                // Footer hint
                Text("Tap to see your preview")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(GrooveOnboardingTheme.textTertiary)
                    .padding(.bottom, 32)
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
        UIImpactFeedbackGenerator(style: .light).impactOccurred()  // light per spec
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            onNext()
        }
    }
}

// ─── Subject card ────────────────────────────────────────────────────────────

private struct SubjectThumbnailCard: View {
    let option: SubjectOption
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
                // Video thumbnail fills card
                RemoteVideoThumbnail(urlString: option.videoURL, cornerRadius: 20)

                // Gradient fade from image to card bottom
                VStack {
                    Spacer()
                    LinearGradient(
                        colors: [Color.clear, GrooveOnboardingTheme.surfaceL1.opacity(0.9), GrooveOnboardingTheme.surfaceL1],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 80) // bottom 30% gradient
                }
                .clipShape(RoundedRectangle(cornerRadius: 20))

                // Left-aligned text at bottom (premium editorial feel)
                VStack(alignment: .leading, spacing: 4) {
                    Text(option.label)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.6), radius: 4, y: 2)

                    Text(option.subtitle)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.white.opacity(0.75))
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }
            .frame(height: 220) // per spec
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
                color: isSelected ? GrooveOnboardingTheme.blueAccent.opacity(0.05) : .clear,
                radius: 16
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.65), value: isSelected)
    }
}
