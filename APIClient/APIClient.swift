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
 */
public protocol URLResponseCapable {
    /// The type that the implementer can  parse Data into.
    associatedtype Result

    /// The Data parsing function
    func handle(data: Data) throws -> Result
}

/// A flexible http client decoupled from request building and response handling
public class APIClient {

    internal var baseURL: URL
    var additionalHeaders = [String: String]()
    lazy var session: URLSession = {
        return URLSession(configuration: .default)
    }()

    public init(baseURL: URL, configuration: URLSessionConfiguration? = nil) {
        self.baseURL = baseURL
        if let config = configuration {
            self.session = URLSession(configuration: config)
        }
    }
    
    public convenience init?(baseURLString: String, configuration: URLSessionConfiguration? = nil) {
        guard let url = URL(string: baseURLString) else {
            return nil
        }
        self.init(baseURL: url)
    }

    public init(baseURL: URL, urlSession: URLSession) {
        self.baseURL = baseURL
        self.session = urlSession
    }

    public func additionalHeaders(_ headers: [String: String]) {
        additionalHeaders.merge(headers, uniquingKeysWith: { $1 })
    }

    @discardableResult
    /**
     Executes an http request.
     
     - Parameter requestConvertible: Object conforming to URLResponseCapable & URLRequestConvertible
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
