import SwiftUI

private enum DanceSubjectImageLoader {
    private static let workspaceRoot = "/Users/blakeyyyclaw/.openclaw/workspace/groove-ai"

    static func load(_ name: String, fallbackPaths: [String]) -> UIImage? {
        if let image = UIImage(named: name) {
            return image
        }

        for path in ([name] + fallbackPaths) {
            let absolutePath = path.hasPrefix("/") ? path : "\(workspaceRoot)/\(path)"
            if let image = UIImage(contentsOfFile: absolutePath) {
                return image
            }
        }

        return nil
    }
}

private struct OnboardingDanceOption: Identifiable {
    let id: String
    let label: String
    let videoURL: String
}

private let r2Base = "https://videos.trygrooveai.com/presets"

private let onboardingDanceOptions: [OnboardingDanceOption] = [
    OnboardingDanceOption(id: "big-guy", label: "Big Guy Dance", videoURL: "\(r2Base)/big-guy-V5-AI.mp4"),
    OnboardingDanceOption(id: "coco-channel", label: "Coco Channel", videoURL: "\(r2Base)/coco-channel-75fcae6c.mp4"),
    OnboardingDanceOption(id: "c-walk", label: "C Walk", videoURL: "\(r2Base)/c-walk-V5-AI.mp4")
]

struct GrooveDanceSelectView: View {
    @ObservedObject var state: GrooveOnboardingState
    let onNext: () -> Void

    @State private var selectedIndex: Int = 0
    @State private var hasSelected = false
    @State private var contentAppeared = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                GrooveOnboardingTheme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer().frame(height: 96)

                    VStack(spacing: 8) {
                        Text("Now pick a dance")
                            .font(.system(size: 32, weight: .bold))
                            .tracking(-0.5)
                            .foregroundColor(.white)

                        Text("Tap any dance below to watch it in motion")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(GrooveOnboardingTheme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 24)
                    .opacity(contentAppeared ? 1 : 0)

                    Spacer().frame(height: 18)

                    dancePreviewPane(in: geo)
                        .opacity(contentAppeared ? 1 : 0)
                        .offset(y: contentAppeared ? 0 : 12)

                    Spacer().frame(height: 20)

                    danceOptionsSection
                        .opacity(contentAppeared ? 1 : 0)
                        .offset(y: contentAppeared ? 0 : 18)

                    Spacer()
                }
            }
        }
        .onAppear {
            if state.selectedDanceId.isEmpty {
                state.selectedDanceId = onboardingDanceOptions[0].id
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                    contentAppeared = true
                }
            }
        }
    }

    @ViewBuilder
    private func dancePreviewPane(in geo: GeometryProxy) -> some View {
        let previewHeight = min(geo.size.height * 0.42, 360)

        ZStack {
            if let previewImage = resolvedSubjectImage {
                Image(uiImage: previewImage)
                    .resizable()
                    .scaledToFill()
            } else {
                GrooveOnboardingTheme.surfaceL1
            }

            LinearGradient(
                colors: [
                    Color.clear,
                    GrooveOnboardingTheme.background.opacity(0.12),
                    GrooveOnboardingTheme.background.opacity(0.45)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .frame(maxWidth: .infinity)
        .frame(height: previewHeight)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.22), radius: 22, y: 12)
        .padding(.horizontal, 24)
    }

    private var danceOptionsSection: some View {
        HStack(spacing: 12) {
            ForEach(Array(onboardingDanceOptions.enumerated()), id: \.element.id) { index, option in
                DanceLoopCard(
                    option: option,
                    isSelected: selectedIndex == index,
                    showPopularBadge: index == 0
                ) {
                    handleDanceTap(index: index, option: option)
                }
            }
        }
        .padding(.horizontal, 24)
    }

    private func handleDanceTap(index: Int, option: OnboardingDanceOption) {
        guard !hasSelected else { return }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.74)) {
            selectedIndex = index
        }

        state.selectedDanceId = option.id
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()

        hasSelected = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            onNext()
        }
    }

    private var resolvedSubjectImage: UIImage? {
        if let selectedPreviewImage = state.selectedPreviewImage {
            return selectedPreviewImage
        }

        switch state.selectedSubjectId {
        case "dog":
            return DanceSubjectImageLoader.load(
                "Gemini_Generated_Image_1555co1555co1555.png",
                fallbackPaths: [
                    "GrooveAI/Assets.xcassets/subject-pet.imageset/subject-pet.png"
                ]
            )
        default:
            return DanceSubjectImageLoader.load(
                "06183b6c390a4741f1cdfa11a3f06e82.jpg",
                fallbackPaths: [
                    "GrooveAI/Assets.xcassets/subject-person.imageset/subject-person.jpg"
                ]
            )
        }
    }
}

private struct DanceLoopCard: View {
    let option: OnboardingDanceOption
    let isSelected: Bool
    let showPopularBadge: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 10) {
                ZStack(alignment: .topLeading) {
                    if let url = URL(string: option.videoURL) {
                        LoopingVideoView(url: url, gravity: .resizeAspectFill, isMuted: true)
                            .frame(maxWidth: .infinity)
                            .frame(height: 168)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    } else {
                        GrooveOnboardingTheme.surfaceL1
                            .frame(maxWidth: .infinity)
                            .frame(height: 168)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }

                    if showPopularBadge {
                        Text("🔥 Popular")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(GrooveOnboardingTheme.badgeTrending)
                            .clipShape(Capsule())
                            .padding(8)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(isSelected ? GrooveOnboardingTheme.blueAccent : Color.white.opacity(0.08), lineWidth: isSelected ? 2 : 1)
                )

                Text(option.label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
    }
}
