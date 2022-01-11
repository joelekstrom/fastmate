import Cocoa
import Combine
import WebKit

class MainWindowController: NSWindowController, NSWindowDelegate {
    private var subscriptions = Set<AnyCancellable>()

    override func windowDidLoad() {
        super.windowDidLoad()
        setupSubscribers()

        // Fixes that we can't trust that the main window exists in applicationDidFinishLaunching:.
        // Here we always know that this content view controller will be the main web view controller,
        // so inform the app delegate
        let appDelegate = NSApplication.shared.delegate as? AppDelegate
        appDelegate?.mainWebViewController = contentViewController as? WebViewController
    }

    func setupSubscribers() {
        guard let webViewController = contentViewController as? WebViewController, let window = window else {
            return
        }

        webViewController.webView.publisher(for: \.title)
            .replaceNil(with: "Fastmate")
            .assign(to: \.title, on: window)
            .store(in: &subscriptions)

        UserDefaults.standard.publisher(for: \.mainWindowFrame)
            .filter { $0 != NSRect.zero }
            .first()
            .sink { window.setFrame($0, display: false) }
            .store(in: &subscriptions)

        UserDefaults.standard.publisher(for: \.shouldUseTransparentTitleBar)
            .sink {
                window.titlebarAppearsTransparent = $0
                window.titleVisibility = $0 ? .hidden : .visible
            }
            .store(in: &subscriptions)

        NotificationCenter.default.publisher(for: NSWindow.didResizeNotification, object: window)
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .compactMap { ($0.object as? NSWindow)?.frame }
            .assign(to: \.mainWindowFrame, on: UserDefaults.standard)
            .store(in: &subscriptions)

        UserDefaults.standard.publisher(for: \.lastUsedWindowColor)
            .assign(to: \.backgroundColor, on: window)
            .store(in: &subscriptions)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        NSApp.hide(sender)
        return false
    }
}

