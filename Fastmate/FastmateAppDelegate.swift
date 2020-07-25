import Foundation
import Combine

class FastmateAppDelegate: NSObject, NSApplicationDelegate {

    let didFinishLaunching = PassthroughSubject<Void, Never>()
    let checkForNewVersionAction = PassthroughSubject<Void, Never>()
    let mainWindow = CurrentValueSubject<NSWindow?, Never>(nil)

    private var subscriptions = Set<AnyCancellable>()
    private var statusItemButtonSubscription: AnyCancellable?
    private var statusItem: NSStatusItem?

    static var shared = {
        FastmateAppDelegate()
    }()

    @objc static func sharedInstance() -> FastmateAppDelegate {
        shared
    }

    override init() {
        super.init()
        setupSubscriptions()
    }

    func setupSubscriptions() {
        let settings = Settings.shared

        let unreadCount = mainWindow
            .compactMap { $0?.contentViewController as? WebViewController }
            .map { $0.unreadCount }
            .switchToLatest()
            .share()
            .eraseToAnyPublisher()

        statusItemState(for: unreadCount, settings: settings)
            .sink {
                self.setStatusItemVisible($0 != .hidden)
                self.statusItem?.button?.image = $0.image()
            }
            .store(in: &subscriptions)

        dockBadgeLabel(for: unreadCount, settings: settings)
            .assign(to: \.badgeLabel, on: NSApplication.shared.dockTile)
            .store(in: &subscriptions)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        didFinishLaunching.send()
        VersionChecker.setup()
    }

    func setStatusItemVisible(_ visible: Bool) {
        if (visible) {
            let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            statusItemButtonSubscription = statusItem.button?.publisher
                .sink {
                    NSApp.unhide(statusItem)
                    NSApp.activate(ignoringOtherApps: true)
                }
            self.statusItem = statusItem
        } else if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItemButtonSubscription?.cancel()
        }
    }

    @IBAction func checkForUpdates(sender: AnyObject) {
        checkForNewVersionAction.send()
    }

    private func statusItemState(for unreadCount: AnyPublisher<Int, Never>, settings: Settings) -> AnyPublisher<StatusItemState, Never> {
        unreadCount.combineLatest(settings.$shouldShowStatusBarIcon.publisher,
                                  settings.$shouldShowUnreadMailIndicator.publisher,
                                  settings.$shouldShowUnreadMailInStatusBar.publisher)
            .map { predicates -> StatusItemState in
                switch predicates {
                case (let count, true, true, true) where count > 0: return .visibleUnread
                case (_, true, true, true): return .visible
                default: return .hidden
                }
            }.eraseToAnyPublisher()
    }

    private func dockBadgeLabel(for unreadCount: AnyPublisher<Int, Never>, settings: Settings) -> AnyPublisher<String?, Never> {
        unreadCount.combineLatest(settings.$shouldShowUnreadMailIndicator.publisher,
                                  settings.$shouldShowUnreadMailInDock.publisher,
                                  settings.$shouldShowUnreadMailCountInDock.publisher)
            .map { predicates -> String? in
                switch predicates {
                case (let count, true, true, true) where count > 0: return String(count)
                case (let count, true, true, false) where count > 0: return " "
                default: return nil
                }
            }.eraseToAnyPublisher()
    }
}

fileprivate enum StatusItemState {
    case visible
    case visibleUnread
    case hidden

    func image() -> NSImage? {
        switch self {
        case .visible: return NSImage(named: "status-bar")
        case .visibleUnread: return NSImage(named: "status-bar-unread")
        case .hidden: return nil
        }
    }
}
