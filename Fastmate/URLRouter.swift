import Foundation
import Combine

/// Responsible for transforming url's such as fastmate: or mailto: into
/// Fastmail https URL's that can be opened by the web view
class URLRouter {
    static let appURL = URL(string: "https://app.fastmail.com")!
    static let betaAppURL = URL(string: "https://betaapp.fastmail.com")!

    @Published private(set) var baseURL: URL = appURL
    private var shouldUseBetaSubscription: AnyCancellable?

    init() {
        shouldUseBetaSubscription = UserDefaults.standard.publisher(for: \.shouldUseFastmailBeta)
            .map { $0 ? URLRouter.betaAppURL : URLRouter.appURL }
            .sink { [unowned self] in self.baseURL = $0 }
    }

    func route(for url: URL?) -> URL? {
        guard let url = url else { return nil }
        switch url.scheme {
        case "https": return url
        case "fastmate": return routeFastmateURL(url)
        case "mailto": return routeMailtoURL(url)
        default: return nil
        }
    }

    private func routeFastmateURL(_ url: URL) -> URL? {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.scheme = baseURL.scheme
        components?.host = baseURL.host
        return components?.url
    }

    private func routeMailtoURL(_ url: URL) -> URL? {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.scheme = baseURL.scheme // Rewrite mailto: to https:
        components?.host = baseURL.host
        // path will be "to" field, map into query item instead
        let recipients = components?.path
        components?.prependPercentEncodedQueryItem(.init(name: "to", value: recipients))
        components?.path = "/mail/compose"
        return components?.url
    }
}

extension URLComponents {
    mutating func prependPercentEncodedQueryItem(_ item: URLQueryItem) {
        var queryItems = percentEncodedQueryItems ?? []
        queryItems.insert(item, at: 0)
        percentEncodedQueryItems = queryItems
    }
}
