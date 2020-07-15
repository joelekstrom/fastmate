import Foundation
import Combine
import Logic

struct Versions {
    typealias Error = RedirectTrap.Error

    let current: AnyPublisher<String, Never>
    let latest: AnyPublisher<(String, URL), Error>
    let combined: AnyPublisher<(String, (String, URL)), Error>

    init(current: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String,
         checkURL: URL = URL(string: "https://github.com/joelekstrom/fastmate/releases/latest")!) {
        self.current = Just(current).eraseToAnyPublisher()

        latest = RedirectTrap.publisher(for: checkURL)
            .map { ($0.lastPathComponent.trimmingCharacters(in: CharacterSet.lowercaseLetters), $0) }
            .eraseToAnyPublisher()

        combined = self.current
            .setFailureType(to: Error.self)
            .combineLatest(latest)
            .handleEvents(receiveOutput: { _ in Settings.shared.lastUpdateCheckDate = Date() })
            .eraseToAnyPublisher()
    }
}

struct VersionChecker {
    typealias Error = RedirectTrap.Error

    private static var subscriptions = Set<AnyCancellable>()

    static func setup() {
        let versions = Versions()

        let manualUpdateChecker = versions.combined
            .map { .manualVersionCheckConfigurationFor($0) }
            .catch { Just(.versionCheckFailed($0)) }
            .displayAlert()
            .compactMap { return $0.modalResponse == .alertFirstButtonReturn ? ($0.userInfo as? URL) : nil }

        let automaticUpdateChecker = versions.combined
            .map { .automaticVersionCheckConfigurationFor($0) }
            .catch { _ in Just(nil) }
            .compactMap { $0 }
            .displayAlert()
            .handleEvents(receiveOutput: { Settings.shared.automaticUpdateChecks = ($0.suppressButtonState ?? .on) == .on } )
            .compactMap { return $0.modalResponse == .alertFirstButtonReturn ? ($0.userInfo as? URL) : nil }

        FastmateAppDelegate.shared.checkForNewVersionAction
            .map { manualUpdateChecker }
            .switchToLatest()
            .sink { NSWorkspace.shared.open($0) }
            .store(in: &subscriptions)

        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .map { _ in (Settings.shared.automaticUpdateChecks, Settings.shared.lastUpdateCheckDate) }
            .filter { return $0 && Calendar.current.dateComponents([.day], from: $1, to: Date()).day ?? 0 >= 7 }
            .map { _ in automaticUpdateChecker }
            .switchToLatest()
            .sink { NSWorkspace.shared.open($0) }
            .store(in: &subscriptions)
    }
}

extension Alert.Configuration {
    typealias Versions = (current: String, latest: (String, URL))

    static func manualVersionCheckConfigurationFor(_ versions: Versions) -> Self {
        let newVersionAvailable = versions.latest.0 > versions.current
        return newVersionAvailable ? newVersion(versions) : usingLatestVersion(versions.current)
    }

    static func automaticVersionCheckConfigurationFor(_ versions: Versions) -> Self? {
        var config: Self?
        if versions.latest.0 > versions.current {
            config = newVersion(versions)
            config!.suppressionButtonTitle = "Check for new versions automatically"
            config!.suppressionButtonState = .on
        }
        return config
    }

    static func newVersion(_ versions: Versions) -> Self {
        .init(
            messageText: "New version available: \(versions.latest.0)",
            informativeText: "You're currently using \(versions.current)",
            buttonTitles: ["Take me there!", "Cancel"],
            userInfo: versions.latest.1
        )
    }

    static func usingLatestVersion(_ version: String) -> Self {
        Alert.Configuration(
            messageText: "Up to date!",
            informativeText: "You're on the latest version. (\(version))",
            buttonTitles: ["Nice!"]
        )
    }

    static func versionCheckFailed(_ error: RedirectTrap.Error) -> Self {
        Alert.Configuration(
            messageText: "Couldn't fetch latest version",
            informativeText: error.localizedDescription,
            buttonTitles: ["Darn it!"],
            style: .warning
        )
    }
}
