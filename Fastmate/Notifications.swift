import Combine
import UserNotifications
import WebKit

class FastmateNotificationCenter: NSObject {
    var clickHandler: ((_ notificationID: String) -> Void)?

    func registerForNotifications() {
        // NOTE: This is an attempt to fix a crash that's happening for certain users:
        // https://stackoverflow.com/questions/43840090/calling-unusernotificationcenter-current-getpendingnotificationrequests-crashe
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UNUserNotificationCenter.current().delegate = self

        let options: UNAuthorizationOptions = [.alert, .sound, .providesAppNotificationSettings, .badge]
        UNUserNotificationCenter.current().requestAuthorization(options: options) { response, error in
            if let error = error {
                print("Failed to register notifications: \(error)")
            } else {
                print("Notification authorization granted: \(response)")
            }
        }
    }

    func postNotifification(for message: WKScriptMessage) {
        guard let jsonString = message.body as? String,
              let data = jsonString.data(using: .utf8),
              let notification = try? JSONDecoder().decode(Notification.self, from: data)
        else {
            print("Failed to decode notification: \(message.body)")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = notification.title ?? "Untitled"
        content.subtitle = notification.options?.body ?? ""
        content.sound = .default

        let request = UNNotificationRequest(identifier: String(notification.notificationID), content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error { print("Failed to post notification: \(error)") }
        }
    }
}

extension FastmateNotificationCenter: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        clickHandler?(response.notification.request.identifier)
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        .alert
    }
}

private struct Notification: Decodable {
    var notificationID: Int
    var title: String?
    var options: Options?

    struct Options: Decodable {
        var body: String?
    }
}
