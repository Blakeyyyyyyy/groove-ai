import SwiftUI

struct ExitPopupView: View {
    let onSubscribe: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: Spacing.xl) {
            // Drag handle
            RoundedRectangle(cornerRadius: Radius.full)
                .fill(Color.bgElevated)
                .frame(width: 40, height: 5)
                .padding(.top, Spacing.md)

            Text("Wait — Your Video Is Waiting")
                .font(.title3.bold())
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(.center)

            Text("You're one tap away. $9.99 gets you instant access — your video generates in minutes.")
                .font(.body)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Spacing.lg)

            GradientCTAButton("Start Dancing — $9.99 →", action: onSubscribe)

            Button("No thanks, I'll pass") {
                onDismiss()
            }
            .font(.subheadline)
            .foregroundStyle(Color.textTertiary)
            .frame(minHeight: 44)

            Spacer().frame(height: Spacing.sm)
        }
        .frame(maxWidth: .infinity)
        .background(Color.bgSecondary)
    }
}

#Preview {
    ExitPopupView(onSubscribe: {}, onDismiss: {})
}
