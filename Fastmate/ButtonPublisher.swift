import Combine

extension Publishers {
    struct Button: Publisher {
        typealias Output = Void
        typealias Failure = Never
        let button: NSButton

        func receive<S>(subscriber: S) where S : Subscriber, Self.Failure == S.Failure, Self.Output == S.Input {
            subscriber.receive(subscription: ButtonSubscription(subscriber: subscriber, button: button))
        }
    }
}

extension NSButton {
    var publisher: Publishers.Button {
        Publishers.Button(button: self)
    }
}

class ButtonSubscription<S: Subscriber>: Subscription where S.Input == Void {
    let button: NSButton
    var subscriber: S?

    init(subscriber: S, button: NSButton) {
        self.button = button
        self.subscriber = subscriber
        button.target = self
        button.action = #selector(buttonClicked)
    }

    func request(_ demand: Subscribers.Demand) {}
    func cancel() { subscriber = nil }
    @objc func buttonClicked() { _ = subscriber?.receive() }
}
