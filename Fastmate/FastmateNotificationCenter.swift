import Foundation
import UserNotifications
import Combine

typealias NotificationIdentifier = String

struct FastmateNotification {
    typealias Identifier = String
    let identifier: Identifier
    let title: String
    let body: String

    @available(macOS 10.14, *)
    fileprivate func notificationRequest() -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = title
        content.subtitle = body
        return .init(identifier: identifier, content: content, trigger: nil)
    }

    fileprivate func userNotification() -> NSUserNotification {
        let notification = NSUserNotification()
        notification.identifier = identifier
        notification.title = title
        notification.subtitle = body
        notification.soundName = NSUserNotificationDefaultSoundName
        return notification
    }
}

class FastmateNotificationCenter: NSObject {
    static var shared = FastmateNotificationCenter()

    let notificationSubject = PassthroughSubject<FastmateNotification, Never>()
    let notificationClickPublisher: AnyPublisher<NotificationIdentifier, Never>

    private let notificationClickSubject = PassthroughSubject<NotificationIdentifier, Never>()
    private let notificationSubscription: AnyCancellable

    private override init() {
        notificationClickPublisher = notificationClickSubject.eraseToAnyPublisher()
        notificationSubscription = notificationSubject.sink {
            if #available(macOS 10.14, *) {
                UNUserNotificationCenter.current().add($0.notificationRequest()) { (error) in
                    if let error = error { print("Failed to post notification: \(error)") }
                }
            } else {
                NSUserNotificationCenter.default.deliver($0.userNotification())
            }
        }
        super.init()
    }

    func registerForNotifications() {
        if #available(macOS 10.14, *) {
            UNUserNotificationCenter.current().delegate = self
            let options: UNAuthorizationOptions = [.alert, .sound, .badge, .providesAppNotificationSettings]
            UNUserNotificationCenter.current().requestAuthorization(options: options) { (granted, error) in
                print("Notification authorization granted: \(granted)");
            }
        } else {
            NSUserNotificationCenter.default.delegate = self
        }
    }
}

extension FastmateNotificationCenter: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let identifer = response.notification.request.identifier
        notificationClickSubject.send(identifer)
        completionHandler()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler(.alert)
    }
}

extension FastmateNotificationCenter: NSUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: NSUserNotificationCenter, didActivate notification: NSUserNotification) {
        notificationClickSubject.send(notification.identifier ?? "")
    }

    func userNotificationCenter(_ center: NSUserNotificationCenter, shouldPresent notification: NSUserNotification) -> Bool {
        return true
    }
}
