import SwiftUI

struct GeneratingPill: View {
    @Environment(AppState.self) private var appState
    let onTap: () -> Void

    @State private var sparkleVisible = true
    @State private var now = Date()

    // Real-time countdown timer (BUG-003 fix) — ticks every 30s (minutes-only display)
    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.md) {
                // Thumbnail from user's uploaded photo
                thumbnailView

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    HStack(spacing: Spacing.sm) {
                        if appState.generationFailed {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Color.warning)
                        } else {
                            Text("✦")
                                .foregroundStyle(Color.accentStart)
                                .opacity(sparkleVisible ? 1.0 : 0.5)
                                .animation(
                                    Animation.easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                                    value: sparkleVisible
                                )
                        }

                        Text(titleText)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.textPrimary)
                    }

                    Text(subtitleText)
                        .font(.caption)
                        .foregroundStyle(Color.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(.vertical, Spacing.lg)
            .padding(.horizontal, Spacing.lg)
            .frame(maxWidth: .infinity)
            .background(
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: Radius.xl)
                        .fill(Color.bgSecondary)

                    // Subtle accent glow border
                    RoundedRectangle(cornerRadius: Radius.xl)
                        .stroke(
                            appState.generationFailed
                                ? Color.warning.opacity(0.3)
                                : Color.accentStart.opacity(0.3),
                            lineWidth: 1
                        )

                    // Left accent strip
                    HStack(spacing: 0) {
                        UnevenRoundedRectangle(
                            topLeadingRadius: Radius.xl,
                            bottomLeadingRadius: Radius.xl,
                            bottomTrailingRadius: 0,
                            topTrailingRadius: 0
                        )
                        .fill(appState.generationFailed
                              ? AnyShapeStyle(Color.warning)
                              : AnyShapeStyle(LinearGradient.accent))
                        .frame(width: 3)
                        Spacer()
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: Radius.xl))
            .padding(.horizontal, Spacing.lg)
        }
        .buttonStyle(.plain)
        .onAppear { sparkleVisible = true }
        .onReceive(timer) { tick in
            now = tick
        }
    }

    // MARK: - Thumbnail

    @ViewBuilder
    private var thumbnailView: some View {
        Group {
            if let photoData = appState.generatingPhotoData,
               let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Color.bgElevated
                    Image(systemName: "figure.dance")
                        .font(.caption)
                        .foregroundStyle(Color.textTertiary)
                }
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
    }

    // MARK: - Text

    private var titleText: String {
        if appState.generationFailed {
            return "Something went wrong"
        }
        return "Creating your video"
    }

    private var subtitleText: String {
        if appState.generationFailed {
            return "Coins refunded — tap to retry"
        }
        let countdown = appState.countdownText(from: now)
        if countdown == "almost done" {
            return "Almost done..."
        }
        return "\(countdown) remaining"
    }
}

#Preview {
    VStack(spacing: Spacing.lg) {
        GeneratingPill(onTap: {})
    }
    .padding()
    .background(Color.bgPrimary)
    .environment(AppState())
}
