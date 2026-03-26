import SwiftUI

struct VideoThumbnailCard: View {
    let danceName: String
    let date: Date
    let photoData: Data?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Thumbnail area
                ZStack {
                    if let photoData, let uiImage = UIImage(data: photoData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(9/16, contentMode: .fill)
                            .clipped()
                    } else {
                        Color.bgElevated.opacity(0.6)
                            .aspectRatio(9/16, contentMode: .fill)
                    }

                    // Play icon overlay
                    Circle()
                        .fill(Color.bgElevated.opacity(0.8))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: "play.fill")
                                .font(.caption)
                                .foregroundStyle(Color.accentStart)
                        )
                }
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: Radius.lg,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: Radius.lg
                    )
                )

                // Info area
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(danceName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)

                    Text(date, style: .date)
                        .font(.caption)
                        .foregroundStyle(Color.textTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.sm)
            }
            .background(Color.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

#Preview {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.sm) {
        VideoThumbnailCard(danceName: "Hip Hop", date: .now, photoData: nil, onTap: {})
        VideoThumbnailCard(danceName: "Viral TikTok", date: .now, photoData: nil, onTap: {})
    }
    .padding()
    .background(Color.bgPrimary)
}
