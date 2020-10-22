import Foundation
import Combine
import Cocoa

struct Alert {

    struct ModalResponse {
        let modalResponse: NSApplication.ModalResponse
        let suppressButtonState: NSControl.StateValue?
        let userInfo: Any?
    }

    class Builder {
        private var messageText = ""
        private var informativeText: String?
        private var buttonTitles = [String]()
        private var suppressionButtonTitle: String?
        private var suppressionButtonState: NSControl.StateValue?
        private var style = NSAlert.Style.informational
        private var accessoryView: NSView?
        fileprivate var userInfo: Any?

        @discardableResult func with(text: String) -> Self { messageText = text; return self }
        @discardableResult func with(informativeText: String) -> Self { self.informativeText = informativeText; return self }
        @discardableResult func with(buttonTitles: [String]) -> Self { self.buttonTitles = buttonTitles; return self }
        @discardableResult func with(style: NSAlert.Style) -> Self { self.style = style; return self }
        @discardableResult func with(accessoryView: NSView) -> Self { self.accessoryView = accessoryView; return self }
        @discardableResult func with(userInfo: Any?) -> Self { self.userInfo = userInfo; return self }
        @discardableResult func with(suppressButton: (title: String, state: NSControl.StateValue)) -> Self {
            suppressionButtonTitle = suppressButton.title
            suppressionButtonState = suppressButton.state
            return self
        }

        var alert: NSAlert {
            let alert = NSAlert()
            buttonTitles.forEach { alert.addButton(withTitle: $0) }
            alert.messageText = messageText
            alert.informativeText = informativeText ?? ""
            alert.alertStyle = style
            alert.accessoryView = accessoryView
            if let suppressionButtonTitle = suppressionButtonTitle {
                alert.showsSuppressionButton = true
                alert.suppressionButton!.title = suppressionButtonTitle
                alert.suppressionButton!.state = suppressionButtonState ?? .off
            }
            return alert
        }
    }
}

extension Publisher where Output == Alert.Builder {
    func presentModally(in window: NSWindow? = nil) -> AnyPublisher<Alert.ModalResponse, Failure> {
        var windowPublisher: AnyPublisher<NSWindow, Never>
        if let window = window {
            windowPublisher = Just(window).eraseToAnyPublisher()
        } else {
            windowPublisher = NSApplication.shared.publisher(for: \.mainWindow)
                .compactMap { $0 }
                .eraseToAnyPublisher()
        }

        return
            receive(on: DispatchQueue.main)
            .combineLatest(windowPublisher.setFailureType(to: Failure.self))
            .first()
            .map(\.0.alert, \.0.userInfo, \.1)
            .flatMap { (alert, userInfo, window) in
                Future { promise in
                    alert.beginSheetModal(for: window) {
                        let response = Alert.ModalResponse(
                            modalResponse: $0,
                            suppressButtonState: alert.suppressionButton?.state,
                            userInfo: userInfo
                        )
                        promise(.success(response))
                    }
                }
            }
            .eraseToAnyPublisher()
    }
}
