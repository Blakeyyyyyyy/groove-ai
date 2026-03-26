import SwiftUI

struct OnboardingPage2: View {
    let onContinue: () -> Void
    let onSkip: () -> Void

    @State private var showCards = false
    @State private var arrowBounce = false
    @State private var glowPulse = false

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
                Text("Any Photo. Any Dance.")
                    .font(.largeTitle.bold())
                    .foregroundStyle(Color.textPrimary)

                Text("Takes seconds. Looks unreal.")
                    .font(.body)
                    .foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.lg)

            Spacer().frame(height: Spacing.xl)

            // Before / After cards
            HStack(spacing: Spacing.lg) {
                // Before card
                VStack(spacing: Spacing.sm) {
                    ZStack {
                        RoundedRectangle(cornerRadius: Radius.xl)
                            .fill(Color.bgElevated.opacity(0.6))
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 40))
                                    .foregroundStyle(Color.textSecondary)
                            )
                    }
                    .aspectRatio(0.65, contentMode: .fit)
                    .background(Color.bgSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.xl))

                    Text("Before")
                        .font(.caption)
                        .foregroundStyle(Color.textTertiary)
                }
                .offset(y: showCards ? 0 : 20)
                .opacity(showCards ? 1 : 0)

                // Arrow
                Image(systemName: "arrow.right")
                    .font(.title2.bold())
                    .foregroundStyle(Color.accentStart)
                    .offset(x: arrowBounce ? 8 : 0)
                    .animation(
                        Animation.spring(response: 0.4, dampingFraction: 0.5)
                            .repeatForever(autoreverses: true)
                            .speed(0.5),
                        value: arrowBounce
                    )

                // After card
                VStack(spacing: Spacing.sm) {
                    ZStack {
                        RoundedRectangle(cornerRadius: Radius.xl)
                            .fill(Color.bgElevated.opacity(0.6))
                            .overlay(
                                Image(systemName: "figure.dance")
                                    .font(.system(size: 40))
                                    .foregroundStyle(LinearGradient.accent)
                            )
                    }
                    .aspectRatio(0.65, contentMode: .fit)
                    .background(Color.bgSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.xl))
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.xl)
                            .stroke(Color.accentStart, lineWidth: 1.5)
                    )
                    .shadow(
                        color: Color.accentStart.opacity(glowPulse ? 0.4 : 0.15),
                        radius: glowPulse ? 16 : 8
                    )

                    Text("After")
                        .font(.caption)
                        .foregroundStyle(Color.accentStart)
                }
                .offset(y: showCards ? 0 : 20)
                .opacity(showCards ? 1 : 0)
                .animation(AppAnimation.cardTransition.delay(0.1), value: showCards)
            }
            .padding(.horizontal, Spacing.xxl)

            Spacer()

            // Page dots
            PageIndicatorDots(count: 3, current: 1)
                .padding(.bottom, Spacing.lg)

            // CTA
            GradientCTAButton("Looks Good →", action: onContinue)
                .padding(.bottom, Spacing.xxl)
        }
        .background(Color.bgPrimary)
        .onAppear {
            withAnimation(AppAnimation.cardTransition.delay(0.2)) {
                showCards = true
            }
            arrowBounce = true
            withAnimation(
                Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true)
            ) {
                glowPulse = true
            }
        }
    }
}

#Preview {
    OnboardingPage2(onContinue: {}, onSkip: {})
}
