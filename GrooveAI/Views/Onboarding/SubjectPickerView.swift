import SwiftUI

// MARK: - Screen 2: Subject Picker
// Visual cards: Pet / Baby / Friend / Myself — tap to select
struct SubjectPickerView: View {
    @Binding var selectedSubject: OnboardingSubject?
    let onContinue: () -> Void

    @State private var showCards = false

    private let subjects = OnboardingSubject.allCases
    private let columns = [
        GridItem(.flexible(), spacing: Spacing.md),
        GridItem(.flexible(), spacing: Spacing.md)
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 80)

            // Progress dots
            PageIndicatorDots(count: 4, current: 1)
                .padding(.bottom, Spacing.xl)

            // Headline
            VStack(spacing: Spacing.sm) {
                Text("Who's dancing?")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color.textPrimary)

                Text("Tap one to start")
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
            }
            .padding(.bottom, Spacing.xl)

            // 2x2 grid of subject cards
            LazyVGrid(columns: columns, spacing: Spacing.md) {
                ForEach(Array(subjects.enumerated()), id: \.element.id) { index, subject in
                    SubjectCard(
                        subject: subject,
                        isSelected: selectedSubject == subject,
                        onTap: {
                            withAnimation(AppAnimation.bouncy) {
                                selectedSubject = subject
                            }
                            // Auto-advance after 400ms
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                onContinue()
                            }
                        }
                    )
                    .offset(y: showCards ? 0 : 20)
                    .opacity(showCards ? 1 : 0)
                    .animation(
                        AppAnimation.cardTransition.delay(Double(index) * 0.08),
                        value: showCards
                    )
                }
            }
            .padding(.horizontal, Spacing.lg)

            Spacer()
        }
        .background(Color.bgPrimary)
        .onAppear {
            withAnimation(AppAnimation.cardTransition.delay(0.2)) {
                showCards = true
            }
        }
    }
}

// MARK: - Subject Card
private struct SubjectCard: View {
    let subject: OnboardingSubject
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: Spacing.sm) {
                // Icon area (placeholder for video loop)
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.lg)
                        .fill(Color.bgElevated.opacity(0.6))

                    Image(systemName: subject.icon)
                        .font(.system(size: 40))
                        .foregroundStyle(
                            isSelected ? AnyShapeStyle(LinearGradient.accent) : AnyShapeStyle(Color.textSecondary)
                        )
                }
                .aspectRatio(1.0, contentMode: .fit)

                Text(subject.rawValue)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.textPrimary)
                    .padding(.bottom, Spacing.sm)
            }
            .background(Color.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: Radius.xl))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.xl)
                    .stroke(
                        isSelected ? Color.white : Color.clear,
                        lineWidth: 2
                    )
            )
            .shadow(
                color: isSelected ? Color.white.opacity(0.15) : Color.clear,
                radius: isSelected ? 12 : 0
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .opacity(selectedOpacity)
        }
        .buttonStyle(.plain)
    }

    private var selectedOpacity: Double {
        // If nothing selected, all full. If something selected, dim unselected.
        isSelected ? 1.0 : 0.6
    }
}

#Preview {
    SubjectPickerView(selectedSubject: .constant(nil), onContinue: {})
}
