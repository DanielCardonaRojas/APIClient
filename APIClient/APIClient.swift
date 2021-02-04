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
 
 - Parameter baseURL: An optional baseURL to overwrite the URLRequests
 */
public protocol URLRequestConvertible {
    func asURLRequest(baseURL: URL?) -> URLRequest
}

/**
 Protocol  requirements for all types that can transform data into a specified type.
 
 This is used to especify how parse the response of a http request.
 */
public protocol URLResponseCapable {
    /// The type that the implementer can  parse Data into.
    associatedtype Result

    /// The Data parsing function that tries to transform Data into a the corresponding associated type
    ///
    /// This function can fail by throwing an error that will propagate when executing a request.
    func handle(data: Data) throws -> Result
}

/// A flexible http client decoupled from request building and response handling
public class APIClient {

    internal var baseURL: URL
    
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
     Executes an http request.
     
     - Parameter requestConvertible: Object conforming to URLResponseCapable & URLRequestConvertible (usually Endpoint)
     - Parameter baseUrl: Ovewrite the base url for this request.
     - Parameter success: Callback for when response is as expected.
     - Parameter fail: Callback for when status code is not in 200 range, failed to parse or other exception has ocurred.
     
     */
    public func request<Response, T>(
        _ requestConvertible: T,
        baseUrl: URL? = nil,
        success: @escaping (Response) -> Void,
        fail: @escaping (Error) -> Void
    ) -> URLSessionDataTask
        where T: URLResponseCapable, T: URLRequestConvertible, T.Result == Response {
            var httpRequest = requestConvertible.asURLRequest(baseURL: baseUrl ?? self.baseURL)
            
            for (header, value) in additionalHeaders {
                httpRequest.addValue(value, forHTTPHeaderField: header)
            }
            
            let task: URLSessionDataTask = session.dataTask(with: httpRequest) {
                (data: Data?, response: URLResponse?, error: Error?) in
                
                if let data = data, let httpResponse = response as? HTTPURLResponse {
                    if !httpResponse.isOK {
                        let statusCoreError = NetworkError(statusCode: httpResponse.statusCode, data: data)
                        fail(statusCoreError)
                        return
                    }
                    
                    do {
                        let parsedResponse = try requestConvertible.handle(data: data)
                        success(parsedResponse)
                    } catch (let parsingError) {
                        fail(parsingError)
                    }
                } else if let error = error {
                    fail(error)
                }
            }
            
            task.resume()
            return task
    }
    
}

extension URLRequest {
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
    var isOK: Bool {
        statusCode >= 200 && statusCode < 400
    }
}
