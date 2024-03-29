import Foundation
import AppKit
import Carbon.HIToolbox
import Combine

class FastmateApplication: NSApplication {
    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown {
            if (delegate as? AppDelegate)?.handleKey(event) == true {
                return // if the appDelegate handled the key, eat the event
            }
        }
        super.sendEvent(event)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var isAutomaticUpdateCheck = false
    private var subscriptions = Set<AnyCancellable>()
    private var notificationCenter = FastmateNotificationCenter()
    private var router = URLRouter()

    @Published var mainWebViewController: WebViewController? {
        didSet { mainWebViewController?.notificationHandler = notificationCenter.postNotifification(for:) }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.registerFastmateDefaults()
        notificationCenter.registerForNotifications()
        notificationCenter.clickHandler = { self.mainWebViewController?.handleNotificationClick(withIdentifier: $0) }

        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification, object: nil)
            .sink { _ in self.mainWebViewController?.reload() }
            .store(in: &subscriptions)

        UserDefaults.standard.publisher(for: \.shouldShowStatusBarIcon)
            .assign(to: \.statusItemVisible, on: self)
            .store(in: &subscriptions)

        let unreadCountPublisher = $mainWebViewController
            .compactMap(\.?.unreadCountPublisher)
            .switchToLatest()
            .share()

        dockBadgeLabelPublisher(with: unreadCountPublisher.eraseToAnyPublisher())
            .assign(to: \.badgeLabel, on: NSApplication.shared.dockTile)
            .store(in: &subscriptions)

        statusItemImagePublisher(with: unreadCountPublisher.eraseToAnyPublisher())
            .combineLatest($statusItem)
            .sink { (image, statusItem) in statusItem?.button?.image = image }
            .store(in: &subscriptions)

        router.$baseURL
            .sink { self.mainWebViewController?.setBaseURL($0) }
            .store(in: &subscriptions)

        DispatchQueue.global().async {
            self.createUserScriptsFolderIfNeeded()
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        performAutomaticUpdateCheckIfNeeded()
    }

    @Published private var statusItem: NSStatusItem?
    private var statusItemVisible: Bool = false {
        didSet {
            if statusItemVisible {
                let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
                statusItem.button?.target = self
                statusItem.button?.action = #selector(statusItemSelected(sender:))
                self.statusItem = statusItem
            } else if let item = statusItem {
                NSStatusBar.system.removeStatusItem(item)
                statusItem = nil
            }
        }
    }

    @objc func statusItemSelected(sender: Any) {
        NSApp.unhide(sender)
        NSApp.activate(ignoringOtherApps: true)
    }

    func createUserScriptsFolderIfNeeded() {
        let path = (NSHomeDirectory() as NSString).appendingPathComponent("userscripts")
        var folderExists: ObjCBool = false
        FileManager.default.fileExists(atPath: path, isDirectory: &folderExists)

        guard folderExists.boolValue == false else {
            return
        }

        try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: false, attributes: nil)
        addUserScriptsREADMEInFolder(path)
    }

    func addUserScriptsREADMEInFolder(_ path: String) {
        let readmeFilePath = (path as NSString).appendingPathComponent("README.txt")
        let text = """
            Fastmate user scripts

            Put JavaScript files in this folder (.js), and Fastmate will load them at document end after loading the Fastmail website.

            Example:

            // fastmate.js
            alert("Hello! I'm an alert within Fastmate!");
            """
        FileManager.default.createFile(atPath: readmeFilePath, contents: text.data(using: .utf8), attributes: nil)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        if let route = router.route(for: urls.first) {
            mainWebViewController?.webView?.load(URLRequest(url: route))
        }
    }

    func dockBadgeLabelPublisher(with unreadCount: AnyPublisher<Int, Never>) -> AnyPublisher<String?, Never> {
        unreadCount
            .combineLatest(
                UserDefaults.standard.publisher(for: \.shouldShowUnreadMailIndicator),
                UserDefaults.standard.publisher(for: \.shouldShowUnreadMailInDock),
                UserDefaults.standard.publisher(for: \.shouldShowUnreadMailCountInDock)
            ).map { count, shouldShowAnyIndicator, shouldShowBadgeInDock, shouldShowCountInBadge in
                guard count > 0, shouldShowAnyIndicator, shouldShowBadgeInDock else { return nil }
                return shouldShowCountInBadge ? String(count) : " "
            }.eraseToAnyPublisher()
    }

    func statusItemImagePublisher(with unreadCount: AnyPublisher<Int, Never>) -> AnyPublisher<NSImage?, Never> {
        unreadCount
            .map { $0 > 0 }
            .combineLatest(
                UserDefaults.standard.publisher(for: \.shouldShowUnreadMailInStatusBar),
                UserDefaults.standard.publisher(for: \.shouldShowUnreadMailIndicator)
            )
            .map { $0 && $1 && $2 ? "status-bar-unread" : "status-bar" }
            .map(NSImage.init(imageLiteralResourceName:))
            .eraseToAnyPublisher()
    }
    
    @objc func currentURL() -> String? {
        return self.mainWebViewController?.webView?.url?.absoluteString
    }
    
    @objc func currentTitle() -> String? {
        return self.mainWebViewController?.webView?.title
    }
    
    @objc func application(_ sender: NSApplication, delegateHandlesKey key: String) -> Bool {
        return ["currentURL","currentTitle"].contains(key)
    }
    
    
}

// MARK: Update checks
extension AppDelegate: VersionCheckerDelegate {
    func performAutomaticUpdateCheckIfNeeded() {
        guard UserDefaults.standard.automaticUpdateChecks else {
            return
        }

        let lastUpdateCheckDate = VersionChecker.sharedInstance().lastUpdateCheckDate()
        let components = NSCalendar.current.dateComponents([.day], from: lastUpdateCheckDate, to: Date())
        if components.day ?? 0 >= 7 {
            isAutomaticUpdateCheck = true
            checkForUpdates()
        }
    }

    func checkForUpdates() {
        VersionChecker.sharedInstance().delegate = self
        VersionChecker.sharedInstance().checkForUpdates()
    }

    func versionCheckerDidFindNewVersion(_ latestVersion: String, with latestVersionURL: URL) {
        guard let window = mainWebViewController?.view.window else {
            return
        }

        let alert = NSAlert()
        alert.addButton(withTitle: "Take me there!")
        alert.addButton(withTitle: "Cancel")
        alert.messageText = "New version available: \(latestVersion)"
        if let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
            alert.informativeText = "You're currently at v\(currentVersion)"
        }
        alert.alertStyle = .informational
        alert.showsSuppressionButton = self.isAutomaticUpdateCheck
        alert.suppressionButton?.title = "Check for new versions automatically"
        alert.suppressionButton?.state = .on

        alert.beginSheetModal(for: window) { response in
            if response == .alertFirstButtonReturn {
                NSWorkspace.shared.open(latestVersionURL)
            }

            if alert.suppressionButton?.state == .off {
                UserDefaults.standard.automaticUpdateChecks = false
            }
        }
    }

    func versionCheckerDidNotFindNewVersion() {
        guard !isAutomaticUpdateCheck, let window = mainWebViewController?.view.window else {
            return
        }

        let alert = NSAlert()
        alert.addButton(withTitle: "Nice!")
        alert.messageText = "Up to date!"
        if let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
            alert.informativeText = "You're on the latest version. (v\(currentVersion))"
        }
        alert.alertStyle = .informational
        alert.beginSheetModal(for: window, completionHandler: nil)
    }
}

// MARK: Actions
extension AppDelegate {
    @IBAction func checkForUpdates(_ sender: Any?) {
        isAutomaticUpdateCheck = false
        checkForUpdates()
    }

    @IBAction func newDocument(_ sender: Any?) {
        mainWebViewController?.composeNewEmail()
    }

    @IBAction func performFindPanelAction(_ sender: Any?) {
        mainWebViewController?.focusSearchField()
    }

    @IBAction func print(_ sender: Any?) {
        guard let webViewController = mainWebViewController else {
            return
        }
        PrintManager.sharedInstance().printControllerContent(webViewController)
    }

    @objc func handleKey(_ event: NSEvent) -> Bool {
        guard UserDefaults.standard.arrowNavigatesMessageList else { return false }
        switch Int(event.keyCode) {
        case kVK_UpArrow: return mainWebViewController?.nextMessage() ?? false
        case kVK_DownArrow: return mainWebViewController?.previousMessage() ?? false
        default: return false
        }
    }
}
