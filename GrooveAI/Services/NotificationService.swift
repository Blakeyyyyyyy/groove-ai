import UserNotifications

enum NotificationService {
    static func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            return false
        }
    }

    static func scheduleVideoReady(videoID: String) {
        let content = UNMutableNotificationContent()
        content.title = "Your video is ready 🔥"
        content.body = "Your video is ready and it's wild. Tap to watch."
        content.sound = .default
        content.userInfo = ["videoID": videoID]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "video-ready-\(videoID)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }
}
