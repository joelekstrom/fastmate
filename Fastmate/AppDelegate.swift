import Foundation
import AppKit
import Carbon.HIToolbox

class AppDelegate: NSObject, NSApplicationDelegate {
    private var workspaceDidWakeObserver: Any?
    private var statusBarIconObserver: KVOBlockObserver?
    private var isAutomaticUpdateCheck = false

    lazy var unreadCountObserver = UnreadCountObserver()

    @objc var mainWebViewController: WebViewController? {
        didSet {
            unreadCountObserver.webViewController = mainWebViewController
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        workspaceDidWakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.mainWebViewController?.reload()
        }

        statusBarIconObserver = .observeUserDefaultsKey(ShouldShowStatusBarIconKey) {
            self.statusItemVisible = $0
        }

        DispatchQueue.global().async {
            self.createUserScriptsFolderIfNeeded()
        }

        FastmateNotificationCenter.sharedInstance().delegate = self
        FastmateNotificationCenter.sharedInstance().registerForNotifications()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        UserDefaults.standard.register(defaults: [
            ArrowNavigatesMessageListKey: false,
            AutomaticUpdateChecksKey: true,
            ShouldShowUnreadMailIndicatorKey: true,
            ShouldShowUnreadMailInDockKey: true,
            ShouldShowUnreadMailCountInDockKey: true,
            ShouldUseFastmailBetaKey: false,
            ShouldUseTransparentTitleBarKey: true
        ])

        performAutomaticUpdateCheckIfNeeded()
    }

    private var statusItem: NSStatusItem?
    private var statusItemVisible: Bool = false {
        didSet {
            if statusItemVisible {
                self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
                self.statusItem?.button?.target = self
                self.statusItem?.button?.action = #selector(statusItemSelected(sender:))
                self.unreadCountObserver.statusItem = self.statusItem
            } else if let item = statusItem {
                NSStatusBar.system.removeStatusItem(item)
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
            """
        FileManager.default.createFile(atPath: readmeFilePath, contents: text.data(using: .utf8), attributes: nil)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else {
            return
        }

        if url.scheme == "fastmate" {
            mainWebViewController?.handleFastmateURL(url)
        } else if url.scheme == "mailto" {
            mainWebViewController?.handleMailtoURL(url)
        }
    }
}

extension AppDelegate: FastmateNotificationCenterDelegate {
    func notificationCenter(_ center: FastmateNotificationCenter, notificationClickedWithIdentifier identifier: String) {
        mainWebViewController?.handleNotificationClick(withIdentifier: identifier)
    }
}

// MARK: Update checks
extension AppDelegate: VersionCheckerDelegate {
    func performAutomaticUpdateCheckIfNeeded() {
        guard UserDefaults.standard.bool(forKey: AutomaticUpdateChecksKey) == true else {
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
                UserDefaults.standard.set(false, forKey: AutomaticUpdateChecksKey)
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
        switch Int(event.keyCode) {
        case kVK_UpArrow:
            if UserDefaults.standard.bool(forKey: ArrowNavigatesMessageListKey) {
                return mainWebViewController?.nextMessage() ?? false
            } else {
                return false
            }

        case kVK_DownArrow:
            if UserDefaults.standard.bool(forKey: ArrowNavigatesMessageListKey) {
                return mainWebViewController?.previousMessage() ?? false
            } else {
                return false
            }

        case kVK_Delete:
            return mainWebViewController?.deleteMessage() ?? false

        default:
            return false
        }
    }
}
