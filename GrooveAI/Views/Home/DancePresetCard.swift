import SwiftUI
import AVKit

struct DancePresetCard: View {
    let preset: DancePreset
    @State private var player: AVPlayer?
    @State private var isHovering = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Video or gradient placeholder
            if let videoURL = preset.videoURL, let url = URL(string: videoURL) {
                VideoPlayer(player: player ?? AVPlayer(url: url))
                    .disabled(true)
                    .onAppear {
                        player = AVPlayer(url: url)
                        player?.isMuted = true
                        player?.actionAtItemEnd = .none
                        NotificationCenter.default.addObserver(
                            forName: .AVPlayerItemDidPlayToEndTime,
                            object: player?.currentItem,
                            queue: .main
                        ) { _ in
                            player?.seek(to: .zero)
                            player?.play()
                        }
                        player?.play()
                    }
                    .onDisappear {
                        player?.pause()
                    }
                    .onTapGesture {
                        if player?.rate == 0 {
                            player?.play()
                        } else {
                            player?.pause()
                        }
                    }
                    .overlay {
                        if player == nil || player?.rate == 0 {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                    .clipped()
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

            // Bottom gradient overlay for text readability
            LinearGradient(
                colors: [.clear, .black.opacity(0.7)],
                startPoint: .center,
                endPoint: .bottom
            )

            // Name
            Text(preset.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(10)
        }
        .frame(height: 180)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .overlay(alignment: .topTrailing) {
            if let badge = preset.badge {
                Text(badge.rawValue)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.6))
                    .clipShape(Capsule())
                    .padding(8)
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
