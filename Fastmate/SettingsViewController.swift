import Foundation
import Cocoa
import Combine

class SettingsViewController: NSViewController {

    @IBOutlet weak var watchedFolderTypeButtonInbox: PublishedButton!
    @IBOutlet weak var watchedFolderTypeButtonAll: PublishedButton!
    @IBOutlet weak var watchedFolderTypeButtonSpecific: PublishedButton!
    @IBOutlet weak var userScriptsFolderButton: PublishedButton!
    @IBOutlet weak var watchedFoldersTextField: NSTextField!

    var subscriptions = Set<AnyCancellable>()

    override func viewDidLoad() {
        super.viewDidLoad()
        let settings = Settings.shared

        settings.$watchedFolderType.publisher
            .map { WatchedFolderType(rawValue: $0) ?? .inbox }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.set(watchedFolderType: $0) }
            .store(in: &subscriptions)

        let buttonTapped = Publishers.Merge3(
            watchedFolderTypeButtonInbox.publisher.map { WatchedFolderType.inbox },
            watchedFolderTypeButtonSpecific.publisher.map { WatchedFolderType.specific },
            watchedFolderTypeButtonAll.publisher.map { WatchedFolderType.all })

        buttonTapped
            .sink { settings.watchedFolderType = $0.rawValue }
            .store(in: &subscriptions)

        userScriptsFolderButton.publisher
            .map { (NSHomeDirectory() as NSString).appendingPathComponent("userscripts") }
            .sink { NSWorkspace.shared.openFile($0) }
            .store(in: &subscriptions)

        let folderTextFieldEnabled = Publishers.CombineLatest4(
            settings.$shouldShowUnreadMailIndicator.publisher,
            settings.$shouldShowUnreadMailInDock.publisher,
            settings.$shouldShowUnreadMailCountInDock.publisher,
            settings.$watchedFolderType.publisher)
            .map { $0 && $1 && $2 && $3 == WatchedFolderType.specific.rawValue }

        folderTextFieldEnabled
            .receive(on: DispatchQueue.main)
            .assign(to: \.isEnabled, on: watchedFoldersTextField)
            .store(in: &subscriptions)
    }

    func set(watchedFolderType: WatchedFolderType) {
        watchedFolderTypeButtonInbox?.state = watchedFolderType == .inbox ? .on : .off
        watchedFolderTypeButtonAll?.state = watchedFolderType == .all  ? .on : .off
        watchedFolderTypeButtonSpecific?.state = watchedFolderType == .specific ? .on : .off
    }
}

class PublishedButton: NSButton {
    lazy var publisher: AnyPublisher<Void, Never> = {
        self.target = self
        self.action = #selector(buttonClicked)
        return subject.eraseToAnyPublisher()
    }()

    private var subject = PassthroughSubject<Void, Never>()

    @objc func buttonClicked() {
        subject.send()
    }
}
