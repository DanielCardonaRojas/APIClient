//
//  APIClient.swift
//  APIClient
//
//  Created by Daniel Cardona Rojas on 5/20/19.
//  Copyright © 2019 Daniel Cardona Rojas. All rights reserved.
//

import Foundation

public struct NetworkError: Error {
    let statusCode: Int
    let data: Data?
}

/**
 Protocol for anything that can be converted into a standart URLRequest
 
 - Parameter baseURL: An optional baseURL which passed by the APIClient to create the full url of the URLRequest
 */
public protocol URLRequestConvertible {
    func asURLRequest(baseURL: URL?) -> URLRequest
}

/**
 Protocol  requirements for all types that can transform data into a specified type.
 
 This is used to especify how parse the response of a http request.
 */
public protocol URLResponseCapable {
    /// A type representing the output of the parsing operation
    associatedtype ResponseType

    /// The Data parsing function that tries to transform Data into a the corresponding associated type
    ///
    /// This function can fail by throwing an error that will propagate when executing a request.
    func handle(data: Data) throws -> ResponseType
}

/// A flexible http client decoupled from request building and response handling
public class APIClient {

    internal var baseURL: URL

    /// An object conforming to MockClient which can ihijack request and return
    /// the expected response or errors prematurily
    public var hijacker: ClientHijacker?

    /// Additional headers attached to every request
    var additionalHeaders = [String: String]()
    lazy var session: URLSession = {
        return URLSession(configuration: .default)
    }()

    /**
         Creates a client instance from a base URL and URLSessionConfiguration
            - Parameter baseURL: Base url for all requests (this can be overwritten when calling request)
            - Parameter configuration: configuration object used to create a new URLSession instance.
     */
    public init(baseURL: URL, configuration: URLSessionConfiguration? = nil) {
        self.baseURL = baseURL
        if let config = configuration {
            self.session = URLSession(configuration: config)
        }
    }

    /// Creates a client from a base url string.
    ///
    /// Note: Will return nil if not well formed URL.
    public convenience init?(baseURLString: String, configuration: URLSessionConfiguration? = nil) {
        guard let url = URL(string: baseURLString) else {
            return nil
        }
        self.init(baseURL: url, configuration: configuration)
    }

    /// Creates a APIClient from base URL and user provided URLSession
    public init(baseURL: URL, urlSession: URLSession) {
        self.baseURL = baseURL
        self.session = urlSession
    }

    /// Add additional headers to all requests executed by this instance.
    public func additionalHeaders(_ headers: [String: String]) {
        additionalHeaders.merge(headers, uniquingKeysWith: { $1 })
    }

    @discardableResult
    /**
     Executes the http request associated with an Endpoint
     
     - Parameter requestConvertible: Object conforming to URLResponseCapable & URLRequestConvertible (usually Endpoint)
     - Parameter baseUrl: Overwrite the base url for this request.
     - Parameter success: Callback for when response is as expected.
     - Parameter fail: Callback for when status code is not in 200 range, failed to parse or other exception has ocurred.
     
     */
    public func request<T>(
        _ requestConvertible: Endpoint<T>,
        baseUrl: URL? = nil,
        success: @escaping (T) -> Void,
        fail: @escaping (Error) -> Void) -> URLSessionDataTask {

        request(requestConvertible, handler: { result in
            switch result {
            case .failure(let error):
                fail(error)
            case .success(let response):
                success(response)
            }
        })

    }
    
    /**
     Executes the http request associated with an Endpoint
     
     - Parameter requestConvertible: Endpoint specification
     - Parameter baseUrl: Overwrite the base url for this request.
     - Returns: Response type as especified by endpoint object
     - Throws: NetworkError for bad status codes
     */
    @available(iOS 15.0.0, *)
    public func request<T>(
        _ requestConvertible: Endpoint<T>,
        baseUrl: URL? = nil
    ) async throws -> T {
        
        var httpRequest = requestConvertible.asURLRequest(baseURL: baseUrl ?? self.baseURL)
        
        if let hijackingClient = hijacker, let match = hijackingClient.hijack(endpoint: requestConvertible) {
            return try match.get()
        }
        
        // insert additional headers
        for (header, value) in additionalHeaders {
            httpRequest.addValue(value, forHTTPHeaderField: header)
        }
        
        // perform request
        let (data, response) = try await session.data(for: httpRequest, delegate: nil)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError()
        }
        
        // convert status code into error if required
        if !httpResponse.isOK {
            let statusCodeError = NetworkError(statusCode: httpResponse.statusCode, data: data)
            throw statusCodeError
        }
        
        // Parse into codable
        let parsedResponse = try requestConvertible.handle(data: data)
        return parsedResponse
        
    }

    /**
     Executes the http request associated with an Endpoint
     
     - Parameter requestConvertible: Object conforming to URLResponseCapable & URLRequestConvertible (usually Endpoint)
     - Parameter baseUrl: Overwrite the base url for this request.
     - Parameter handler: void callback handling a Result<T, Error>
     */
    public func request<T>(
        _ requestConvertible: Endpoint<T>,
        baseUrl: URL? = nil,
        handler: @escaping (Result<T, Error>) -> Void
    ) -> URLSessionDataTask {
            var httpRequest = requestConvertible.asURLRequest(baseURL: baseUrl ?? self.baseURL)

            if let hijackingClient = hijacker, let match = hijackingClient.hijack(endpoint: requestConvertible) {
                handler(match)
            }

            for (header, value) in additionalHeaders {
                httpRequest.addValue(value, forHTTPHeaderField: header)
            }

            let task: URLSessionDataTask = session.dataTask(with: httpRequest) { (data: Data?, response: URLResponse?, error: Error?) in

                if let data = data, let httpResponse = response as? HTTPURLResponse {
                    if !httpResponse.isOK {
                        let statusCode = NetworkError(statusCode: httpResponse.statusCode, data: data)
                        handler(.failure(statusCode))
                        return
                    }

                    do {
                        let parsedResponse = try requestConvertible.handle(data: data)
                        handler(.success(parsedResponse))
                    } catch let parsingError {
                        handler(.failure(parsingError))
                    }
                } else if let error = error {
                    handler(.failure(error))
                }
            }

            task.resume()
            return task
    }

}

extension URLRequest {
    /// Mutate the calling request by appending the provided URLQueryItem's
    public mutating func addQueryItems(_ items: [URLQueryItem]) {
        guard let url = self.url, items.count > 0 else {
            return
        }
        var cmps = URLComponents(string: url.absoluteString)
        let currentItems = cmps?.queryItems ?? []
        cmps?.queryItems = currentItems + items
        self.url = cmps?.url
    }
}

extension HTTPURLResponse {
    /// Validates status code to be in a range of success 200 >=  statusCode < 400
    var isOK: Bool {
        statusCode >= 200 && statusCode < 400
    }
}
