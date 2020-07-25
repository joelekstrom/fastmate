import Combine

extension WebViewController {
    var unreadCount: AnyPublisher<Int, Never> {
        let mailboxes = publisher(for: \.mailboxes)

        let titleCount = publisher(for: \.webView?.title)
            .map { extractUnreadCount(from: $0 ?? "") }

        let allFoldersCount = mailboxes
            .map { $0.reduce(0, { $0 + (($1.value as? Int) ?? 0) }) }

        let specificFoldersCount = mailboxes.combineLatest(Settings.shared.$watchedFolders.publisher)
            .map { mailboxes, watchedFolderString -> Int in
                let watchedFolders = watchedFolderString?.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                return watchedFolders?.reduce(0, { $0 + ((mailboxes[$1] as? Int) ?? 0) }) ?? 0
        }

        return Settings.shared.$watchedFolderType.publisher
            .compactMap { type -> AnyPublisher<Int, Never>? in
                switch WatchedFolderType(rawValue: type) {
                case .inbox: return titleCount.eraseToAnyPublisher()
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
