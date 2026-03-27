import SwiftUI

struct GeneratingPill: View {
    @Environment(AppState.self) private var appState
    let onTap: () -> Void

    @State private var sparkleVisible = true
    @State private var now = Date()

    // Real-time countdown timer (BUG-003 fix)
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Button(action: onTap) {
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
                        .fill(Color.bgSecondary)

                    // Subtle blue glow border
                    RoundedRectangle(cornerRadius: Radius.full)
                        .stroke(Color.accentStart.opacity(0.3), lineWidth: 1)

                    // Left accent strip
                    HStack(spacing: 0) {
                        UnevenRoundedRectangle(
                            topLeadingRadius: Radius.full,
                            bottomLeadingRadius: Radius.full,
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
            .clipShape(RoundedRectangle(cornerRadius: Radius.full))
            .padding(.horizontal, Spacing.lg)
        }
        .buttonStyle(.plain)
        .onAppear { sparkleVisible = true }
        .onReceive(timer) { tick in
            now = tick
        }
    }

    private var statusText: String {
        if appState.generationFailed {
            return "Something went wrong — coins refunded. Tap to retry"
        }
        let countdown = appState.countdownText(from: now)
        if countdown == "almost done" {
            return "Generating your video — almost done ✦"
        }
        return "Generating your video — \(countdown) ✦"
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
