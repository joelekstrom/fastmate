import Foundation
import Combine

class FastmateAppDelegate: NSObject, NSApplicationDelegate {

    let mainWindowPublisher = CurrentValueSubject<NSWindow?, Never>(nil)

    private let urlEventHandler = URLEventHandler()

    private var subscriptions = Set<AnyCancellable>()
    private let statusItemPublisher = CurrentValueSubject<NSStatusItem?, Never>(nil)

    static var shared = { NSApplication.shared.delegate as! FastmateAppDelegate }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupSubscriptions()

        DispatchQueue.global().async {
            self.createUserScriptsFolderIfNeeded()
        }

        VersionChecker.setup()
    }

    func setupSubscriptions() {
        let settings = Settings.shared

        let mainWebViewPublisher = mainWindowPublisher
            .compactMap { $0?.contentViewController as? WebViewController }

        let unreadCount = mainWebViewPublisher
            .map { $0.unreadCount }
            .switchToLatest()
            .share()

        unreadCount
            .statusItemState(with: settings)
            .sink {
                self.setStatusItemVisible($0 != .hidden)
                self.statusItemPublisher.value?.button?.image = $0.image()
            }
            .store(in: &subscriptions)

        unreadCount
            .dockBadgeLabel(with: settings)
            .assign(to: \.badgeLabel, on: NSApplication.shared.dockTile)
            .store(in: &subscriptions)

        statusItemPublisher
            .compactMap { $0?.button?.publisher }
            .switchToLatest()
            .sink {
                NSApp.unhide(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
            .store(in: &subscriptions)

        // TODO: Move to web view controller when migrated
        NotificationCenter.default.publisher(for: NSWorkspace.didWakeNotification)
            .flatMap { _ in mainWebViewPublisher }
            .sink { $0.reload() }
            .store(in: &subscriptions)

        Publishers.MainMenu(path: "File", "New mail")
            .flatMap { mainWebViewPublisher }
            .sink { $0.composeNewEmail() }
            .store(in: &subscriptions)

        Publishers.MainMenu(path: "Edit", "Find…")
            .flatMap { mainWebViewPublisher }
            .sink { $0.focusSearchField() }
            .store(in: &subscriptions)

        Publishers.MainMenu(path: "File", "Print…")
            .flatMap { mainWebViewPublisher }
            .compactMap { $0.webView ?? nil }
            .sink { PrintManager.sharedInstance().print($0) }
            .store(in: &subscriptions)

        // FIXME: Doesn't work when called by launching the app. Make a publisher that waits until Fastmail loads
        // before calling handleMailtoURL (needs web view migration)
        urlEventHandler.mailtoURLPublisher
            .flatMap { mainWebViewPublisher.zip(Just($0)) }
            .sink { $0.handleMailtoURL($1) }
            .store(in: &subscriptions)
    }

    func setStatusItemVisible(_ visible: Bool) {
        if visible, statusItemPublisher.value == nil {
            statusItemPublisher.value = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        } else if visible == false, let item = statusItemPublisher.value {
            NSStatusBar.system.removeStatusItem(item)
            statusItemPublisher.value = nil
        }
    }

    // TODO: Move to a UserScriptController-class after web view migration
    func createUserScriptsFolderIfNeeded() {
        let path = (NSHomeDirectory() as NSString).appendingPathComponent("userscripts")
        var folderExists = ObjCBool(false)
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

class URLEventHandler {
    let mailtoURLPublisher = PassthroughSubject<URL, Never>()

    init() {
        NSAppleEventManager.shared().setEventHandler(self, andSelector: #selector(handleURLEvent(event:_:)), forEventClass:AEEventClass(kInternetEventClass), andEventID:AEEventID(kAEGetURL))
    }

    @objc func handleURLEvent(event: NSAppleEventDescriptor, _ : NSAppleEventDescriptor) {
        let descriptor = event.paramDescriptor(forKeyword: keyDirectObject)
        if let urlString = descriptor?.stringValue, let mailtoURL = URL(string: urlString) {
            mailtoURLPublisher.send(mailtoURL)
        }
    }
}
