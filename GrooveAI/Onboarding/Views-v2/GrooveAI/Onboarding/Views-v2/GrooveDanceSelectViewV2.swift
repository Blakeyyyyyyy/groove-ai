// GrooveDanceSelectView.swift — v2
// PAGE 3 — Dance style selection

import SwiftUI

private struct DanceOption: Identifiable {
    let id: String
    let name: String
    let descriptor: String
    let videoURL: String
    let isMostPopular: Bool
}

private let danceR2Base = "https://videos.trygrooveai.com/presets"

private let danceOptions: [DanceOption] = [
    DanceOption(
        id: "big-guy",
        name: "Big Guy",
        descriptor: "Bold & energetic",
        videoURL: "\(danceR2Base)/big-guy-V5-AI.mp4",
        isMostPopular: true
    ),
    DanceOption(
        id: "boombastic",
        name: "Boombastic",
        descriptor: "Fun & playful",
        videoURL: "\(danceR2Base)/baby-boombastic.mp4",
        isMostPopular: false
    ),
    DanceOption(
        id: "trag",
        name: "Trag",
        descriptor: "Smooth & satisfying",
        videoURL: "\(danceR2Base)/trag-V5-AI.mp4",
        isMostPopular: false
    ),
]

struct GrooveDanceSelectViewV2: View {
    @ObservedObject var state: GrooveOnboardingState
    let onNext: () -> Void

    @State private var selectedDanceId: String? = nil
    @State private var cardsAppeared = false
    @State private var ctaVisible = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(hex: 0x0A0A0A).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: 96)

                SubjectConfirmationStrip(subjectId: state.selectedSubjectId)
                    .opacity(cardsAppeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.3), value: cardsAppeared)

                Spacer().frame(height: 24)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Now pick a dance")
                        .font(.system(size: 32, weight: .bold))
                        .tracking(-0.5)
                        .foregroundColor(.white)

                    Text("Tap one to preview the magic")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(GrooveOnboardingTheme.textSecondary)
                }
                .padding(.horizontal, 20)

                Spacer().frame(height: 20)

                VStack(spacing: 12) {
                    ForEach(Array(danceOptions.enumerated()), id: \.element.id) { index, option in
                        DanceHorizontalCard(
                            option: option,
                            isSelected: selectedDanceId == option.id
                        ) {
                            handleDanceTap(option)
                        }
                        .offset(y: cardsAppeared ? 0 : 20)
                        .opacity(cardsAppeared ? 1 : 0)
                        .animation(
                            .spring(response: 0.4, dampingFraction: 0.8)
                                .delay(Double(index) * 0.06),
                            value: cardsAppeared
                        )
                    }
                }
                .padding(.horizontal, 20)

                Spacer()
            }

            if ctaVisible {
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [Color(hex: 0x0A0A0A).opacity(0), Color(hex: 0x0A0A0A)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 32)

                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onNext()
                    }) {
                        Text("See the magic →")
                            .font(.system(size: GrooveOnboardingTheme.ctaFontSize, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: GrooveOnboardingTheme.ctaButtonHeight)
                            .background(GrooveOnboardingTheme.blueAccent)
                            .clipShape(Capsule())
                            .shadow(color: GrooveOnboardingTheme.ctaShadow, radius: 12, y: 4)
                    }
                    .buttonStyle(CTAPressStyleV2())
                    .padding(.horizontal, GrooveOnboardingTheme.ctaHorizontalPadding)
                    .padding(.bottom, GrooveOnboardingTheme.ctaBottomPadding)
                    .background(Color(hex: 0x0A0A0A))
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                cardsAppeared = true
            }
        }
    }

    private func handleDanceTap(_ option: DanceOption) {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            selectedDanceId = option.id
            state.selectedDanceId = option.id
        }

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.15)) {
            ctaVisible = true
        }
    }
}

private struct DanceHorizontalCard: View {
    let option: DanceOption
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                ZStack(alignment: .topLeading) {
                    if let url = URL(string: option.videoURL) {
                        LoopingVideoView(url: url)
                            .frame(width: 120, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    } else {
                        LinearGradient(
                            colors: [Color(hex: 0x1A1A2E), Color(hex: 0x16213E)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        Image(systemName: "play.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white.opacity(0.5))
                    }

                    if option.isMostPopular {
                        Text("🔥 Most popular")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color(red: 1.0, green: 0.35, blue: 0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .padding(6)
                    }
                }
                .frame(width: 120, height: 120)

                VStack(alignment: .leading, spacing: 6) {
                    Text(option.name)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)

                    Text(option.descriptor)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(GrooveOnboardingTheme.textSecondary)
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "chevron.right")
                    .font(.system(size: isSelected ? 22 : 16, weight: .semibold))
                    .foregroundColor(isSelected ? GrooveOnboardingTheme.blueAccent : Color.white.opacity(0.25))
                    .padding(.trailing, 16)
                    .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
            }
            .frame(height: 120)
            .background(Color.white.opacity(isSelected ? 0.08 : 0.04))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                        isSelected ? GrooveOnboardingTheme.blueAccent : Color.white.opacity(0.08),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .scaleEffect(isSelected ? 1.01 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

private struct SubjectConfirmationStrip: View {
    let subjectId: String

    private var label: String {
        switch subjectId {
        case "dog": return "Your pet"
        case "person": return "Your person"
        default: return "Your subject"
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(GrooveOnboardingTheme.blueAccent)

            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.05))
        .clipShape(Capsule())
        .padding(.horizontal, 20)
    }
}
