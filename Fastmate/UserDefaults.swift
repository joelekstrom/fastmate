import Foundation
import Combine
import AppKit

extension UserDefaults {
    func registerFastmateDefaults() {
        register(defaults: [
            #keyPath(arrowNavigatesMessageList): false,
            #keyPath(automaticUpdateChecks): true,
            #keyPath(downloadsPath): NSSearchPathForDirectoriesInDomains(.downloadsDirectory, .userDomainMask, true).first!,
            #keyPath(downloadBehavior): DownloadBehaviorType.keep.rawValue,
            #keyPath(shouldShowStatusBarIcon): false,
            #keyPath(shouldShowUnreadMailIndicator): true,
            #keyPath(shouldShowUnreadMailInDock): true,
            #keyPath(shouldShowUnreadMailCountInDock): true,
            #keyPath(shouldShowUnreadMailInStatusBar): true,
            #keyPath(shouldOpenSafeDownloads): true,
            #keyPath(shouldUseFastmailBeta): false,
            #keyPath(shouldUseTransparentTitleBar): true,
            #keyPath(watchedFolderType): WatchedFolderType.selected.rawValue,
            #keyPath(watchedFolders): "",
            #keyPath(shouldDownloadInExternalBrowser): false,
            #keyPath(zoomLevel): 1.0
        ])
    }

    // These variable names must exactly match the key string for KVO Combine publishers to work. #keyPath sort of verifies this
    @objc dynamic var downloadBehavior: DownloadBehaviorType { .init(rawValue: UInt(integer(forKey: #keyPath(downloadBehavior))))! }
    @objc dynamic var shouldShowStatusBarIcon: Bool { bool(forKey: #keyPath(shouldShowStatusBarIcon)) }
    @objc dynamic var shouldShowUnreadMailIndicator: Bool { bool(forKey: #keyPath(shouldShowUnreadMailIndicator)) }
    @objc dynamic var shouldShowUnreadMailInDock: Bool { bool(forKey: #keyPath(shouldShowUnreadMailInDock)) }
    @objc dynamic var shouldShowUnreadMailCountInDock: Bool { bool(forKey: #keyPath(shouldShowUnreadMailCountInDock)) }
    @objc dynamic var shouldShowUnreadMailInStatusBar: Bool { bool(forKey: #keyPath(shouldShowUnreadMailInStatusBar)) }
    @objc dynamic var shouldOpenSafeDownloads: Bool { bool(forKey: #keyPath(shouldOpenSafeDownloads)) }
    @objc dynamic var shouldUseFastmailBeta: Bool { bool(forKey: #keyPath(shouldUseFastmailBeta)) }
    @objc dynamic var shouldUseTransparentTitleBar: Bool { bool(forKey: #keyPath(shouldUseTransparentTitleBar)) }
    @objc dynamic var watchedFolderType: WatchedFolderType { .init(rawValue: UInt(integer(forKey: #keyPath(watchedFolderType))))! }
    @objc dynamic var watchedFolders: String { string(forKey: #keyPath(watchedFolders)) ?? "" }
    @objc dynamic var shouldDownloadInExternalBrowser: Bool { bool(forKey: #keyPath(shouldDownloadInExternalBrowser)) }
    @objc dynamic var zoomLevel: Double { double(forKey: #keyPath(zoomLevel)) }

    @objc dynamic var arrowNavigatesMessageList: Bool {
        get { bool(forKey: #keyPath(arrowNavigatesMessageList)) }
        set { set(newValue, forKey: #keyPath(arrowNavigatesMessageList)) }
    }

    @objc dynamic var automaticUpdateChecks: Bool {
        get { bool(forKey: #keyPath(automaticUpdateChecks)) }
        set { set(newValue, forKey: #keyPath(automaticUpdateChecks)) }
    }

    @objc dynamic var downloadsPath: String {
        get { string(forKey: #keyPath(downloadsPath)) ?? NSSearchPathForDirectoriesInDomains(.downloadsDirectory, .userDomainMask, true).first! }
        set { set(newValue, forKey: #keyPath(downloadsPath)) }
    }

    @objc dynamic var mainWindowFrame: NSRect {
        get { NSRectFromString(string(forKey: #keyPath(mainWindowFrame)) ?? "") }
        set { set(NSStringFromRect(newValue), forKey: #keyPath(mainWindowFrame)) }
    }

    @objc dynamic var lastUsedWindowColor: NSColor {
        data(forKey: #keyPath(lastUsedWindowColor))
            .flatMap { try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: $0) }
        ?? NSColor(red: 0.27, green: 0.34, blue: 0.49, alpha: 1.0)
    }
}

@objc enum WatchedFolderType: UInt {
    case selected
    case all
    case specific
}

@objc enum DownloadBehaviorType: UInt {
    case keep
    case overwrite
    case ask
}
