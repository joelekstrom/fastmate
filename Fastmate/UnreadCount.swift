import Combine

private extension Dictionary where Key == String, Value == NSNumber {
    // Extracts total unread count from a dictionary with folder name -> count
    var unreadCount: Int {
        mapValues(\.intValue)
            .reduce(0, { $0 + $1.value })
    }
}

private extension String {
    // Extracts unread count from a Fastmail web view title
    var unreadCount: Int {
        let regex = try! NSRegularExpression(pattern: "^(\\d+) •", options: .anchorsMatchLines)
        let result = regex.firstMatch(in: self, options: [], range: NSRange(location: 0, length: self.count))
        if let result = result, result.numberOfRanges > 1 {
            let range = Range(result.range(at: 1), in: self)!
            let countString = self[range]
            return Int(String(countString)) ?? 0
        }
        return 0
    }
}

extension WebViewController {
    var unreadCountPublisher: AnyPublisher<Int, Never> {
        let titleCount = publisher(for: \.webView?.title)
            .map(\.?.unreadCount)
            .replaceNil(with: 0)

        let allFoldersCount = publisher(for: \.mailboxes)
            .map(\.unreadCount)

        let watchedFolders = UserDefaults.standard.publisher(for: \.watchedFolders)
            .map { $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }}

        let specificFoldersCount = publisher(for: \.mailboxes)
            .combineLatest(watchedFolders)
            .map { mailboxes, watchedFolders in
                mailboxes.filter { title, _ in watchedFolders.contains(title) }
            }
            .map(\.unreadCount)

        return UserDefaults.standard.publisher(for: \.watchedFolderType)
            .map { type -> AnyPublisher<Int, Never> in
                switch type {
                case .selected: return titleCount.eraseToAnyPublisher()
                case .all: return allFoldersCount.eraseToAnyPublisher()
                case .specific: return specificFoldersCount.eraseToAnyPublisher()
                }
            }
            .switchToLatest()
            .eraseToAnyPublisher()
    }
}
