import Foundation
import Combine

// A publisher that takes a redirect response from a dataTaskPublisher and returns the Location URL
extension Publisher where Output == URLSession.DataTaskPublisher.Output {
    typealias Error = RedirectTrap.Error

    func extractRedirectURL() -> AnyPublisher<URL, Error> {
        return tryMap { (data: Data, response: URLResponse) -> URL in
            guard
                let response = response as? HTTPURLResponse,
                response.statusCode == 302,
                let location = response.value(forHTTPHeaderField: "Location"),
                let newURL = URL(string: location) else { throw Error.didNotRedirect }
            return newURL
        }
        .mapError { $0 as? Error ?? Error.requestFailed(reason: $0) }
        .eraseToAnyPublisher()
    }
}

public enum RedirectTrap {

    // For a given URL, performs a request but stops at the first redirect response and
    // returns the Location-URL
    public static func publisher(for url: URL) -> AnyPublisher<URL, Error> {
        session.dataTaskPublisher(for: url)
            .extractRedirectURL()
            .eraseToAnyPublisher()
    }

    public enum Error: LocalizedError {
        case didNotRedirect
        case requestFailed(reason: Swift.Error)

        public var errorDescription: String? {
            switch self {
            case .didNotRedirect: return "URL to latest version did not redirect. Fastmate might have to be updated manually.\n\nContact fastmate@ekstrom.dev for additional support."
            case .requestFailed(let reason): return reason.localizedDescription
            }
        }
    }

    private static var session: URLSession = {
        URLSession(configuration: URLSessionConfiguration.default, delegate: DataDelegate(), delegateQueue: nil)
    }()

    private class DataDelegate: NSObject, URLSessionDataDelegate {
        func urlSession(_ session: URLSession,
                        task: URLSessionTask,
                        willPerformHTTPRedirection response: HTTPURLResponse,
                        newRequest request: URLRequest,
                        completionHandler: @escaping (URLRequest?) -> Void) {
            completionHandler(nil)
        }
    }
}
