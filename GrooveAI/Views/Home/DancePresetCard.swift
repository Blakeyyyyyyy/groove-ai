import SwiftUI

struct DancePresetCard: View {
    let preset: DancePreset
    
    private var thumbnailVideoURL: URL? {
        guard let urlString = preset.thumbnailURL else { return nil }
        return URL(string: urlString)
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Thumbnail video or gradient placeholder
            if let videoURL = thumbnailVideoURL {
                LoopingVideoView(url: videoURL, gravity: .resizeAspectFill)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md))
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
