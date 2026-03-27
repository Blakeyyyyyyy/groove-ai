import SwiftUI
import AVKit

// MARK: - Screen 4: Simulated Magic Moment
// 1.5s fake "generating" → pre-rendered video plays full-screen
struct SimulatedResultView: View {
    let subject: OnboardingSubject
    let style: OnboardingDanceStyle?
    let onContinue: () -> Void

    @State private var phase: ResultPhase = .generating
    @State private var progressValue: CGFloat = 0.6
    @State private var showCTA = false
    @State private var player: AVQueuePlayer?
    @State private var looper: AVPlayerLooper?

    enum ResultPhase {
        case generating
        case reveal
    }

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            switch phase {
            case .generating:
                generatingPhase

            case .reveal:
                revealPhase
            }
        }
        .onAppear {
            startSimulation()
        }
        .onDisappear {
            player?.pause()
        }
    }

    // MARK: - Phase 1: Generating (1.5s)
    private var generatingPhase: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            // Progress dots
            PageIndicatorDots(count: 4, current: 3)

            Spacer().frame(height: Spacing.lg)

            // Progress bar fills to 100%
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: Radius.full)
                        .fill(Color.bgElevated)
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: Radius.full)
                        .fill(LinearGradient.accent)
                        .frame(width: geo.size.width * progressValue, height: 6)
                        .animation(.easeInOut(duration: 1.5), value: progressValue)
                }
            }
            .frame(height: 6)
            .padding(.horizontal, Spacing.xxl)

            Spacer().frame(height: Spacing.xl)

            // Bouncing dots
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { i in
                    BouncingDot(delay: Double(i) * 0.15)
                }
            }

            Text("Getting ready…")
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)

            Spacer()
            Spacer()
        }
    }

    // MARK: - Phase 2: Video Reveal
    private var revealPhase: some View {
        ZStack {
            // Full-screen video
            if let player {
                VideoPlayer(player: player)
                    .disabled(true)
                    .ignoresSafeArea()
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                // Fallback gradient
                LinearGradient(
                    colors: [Color.bgSecondary, Color.bgPrimary],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                Image(systemName: "figure.dance")
                    .font(.system(size: 80))
                    .foregroundStyle(LinearGradient.accent)
            }

            // Bottom gradient
            VStack {
                Spacer()
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.5)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 250)
            }
            .ignoresSafeArea()

            // CTA overlay
            VStack {
                Spacer()

                if showCTA {
                    VStack(spacing: Spacing.sm) {
                        GradientCTAButton("Make it with your own photo →", action: onContinue)

                        Text("Tap to continue")
                            .font(.caption)
                            .foregroundStyle(Color.textTertiary)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, Spacing.xxl + 20)
                }
            }
        }
    }

    // MARK: - Simulation Logic

    private func startSimulation() {
        // Preload video immediately
        preloadVideo()

        // Fill progress to 100% over 1.5s
        progressValue = 1.0

        // After 1.5s delay, reveal video
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run {
                withAnimation(.easeIn(duration: 0.4)) {
                    phase = .reveal
                }
                player?.play()

                // Show CTA after 1s of video playback
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) {
                        showCTA = true
                    }
                }
            }
        }
    }

    private func preloadVideo() {
        let videoName: String
        if let style {
            videoName = OnboardingVideoMapper.resultVideoName(subject: subject, style: style)
        } else {
            // Fallback
            videoName = subject.tileVideoName
        }

        guard let url = Bundle.main.url(forResource: videoName, withExtension: "mp4") else { return }

        let item = AVPlayerItem(url: url)
        let queuePlayer = AVQueuePlayer(items: [item])
        queuePlayer.isMuted = true
        let playerLooper = AVPlayerLooper(player: queuePlayer, templateItem: AVPlayerItem(url: url))

        self.player = queuePlayer
        self.looper = playerLooper
        // Don't play yet — wait for reveal
    }
}

// MARK: - Bouncing Dot
private struct BouncingDot: View {
    let delay: Double
    @State private var bounce = false

    var body: some View {
        Circle()
            .fill(Color.textSecondary)
            .frame(width: 8, height: 8)
            .offset(y: bounce ? -8 : 0)
            .animation(
                .easeInOut(duration: 0.4)
                .repeatForever(autoreverses: true)
                .delay(delay),
                value: bounce
            )
            .onAppear { bounce = true }
    }
}

#Preview {
    SimulatedResultView(subject: .pet, style: nil, onContinue: {})
}
