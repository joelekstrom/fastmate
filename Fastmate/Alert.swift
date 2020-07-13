import Foundation
import Combine

struct Alert {
    struct Configuration {
        var messageText: String
        var informativeText: String
        var buttonTitles: [String]
        var suppressionButtonTitle: String?
        var suppressionButtonState: NSControl.StateValue?
        var style = NSAlert.Style.informational
        var userInfo: Any?
    }

    struct Response {
        let modalResponse: NSApplication.ModalResponse
        let suppressButtonState: NSControl.StateValue?
        let userInfo: Any?
    }

    static func modalPublisher(configuration: Configuration, window: NSWindow) -> AnyPublisher<Response, Never> {
        Future { promise in
            let alert = self.alert(configuration: configuration)
            alert.beginSheetModal(for: window) {
                promise(.success(Response(modalResponse: $0, suppressButtonState: alert.suppressionButton?.state, userInfo: configuration.userInfo)))
            }
        }.eraseToAnyPublisher()
    }

    private static func alert(configuration: Configuration) -> NSAlert {
        let alert = NSAlert()
        configuration.buttonTitles.forEach { alert.addButton(withTitle: $0) }
        alert.messageText = configuration.messageText
        alert.informativeText = configuration.informativeText
        alert.alertStyle = configuration.style
        if let suppressionButtonTitle = configuration.suppressionButtonTitle {
            alert.showsSuppressionButton = true
            alert.suppressionButton!.title = suppressionButtonTitle
            alert.suppressionButton!.state = configuration.suppressionButtonState ?? .off
        }
        return alert
    }
}

extension Publisher where Output == Alert.Configuration {
    func displayAlert() -> AnyPublisher<Alert.Response, Failure> {
        let windowPublisher = NSApplication.shared.publisher(for: \.mainWindow)
            .setFailureType(to: Failure.self)
            .compactMap { $0 }
            .eraseToAnyPublisher()

        return self.receive(on: DispatchQueue.main)
            .combineLatest(windowPublisher)
            .first()
            .flatMap { Alert.modalPublisher(configuration: $0, window: $1).setFailureType(to: Failure.self) }
            .eraseToAnyPublisher()
    }
}
