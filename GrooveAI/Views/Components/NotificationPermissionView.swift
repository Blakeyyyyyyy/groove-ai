import SwiftUI
import UserNotifications

struct NotificationPermissionView: View {
    let onAllow: () -> Void
    let onDismiss: () -> Void

    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: Spacing.xl) {
            // Drag handle
            RoundedRectangle(cornerRadius: Radius.full)
                .fill(Color.bgElevated)
                .frame(width: 40, height: 5)
                .padding(.top, Spacing.md)

            // Bell icon
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 48))
                .foregroundStyle(LinearGradient.accent)
                .padding(.top, Spacing.lg)

            // Headline
            Text("Know the moment your video is ready")
                .font(.title3.bold())
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            // Body
            Text("We'll send you one notification when your video is done. That's it.")
                .font(.body)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Spacing.lg)

            // Allow CTA
            GradientCTAButton("Allow Notifications") {
                requestNotificationPermission()
            }

            // Not now
            Button("Not now") {
                appState.hasRequestedNotificationPermission = true
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

    private func requestNotificationPermission() {
        appState.hasRequestedNotificationPermission = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
            DispatchQueue.main.async {
                onAllow()
            }
        }
    }
}

#Preview {
    NotificationPermissionView(onAllow: {}, onDismiss: {})
        .environment(AppState())
}
