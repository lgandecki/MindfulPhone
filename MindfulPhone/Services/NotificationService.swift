import Foundation
import UserNotifications

enum NotificationService {
    static func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    /// Schedules a warning notification before an unlock expires.
    static func scheduleExpiryWarning(appName: String, expiresAt: Date) {
        let warningTime = expiresAt.addingTimeInterval(-5 * 60) // 5 minutes before
        guard warningTime > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "5 minutes remaining"
        content.body = "\(appName) will be blocked again in 5 minutes."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: warningTime.timeIntervalSinceNow,
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "expiry-warning-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { _ in }
    }

    /// Schedules a notification when an unlock fully expires.
    static func scheduleExpiryNotification(appName: String, expiresAt: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Time's up"
        content.body = "\(appName) has been blocked again."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(expiresAt.timeIntervalSinceNow, 1),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "expiry-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { _ in }
    }
}
