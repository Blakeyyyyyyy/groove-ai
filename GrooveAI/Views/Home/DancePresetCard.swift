import SwiftUI
import AVFoundation

struct DancePresetCard: View {
    let preset: DancePreset
    @State private var isVisible = false

    private let cornerRadius = Radius.lg

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
            .modifier(HomePresetVisibilityPlayback(isVisible: $isVisible))
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
        if let videoURLString = preset.videoURL, let videoURL = URL(string: videoURLString) {
            let posterURL = preset.posterURL.flatMap { URL(string: $0) }
            // Color.clear anchors the layout size to the proposed space.
            // .overlay constrains LoopingVideoView to that same frame,
            // preventing AsyncImage from reporting its natural image size upward.
            Color.clear.overlay {
                LoopingVideoView(
                    videoURL: videoURL,
                    posterURL: posterURL,
                    isPlaying: $isVisible
                )
            }.clipped()
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
    @Binding var isVisible: Bool

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content
                .onScrollVisibilityChange(threshold: 0.55) { visible in
                    isVisible = visible
                }
                .onDisappear {
                    isVisible = false
                }
        } else {
            content
                .onAppear {
                    isVisible = true
                }
                .onDisappear {
                    isVisible = false
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
