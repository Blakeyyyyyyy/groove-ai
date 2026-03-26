import SwiftUI

struct DancePresetCard: View {
    let preset: DancePreset

    var body: some View {
        VStack(spacing: 0) {
            // Video thumbnail area
            ZStack(alignment: .topLeading) {
                // Dark placeholder with play icon
                ZStack {
                    Color.bgElevated.opacity(0.5)

                    VStack(spacing: Spacing.sm) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(LinearGradient.accent)
                    }

                    // Gradient overlay bottom third
                    VStack {
                        Spacer()
                        LinearGradient(
                            colors: [Color.clear, Color.bgSecondary.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 60)
                    }
                }
                .aspectRatio(16/9, contentMode: .fill)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: Radius.xl,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: Radius.xl
                    )
                )

                // Badge overlay
                if let badge = preset.badge {
                    Text(badge.rawValue)
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .background(LinearGradient.accent)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.full))
                        .padding(Spacing.md)
                }
            }

            // Info area
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(preset.name)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.textPrimary)

                Text(preset.shortDescription)
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.lg)
        }
        .background(Color.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: Radius.xl))
    }
}

#Preview {
    ScrollView {
        VStack(spacing: Spacing.lg) {
            DancePresetCard(preset: DancePreset.allPresets[0])
            DancePresetCard(preset: DancePreset.allPresets[1])
        }
        .padding()
    }
    .background(Color.bgPrimary)
}
