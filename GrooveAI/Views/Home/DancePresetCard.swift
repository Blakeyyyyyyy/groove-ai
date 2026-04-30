import SwiftUI
import AVFoundation

struct DancePresetCard: View {
    let preset: DancePreset
    @Environment(\.playerPool) private var pool
    @State private var isVisibleForPlayback = false
    @State private var lease: LeaseToken? = nil
    @State private var activePlayer: AVQueuePlayer? = nil

    private let cornerRadius = Radius.lg

    private var videoURL: URL? {
        guard let s = preset.videoURL else { return nil }
        return URL(string: s)
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
            .onChange(of: isVisibleForPlayback) { _, isVisible in
                if isVisible {
                    acquireIfNeeded()
                }
                // On visibility false: don't release — just pause via isPlaying binding.
                // Releasing here causes the placeholder gate to flash gradient mid-scroll.
                // Only fully release when the card leaves the view hierarchy (onDisappear).
            }
            .onDisappear {
                releaseIfHeld()
            }
    }

    private func acquireIfNeeded() {
        // If we hold a lease but the pool evicted our slot, clear stale state first.
        if let existingLease = lease, !pool.isValid(existingLease) {
            lease = nil
            activePlayer = nil
        }
        guard lease == nil, let url = videoURL else { return }
        let (player, token) = pool.acquire(url: url)
        activePlayer = player
        lease = token
    }

    private func releaseIfHeld() {
        guard let token = lease else { return }
        pool.release(token: token)
        lease = nil
        activePlayer = nil
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
        // Gate: only mount LoopingVideoView once the pool has assigned a player.
        // Mounting with pooledPlayer=nil lets LoopingPlayerUIView create its own
        // AVQueuePlayer — defeating the pool and causing the original lag.
        if let url = videoURL, let player = activePlayer, lease != nil {
            LoopingVideoView(
                url: url,
                gravity: .resizeAspectFill,
                isMuted: true,
                isPlaying: isVisibleForPlayback,  // pause (show last frame) when scrolled past
                pooledPlayer: player
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
