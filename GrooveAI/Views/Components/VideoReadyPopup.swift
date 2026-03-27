import SwiftUI

// MARK: - Video Ready Popup
// In-app popup at top of screen: "Your video is ready 🎉"
// Confetti/sparkle animation, taps to navigate to completed video
struct VideoReadyPopup: View {
    let onTap: () -> Void
    let onDismiss: () -> Void

    @State private var showSparkles = false
    @State private var sparkleOffsets: [(x: CGFloat, y: CGFloat)] = (0..<8).map { _ in
        (x: CGFloat.random(in: -80...80), y: CGFloat.random(in: -30...30))
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Sparkle particles
                ForEach(0..<8, id: \.self) { i in
                    Text(["✨", "🎉", "⭐", "🌟", "✨", "🎊", "⭐", "🎉"][i])
                        .font(.caption)
                        .offset(
                            x: showSparkles ? sparkleOffsets[i].x : 0,
                            y: showSparkles ? sparkleOffsets[i].y - 20 : 0
                        )
                        .opacity(showSparkles ? 0 : 1)
                        .animation(
                            .easeOut(duration: 1.2).delay(Double(i) * 0.05),
                            value: showSparkles
                        )
                }

                // Main pill
                HStack(spacing: Spacing.sm) {
                    Text("🎉")
                        .font(.title3)

                    Text("Your video is ready!")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.textPrimary)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.textSecondary)
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: Radius.full)
                        .fill(Color.bgSecondary)
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.full)
                                .stroke(Color.success.opacity(0.4), lineWidth: 1)
                        )
                        .shadow(color: Color.success.opacity(0.2), radius: 12, y: 4)
                )
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Spacing.lg)
        .onAppear {
            // Trigger sparkle burst
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                showSparkles = true
            }
            // Auto-dismiss after 8 seconds if not tapped
            DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                onDismiss()
            }
        }
    }
}

#Preview {
    VStack {
        VideoReadyPopup(onTap: {}, onDismiss: {})
        Spacer()
    }
    .background(Color.bgPrimary)
}
