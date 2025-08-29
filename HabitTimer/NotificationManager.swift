import Foundation
import UserNotifications

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    private override init() {}

    func configure() {
        UNUserNotificationCenter.current().delegate = self
    }

    func requestAuthorizationIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        }
    }

    func notifyTimerFinished(title: String) {
        let content = UNMutableNotificationContent()
        content.title = "Fertig ✨"
        content.body = title
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    // Banner/Sound auch im Vordergrund
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
    }
}
