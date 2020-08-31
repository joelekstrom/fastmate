import Combine

// Extracts total unread count from a dictionary with folder name -> count
func totalUnreadCount(for folders: [String: Int]) -> Int {
    folders.reduce(0, { $0 + $1.value })
}

// Extracts unread count from a Fastmail web view title
func extractUnreadCount(from title: String) -> Int {
    let regex = try! NSRegularExpression(pattern: "^(\\d+) •", options: .anchorsMatchLines)
    let result = regex.firstMatch(in: title, options: [], range: NSRange(location: 0, length: title.count))
    if let result = result, result.numberOfRanges > 1 {
        let range = Range(result.range(at: 1), in: title)!
        let countString = title[range]
        return Int(String(countString)) ?? 0
    }
    return 0
}

typealias UnreadCountPublisher = AnyPublisher<Int, Never>

extension WebViewController {
    var unreadCount: UnreadCountPublisher {
        guard let webView = webView else { fatalError() }

        let titleCount = webView.publisher(for: \.title)
            .compactMap { $0 }
            .map(extractUnreadCount(from:))

        let allFoldersCount = $mailboxCounts
            .map(totalUnreadCount(for:))

        let specificFoldersCount = $mailboxCounts.combineLatest(Settings.shared.$watchedFolders.publisher)
            .map { mailboxes, watchedFolderString in
                let watchedFolders = watchedFolderString?
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                return mailboxes.filter { title, _ in watchedFolders?.contains(title) ?? false }
        }
        .map(totalUnreadCount(for:))

        return Settings.shared.$watchedFolderType.publisher
            .compactMap { type -> UnreadCountPublisher? in
                switch WatchedFolderType(rawValue: type) {
                case .selected: return titleCount.eraseToAnyPublisher()
                case .all: return allFoldersCount.eraseToAnyPublisher()
                case .specific: return specificFoldersCount.eraseToAnyPublisher()
                default: return nil
                }
        }
        .switchToLatest()
        .removeDuplicates()
        .eraseToAnyPublisher()
    }
}

