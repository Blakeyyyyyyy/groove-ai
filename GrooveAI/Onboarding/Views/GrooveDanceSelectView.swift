// GrooveDanceSelectView.swift
// PAGE 3 — Hero preview + dance preset selection
// Per spec: NO typewriter, NO "generating...", instant video reveal on tap
// Demo subject image pre-loaded, 3 presets: Big Guy, Boombastic, Cotton Eye Joe

import SwiftUI
import AVKit

struct GrooveDanceSelectView: View {
    @ObservedObject var state: GrooveOnboardingState
    let onNext: () -> Void

    // ── Onboarding presets (3 only) ────────────────────────────────────────────
    private let onboardingPresets: [DancePreset] = {
        let ids = ["big-guy", "boombastic", "cotton-eye-joe"]
        return ids.compactMap { id in DancePreset.allPresets.first(where: { $0.id == id }) }
    }()

    // ── UI state ──────────────────────────────────────────────────────────────
    @State private var selectedDanceId: String? = nil
    @State private var didReveal: Bool = false

    // Video player
    @State private var player: AVPlayer? = nil
    @State private var playerItem: AVPlayerItem? = nil

    var body: some View {
        ZStack {
            GrooveOnboardingTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 40)

                // ── HERO SECTION (top ~55%) ────────────────────────────────────
                ZStack {
                    // Glow halo behind
                    RoundedRectangle(cornerRadius: 32)
                        .fill(GrooveOnboardingTheme.blueAccent.opacity(didReveal ? 0.25 : 0))
                        .blur(radius: 24)
                        .animation(.easeInOut(duration: 0.6), value: didReveal)
                        .frame(width: GrooveOnboardingTheme.heroImageSize.width + 20,
                               height: GrooveOnboardingTheme.heroImageSize.height + 20)

                    // Hero content (image or video)
                    heroContent
                        .frame(width: GrooveOnboardingTheme.heroImageSize.width,
                               height: GrooveOnboardingTheme.heroImageSize.height)
                        .clipShape(RoundedRectangle(cornerRadius: GrooveOnboardingTheme.heroCornerRadius))
                        .shadow(
                            color: didReveal ? GrooveOnboardingTheme.blueAccent.opacity(0.5) : .clear,
                            radius: 20
                        )
                        .scaleEffect(didReveal ? 1.02 : 1.0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: didReveal)
                }
                .frame(width: GrooveOnboardingTheme.heroImageSize.width,
                       height: GrooveOnboardingTheme.heroImageSize.height)
                .padding(.top, GrooveOnboardingTheme.heroImageTopPadding)

                Spacer()

                // ── BOTTOM SECTION ─────────────────────────────────────────────
                if !didReveal {
                    // Pre-reveal: show dance selection
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Now pick a dance")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                            Text("Tap one to see the magic")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.55))
                        }

                        // Dance preset cards — horizontal row
                        HStack(spacing: 12) {
                            ForEach(onboardingPresets) { preset in
                                DancePresetCardView(
                                    preset: preset,
                                    isSelected: selectedDanceId == preset.id
                                ) {
                                    handleDanceTap(preset)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 30)
                    .padding(.bottom, GrooveOnboardingTheme.ctaBottomPadding)
                    .transition(.opacity)

                } else {
                    // Post-reveal: "It's alive!" + CTA
                    VStack(spacing: 20) {
                        VStack(spacing: 6) {
                            Text("🔥 It's alive!")
                                .font(.system(size: 36, weight: .heavy))
                                .foregroundColor(.white)
                            Text("Now make YOUR photos dance.")
                                .font(.system(size: 17))
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }

                        Button(action: onNext) {
                            Text("Start Dancing Free")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: GrooveOnboardingTheme.ctaButtonHeight)
                                .background(GrooveOnboardingTheme.blueAccent)
                                .clipShape(Capsule())
                                .shadow(
                                    color: GrooveOnboardingTheme.blueAccent.opacity(0.4),
                                    radius: 10, y: 5
                                )
                        }
                    }
                    .padding(.horizontal, 30)
                    .padding(.bottom, GrooveOnboardingTheme.ctaBottomPadding)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
        }
        .onDisappear {
            player?.pause()
            NotificationCenter.default.removeObserver(self)
        }
    }

    // ─── Hero content: image or video ─────────────────────────────────────────
    @ViewBuilder
    private var heroContent: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x1C1C2C), Color(hex: 0x0F0F18)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if didReveal, let player = player {
                // Video player
                VideoPlayer(player: player)
                    .aspectRatio(contentMode: .fill)
                    .transition(.opacity.animation(.easeInOut(duration: 0.25)))
            } else {
                // Static subject emoji (placeholder until real assets)
                Text(demoEmoji)
                    .font(.system(size: 120))
            }
        }
    }

    private var demoEmoji: String {
        state.selectedSubjectId == "dog" ? "🐕" : "👩"
    }

    // ─── Demo video URL for (subject, dance) combo ────────────────────────────
    private func demoVideoURL(subjectId: String, danceId: String) -> URL? {
        // Use R2 URL from DancePreset as fallback
        guard let preset = DancePreset.allPresets.first(where: { $0.id == danceId }),
              let urlString = preset.videoURL else {
            return nil
        }
        return URL(string: urlString)
    }

    // ─── Handle dance tap ────────────────────────────────────────────────────
    private func handleDanceTap(_ preset: DancePreset) {
        guard selectedDanceId == nil else { return }  // prevent double-tap
        selectedDanceId = preset.id
        state.selectedDanceId = preset.id
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()

        // Load video from R2
        if let url = demoVideoURL(subjectId: state.selectedSubjectId, danceId: preset.id) {
            let item = AVPlayerItem(url: url)
            playerItem = item
            player = AVPlayer(playerItem: item)
            player?.actionAtItemEnd = .none  // loop

            // Loop video
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: item,
                queue: .main
            ) { _ in
                player?.seek(to: .zero)
                player?.play()
            }
        }

        // Reveal immediately (no generation delay)
        withAnimation(.easeInOut(duration: 0.3)) {
            didReveal = true
        }
        player?.play()

        // Haptic burst for "magic" feel
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }
}

// ─── Dance preset card (per spec) ─────────────────────────────────────────────

private struct DancePresetCardView: View {
    let preset: DancePreset
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                // Badge
                if let badge = preset.badge {
                    Text(badge.rawValue)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(hex: 0xFF6B35))
                        .clipShape(Capsule())
                }

                // Dance name
                Text(preset.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected
                        ? GrooveOnboardingTheme.blueAccent.opacity(0.3)
                        : Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isSelected ? GrooveOnboardingTheme.blueAccent : Color.white.opacity(0.15),
                                lineWidth: isSelected ? 1.5 : 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 0.96 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
    }
}
