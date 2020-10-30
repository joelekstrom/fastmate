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

protocol PropertyListValue: Equatable {}
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
    var isSome: Bool { get }
    var isNil: Bool { get }
}

extension Optional: OptionalProtocol {
    var isSome: Bool {
        switch self {
        case .none: return false
        case .some: return true
        }
    }

    var isNil: Bool { !isSome }
}

@propertyWrapper
class UserDefault<T: PropertyListValue> {
    let key: String
    private let subject: CurrentValueSubject<T, Never>
    private let defaults: UserDefaults
    private let subscription: AnyCancellable?

    public init(key: UserDefaultsKey, defaultValue: T, defaults: UserDefaults = UserDefaults.standard) {
        self.key = key.rawValue
        self.defaults = defaults
        var value = defaultValue
        if let stored = defaults.value(forKey: key.rawValue) as? T {
            value = stored
        }
        let subject = CurrentValueSubject<T, Never>(value)
        self.subject = subject
        self.observer = DefaultsObservation<T>(key: key.rawValue, defaults: defaults) { _, new in
            subject.value = new ?? defaultValue
        }

        subscription = subject
            .dropFirst()
            .removeDuplicates()
            .sink {
                if let optional = $0 as? OptionalProtocol, optional.isNil {
                    defaults.removeObject(forKey: key.rawValue)
                } else {
                    defaults.set($0, forKey: key.rawValue)
                }
            }
    }

    var projectedValue: CurrentValueSubject<T, Never> { self.subject }
    private let observer: DefaultsObservation<T>

    var wrappedValue: T {
        get { subject.value }
        set { subject.value = newValue }
    }
}

class DefaultsObservation<T: PropertyListValue>: NSObject {
    let key: String
    private var onChange: (T?, T?) -> Void
    private let defaults: UserDefaults

    init(key: String, defaults: UserDefaults, onChange: @escaping (T?, T?) -> Void) {
        self.onChange = onChange
        self.key = key
        self.defaults = defaults
        super.init()
        defaults.addObserver(self, forKeyPath: key, options: [.old, .new], context: nil)
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        guard let change = change, object != nil, keyPath == key else { return }
        onChange(change[.oldKey] as? T, change[.newKey] as? T)
    }

    deinit {
        defaults.removeObserver(self, forKeyPath: key, context: nil)
    }
}

