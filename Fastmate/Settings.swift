import Cocoa
import Combine

enum UserDefaultsKey: String {
    case shouldUseTransparentTitleBar
    case mainWindowFrame
    case windowBackgroundColor
    case lastUpdateCheckDate
    case automaticUpdateChecks
    case watchedFolderType
    case watchedFolders
    case shouldShowStatusBarIcon
    case shouldUseFastmailBeta

    case shouldShowUnreadMailIndicator
    case shouldShowUnreadMailInDock
    case shouldShowUnreadMailCountInDock
    case shouldShowUnreadMailInStatusBar
}

enum WatchedFolderType: Int {
    case selected
    case all
    case specific
}

class Settings {
    static var shared = Settings()

    @UserDefault(key: .shouldUseTransparentTitleBar, defaultValue: true)
    var shouldUseTransparentTitleBar: Bool

    @UserDefault(key: .mainWindowFrame, defaultValue: nil)
    var mainWindowFrame: String?

    @UserDefault(key: .windowBackgroundColor, defaultValue: Settings.defaultWindowBackgroundColor)
    var windowBackgroundColor: Data

    @UserDefault(key: .lastUpdateCheckDate, defaultValue: Date.distantPast)
    var lastUpdateCheckDate: Date

    @UserDefault(key: .automaticUpdateChecks, defaultValue: true)
    var automaticUpdateChecks: Bool

    @UserDefault(key: .watchedFolderType, defaultValue: WatchedFolderType.selected.rawValue)
    var watchedFolderType: Int

    @UserDefault(key: .shouldShowUnreadMailInDock, defaultValue: true)
    var shouldShowUnreadMailInDock: Bool

    @UserDefault(key: .shouldShowUnreadMailCountInDock, defaultValue: true)
    var shouldShowUnreadMailCountInDock: Bool

    @UserDefault(key: .shouldShowUnreadMailInStatusBar, defaultValue: true)
    var shouldShowUnreadMailInStatusBar: Bool

    @UserDefault(key: .watchedFolders, defaultValue: nil)
    var watchedFolders: String?

    @UserDefault(key: .shouldShowStatusBarIcon, defaultValue: true)
    var shouldShowStatusBarIcon: Bool

    @UserDefault(key: .shouldUseFastmailBeta, defaultValue: false)
    var shouldUseFastmailBeta: Bool

    private static var defaultWindowBackgroundColor: Data {
        let color = NSColor(red: 0.14, green: 0.22, blue: 0.35, alpha: 1.0)
        return try! NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: true)
    }
}

protocol PropertyListValue {}
extension Data: PropertyListValue {}
extension String: PropertyListValue {}
extension Date: PropertyListValue {}
extension Bool: PropertyListValue {}
extension Int: PropertyListValue {}
extension Double: PropertyListValue {}
extension Float: PropertyListValue {}
extension Optional: PropertyListValue where Wrapped: PropertyListValue {}
extension Array: PropertyListValue where Element: PropertyListValue {}
extension Dictionary: PropertyListValue where Key == String, Value: PropertyListValue {}

protocol OptionalProtocol {
    func isSome() -> Bool
}

extension Optional: OptionalProtocol {
    func isSome() -> Bool {
        switch self {
        case .none: return false
        case .some: return true
        }
    }
}

@propertyWrapper
struct UserDefault<T: PropertyListValue> {
    let key: UserDefaultsKey
    let publisher: CurrentValueSubject<T, Never>

    public init(key: UserDefaultsKey, defaultValue: T) {
        self.key = key
        var value = defaultValue
        if let stored = UserDefaults.standard.value(forKey: key.rawValue) as? T {
            value = stored
        }
        let publisher = CurrentValueSubject<T, Never>(value)
        self.publisher = publisher
        self.observer = DefaultsObservation(key: key) {_, new in publisher.value = new ?? defaultValue }
    }

    var projectedValue: UserDefault<T> { return self }
    private let observer: DefaultsObservation<T>

    var wrappedValue: T {
        get { publisher.value }
        set {
            publisher.send(newValue)
            if newValue is OptionalProtocol {
                if (newValue as! OptionalProtocol).isSome() == false {
                    UserDefaults.standard.removeObject(forKey: key.rawValue)
                    return
                }
            }
            UserDefaults.standard.set(newValue, forKey: key.rawValue)
        }
    }
}

class DefaultsObservation<T: PropertyListValue>: NSObject {
    let key: UserDefaultsKey
    private var onChange: (T?, T?) -> Void

    init(key: UserDefaultsKey, onChange: @escaping (T?, T?) -> Void) {
        self.onChange = onChange
        self.key = key
        super.init()
        UserDefaults.standard.addObserver(self, forKeyPath: key.rawValue, options: [.old, .new], context: nil)
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        guard let change = change, object != nil, keyPath == key.rawValue else { return }
        onChange(change[.oldKey] as? T, change[.newKey] as? T)
    }

    deinit {
        UserDefaults.standard.removeObserver(self, forKeyPath: key.rawValue, context: nil)
    }
}

