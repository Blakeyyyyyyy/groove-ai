// GroovePremiumMagicResultFlowView.swift
// PAGE 4 (premium flag) — Combined Loading + Reveal in one view

import SwiftUI
import AVKit
import StoreKit

struct GroovePremiumMagicResultFlowView: View {
    @ObservedObject var state: GrooveOnboardingState
    let onNext: () -> Void

    @State private var progress: Double = 0.02
    @State private var displayPercent: Int = 0
    @State private var statusIndex: Int = 0
    @State private var loaderOpacity: Double = 1
    @State private var loaderScale: CGFloat = 1

    @State private var loadingComplete = false
    @State private var headlineVisible = false
    @State private var sublineVisible = false
    @State private var primaryCTAVisible = false

    @State private var player: AVPlayer?
    @State private var playerEndObserver: NSObjectProtocol?
    @State private var hasStarted = false
    @State private var showReviewPrompt = false

    private let statusMessages = [
        "Preparing your result",
        "Almost there",
        "Your result is ready"
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                backgroundLayer

                if !loadingComplete {
                    loadingLayer(in: geo)
                        .opacity(loaderOpacity)
                        .scaleEffect(loaderScale)
                } else {
                    revealLayer(in: geo)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .ignoresSafeArea()
        }
        .alert("Enjoying Groove AI so far?", isPresented: $showReviewPrompt) {
            Button("Love it! ⭐") {
                if let scene = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene })
                    .first {
                    SKStoreReviewController.requestReview(in: scene)
                }
            }
            Button("Not yet", role: .cancel) { }
        }
        .onAppear {
            guard !hasStarted else { return }
            hasStarted = true
            setupPlayer()
            startLoadingSequence()
        }
        .onDisappear {
            player?.pause()
            if let playerEndObserver {
                NotificationCenter.default.removeObserver(playerEndObserver)
                self.playerEndObserver = nil
            }
        }
    }

    private var backgroundLayer: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if !loadingComplete {
                RadialGradient(
                    colors: [
                        GrooveOnboardingTheme.blueAccent.opacity(0.14),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 20,
                    endRadius: 280
                )
            }
        }
    }

    private func loadingLayer(in geo: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            Spacer()

            progressRing

            Spacer().frame(height: 20)

            Text("\(displayPercent)%")
                .font(.system(size: 62, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.white)
                .contentTransition(.numericText())

            Spacer().frame(height: 40)

            VStack(spacing: 8) {
                Text("Creating your video")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.94))

                Text(statusMessages[statusIndex])
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(GrooveOnboardingTheme.textSecondary)
                    .id(statusIndex)
                    .transition(.opacity)
            }

            Spacer()
        }
        .frame(width: geo.size.width, height: geo.size.height)
    }

    private var progressRing: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.10), style: StrokeStyle(lineWidth: 6, lineCap: .round))

            Circle()
                .trim(from: 0, to: max(CGFloat(progress), 0.02))
                .stroke(
                    GrooveOnboardingTheme.blueAccent,
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 124, height: 124)
    }

    private func revealLayer(in geo: GeometryProxy) -> some View {
        let containerWidth = min(geo.size.width - 34, 350)
        let containerHeight = min(geo.size.height * 0.62, 560)
        let topPadding = max(geo.safeAreaInsets.top + 4, 16)

        return VStack(spacing: 0) {
            Spacer().frame(height: topPadding)

            ZStack {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(Color.white.opacity(0.03))

                if let player {
                    ControlledVideoView(player: player, gravity: .resizeAspectFill)
                        .frame(width: containerWidth - 12, height: containerHeight - 12)
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                }
            }
            .frame(width: containerWidth, height: containerHeight)
            .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.32), radius: 24, y: 14)

            Spacer().frame(height: 28)

            VStack(spacing: 12) {
                Text("🎉 It's alive!")
                    .font(.system(size: 38, weight: .heavy))
                    .tracking(-0.5)
                    .foregroundColor(.white)
                    .opacity(headlineVisible ? 1 : 0)
                    .offset(y: headlineVisible ? 0 : 12)

                (Text("Now make ")
                    .foregroundColor(GrooveOnboardingTheme.textSecondary)
                 + Text("YOUR")
                    .foregroundColor(GrooveOnboardingTheme.textSecondary)
                    .fontWeight(.bold)
                 + Text(" photos dance")
                    .foregroundColor(GrooveOnboardingTheme.textSecondary))
                    .font(.system(size: 19, weight: .regular))
                    .multilineTextAlignment(.center)
                    .opacity(sublineVisible ? 1 : 0)
                    .offset(y: sublineVisible ? 0 : 8)
            }
            .padding(.horizontal, 28)

            Spacer(minLength: 0)
        }
        .safeAreaInset(edge: .bottom) {
            Button(action: {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onNext()
            }) {
                Text("Try yours →")
                    .font(.system(size: GrooveOnboardingTheme.ctaFontSize, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: GrooveOnboardingTheme.ctaButtonHeight)
                    .background(GrooveOnboardingTheme.blueAccent)
                    .clipShape(Capsule())
                    .shadow(color: GrooveOnboardingTheme.ctaShadow, radius: 12, y: 4)
            }
            .buttonStyle(CTAPressStyle())
            .padding(.horizontal, GrooveOnboardingTheme.ctaHorizontalPadding)
            .padding(.bottom, 8)
            .opacity(primaryCTAVisible ? 1 : 0)
            .offset(y: primaryCTAVisible ? 0 : 16)
        }
    }

    private func startLoadingSequence() {
        let totalDuration: Double = 3.5
        let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
        impactGenerator.prepare()

        let startTime = CACurrentMediaTime()
        // Evenly-spaced haptic ticks at 20/40/60/80/100% with increasing intensity
        let hapticThresholds: [Int] = [20, 40, 60, 80, 100]
        let hapticIntensities: [CGFloat] = [0.4, 0.6, 0.7, 0.85, 1.0]
        var lastHapticIndex = -1

        let progressTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { timer in
            let elapsed = CACurrentMediaTime() - startTime
            let t = min(max(elapsed / totalDuration, 0), 1)

            // Single smooth ease curve: progress = sin(t * π/2)
            // Natural slow-start, fast-middle, slow-finish feel.
            let eased = sin(t * .pi / 2)
            let currentValue = eased * 100

            let wholePercent = min(Int(currentValue.rounded(.down)), 100)
            progress = max(currentValue / 100, 0.02)

            if displayPercent != wholePercent {
                displayPercent = wholePercent
            }

            // Status messages transition at 33% and 66%
            let newStatusIndex: Int
            switch currentValue {
            case ..<33: newStatusIndex = 0
            case ..<66: newStatusIndex = 1
            default: newStatusIndex = 2
            }
            if newStatusIndex != statusIndex {
                withAnimation(.easeInOut(duration: 0.2)) {
                    statusIndex = newStatusIndex
                }
            }

            if lastHapticIndex + 1 < hapticThresholds.count,
               wholePercent >= hapticThresholds[lastHapticIndex + 1] {
                let nextIndex = lastHapticIndex + 1
                impactGenerator.impactOccurred(intensity: hapticIntensities[nextIndex])
                impactGenerator.prepare()
                lastHapticIndex = nextIndex
            }

            if elapsed >= totalDuration {
                timer.invalidate()
                progress = 1.0
                displayPercent = 100
                transitionToReveal()
            }
        }
        RunLoop.main.add(progressTimer, forMode: .common)
    }

    private func transitionToReveal() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        withAnimation(.easeInOut(duration: 0.25)) {
            loaderOpacity = 0
            loaderScale = 0.92
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.75)) {
                loadingComplete = true
            }
            revealContent()
        }
    }

    private func revealContent() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        player?.seek(to: .zero)
        player?.play()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 0.3)) {
                headlineVisible = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeOut(duration: 0.3)) {
                sublineVisible = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeOut(duration: 0.3)) {
                primaryCTAVisible = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            showReviewPrompt = true
        }
    }

    // MARK: - Demo Video Logic

    // Bundled demo videos: subject → danceId → bundle resource name
    private static let bundledDogDemos: [String: String] = [
        "big-guy":      "demo_dog_big_guy",
        "coco-channel": "demo_dog_coco",
        "c-walk":       "demo_dog_cwalk",
    ]
    private static let bundledWomanDemos: [String: String] = [
        "big-guy":      "demo_woman_big_guy",
        "coco-channel": "demo_woman_coco",
        "c-walk":       "demo_woman_cwalk",
    ]

    private func getRevealVideoURL() -> URL? {
        let danceId = state.selectedDanceId

        if state.selectedSubjectId == "dog" {
            if let name = Self.bundledDogDemos[danceId],
               let url = Bundle.main.url(forResource: name, withExtension: "mp4") {
                return url
            }
        } else if state.selectedSubjectId == "person" {
            if let name = Self.bundledWomanDemos[danceId],
               let url = Bundle.main.url(forResource: name, withExtension: "mp4") {
                return url
            }
        }

        // Fallback: generated video URL from state
        if let urlString = state.selectedVideoURL, let url = URL(string: urlString) {
            return url
        }
        return nil
    }

    private func setupPlayer() {
        guard let videoURL = getRevealVideoURL() else { return }

        let item = AVPlayerItem(url: videoURL)
        let avPlayer = AVPlayer(playerItem: item)
        avPlayer.isMuted = false
        avPlayer.actionAtItemEnd = .none
        avPlayer.pause()

        playerEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { _ in
            avPlayer.seek(to: .zero)
            avPlayer.play()
        }

        player = avPlayer
    }
}
