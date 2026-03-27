import SwiftUI
import AVKit

// MARK: - Screen 1: The Hook
// Full-screen video loop, no text, CTA springs in after 1.5s
struct OnboardingHookView: View {
    let onContinue: () -> Void

    @State private var showCTA = false
    @State private var ctaPulse = false
    @State private var currentVideoIndex = 0
    @State private var opacity1: Double = 1
    @State private var opacity2: Double = 0

    // Two players for crossfade
    @State private var player1: AVQueuePlayer?
    @State private var looper1: AVPlayerLooper?
    @State private var player2: AVQueuePlayer?
    @State private var looper2: AVPlayerLooper?

    private let videoNames = OnboardingVideoMapper.hookVideos
    private let crossfadeInterval: TimeInterval = 3.0

    var body: some View {
        ZStack {
            // Video layer 1
            if let player1 {
                VideoPlayer(player: player1)
                    .disabled(true)
                    .opacity(opacity1)
                    .ignoresSafeArea()
            }

            // Video layer 2
            if let player2 {
                VideoPlayer(player: player2)
                    .disabled(true)
                    .opacity(opacity2)
                    .ignoresSafeArea()
            }

            // Fallback if no videos
            if player1 == nil {
                Color.bgPrimary.ignoresSafeArea()
                Image(systemName: "figure.dance")
                    .font(.system(size: 80))
                    .foregroundStyle(LinearGradient.accent)
            }

            // Bottom gradient for readability
            VStack {
                Spacer()
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.4)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 300)
            }
            .ignoresSafeArea()

            // Overlay content
            VStack {
                // Top-left wordmark
                HStack {
                    Text("Groove AI")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.leading, Spacing.lg)
                        .padding(.top, 60)
                    Spacer()
                }

                Spacer()

                // CTA + dots
                VStack(spacing: Spacing.lg) {
                    if showCTA {
                        GradientCTAButton("Make yours →", action: onContinue)
                            .scaleEffect(ctaPulse ? 1.04 : 1.0)
                            .transition(.scale(scale: 0.5).combined(with: .opacity))
                    }

                    PageIndicatorDots(count: 4, current: 0)
                }
                .padding(.bottom, Spacing.xxl + 20)
            }
        }
        .onAppear {
            setupVideos()
            startCrossfadeTimer()

            // CTA springs in after 1.5s
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) {
                    showCTA = true
                }
                // Start pulse after spring settles
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    withAnimation(
                        .easeInOut(duration: 0.6)
                        .repeatForever(autoreverses: true)
                        .delay(4.0)
                    ) {
                        ctaPulse = true
                    }
                }
            }
        }
        .onDisappear {
            player1?.pause()
            player2?.pause()
        }
    }

    private func setupVideos() {
        guard let url = videoURL(for: videoNames[0]) else { return }

        let item1 = AVPlayerItem(url: url)
        let queuePlayer1 = AVQueuePlayer(items: [item1])
        queuePlayer1.isMuted = true
        let loop1 = AVPlayerLooper(player: queuePlayer1, templateItem: AVPlayerItem(url: url))
        self.player1 = queuePlayer1
        self.looper1 = loop1
        queuePlayer1.play()
    }

    private func startCrossfadeTimer() {
        Timer.scheduledTimer(withTimeInterval: crossfadeInterval, repeats: true) { _ in
            Task { @MainActor in
                crossfadeToNext()
            }
        }
    }

    private func crossfadeToNext() {
        currentVideoIndex = (currentVideoIndex + 1) % videoNames.count
        let nextName = videoNames[currentVideoIndex]
        guard let url = videoURL(for: nextName) else { return }

        // Determine which layer is currently visible
        let isLayer1Active = opacity1 > 0.5

        if isLayer1Active {
            // Load into player2, fade to it
            let item = AVPlayerItem(url: url)
            let queuePlayer = AVQueuePlayer(items: [item])
            queuePlayer.isMuted = true
            let loop = AVPlayerLooper(player: queuePlayer, templateItem: AVPlayerItem(url: url))
            player2 = queuePlayer
            looper2 = loop
            queuePlayer.play()

            withAnimation(.easeInOut(duration: 0.3)) {
                opacity1 = 0
                opacity2 = 1
            }
            // Pause old player after fade
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                player1?.pause()
            }
        } else {
            // Load into player1, fade to it
            let item = AVPlayerItem(url: url)
            let queuePlayer = AVQueuePlayer(items: [item])
            queuePlayer.isMuted = true
            let loop = AVPlayerLooper(player: queuePlayer, templateItem: AVPlayerItem(url: url))
            player1 = queuePlayer
            looper1 = loop
            queuePlayer.play()

            withAnimation(.easeInOut(duration: 0.3)) {
                opacity1 = 1
                opacity2 = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                player2?.pause()
            }
        }
    }

    private func videoURL(for name: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: "mp4")
    }
}

#Preview {
    OnboardingHookView(onContinue: {})
}
