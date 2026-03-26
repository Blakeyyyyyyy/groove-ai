import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let headline: String
    let bodyText: String
    let ctaLabel: String
    let ctaAction: () -> Void

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundStyle(Color.textTertiary)

            Text(headline)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(.center)

            Text(bodyText)
                .font(.body)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            GradientCTAButton(ctaLabel, action: ctaAction)
        }
        .padding(Spacing.xxxl)
    }
}

#Preview {
    EmptyStateView(
        icon: "film.stack",
        headline: "Your videos will live here",
        bodyText: "Pick a dance style, upload a photo, and make someone dance. Your creations show up here.",
        ctaLabel: "Browse Dance Styles →",
        ctaAction: {}
    )
    .background(Color.bgPrimary)
}
