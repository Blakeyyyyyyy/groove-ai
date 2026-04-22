import SwiftUI
import AVKit

struct GroovePremiumMagicResultFlowViewV2: View {
    @ObservedObject var state: GrooveOnboardingState
    let onNext: () -> Void

    @State private var progress: Double = 0.02
    @State private var displayPercent: Int = 0
    @State private var statusIndex: Int = 0
    @State private var backgroundScale: CGFloat = 1.08
    @State private var backgroundBlur: CGFloat = 30
    @State private var backgroundDarkness: Double = 0.54
    @State private var loaderOpacity: Double = 1
    @State private var loaderScale: CGFloat = 1
    @State private var loaderOffset: CGFloat = 0
    @State private var resultVisible = false
    @State private var resultTextVisible = false
    @State private var ctaVisible = false
    @State private var player: AVPlayer?
    @State private var progressTimer: Timer?
    @State private var playerEndObserver: NSObjectProtocol?
    @State private var hasStarted = false

    private let loadingStatuses = [
        "Mapping the movement",
        "Shaping the groove",
        "Finishing touches"
    ]

    private let hapticThresholds = [12, 26, 40, 56, 72, 88]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                backgroundLayer(in: geo)

                resultLayer(in: geo)

                loaderLayer(in: geo)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .ignoresSafeArea()
        }
        .onAppear {
            guard !hasStarted else { return }
            hasStarted = true
            setupPlayer()
            startSequence()
        }
        .onDisappear {
            progressTimer?.invalidate()
            progressTimer = nil
            player?.pause()

            if let playerEndObserver {
                NotificationCenter.default.removeObserver(playerEndObserver)
                self.playerEndObserver = nil
            }
        }
    }

    private func backgroundLayer(in geo: GeometryProxy) -> some View {
        ZStack {
            previewArtwork(cornerRadius: 0, blurRadius: 0)
                .frame(width: geo.size.width, height: geo.size.height)
                .scaleEffect(backgroundScale)
                .blur(radius: backgroundBlur)
                .overlay(Color.black.opacity(backgroundDarkness))
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.18),
                            GrooveOnboardingTheme.background.opacity(0.76)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            RadialGradient(
                colors: [
                    GrooveOnboardingTheme.blueAccent.opacity(resultVisible ? 0.12 : 0.22),
                    Color.clear
                ],
                center: .center,
                startRadius: 20,
                endRadius: 280
            )
        }
    }

    private func loaderLayer(in geo: GeometryProxy) -> some View {
        let contentWidth = min(geo.size.width - 56, 340)

        return VStack {
            Spacer(minLength: 0)

            VStack(spacing: 18) {
                timerDial

                Text("\(displayPercent)%")
                    .font(.system(size: 60, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.white)
                    .contentTransition(.numericText())
                    .frame(maxWidth: .infinity)

                VStack(spacing: 8) {
                    Text("Creating your video")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white.opacity(0.94))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .frame(maxWidth: .infinity)

                    Text(loadingStatuses[statusIndex])
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(GrooveOnboardingTheme.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .frame(maxWidth: .infinity)
                        .id(statusIndex)
                        .transition(.opacity)
                }
            }
            .frame(width: contentWidth)
            .multilineTextAlignment(.center)
            .offset(y: loaderOffset)

            Spacer(minLength: 0)
        }
        .frame(width: geo.size.width, height: geo.size.height)
        .padding(.top, max(geo.safeAreaInsets.top, 16))
        .padding(.bottom, max(geo.safeAreaInsets.bottom, 24))
        .opacity(loaderOpacity)
        .scaleEffect(loaderScale)
        .allowsHitTesting(false)
    }

    private func resultLayer(in geo: GeometryProxy) -> some View {
        let cardWidth = min(geo.size.width - 32, 360)
        let textWidth = min(geo.size.width - 56, 320)
        let availableHeight = geo.size.height - geo.safeAreaInsets.top - geo.safeAreaInsets.bottom
        let heroHeight = min(max(availableHeight * 0.43, 330), min(cardWidth * 1.08, 390))
        let topPadding = max(geo.safeAreaInsets.top + 18, 36)
        let bottomPadding = max(geo.safeAreaInsets.bottom + 22, GrooveOnboardingTheme.ctaBottomPadding)

        return VStack(spacing: 0) {
            Spacer().frame(height: topPadding)

            resultHeroCard(height: heroHeight)
                .frame(width: cardWidth, height: heroHeight)
                .opacity(resultVisible ? 1 : 0)
                .scaleEffect(resultVisible ? 1.0 : 0.92)

            Spacer().frame(height: 24)

            VStack(spacing: 12) {
                Text("🔥 It's alive!")
                    .font(.system(size: 36, weight: .heavy))
                    .tracking(-0.5)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity)

                (Text("Now make ")
                    .foregroundColor(GrooveOnboardingTheme.textSecondary)
                 + Text("YOUR")
                    .foregroundColor(GrooveOnboardingTheme.textSecondary)
                    .fontWeight(.bold)
                 + Text(" photos dance.")
                    .foregroundColor(GrooveOnboardingTheme.textSecondary))
                    .font(.system(size: 17, weight: .regular))
                    .multilineTextAlignment(.center)
            }
            .frame(width: textWidth)
            .opacity(resultTextVisible ? 1 : 0)
            .offset(y: resultTextVisible ? 0 : 16)

            Spacer().frame(height: 30)

            Button(action: {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onNext()
            }) {
                Text("Make yours free →")
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
            .opacity(ctaVisible ? 1 : 0)
            .offset(y: ctaVisible ? 0 : 22)

            Spacer(minLength: bottomPadding)
        }
        .frame(width: geo.size.width, height: geo.size.height)
        .opacity(resultVisible ? 1 : 0)
        .offset(y: resultVisible ? 0 : 32)
        .animation(.interpolatingSpring(mass: 1.0, stiffness: 175, damping: 24), value: resultVisible)
        .animation(.easeOut(duration: 0.28), value: resultTextVisible)
        .animation(.interpolatingSpring(mass: 1.0, stiffness: 190, damping: 20), value: ctaVisible)
    }

    private func resultHeroCard(height: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(GrooveOnboardingTheme.blueAccent.opacity(0.30))
                .blur(radius: 74)
                .padding(.horizontal, 18)
                .scaleEffect(resultVisible ? 1.0 : 0.92)

            ZStack {
                previewArtwork(cornerRadius: 28, blurRadius: 0)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if let player {
                    ControlledVideoView(player: player, gravity: .resizeAspectFill)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .opacity(resultVisible ? 1 : 0)
                }

                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.18), GrooveOnboardingTheme.background.opacity(0.72)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.30), radius: 28, y: 16)
        }
        .frame(height: height)
    }

    private var timerDial: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.10), style: StrokeStyle(lineWidth: 10, lineCap: .round))

            Circle()
                .trim(from: 0.02, to: max(progress, 0.04))
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.28),
                            GrooveOnboardingTheme.blueAccent.opacity(0.72),
                            Color(hex: 0x93B7FF),
                            GrooveOnboardingTheme.blueAccent
                        ]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: GrooveOnboardingTheme.blueAccent.opacity(0.30), radius: 14)

            Circle()
                .fill(Color.white)
                .frame(width: 10, height: 10)
                .shadow(color: GrooveOnboardingTheme.blueAccent.opacity(0.45), radius: 10)
                .offset(y: -57)
                .rotationEffect(.degrees(progress * 360))

            Circle()
                .fill(Color.white.opacity(0.05))
                .frame(width: 94, height: 94)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        }
        .frame(width: 124, height: 124)
    }

    @ViewBuilder
    private func previewArtwork(cornerRadius: CGFloat, blurRadius: CGFloat) -> some View {
        Group {
            if let previewImage = state.selectedPreviewImage {
                Image(uiImage: previewImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if let url = state.selectedPreviewURL {
                RemoteVideoThumbnail(urlString: url, cornerRadius: cornerRadius)
            } else {
                LinearGradient(
                    colors: [Color(hex: 0x111723), Color(hex: 0x090B10)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .blur(radius: blurRadius)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private func startSequence() {
        withAnimation(.easeOut(duration: 2.2)) {
            backgroundScale = 1.02
        }

        let impactGenerator = UIImpactFeedbackGenerator(style: .rigid)
        impactGenerator.prepare()

        let startTime = CACurrentMediaTime()
        var lastHapticIndex = -1

        progressTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { timer in
            let elapsed = CACurrentMediaTime() - startTime
            let currentValue = min(progressValue(for: elapsed), 100)
            let wholePercent = min(Int(currentValue.rounded(.down)), 100)

            progress = max(currentValue / 100, 0.02)

            if displayPercent != wholePercent {
                displayPercent = wholePercent
            }

            let newStatusIndex = statusIndex(for: currentValue)
            if newStatusIndex != statusIndex {
                withAnimation(.easeInOut(duration: 0.2)) {
                    statusIndex = newStatusIndex
                }
            }

            if lastHapticIndex + 1 < hapticThresholds.count,
               wholePercent >= hapticThresholds[lastHapticIndex + 1] {
                impactGenerator.impactOccurred(intensity: 0.85)
                impactGenerator.prepare()
                lastHapticIndex += 1
            }

            if elapsed >= 2.0 {
                timer.invalidate()
                progressTimer = nil
                progress = 1.0
                displayPercent = 100
                revealResult()
            }
        }

        if let progressTimer {
            RunLoop.main.add(progressTimer, forMode: .common)
        }
    }

    private func progressValue(for elapsed: Double) -> Double {
        let clamped = min(max(elapsed / 2.0, 0), 1)

        if clamped < 0.45 {
            let t = clamped / 0.45
            let eased = 1 - pow(1 - t, 1.8)
            return 62 * eased
        }

        if clamped < 0.80 {
            let t = (clamped - 0.45) / 0.35
            let eased = t * t * (3 - 2 * t)
            return 62 + (24 * eased)
        }

        let t = (clamped - 0.80) / 0.20
        let eased = 1 - pow(1 - t, 2.3)
        return 86 + (14 * eased)
    }

    private func statusIndex(for value: Double) -> Int {
        switch value {
        case ..<38:
            return 0
        case ..<78:
            return 1
        default:
            return 2
        }
    }

    private func revealResult() {
        player?.seek(to: .zero)
        player?.play()
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        withAnimation(.easeInOut(duration: 0.18)) {
            loaderOpacity = 0
            loaderScale = 0.92
            loaderOffset = -12
            backgroundBlur = 26
            backgroundDarkness = 0.46
        }

        withAnimation(.interpolatingSpring(mass: 1.0, stiffness: 175, damping: 24, initialVelocity: 0)) {
            resultVisible = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
            resultTextVisible = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            ctaVisible = true
        }
    }

    private func setupPlayer() {
        guard let videoURLString = state.selectedVideoURL,
              let videoURL = URL(string: videoURLString) else {
            return
        }

        let item = AVPlayerItem(url: videoURL)
        let avPlayer = AVPlayer(playerItem: item)
        avPlayer.isMuted = true
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
