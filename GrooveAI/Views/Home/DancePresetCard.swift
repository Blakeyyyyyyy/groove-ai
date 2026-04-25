import SwiftUI
import AVFoundation

struct DancePresetCard: View {
    let preset: DancePreset
    @State private var isVisibleForPlayback = false
    @State private var pooledPlayer: AVQueuePlayer? = nil
    @StateObject private var playerPool = AVPlayerPoolManager.shared

    private let cornerRadius = Radius.lg

    private var videoURL: URL? {
        guard let videoURL = preset.videoURL else { return nil }
        return URL(string: videoURL)
    }

    var body: some View {
        cardContent
            .aspectRatio(9 / 16, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(alignment: .topTrailing) {
                if let badge = preset.badge {
                    Text(badge.rawValue)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.6))
                        .clipShape(Capsule())
                        .padding(10)
                }
            }
            .modifier(HomePresetVisibilityPlayback(isVisibleForPlayback: $isVisibleForPlayback))
            .onAppear {
                if videoURL != nil && pooledPlayer == nil {
                    pooledPlayer = playerPool.getPlayer()
                }
                if let videoURL {
                    VideoPreloader.shared.preload(url: videoURL)
                }
            }
            .onDisappear {
                pooledPlayer?.pause()
                pooledPlayer = nil
            }
    }

    private var cardContent: some View {
        ZStack(alignment: .bottomLeading) {
            mediaContent

            LinearGradient(
                colors: [.clear, .black.opacity(0.78)],
                startPoint: .center,
                endPoint: .bottom
            )

            Text(preset.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .padding(10)
        }
        .background(
            LinearGradient(
                colors: [preset.placeholderGradientTop, preset.placeholderGradientBottom],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    @ViewBuilder
    private var mediaContent: some View {
        if let videoURL {
            LoopingVideoView(
                url: videoURL,
                gravity: .resizeAspectFill,
                isMuted: true,
                isPlaying: isVisibleForPlayback,
                pooledPlayer: pooledPlayer  // Fix 1: pass pooled player
            )
        } else {
            LinearGradient(
                colors: [preset.placeholderGradientTop, preset.placeholderGradientBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .overlay {
                Image(systemName: "figure.dance")
                    .font(.system(size: 32))
                    .foregroundStyle(.white.opacity(0.15))
            }
        }
    }
}

private struct HomePresetVisibilityPlayback: ViewModifier {
    @Binding var isVisibleForPlayback: Bool

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content
                .onScrollVisibilityChange(threshold: 0.55) { isVisible in
                    isVisibleForPlayback = isVisible
                }
                .onDisappear {
                    isVisibleForPlayback = false
                }
        } else {
            content
                .onAppear {
                    isVisibleForPlayback = true
                }
                .onDisappear {
                    isVisibleForPlayback = false
                }
        }
    }
}

#Preview {
    HStack(spacing: 12) {
        DancePresetCard(preset: DancePreset.allPresets[0])
            .frame(width: 150)
        DancePresetCard(preset: DancePreset.allPresets[1])
            .frame(width: 150)
    }
    .padding()
    .background(Color.bgPrimary)
}
