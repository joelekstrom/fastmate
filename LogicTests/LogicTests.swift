import XCTest
import Foundation
import Combine
@testable import Logic

class RedirectTrapTests: XCTestCase {

    var subscriptions: Set<AnyCancellable>!

    override func setUpWithError() throws {
        subscriptions = Set()
    }

    func testThatStatusCodeOtherThan302DoesNotRedirect() throws {
        Just((Data(), responseWith(statusCode: 200)))
            .extractRedirectURL()
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error): XCTAssertEqual(error, .didNotRedirect)
                case .finished: XCTFail()
                }
            }, receiveValue: {url in XCTFail() })
            .store(in: &subscriptions)
    }

    func testThatStatusCode302DoesRedirect() {
        Just((Data(), responseWith(statusCode: 302)))
            .extractRedirectURL()
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(_): XCTFail()
                case .finished: break
                }
            }, receiveValue: {_ in })
            .store(in: &subscriptions)
    }

    func testRedirectResponseWithLocation() {
        Just((Data(), responseWith(statusCode: 302)))
            .extractRedirectURL()
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(_): XCTFail()
                case .finished: break
                }
            }, receiveValue: {url in XCTAssertEqual(url, URL(string: "https://www.example.com/v1.2.3")!)})
            .store(in: &subscriptions)
    }

    func testRedirectResponseWithoutLocation() {
        Just((Data(), responseWith(statusCode: 302, location: nil)))
            .extractRedirectURL()
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error): XCTAssertEqual(error, .didNotRedirect)
                case .finished: XCTFail()
                }
            }, receiveValue: {url in XCTFail() })
            .store(in: &subscriptions)
    }

    func testRequestError() {
        Just((Data(), responseWith(statusCode: 302, location: nil)))
            .setFailureType(to: URLSession.DataTaskPublisher.Failure.self)
            .tryMap { _ in throw URLError(URLError.Code.badURL) }
            .extractRedirectURL()
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error): XCTAssertEqual(error, .requestFailed(reason: URLError(URLError.Code.badURL)))
                case .finished: XCTFail()
                }
            }, receiveValue: {url in XCTFail() })
            .store(in: &subscriptions)
    }

    func responseWith(statusCode: Int, location: String? = "https://www.example.com/v1.2.3") -> HTTPURLResponse {
        let url = URL(string: "https://www.example.com")!
        let headerFields = location != nil ? ["Location": location!] : nil
        return HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: headerFields)!
    }
}

extension RedirectTrap.Error: Equatable {
    public static func == (lhs: RedirectTrap.Error, rhs: RedirectTrap.Error) -> Bool {
        switch (lhs, rhs) {
        case (.didNotRedirect, .didNotRedirect): return true
        case (.didNotRedirect, .requestFailed(_)): return false
        case (.requestFailed, .didNotRedirect): return false
        case (.requestFailed(let a), .requestFailed(let b)): return a.localizedDescription == b.localizedDescription
        }
    }
}
