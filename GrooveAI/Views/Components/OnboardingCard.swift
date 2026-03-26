import SwiftUI

struct OnboardingCard: View {
    let iconName: String
    let title: String
    let badge: String?

    var body: some View {
        VStack(spacing: 0) {
            // Thumbnail area
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: Radius.lg)
                    .fill(Color.bgElevated.opacity(0.6))
                    .overlay(
                        Image(systemName: iconName)
                            .font(.system(size: 32))
                            .foregroundStyle(LinearGradient.accent)
                    )

                if let badge = badge {
                    Text(badge)
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .background(LinearGradient.accent)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.full))
                        .padding(Spacing.sm)
                }
            }
            .aspectRatio(0.75, contentMode: .fit)

            // Title
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.md)
        }
        .background(Color.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: Radius.xl))
    }
}

#Preview {
    HStack(spacing: Spacing.sm) {
        OnboardingCard(iconName: "music.note", title: "Hip Hop", badge: "🔥 Hot")
        OnboardingCard(iconName: "sparkles", title: "Viral TikTok", badge: "✨ Trending")
        OnboardingCard(iconName: "music.note.list", title: "Salsa", badge: nil)
    }
    .padding()
    .background(Color.bgPrimary)
}
