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

    @State private var selectedIndex: Int = 1
    @State private var contentAppeared = false
    @State private var tapped = false
    @State private var showTapHint = false
    @State private var scrollPositionId: String? = nil

    var body: some View {
        GeometryReader { geo in
            ZStack {
                GrooveOnboardingTheme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer().frame(height: 96)

                    // Header + subtitle
                    VStack(spacing: 8) {
                        Text("Now pick a dance")
                            .font(.system(size: 32, weight: .bold))
                            .tracking(-0.5)
                            .foregroundColor(.white)

                        Text("Tap a dance to make your image Groove.")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(GrooveOnboardingTheme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 24)
                    .opacity(contentAppeared ? 1 : 0)

                    Spacer().frame(height: 20)

                    // Peeking horizontal carousel
                    danceCardSlider(in: geo)
                        .opacity(contentAppeared ? 1 : 0)
                        .offset(y: contentAppeared ? 0 : 12)

                    Spacer().frame(height: 16)

                    // Floating hint text (above subject image)
                    DanceTapHintView()
                        .opacity(showTapHint ? 1 : 0)
                        .animation(.easeInOut(duration: 0.35), value: showTapHint)

                    // Subject thumbnail strip (below hint text)
                    subjectThumbnailStrip
                        .opacity(contentAppeared ? 1 : 0)
                        .padding(.top, 12)

                    Spacer(minLength: 0)

                    // Continue button
                    Button(action: handleContinue) {
                        Text("See the dance →")
                            .font(.system(size: GrooveOnboardingTheme.ctaFontSize, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: GrooveOnboardingTheme.ctaButtonHeight)
                            .background(GrooveOnboardingTheme.blueAccent)
                            .clipShape(Capsule())
                            .shadow(color: GrooveOnboardingTheme.ctaShadow, radius: 12, y: 4)
                    }
                    .buttonStyle(DanceCTAPressStyle())
                    .padding(.horizontal, GrooveOnboardingTheme.ctaHorizontalPadding)
                    .opacity(contentAppeared ? 1 : 0)
                    .offset(y: contentAppeared ? 0 : 18)

                    Spacer().frame(height: GrooveOnboardingTheme.ctaBottomPadding)
                }
            }
        }
        .onAppear {
            MetaTracker.danceSelected()
            // Start centred on coco-channel (middle card, index 1)
            selectedIndex = 1
            if state.selectedDanceId.isEmpty {
                state.selectedDanceId = onboardingDanceOptions[1].id
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
    private func danceCardSlider(in geo: GeometryProxy) -> some View {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        let cardWidth = screenWidth * 0.72 - 35
        let cardHeight = screenHeight * 0.46
        let horizontalMargin = screenWidth * 0.14

        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(Array(onboardingDanceOptions.enumerated()), id: \.element.id) { index, option in
                        DanceSliderCard(
                            option: option,
                            isSelected: selectedIndex == index
                        )
                        .frame(width: cardWidth, height: cardHeight)
                        .id(option.id)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedIndex = index
                            }
                            proxy.scrollTo(option.id, anchor: .center)
                        }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollPosition(id: $scrollPositionId)
            .contentMargins(.horizontal, horizontalMargin, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .frame(height: cardHeight)
            .onChange(of: scrollPositionId) { _, newId in
                if let newId, let idx = onboardingDanceOptions.firstIndex(where: { $0.id == newId }) {
                    selectedIndex = idx
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    proxy.scrollTo("coco-channel", anchor: .center)
                }
            }
        }
    }

    private var subjectThumbnailStrip: some View {
        VStack(spacing: 6) {
            if let previewImage = resolvedSubjectImage {
                Image(uiImage: previewImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(GrooveOnboardingTheme.surfaceL1)
                    .frame(width: 96, height: 96)
            }

            Text("Your subject")
                .font(.caption)
                .foregroundColor(GrooveOnboardingTheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func handleContinue() {
        let option = onboardingDanceOptions[selectedIndex]
        state.selectedDanceId = option.id
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        onNext()
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
            Text("Choose a dance to continue")
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

private struct DanceSliderCard: View {
    let option: OnboardingDanceOption
    let isSelected: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Video (or fallback) fills the card
            Group {
                if let url = option.videoURL {
                    LoopingVideoView(url: url, gravity: .resizeAspectFill, isMuted: true)
                } else {
                    GrooveOnboardingTheme.surfaceL1
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

            // Dark gradient at bottom behind label
            VStack {
                Spacer()
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.55)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 90)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .allowsHitTesting(false)

            // Dance label overlay at bottom
            VStack {
                Spacer()
                HStack {
                    Text(option.label)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 16)
            }
            .allowsHitTesting(false)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    isSelected ? GrooveOnboardingTheme.blueAccent : Color.white.opacity(0.10),
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .shadow(color: Color.black.opacity(0.25), radius: 18, y: 10)
    }
}

private struct DanceCTAPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
