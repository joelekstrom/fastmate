import Foundation
import Cocoa
import Combine

class SettingsViewController: NSViewController {

    @IBOutlet weak var watchedFolderTypeButtonInbox: NSButton!
    @IBOutlet weak var watchedFolderTypeButtonAll: NSButton!
    @IBOutlet weak var watchedFolderTypeButtonSpecific: NSButton!
    @IBOutlet weak var showUnreadInStatusBarButton: NSButton!
    @IBOutlet weak var showUnreadCountInDockButton: NSButton!
    @IBOutlet weak var userScriptsFolderButton: NSButton!
    @IBOutlet weak var watchedFoldersTextField: NSTextField!

    var subscriptions = Set<AnyCancellable>()

    override func viewDidLoad() {
        super.viewDidLoad()
        let settings = Settings.shared

        let watchedFolderType = settings.$watchedFolderType.publisher
            .map { WatchedFolderType(rawValue: $0) ?? .selected }
            .receive(on: DispatchQueue.main)

        watchedFolderType
            .sink { [weak self] in self?.set(watchedFolderType: $0) }
            .store(in: &subscriptions)

        watchedFolderType
            .map { $0 == .specific }
            .assign(to: \.isEnabled, on: watchedFoldersTextField)
            .store(in: &subscriptions)

        settings.$shouldShowStatusBarIcon.publisher
            .receive(on: DispatchQueue.main)
            .assign(to: \.isEnabled, on: showUnreadInStatusBarButton)
            .store(in: &subscriptions)

        settings.$shouldShowUnreadMailInDock.publisher
            .receive(on: DispatchQueue.main)
            .assign(to: \.isEnabled, on: showUnreadCountInDockButton)
            .store(in: &subscriptions)

        Publishers.Merge3(
            watchedFolderTypeButtonInbox.publisher.map { WatchedFolderType.selected },
            watchedFolderTypeButtonSpecific.publisher.map { WatchedFolderType.specific },
            watchedFolderTypeButtonAll.publisher.map { WatchedFolderType.all })
            .map(\.rawValue)
            .assign(to: \.watchedFolderType, on: settings)
            .store(in: &subscriptions)

        userScriptsFolderButton.publisher
            .map { (NSHomeDirectory() as NSString).appendingPathComponent("userscripts") }
            .sink { NSWorkspace.shared.openFile($0) }
            .store(in: &subscriptions)
    }

    func set(watchedFolderType: WatchedFolderType) {
        watchedFolderTypeButtonInbox?.state = watchedFolderType == .selected ? .on : .off
        watchedFolderTypeButtonAll?.state = watchedFolderType == .all  ? .on : .off
        watchedFolderTypeButtonSpecific?.state = watchedFolderType == .specific ? .on : .off
    }
}
