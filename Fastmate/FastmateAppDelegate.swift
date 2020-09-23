import Foundation
import Combine
import Cocoa

class FastmateAppDelegate: NSObject, NSApplicationDelegate {

    static let shared = { NSApplication.shared.delegate as! FastmateAppDelegate }()

    @Published var mainWindow: NSWindow?
    @Published private var statusItem: NSStatusItem?
    let printSubscriber = PassthroughSubject<WebViewController, Never>()

    private let externalURLPublisher = PassthroughSubject<URL, Never>()
    private var subscriptions = Set<AnyCancellable>()
    private var versionChecker: VersionChecker!

    private var externalURLSubscription: AnyCancellable?
    private var notificationClickSubscription: AnyCancellable?

    func applicationWillFinishLaunching(_ notification: Notification) {
        setupSubscriptions()
        FastmateNotificationCenter.shared.registerForNotifications()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.global().async {
            ScriptController.createUserScriptsFolderIfNeeded()
        }

        versionChecker = VersionChecker()
    }

    func setupSubscriptions() {
        let settings = Settings.shared

        let mainWebViewPublisher = $mainWindow
            .compactMap { $0?.contentViewController as? WebViewController }

        mainWebViewPublisher
            .map(\.notificationPublisher)
            .switchToLatest()
            .subscribe(FastmateNotificationCenter.shared.notificationSubject)
            .store(in: &subscriptions)

        let unreadCount = mainWebViewPublisher
            .map(\.unreadCount)
            .switchToLatest()
            .share()

        unreadCount
            .statusItemState(with: settings)
            .sink {
                self.setStatusItemVisible($0 != .hidden)
                self.statusItem?.button?.image = $0.image()
            }
            .store(in: &subscriptions)

        unreadCount
            .dockBadgeLabel(with: settings)
            .assign(to: \.badgeLabel, on: NSApplication.shared.dockTile)
            .store(in: &subscriptions)

        $statusItem
            .compactMap { $0?.button?.publisher }
            .switchToLatest()
            .sink {
                NSApp.unhide(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
            .store(in: &subscriptions)

        mainWebViewPublisher
            .sink {
                self.externalURLSubscription = self.externalURLPublisher.subscribe($0.externalURLSubject)
                self.notificationClickSubscription = FastmateNotificationCenter.shared.notificationClickPublisher
                    .subscribe($0.notificationClickSubject)
            }
            .store(in: &subscriptions)

        printSubscriber
            .sink { PrintManager.sharedInstance().print($0.webView!) }
            .store(in: &subscriptions)
    }

    @IBAction func checkForUpdates(_ sender: AnyObject) {
        versionChecker.checkForUpdates()
    }

    func setStatusItemVisible(_ visible: Bool) {
        if visible, statusItem == nil {
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        } else if visible == false, let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        if let url = urls.first {
            externalURLPublisher.send(url)
        }
    }
}

fileprivate extension Publisher where Output == Int, Failure == Never {
    func statusItemState(with settings: Settings) -> AnyPublisher<StatusItemState, Failure> {
        combineLatest(settings.$shouldShowStatusBarIcon.publisher, settings.$shouldShowUnreadMailInStatusBar.publisher)
            .map { predicates -> StatusItemState in
                switch predicates {
                case (let count, true, true) where count > 0: return .visibleUnread
                case (_, true, _): return .visible
                default: return .hidden
                }
        }.eraseToAnyPublisher()
    }

    func dockBadgeLabel(with settings: Settings) -> AnyPublisher<String?, Failure> {
        combineLatest(settings.$shouldShowUnreadMailInDock.publisher, settings.$shouldShowUnreadMailCountInDock.publisher)
            .map { predicates -> String? in
                switch predicates {
                case (let count, true, true) where count > 0: return String(count)
                case (let count, true, false) where count > 0: return " "
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
