//
//  MockAPIClient.swift
//  APIClient
//
//  Created by Daniel Cardona Rojas on 12/03/21.
//  Copyright © 2021 Daniel Cardona Rojas. All rights reserved.
//

import Foundation

/// RequestMatcher represents, different ways to find matches agains a request
public enum RequestMatcher: Hashable {
    case any
    case method(RequestBuilder.Method)

    /// Path string or regex in escaped string e.g `#"/posts/\d"#`
    case path(String)
}

/// An object that can hijack outgoing requests and return either the expected response type
/// or an error bypassing the actual http request
protocol ClientHijacker {
    /// This function is handed an endpoint and should determine if it should hijack the request
    /// associated with it by returning its expected type or an error
    /// Returns: nil when doesnt bypass request.
    func hijack<T>(endpoint: Endpoint<T>) -> Result<T, Error>?
}

public struct MockedError: Error {
    let description: String
}

struct Config: Hashable {
    let kind: RequestMatcher
    let typeString: String

    init<T>(_ type: T.Type, kind: RequestMatcher) {
        self.kind = kind
        self.typeString = "\(T.self)"
    }
}

/// A ClientHijacker implementation that can register response substitutes and
/// errors in memory.
public class MockDataClientHijacker: ClientHijacker {

    static let sharedInstance = MockDataClientHijacker()

    typealias RequestHijacker<T> = (RequestBuilder) throws -> T?

    private init() {

    }

    public func clear() {
        store = [:]
    }

    private var store: [Config: RequestHijacker<Any>] = [:]

    /// Registers a hijacker that will error out with the provided error message
    public func registerSubstitute<T>(_ substitute: T, matchingRequestBy matching: RequestMatcher) {
        let config = Config(T.self, kind: matching)
        store[config] = Self.createSubstitueHijacker(substitute: substitute, kind: matching)
    }

    @discardableResult
    public func registerJsonFileContentSubstitute<T: Decodable>(for type: T.Type,
                                                                requestThatMatches criteria: RequestMatcher,
                                                                bundle: Bundle,
                                                                fileName: String) -> Bool {
        let fileBundle = bundle

        guard
            let url = fileBundle.resourceURL?.appendingPathComponent(fileName),
            let data = try? Data(contentsOf: URL(fileURLWithPath: url.path)),
            let parsed = try? JSONDecoder().decode(T.self, from: data)
        else {
                return false
        }

        registerSubstitute(parsed, matchingRequestBy: criteria)
        return true
    }

    /// Registers a hijacker that will error out with the provided error message
    public func registerError<T>(_ error: String, for type: T.Type, matching: RequestMatcher) {
        let config = Config(T.self, kind: matching)
        store[config] = Self.createErrorHijacker(T.self, error: error, kind: matching)
    }

    public func hijack<T>(endpoint: Endpoint<T>) -> Result<T, Error>? {
        guard
            let config = store.keys.first(where: { $0.typeString == "\(T.self)" }),
            let entry = store[config]
            else {
            return nil
        }

        let result: Result<T?, Error> = Result(catching: {
            let substitute = try entry(endpoint.builder) as? T
            return substitute
        })

        switch result {
        case .success(let value):
            if let nonNilValue = value {
                 return Result.success(nonNilValue)
            } else {
                return nil
            }
        case .failure(let error):
            return Result.failure(error)
        }
    }

    private static func createErrorHijacker<T>(_ type: T.Type, error: String, kind: RequestMatcher) -> RequestHijacker<T> {
        { _ in
            throw MockedError(description: error)
        }
    }

    private static func createSubstitueHijacker<T>(substitute: T, kind: RequestMatcher) -> RequestHijacker<T> {
        return { (builder: RequestBuilder) in
            switch kind {
            case .any:
                return substitute
            case .method(let method):
                return builder.method == method ? substitute : nil
            case .path(let path):
                return builder.path ~= path ? substitute : nil
            }

        }

    }

}

extension String {
    static func ~= (lhs: String, rhs: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: rhs) else { return lhs == rhs }
        let range = NSRange(location: 0, length: lhs.utf16.count)
        return regex.firstMatch(in: lhs, options: [], range: range) != nil
    }
}
