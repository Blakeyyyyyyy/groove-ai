import SwiftUI

// MARK: - Hero Banner (Home screen, above presets)
// 75% screen width, centered, dark card with gradient, CTA inside
struct HeroBannerView: View {
    let onTap: () -> Void

    @State private var shimmerPhase: CGFloat = 0

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
                // Dark gradient card
                RoundedRectangle(cornerRadius: Radius.xl)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.08, green: 0.06, blue: 0.16),
                                Color(red: 0.04, green: 0.04, blue: 0.10),
                                Color.bgSecondary
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // Subtle accent glow
                RoundedRectangle(cornerRadius: Radius.xl)
                    .fill(
                        RadialGradient(
                            colors: [Color.accentStart.opacity(0.08), Color.clear],
                            center: .topTrailing,
                            startRadius: 0,
                            endRadius: 200
                        )
                    )

                // Shimmer overlay
                RoundedRectangle(cornerRadius: Radius.xl)
                    .fill(
                        LinearGradient(
                            colors: [Color.clear, Color.white.opacity(0.03), Color.clear],
                            startPoint: UnitPoint(x: shimmerPhase - 0.3, y: 0),
                            endPoint: UnitPoint(x: shimmerPhase + 0.3, y: 1)
                        )
                    )

                // Content
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Spacer()

                    // Dancer icon
                    Image(systemName: "figure.dance")
                        .font(.system(size: 28))
                        .foregroundStyle(LinearGradient.accent)

                    Text("See transformation →")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.textPrimary)
                }
                .padding(Spacing.lg)
            }
            .frame(width: UIScreen.main.bounds.width * 0.75, height: 160)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.xl)
                    .stroke(Color.bgElevated, lineWidth: 0.5)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .onAppear {
            withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                shimmerPhase = 2
            }
        }
    }
}

#Preview {
    HeroBannerView(onTap: {})
        .padding()
        .background(Color.bgPrimary)
}
