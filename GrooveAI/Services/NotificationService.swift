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

    static func scheduleTrialReminder() {
        let content = UNMutableNotificationContent()
        content.title = "Your dance is waiting 🔥"
        content.body = "Your Groove trial is almost up — come back and make one more dance before it's gone 🔥"
        content.sound = .default
        content.userInfo = ["action": "openCreate"]

        // Fire exactly 48 hours from now (day 2 of a 3-day trial)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 48 * 60 * 60, repeats: false)
        let request = UNNotificationRequest(
            identifier: "groove-trial-reminder",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("[NotificationService] Failed to schedule trial reminder: \(error.localizedDescription)")
            } else {
                print("[NotificationService] Trial reminder scheduled for 48h from now")
            }
        }
    }

    static func cancelTrialReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["groove-trial-reminder"]
        )
    }
}
