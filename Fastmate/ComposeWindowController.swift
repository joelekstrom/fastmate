import Cocoa
import Combine
import WebKit

class ComposeWindowController: NSWindowController, NSWindowDelegate {
    private var subscriptions = Set<AnyCancellable>()

    override func windowDidLoad() {
        super.windowDidLoad()
        setupSubscribers()
    }

    func setupSubscribers() {
        guard let composeViewController = contentViewController as? WebViewController, let window = window else {
            return
        }

        composeViewController.publisher(for: \.webView?.title)
            .replaceNil(with: "Fastmate")
            .assign(to: \.title, on: window)
            .store(in: &subscriptions)

        UserDefaults.standard.publisher(for: \.composeWindowFrame)
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
            .assign(to: \.composeWindowFrame, on: UserDefaults.standard)
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

