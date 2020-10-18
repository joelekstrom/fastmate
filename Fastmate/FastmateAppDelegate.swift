import Foundation
import Combine
import Cocoa

class FastmateAppDelegate: NSObject, NSApplicationDelegate {

    static let shared = { NSApplication.shared.delegate as! FastmateAppDelegate }()

    @Published var mainWindow: NSWindow?
    @Published private var statusItem: NSStatusItem?

    private let externalURLPublisher = PassthroughSubject<URL, Never>()
    private var subscriptions = Set<AnyCancellable>()
    private var versionChecker = VersionChecker()

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
            .eraseToAnyPublisher()

        Publishers.dockBadgeLabel(with: unreadCount, settings: settings)
            .assign(to: \.badgeLabel, on: NSApplication.shared.dockTile)
            .store(in: &subscriptions)

        let statusItemImageName = Publishers.statusItemImageName(with: unreadCount, settings: settings)

        statusItemImageName
            .map { $0 != nil }
            .assign(to: \.statusItemVisible, on: self)
            .store(in: &subscriptions)

        let statusItemButton = $statusItem
            .compactMap { $0?.publisher(for: \.button) }
            .switchToLatest()
            .compactMap { $0 }

        statusItemButton
            .combineLatest(statusItemImageName
                            .compactMap { $0 }
                            .map(NSImage.init(named:)))
            .sink { $0.image = $1 }
            .store(in: &subscriptions)

        statusItemButton
            .map(\.actionPublisher)
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
    }

    @IBAction func checkForUpdates(_ sender: AnyObject) {
        versionChecker.checkForUpdates()
    }

    var statusItemVisible: Bool = false {
        didSet {
            if statusItemVisible, statusItem == nil {
                statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            } else if statusItemVisible == false, let item = statusItem {
                NSStatusBar.system.removeStatusItem(item)
                statusItem = nil
            }
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        if let url = urls.first {
            externalURLPublisher.send(url)
        }
    }
}

private extension Publishers {
    static func dockBadgeLabel(with unreadCount: AnyPublisher<Int, Never>, settings: Settings) -> AnyPublisher<String?, Never> {
        unreadCount.combineLatest(settings.$shouldShowUnreadMailInDock.publisher, settings.$shouldShowUnreadMailCountInDock.publisher)
            .map {
                switch ($0, $1, $2) {
                case (let count, true, true) where count > 0: return String(count)
                case (let count, true, false) where count > 0: return " "
                default: return nil
                }
            }
            .eraseToAnyPublisher()
    }

    static func statusItemImageName(with unreadCount: AnyPublisher<Int, Never>, settings: Settings) -> AnyPublisher<String?, Never> {
        unreadCount.combineLatest(settings.$shouldShowStatusBarIcon.publisher, settings.$shouldShowUnreadMailInStatusBar.publisher)
            .map {
                switch ($0, $1, $2) {
                case (let count, true, true) where count > 0: return "status-bar-unread"
                case (_, true, _): return "status-bar"
                default: return nil
                }
            }
            .eraseToAnyPublisher()
    }
}
