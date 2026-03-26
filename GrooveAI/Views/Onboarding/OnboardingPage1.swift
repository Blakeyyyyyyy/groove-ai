import SwiftUI

struct OnboardingPage1: View {
    let onContinue: () -> Void
    let onSkip: () -> Void

    @State private var showCards = false

    var body: some View {
        VStack(spacing: 0) {
            // Skip button
            HStack {
                Spacer()
                Button("Skip") { onSkip() }
                    .font(.subheadline)
                    .foregroundStyle(Color.textTertiary)
                    .padding(.trailing, Spacing.lg)
                    .padding(.top, Spacing.sm)
            }

            Spacer()

            // Headline + subheadline
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Watch Anyone Dance")
                    .font(.largeTitle.bold())
                    .foregroundStyle(Color.textPrimary)

                Text("Pick a style. Upload a photo. AI does the rest.")
                    .font(.body)
                    .foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.lg)

            Spacer().frame(height: Spacing.xl)

            // 3 Dance style cards
            HStack(spacing: Spacing.sm) {
                cardView(icon: "music.note", title: "Hip Hop", badge: "🔥 Hot", index: 0)
                cardView(icon: "sparkles", title: "Viral TikTok", badge: "✨ Trending", index: 1)
                cardView(icon: "music.note.list", title: "Salsa", badge: nil, index: 2)
            }
            .padding(.horizontal, Spacing.lg)

            Spacer()

            // Page dots
            PageIndicatorDots(count: 3, current: 0)
                .padding(.bottom, Spacing.lg)

            // CTA
            GradientCTAButton("See What's Possible →", action: onContinue)
                .padding(.bottom, Spacing.xxl)
        }
        .background(Color.bgPrimary)
        .onAppear {
            withAnimation(AppAnimation.cardTransition.delay(0.2)) {
                showCards = true
            }
        }
    }

    @ViewBuilder
    private func cardView(icon: String, title: String, badge: String?, index: Int) -> some View {
        VStack(spacing: 0) {
            // Thumbnail area
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: Radius.lg)
                    .fill(Color.bgElevated.opacity(0.6))
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 32))
                            .foregroundStyle(LinearGradient.accent)
                    )

                if let badge {
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
        .offset(y: showCards ? 0 : 20)
        .opacity(showCards ? 1 : 0)
        .animation(
            AppAnimation.cardTransition.delay(Double(index) * 0.08),
            value: showCards
        )
    }
}

#Preview {
    OnboardingPage1(onContinue: {}, onSkip: {})
}
