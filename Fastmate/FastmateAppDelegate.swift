import Foundation
import Combine

class FastmateAppDelegate: NSObject, NSApplicationDelegate {

    let didFinishLaunching = PassthroughSubject<Void, Never>()
    let checkForNewVersionAction = PassthroughSubject<Void, Never>()
    let unreadCountObserver = UnreadCountObserver()

    var statusItemVisibleSubscription: AnyCancellable?
    var statusItemButtonSubscription: AnyCancellable?
    var statusItem: NSStatusItem?

    static var shared: FastmateAppDelegate {
//        NSApplication.shared.delegate as! FastmateAppDelegate
        (NSApplication.shared.delegate as! AppDelegate).forwardingSwiftDelegate
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        didFinishLaunching.send()
        VersionChecker.setup()

        statusItemVisibleSubscription = Settings.shared.$shouldShowStatusBarIcon.publisher
            .removeDuplicates()
            .sink { self.setStatusItemVisible($0) }
    }

    func setStatusItemVisible(_ visible: Bool) {
        if (visible) {
            let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            unreadCountObserver.statusItem = statusItem
            statusItemButtonSubscription = statusItem.button?.publisher
                .print()
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
}
