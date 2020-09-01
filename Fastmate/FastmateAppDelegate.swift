import Foundation
import Combine
import Cocoa

class FastmateAppDelegate: NSObject, NSApplicationDelegate {

    static var shared = { NSApplication.shared.delegate as! FastmateAppDelegate }()

    @Published var mainWindow: NSWindow?
    @Published private var statusItem: NSStatusItem?
    let urlPublisher = PassthroughSubject<URL, Never>()

    private var subscriptions = Set<AnyCancellable>()
    private var versionChecker: VersionChecker!

    func applicationWillFinishLaunching(_ notification: Notification) {
        setupSubscriptions()
        FastmateNotificationCenter.shared.registerForNotifications()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.global().async {
            self.createUserScriptsFolderIfNeeded()
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

        urlPublisher
            .flatMap {
                mainWebViewPublisher
                    .first()
                    .zip(Just($0))
            }
            .sink { $0.externalURLSubject.send($1) }
            .store(in: &subscriptions)

        FastmateNotificationCenter.shared.notificationClickPublisher
            .flatMap {
                mainWebViewPublisher
                    .first()
                    .zip(Just($0))
            }
            .sink { $0.handleNotificationClick($1) }
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

    func createUserScriptsFolderIfNeeded() {
        var folderExists = ObjCBool(false)
        let path = ScriptController.userScriptsDirectoryPath
        FileManager.default.fileExists(atPath: path, isDirectory: &folderExists)
        if folderExists.boolValue == false {
            createUserScriptsFolder(path: path)
        }
    }

    func createUserScriptsFolder(path: String) {
        let readmePath = (path as NSString).appendingPathComponent("README.txt")
        let readmeData = """
        Fastmate user scripts\n\n
        Put JavaScript files in this folder (.js), and Fastmate will load them at document end after loading the Fastmail website.\n
        """.data(using: .utf8)
        do {
            try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: false, attributes: nil)
            FileManager.default.createFile(atPath: readmePath, contents: readmeData, attributes: nil)
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        if let url = urls.first {
            urlPublisher.send(url)
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
