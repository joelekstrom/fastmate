import Cocoa
import Combine
import WebKit
import Logic

class WindowController: NSWindowController, NSWindowDelegate {

    private var subscriptions = Set<AnyCancellable>()

    override func windowDidLoad() {
        super.windowDidLoad()
        setupSubscribers(notificationCenter: NotificationCenter.default, settings: Settings.shared)

        // Fixes that we can't trust that the main window exists in applicationDidFinishLaunching:.
        // Here we always know that this content view controller will be the main web view controller,
        // so inform the app delegate
        FastmateAppDelegate.shared.mainWindow.value = window

        // Should be removed
        let appDelegate = NSApplication.shared.delegate as? AppDelegate
        appDelegate?.mainWebViewController = contentViewController as? WebViewController
    }

    func setupSubscribers(notificationCenter: NotificationCenter, settings: Settings) {
        guard let webViewController = contentViewController as? WebViewController, let window = window else {
            return
        }

        webViewController.publisher(for: \.webView?.title)
            .replaceNil(with: "Fastmate")
            .assign(to: \.title, on: window)
            .store(in: &subscriptions)

        settings.$mainWindowFrame.publisher
            .first()
            .compactMap { ($0 != nil) ? NSRectFromString($0!) : nil }
            .sink(receiveValue: { window.setFrame($0, display: false) })
            .store(in: &subscriptions)

        let transparentTitleBarPublisher = settings.$shouldUseTransparentTitleBar.publisher
            .removeDuplicates()

        transparentTitleBarPublisher
            .assign(to: \NSWindow.titlebarAppearsTransparent, on: window)
            .store(in: &subscriptions)

        transparentTitleBarPublisher
            .map { (transparent) -> NSWindow.TitleVisibility in transparent ? .hidden : .visible }
            .assign(to: \.titleVisibility, on: window)
            .store(in: &subscriptions)

        notificationCenter.publisher(for: NSWindow.didResizeNotification, object: window)
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .map { return NSStringFromRect(($0.object as! NSWindow).frame) }
            .assign(to: \.mainWindowFrame, on: settings)
            .store(in: &subscriptions)

        settings.$windowBackgroundColor.publisher
            .removeDuplicates()
            .map { try! NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: $0) }
            .assign(to: \.backgroundColor, on: window)
            .store(in: &subscriptions)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        NSApp.hide(sender)
        return false
    }
}
