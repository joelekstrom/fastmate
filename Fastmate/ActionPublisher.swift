import Combine

protocol Actionable {
    var target: AnyObject? { get set }
    var action: Selector? { get set }
    var publisher: Publishers.Action { get }
}

extension Actionable {
    var publisher: Publishers.Action {
        Publishers.Action(item: self)
    }
}

extension NSControl: Actionable {}
extension NSMenuItem: Actionable {}

extension Publishers {
    struct Action: Publisher {
        typealias Output = Void
        typealias Failure = Never
        let item: Actionable

        func receive<S>(subscriber: S) where S : Subscriber, Self.Failure == S.Failure, Self.Output == S.Input {
            subscriber.receive(subscription: ActionSubscription(subscriber: subscriber, item: item))
        }
    }

    struct MainMenu: Publisher {
        typealias Output = Void
        typealias Failure = Never
        let path: [String]

        init(path: String...) { self.path = path }

        func receive<S>(subscriber: S) where S : Subscriber, Self.Failure == S.Failure, Self.Output == S.Input {
            var item = NSApp.mainMenu?.item(withTitle: path.first!)
            for title in path.dropFirst() {
                item = item?.submenu?.item(withTitle: title)
            }
            subscriber.receive(subscription: ActionSubscription(subscriber: subscriber, item: item!))
        }
    }
}

class ActionSubscription<S: Subscriber>: Subscription where S.Input == Void {
    var item: Actionable
    var subscriber: S?

    init(subscriber: S, item: Actionable) {
        self.item = item
        self.subscriber = subscriber
        self.item.target = self
        self.item.action = #selector(buttonClicked)
    }

    func request(_ demand: Subscribers.Demand) {}
    func cancel() { subscriber = nil }
    @objc func buttonClicked() { _ = subscriber?.receive() }
}
