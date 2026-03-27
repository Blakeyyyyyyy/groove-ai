import SwiftUI

// MARK: - Screen 3: Dance Style Picker
// Horizontal scrollable row of dance style cards with progress bar
struct DanceStylePickerView: View {
    let subject: OnboardingSubject
    @Binding var selectedStyle: OnboardingDanceStyle?
    let onContinue: () -> Void

    @State private var showContent = false
    @State private var progressValue: CGFloat = 0.3 // Starts at 30% from Screen 2

    private var styles: [OnboardingDanceStyle] {
        OnboardingDanceStyle.styles(for: subject)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 80)

            // Progress dots
            PageIndicatorDots(count: 4, current: 2)
                .padding(.bottom, Spacing.lg)

            // Progress bar (cosmetic — pure psychology)
            VStack(spacing: Spacing.xs) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: Radius.full)
                            .fill(Color.bgElevated)
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: Radius.full)
                            .fill(LinearGradient.accent)
                            .frame(width: geo.size.width * progressValue, height: 6)
                            .animation(.easeInOut(duration: 0.8), value: progressValue)
                    }
                }
                .frame(height: 6)
                .padding(.horizontal, Spacing.lg)

                Text("Building your preview")
                    .font(.caption)
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(.bottom, Spacing.xl)

            // Headline
            Text("Pick the vibe")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Color.textPrimary)
                .padding(.bottom, Spacing.xl)

            Spacer()

            // Horizontal scrollable dance style cards
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.md) {
                    ForEach(styles) { style in
                        DanceStyleCard(
                            style: style,
                            isSelected: selectedStyle?.id == style.id,
                            onTap: {
                                withAnimation(AppAnimation.bouncy) {
                                    selectedStyle = style
                                }
                                // Auto-advance after 500ms
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    onContinue()
                                }
                            }
                        )
                        .offset(y: showContent ? 0 : 20)
                        .opacity(showContent ? 1 : 0)
                    }
                }
                .padding(.horizontal, Spacing.lg)
            }
            .scrollTargetBehavior(.viewAligned)

            Spacer()
            Spacer()
        }
        .background(Color.bgPrimary)
        .onAppear {
            withAnimation(AppAnimation.cardTransition.delay(0.2)) {
                showContent = true
            }
            // Animate progress bar to 60%
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                progressValue = 0.6
            }
        }
    }
}

// MARK: - Dance Style Card
private struct DanceStyleCard: View {
    let style: OnboardingDanceStyle
    let isSelected: Bool
    let onTap: () -> Void

    @State private var badgePulse = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Thumbnail area
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: Radius.lg)
                        .fill(Color.bgElevated.opacity(0.6))
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 32))
                                .foregroundStyle(
                                    isSelected ? AnyShapeStyle(LinearGradient.accent) : AnyShapeStyle(Color.textSecondary.opacity(0.5))
                                )
                        )

                    if let badge = style.badge {
                        Text(badge)
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, Spacing.xs)
                            .background(LinearGradient.accent)
                            .clipShape(Capsule())
                            .padding(Spacing.sm)
                            .scaleEffect(badgePulse ? 1.06 : 1.0)
                    }
                }
                .frame(width: 140, height: 160)

                // Name
                Text(style.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.md)
            }
            .background(Color.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: Radius.xl))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.xl)
                    .stroke(
                        isSelected ? Color.accentStart : Color.clear,
                        lineWidth: 2
                    )
            )
            .scaleEffect(isSelected ? 1.08 : 1.0)
            .opacity(selectedOpacity)
        }
        .buttonStyle(.plain)
        .onAppear {
            if style.badge != nil {
                withAnimation(
                    .easeInOut(duration: 1.0)
                    .repeatForever(autoreverses: true)
                ) {
                    badgePulse = true
                }
            }
        }
    }

    private var selectedOpacity: Double {
        isSelected ? 1.0 : 0.88
    }
}

#Preview {
    DanceStylePickerView(
        subject: .pet,
        selectedStyle: .constant(nil),
        onContinue: {}
    )
}
