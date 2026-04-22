// GrooveSubjectSelectView.swift — v2
// PAGE 2 — Subject selection

import SwiftUI

private struct SubjectOption: Identifiable {
    let id: String
    let label: String
    let subtitle: String
    let videoURL: String
}

private let subjectR2Base = "https://videos.trygrooveai.com/presets"

private let subjectOptions: [SubjectOption] = [
    SubjectOption(
        id: "person",
        label: "A Person",
        subtitle: "Anyone can groove",
        videoURL: "\(subjectR2Base)/baby-boombastic.mp4"
    ),
    SubjectOption(
        id: "dog",
        label: "My Pet",
        subtitle: "Watch them bust a move",
        videoURL: "\(subjectR2Base)/big-guy-V5-AI.mp4"
    ),
]

struct GrooveSubjectSelectViewV2: View {
    @ObservedObject var state: GrooveOnboardingState
    let onNext: () -> Void

    @State private var cardsAppeared = false

    var body: some View {
        ZStack {
            Color(hex: 0x0A0A0A).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 96)

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

                GeometryReader { geometry in
                    let cardSpacing: CGFloat = 12
                    let cardWidth = (geometry.size.width - cardSpacing) / 2

                    HStack(spacing: cardSpacing) {
                        ForEach(Array(subjectOptions.enumerated()), id: \.element.id) { index, option in
                            SubjectPortraitCard(
                                option: option,
                                isSelected: state.selectedSubjectId == option.id
                            ) {
                                handleSelect(option.id)
                            }
                            .frame(width: cardWidth)
                            .offset(y: cardsAppeared ? 0 : 24)
                            .opacity(cardsAppeared ? 1 : 0)
                            .animation(
                                .spring(response: 0.4, dampingFraction: 0.8)
                                    .delay(Double(index) * 0.07),
                                value: cardsAppeared
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
                .frame(height: 330)
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

private struct SubjectPortraitCard: View {
    let option: SubjectOption
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
                RemoteVideoThumbnail(urlString: option.videoURL, cornerRadius: 20)

                VStack {
                    Spacer()
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color(hex: 0x0A0A0A).opacity(0.70),
                            Color(hex: 0x0A0A0A).opacity(0.94)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 120)
                }
                .clipShape(RoundedRectangle(cornerRadius: 20))

                VStack(alignment: .leading, spacing: 4) {
                    Text(option.label)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)

                    Text(option.subtitle)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.white.opacity(0.72))
                        .lineLimit(2)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 14)
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(9.0 / 16.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        isSelected ? GrooveOnboardingTheme.blueAccent : Color.white.opacity(0.10),
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
