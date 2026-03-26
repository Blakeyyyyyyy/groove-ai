import SwiftUI

struct OnboardingPage3: View {
    let onContinue: () -> Void
    let onSkip: () -> Void

    @State private var showCards = false

    private let subjects: [(icon: String, label: String, badge: String?)] = [
        ("person.fill", "Person", nil),
        ("dog.fill", "Dog", nil),
        ("face.smiling.inverse", "Baby", "NEW")
    ]

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
                Text("Pets. Babies. Anyone.")
                    .font(.largeTitle.bold())
                    .foregroundStyle(Color.textPrimary)

                Text("If they've got a face, they can dance.")
                    .font(.body)
                    .foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.lg)

            Spacer().frame(height: Spacing.xl)

            // 3 Subject cards
            HStack(spacing: Spacing.sm) {
                ForEach(Array(subjects.enumerated()), id: \.offset) { index, subject in
                    subjectCard(
                        icon: subject.icon,
                        label: subject.label,
                        badge: subject.badge,
                        index: index
                    )
                }
            }
            .padding(.horizontal, Spacing.lg)

            Spacer()

            // Page dots
            PageIndicatorDots(count: 3, current: 2)
                .padding(.bottom, Spacing.lg)

            // CTA
            GradientCTAButton("Let's Make It Dance →", action: onContinue)
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
    private func subjectCard(icon: String, label: String, badge: String?, index: Int) -> some View {
        VStack(spacing: 0) {
            // Thumbnail area
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: Radius.lg)
                    .fill(Color.bgElevated.opacity(0.6))
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 36))
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
            .aspectRatio(0.65, contentMode: .fit)

            // Label
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.textPrimary)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.md)
        }
        .background(Color.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: Radius.xl))
        .offset(y: showCards ? 0 : 30)
        .opacity(showCards ? 1 : 0)
        .animation(
            AppAnimation.cardTransition.delay(Double(index) * 0.06),
            value: showCards
        )
    }
}

#Preview {
    OnboardingPage3(onContinue: {}, onSkip: {})
}
