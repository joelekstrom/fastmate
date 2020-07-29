import Combine

// Extracts total unread count from a dictionary with folder name -> count
func totalUnreadCount(for folders: [String: NSNumber]) -> Int {
    folders.reduce(0, { $0 + (($1.value as? Int) ?? 0) })
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
        let mailboxes = publisher(for: \.mailboxes)

        let titleCount = publisher(for: \.webView?.title)
            .map { extractUnreadCount(from: $0 ?? "") }

        let allFoldersCount = mailboxes
            .map { totalUnreadCount(for: $0) }

        let specificFoldersCount = mailboxes.combineLatest(Settings.shared.$watchedFolders.publisher)
            .map { mailboxes, watchedFolderString in
                let watchedFolders = watchedFolderString?
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                return mailboxes.filter { title, _ in watchedFolders?.contains(title) ?? false }
            }
            .map { totalUnreadCount(for: $0) }

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
