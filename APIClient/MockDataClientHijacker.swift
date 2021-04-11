//
//  MockAPIClient.swift
//  APIClient
//
//  Created by Daniel Cardona Rojas on 12/03/21.
//  Copyright © 2021 Daniel Cardona Rojas. All rights reserved.
//

import Foundation

#if SWIFT_PACKAGE
import Utils
#endif

/// RequestMatcher represents, different ways to find matches agains a request
public enum RequestMatchingCriteria: Hashable {
    case any
    case method(RequestBuilder.Method)

    /// Path string or regex in escaped string e.g `#"/posts/\d"#`
    case path(String)

    func match(_ builder: RequestBuilder) -> Bool {
        switch self {
        case .any:
            return true
        case .method(let method):
            return builder.method == method
        case .path(let path):
            return builder.path ~= path
        }
    }
}

struct EndpointMatcher: Hashable {
    let requestCriteria: RequestMatchingCriteria
    let typeString: String

    init<T>(_ type: T.Type, requestMatchingCriteria: RequestMatchingCriteria) {
        typeString = String(describing: T.self)
        requestCriteria = requestMatchingCriteria
    }

    func match<T>(_ endpoint: Endpoint<T>) -> Bool {
        let matchesRequest = requestCriteria.match(endpoint.builder)
        return "\(T.self)" == typeString
    }

}

/// An object that can hijack outgoing requests and return either the expected response type
/// or an error bypassing the actual http request
public protocol ClientHijacker {
    /// This function is handed an endpoint and should determine if it should hijack the request
    /// associated with it by returning its expected type or an error
    /// Returns: nil when doesnt bypass request.
    func hijack<T>(endpoint: Endpoint<T>) -> Result<T, Error>?
}

public struct MockedError: Error {
    let description: String
}

/// A ClientHijacker implementation that can register
/// fake response substitutes and errors in memory.
public class MockDataClientHijacker: ClientHijacker {

    public static let sharedInstance = MockDataClientHijacker()

    typealias RequestHijacker<T> = (RequestBuilder) throws -> T?

    public init() { // Is public becuase is usefull for testing

    }

    public func clear() {
        store = [:]
    }

    private var store: [EndpointMatcher: RequestHijacker<Any>] = [:]

    /**
     Registers a hijacker with a substitute value
     
       - Parameter substitute: The value that will impostor the response expectation
       - Parameter criteria: How outgoing requests will be matched on
     
     */
    public func registerSubstitute<T>(_ substitute: T, requestThatMatches criteria: RequestMatchingCriteria, typed: Bool = true) {
        let config = EndpointMatcher(T.self, requestMatchingCriteria: criteria)
        store[config] = Self.createSubstituteHijacker(substitute: substitute, kind: criteria)
    }

    /**
     Registers a hijacker that will read from file and store the substitute
     
       - Parameter bundle: Bundle to read the file from
       - Parameter fileName: The file name to read and parse
       - Parameter type: The type of the response expectation that will determing how to parse the file
       - Parameter criteria: How outgoing requests will be matched on
     
     */
    @discardableResult
    public func registerJsonFileContentSubstitute<T: Decodable>(for type: T.Type,
                                                                requestThatMatches criteria: RequestMatchingCriteria,
                                                                bundle: Bundle? = nil,
                                                                fileName: String) -> Bool {
        let fileBundle = bundle ?? Bundle.module
        
        do {
            let data = try fileBundle.dataFor(fileName)
            let parsed = try JSONDecoder().decode(T.self, from: data)
            registerSubstitute(parsed, requestThatMatches: criteria)
        } catch let error {
            registerError("Failed loading file content reason: \(error.localizedDescription)",
                          for: T.self,
                          requestThatMatches: criteria)
            return false
        }

        return true

    }

    /**
     Registers a hijacker that will error out with the provided error message
     
       - Parameter error: A error message that will be wrapped in a MockedError
       - Parameter type: The type of the response expectation that this applies to
       - Parameter criteria: How outgoing requests will be matched on
     
     */
    public func registerError<T>(_ error: String, for type: T.Type, requestThatMatches criteria: RequestMatchingCriteria) {
        let config = EndpointMatcher(T.self, requestMatchingCriteria: criteria)
        store[config] = Self.createErrorHijacker(T.self, error: error, kind: criteria)
    }

    public func hijack<T>(endpoint: Endpoint<T>) -> Result<T, Error>? {
        guard
            let config = store.keys.first(where: { $0.match(endpoint) }),
            let entry = store[config]
            else {
            return nil
        }

        let result: Result<T?, Error> = Result(catching: {
            let substitute = try entry(endpoint.builder)
            let casted = substitute as? T
            return casted
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

    private static func createErrorHijacker<T>(_ type: T.Type, error: String, kind: RequestMatchingCriteria) -> RequestHijacker<T> {
        { _ in
            throw MockedError(description: error)
        }
    }

    private static func createSubstituteHijacker<T>(substitute: T, kind: RequestMatchingCriteria) -> RequestHijacker<T> {
        return { (builder: RequestBuilder) in
            let foundMatch = kind.match(builder)
            return foundMatch ? substitute : nil
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
