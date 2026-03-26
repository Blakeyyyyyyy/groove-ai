import SwiftUI

struct GeneratingPill: View {
    let minutesRemaining: Int
    let isFailed: Bool
    let onTap: () -> Void

    @State private var sparkleVisible = true

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.sm) {
                if isFailed {
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

                Text(statusText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .background(
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: Radius.full)
                        .fill(Color.bgElevated)
                    // Left accent strip
                    HStack(spacing: 0) {
                        UnevenRoundedRectangle(
                            topLeadingRadius: Radius.full,
                            bottomLeadingRadius: Radius.full,
                            bottomTrailingRadius: 0,
                            topTrailingRadius: 0
                        )
                        .fill(isFailed
                              ? AnyShapeStyle(Color.warning)
                              : AnyShapeStyle(LinearGradient.accent))
                        .frame(width: 3)
                        Spacer()
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: Radius.full))
            .padding(.horizontal, Spacing.lg)
        }
        .buttonStyle(.plain)
        .onAppear { sparkleVisible = true }
    }

    private var statusText: String {
        if isFailed {
            return "Something went wrong — credits refunded. Tap to retry"
        } else if minutesRemaining <= 0 {
            return "Generating your video — almost done"
        } else {
            return "Generating your video — ~\(minutesRemaining) min"
        }
    }
}

#Preview {
    VStack(spacing: Spacing.lg) {
        GeneratingPill(minutesRemaining: 8, isFailed: false, onTap: {})
        GeneratingPill(minutesRemaining: 0, isFailed: false, onTap: {})
        GeneratingPill(minutesRemaining: 0, isFailed: true, onTap: {})
    }
    .padding()
    .background(Color.bgPrimary)
}
