import Foundation
import Combine
import Logic
import Cocoa

struct Versions {
    let current: String
    let latest: String
    let latestURL: URL
    var newVersionAvailable: Bool { latest > current }
}

class VersionChecker {
    typealias Error = RedirectTrap.Error

    private var applicationDidBecomeActiveSubscription: AnyCancellable?
    private var currentVersionCheckSubscription: AnyCancellable?

    private let versions: AnyPublisher<Versions, Error>

    init(current: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String,
         checkURL: URL = URL(string: "https://github.com/joelekstrom/fastmate/releases/latest")!) {

        versions = RedirectTrap.publisher(for: checkURL)
            .map { ($0.lastPathComponent.trimmingCharacters(in: CharacterSet.lowercaseLetters), $0) }
            .map { Versions(current: current, latest: $0.0, latestURL: $0.1)  }
            .handleEvents(receiveOutput: { _ in Settings.shared.lastUpdateCheckDate = Date() })
            .eraseToAnyPublisher()

        let automaticUpdateChecksEnabled = Settings.shared.$automaticUpdateChecks
        let lastUpdateCheckDate = Settings.shared.$lastUpdateCheckDate
        applicationDidBecomeActiveSubscription = NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .zip(automaticUpdateChecksEnabled, lastUpdateCheckDate)
            .map(\.1, \.2)
            .filter(shouldCheckForUpdates)
            .sink { [weak self] _ in self?.performAutomaticUpdateCheck() }
    }

    func checkForUpdates() {
        performUserInitiatedUpdateCheck()
    }

    private func performUserInitiatedUpdateCheck() {
        currentVersionCheckSubscription = versions
            .map(\.alertBuilder)
            .catch { Just(Alert.Builder().withVersionCheckFailed($0)) }
            .presentModally()
            .compactMap { return $0.modalResponse == .alertFirstButtonReturn ? ($0.userInfo as? URL) : nil }
            .sink { NSWorkspace.shared.open($0) }
    }

    private func performAutomaticUpdateCheck() {
        currentVersionCheckSubscription = versions
            .filter(\.newVersionAvailable)
            .map(\.alertBuilder)
            .map { $0.with(suppressButton: (title: "Check for new versions automatically", state: .on)) as Alert.Builder? }
            .replaceError(with: nil)
            .compactMap { $0 }
            .presentModally()
            .compactMap { return $0.modalResponse == .alertFirstButtonReturn ? ($0.userInfo as? URL) : nil }
            .sink { NSWorkspace.shared.open($0) }
    }
}

private func shouldCheckForUpdates(autoUpdatesEnabled: Bool, lastUpdate: Date) -> Bool {
    guard autoUpdatesEnabled else { return false }
    let numberOfDaysSinceLastUpdateCheck = Calendar.current.dateComponents([.day], from: lastUpdate, to: Date()).day ?? 0
    return numberOfDaysSinceLastUpdateCheck >= 7
}

extension Versions {
    var alertBuilder: Alert.Builder {
        let builder = Alert.Builder()
        return newVersionAvailable
            ? builder.withNewVersionAvailable(versions: self)
            : builder.withVersionUpToDate(current)
    }
}

extension Alert.Builder {

    func withNewVersionAvailable(versions: Versions) -> Alert.Builder {
        self.with(text: "New version available: \(versions.latest)")
            .with(informativeText: "You're currently using \(versions.current)")
            .with(buttonTitles: ["Take me there!", "Cancel"])
            .with(userInfo: versions.latestURL) as! Self
    }

    func withVersionUpToDate(_ version: String) -> Alert.Builder {
        self.with(text: "Up to date!")
            .with(informativeText: "You're on the latest version. (\(version))")
            .with(buttonTitles: ["Nice!"])
    }

    func withVersionCheckFailed(_ error: RedirectTrap.Error) -> Alert.Builder {
        self.with(text: "Couldn't fetch latest version")
            .with(informativeText: error.errorDescription ?? "")
            .with(buttonTitles: ["Darn it!"])
            .with(style: .warning)
    }
}
