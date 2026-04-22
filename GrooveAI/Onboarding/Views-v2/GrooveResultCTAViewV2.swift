// GrooveResultCTAView.swift
// PAGE 5 — Result screen ("It's alive!")
// Per spec: NO device frame (just content with glow), 60% screen for video,
// no progress dots, large blue glow, continuous video loop

import SwiftUI
import AVKit

struct GrooveResultCTAViewV2: View {
    @ObservedObject var state: GrooveOnboardingState
    let onNext: () -> Void

    @State private var player: AVPlayer?
    @State private var glowScale: CGFloat = 0
    @State private var textAppeared = false
    @State private var ctaAppeared = false

    var body: some View {
        ZStack {
            GrooveOnboardingTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 20)

                // ── Result video (60% of screen, no device frame) ──────────────
                ZStack {
                    // Large blue glow behind video
                    RoundedRectangle(cornerRadius: 24)
                        .fill(GrooveOnboardingTheme.blueAccent.opacity(0.30))
                        .blur(radius: 80)
                        .scaleEffect(glowScale)
                        .animation(.easeOut(duration: 0.6), value: glowScale)

                    // Video content
                    GeometryReader { geo in
                        if let player = player {
                            ControlledVideoView(player: player, gravity: .resizeAspectFill)
                                .frame(width: geo.size.width, height: geo.size.height)
                        } else {
                            // Fallback thumbnail
                            RemoteVideoThumbnail(urlString: videoURL, cornerRadius: 0)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.20), lineWidth: 1.5)
                    )
                    .padding(.horizontal, 16)

                    // Bottom gradient overlay so video blends into background
                    VStack {
                        Spacer()
                        LinearGradient(
                            colors: [Color.clear, GrooveOnboardingTheme.background],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 80)
                        .padding(.horizontal, 16)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)
                .layoutPriority(1)

                // ── Text + CTA (bottom 40%) ────────────────────────────────────
                VStack(spacing: 12) {
                    // Headline
                    Text("🔥 It's alive!")
                        .font(.system(size: 36, weight: .heavy))
                        .tracking(-0.5)
                        .foregroundColor(.white)
                        .opacity(textAppeared ? 1 : 0)
                        .offset(y: textAppeared ? 0 : 8)

                    // Subheadline with bold "YOUR"
                    (Text("Now make ")
                        .foregroundColor(GrooveOnboardingTheme.textSecondary)
                     + Text("YOUR")
                        .foregroundColor(GrooveOnboardingTheme.textSecondary)
                        .fontWeight(.bold)
                     + Text(" photos dance.")
                        .foregroundColor(GrooveOnboardingTheme.textSecondary))
                        .font(.system(size: 17, weight: .regular))
                        .multilineTextAlignment(.center)
                        .opacity(textAppeared ? 1 : 0)
                        .offset(y: textAppeared ? 0 : 8)
                }
                .animation(.easeOut(duration: 0.3).delay(0.2), value: textAppeared)

                Spacer().frame(height: 32)

                // CTA Button
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
                .opacity(ctaAppeared ? 1 : 0)
                .offset(y: ctaAppeared ? 0 : 20)
                .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.35), value: ctaAppeared)

                Spacer().frame(height: GrooveOnboardingTheme.ctaBottomPadding)
            }
        }
        .onAppear {
            setupPlayer()
            // Staggered entrance animations
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                glowScale = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                textAppeared = true
                ctaAppeared = true
            }
            // Success haptic on entry
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        .onDisappear {
            player?.pause()
        }
    }

    private var videoURL: String {
        if let preset = DancePreset.allPresets.first(where: { $0.id == state.selectedDanceId }),
           let url = preset.videoURL {
            return url
        }
        let r2Base = "https://videos.trygrooveai.com/presets"
        return "\(r2Base)/big-guy-V5-AI.mp4"
    }

    private func setupPlayer() {
        guard let url = URL(string: videoURL) else { return }
        let item = AVPlayerItem(url: url)
        let avPlayer = AVPlayer(playerItem: item)
        avPlayer.isMuted = true
        avPlayer.actionAtItemEnd = .none

        // Loop
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { _ in
            avPlayer.seek(to: .zero)
            avPlayer.play()
        }

        player = avPlayer
        avPlayer.play()
    }
}
