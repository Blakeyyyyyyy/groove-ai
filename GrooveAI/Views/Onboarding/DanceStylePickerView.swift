import SwiftUI
import AVFoundation

// MARK: - Screen 3: Dance Style Picker (Redesigned)
// Three full-width horizontal cards (350×120pt). Left panel = video loop. Right panel = name + descriptor.
// User selects → Continue button appears. NO auto-advance.
struct DanceStylePickerView: View {
    let subject: OnboardingSubject
    @Binding var selectedStyle: OnboardingDanceStyle?
    let onContinue: () -> Void

    @State private var showContent = false
    @State private var progressValue: CGFloat = 0.3

    private var styles: [OnboardingDanceStyle] {
        // Model now returns exactly 3 styles
        OnboardingDanceStyle.styles(for: subject)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 72)

            // Progress dots
            PageIndicatorDots(count: 4, current: 2)
                .padding(.bottom, Spacing.lg)

            // Progress bar (psychological momentum)
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

            // Dance style cards (3 full-width vertical cards)
            VStack(spacing: 12) {
                ForEach(Array(styles.enumerated()), id: \.element.id) { index, style in
                    DanceStyleRowCard(
                        style: style,
                        isSelected: selectedStyle?.id == style.id,
                        onTap: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
                                selectedStyle = style
                            }
                        }
                    )
                    .offset(y: showContent ? 0 : 24)
                    .opacity(showContent ? 1 : 0)
                    .animation(
                        AppAnimation.cardTransition.delay(Double(index) * 0.08),
                        value: showContent
                    )
                }
            }
            .padding(.horizontal, Spacing.lg)

            Spacer()

            // Continue button — appears after selection
            if selectedStyle != nil {
                GradientCTAButton("Let's go →", action: onContinue)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.xxl + 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: selectedStyle?.id)
        .background(Color.bgPrimary)
        .onAppear {
            withAnimation(AppAnimation.cardTransition.delay(0.15)) {
                showContent = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                progressValue = 0.6
            }
        }
    }
}

// MARK: - Dance Style Row Card
// Full-width horizontal card: left video panel (120×120) + right text panel
private struct DanceStyleRowCard: View {
    let style: OnboardingDanceStyle
    let isSelected: Bool
    let onTap: () -> Void

    @State private var videoURL: URL?

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                // LEFT: Video preview panel (120×120)
                ZStack {
                    if let url = videoURL {
                        LoopingVideoView(url: url, gravity: .resizeAspectFill)
                            .disabled(true)
                    } else {
                        // Fallback: gradient + play icon
                        LinearGradient(
                            colors: [Color.bgElevated, Color.bgSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )

                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.white.opacity(0.5))
                    }

                    // Subtle dark scrim on right edge for text panel separation
                    HStack {
                        Spacer()
                        LinearGradient(
                            colors: [Color.clear, Color.black.opacity(0.4)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: 24)
                    }
                }
                .frame(width: 120, height: 120)
                .clipped()

                // RIGHT: Name + descriptor + badge
                VStack(alignment: .leading, spacing: 6) {
                    // "Most popular" badge
                    if let badge = style.badge {
                        Text(badge)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(LinearGradient.accent)
                            .clipShape(Capsule())
                    }

                    Text(style.name)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)

                    Text(style.descriptor)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .frame(height: 120)
        .background(Color.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: Radius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.xl)
                .stroke(
                    isSelected ? Color.accentStart : Color.white.opacity(0.06),
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .shadow(
            color: isSelected ? Color.accentStart.opacity(0.25) : Color.black.opacity(0.2),
            radius: isSelected ? 14 : 6,
            y: isSelected ? 4 : 2
        )
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.65), value: isSelected)
        .onAppear {
            videoURL = Bundle.main.url(forResource: style.videoName, withExtension: "mp4")
        }
    }
}

#Preview {
    DanceStylePickerView(
        subject: .pet,
        selectedStyle: .constant(nil),
        onContinue: {}
    )
}
