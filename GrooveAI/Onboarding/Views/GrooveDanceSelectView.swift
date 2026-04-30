import SwiftUI


private struct OnboardingDanceOption: Identifiable {
    let id: String
    let label: String
    let bundleVideo: String  // bundle resource name (without extension)

    var videoURL: URL? {
        Bundle.main.url(forResource: bundleVideo, withExtension: "mp4")
    }
}

private let onboardingDanceOptions: [OnboardingDanceOption] = [
    OnboardingDanceOption(id: "big-guy", label: "Big Guy Dance", bundleVideo: "onb_big_guy"),
    OnboardingDanceOption(id: "coco-channel", label: "Coco Channel", bundleVideo: "onb_coco_channel"),
    OnboardingDanceOption(id: "c-walk", label: "C Walk", bundleVideo: "onb_c_walk"),
]

struct GrooveDanceSelectView: View {
    @ObservedObject var state: GrooveOnboardingState
    let onNext: () -> Void

    @State private var selectedIndex: Int = 0
    @State private var hasSelected = false
    @State private var contentAppeared = false
    @State private var tapped = false
    @State private var showTapHint = false

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

                    DanceTapHintView()
                        .opacity(showTapHint && !tapped ? 1 : 0)
                        .animation(.easeInOut(duration: 0.35), value: tapped)
                        .padding(.top, 16)

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
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeIn(duration: 0.3)) {
                    showTapHint = true
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

        tapped = true
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
            return UIImage(named: "subject-pet")
        default:
            return UIImage(named: "subject-person")
        }
    }
}

private struct DanceTapHintView: View {
    @State private var pulseOpacity: Double = 0.4

    var body: some View {
        HStack(spacing: 6) {
            Text("👆")
                .font(.system(size: 18))
            Text("Tap a dance to continue")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
        .opacity(pulseOpacity)
        .onAppear {
            withAnimation(
                .easeInOut(duration: 0.9)
                    .repeatForever(autoreverses: true)
            ) {
                pulseOpacity = 1.0
            }
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
                    if let url = option.videoURL {
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
