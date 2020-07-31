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

public protocol URLRequestConvertible {
    func asURLRequest(baseURL: URL?) throws -> URLRequest
}

public protocol URLResponseCapable {
    associatedtype Result
    func handle(data: Data) throws -> Result
}

public class APIClient {

    internal var baseURL: URL?
    var additionalHeaders = [String: String]()
    lazy var session: URLSession = {
        return URLSession(configuration: .default)
    }()

    public init(baseURL: String, configuration: URLSessionConfiguration? = nil) {
        if let config = configuration {
            self.session = URLSession(configuration: config)
        }
        self.baseURL = URL(string: baseURL)
    }

    public init(baseURL: String, urlSession: URLSession) {
        self.session = urlSession
        self.baseURL = URL(string: baseURL)
    }

    public func additionalHeaders(_ headers: [String: String]) {
        additionalHeaders.merge(headers, uniquingKeysWith: { $1 })
    }

    @discardableResult
    public func request<Response, T>(
        _ requestConvertible: T,
        baseUrl: URL? = nil,
        success: @escaping (Response) -> Void,
        fail: @escaping (Error) -> Void
    ) -> URLSessionDataTask?
    where T: URLResponseCapable, T: URLRequestConvertible, T.Result == Response {
        print(">>>Request")
        do {
            var httpRequest = try requestConvertible.asURLRequest(baseURL: baseUrl ?? self.baseURL)

            for (header, value) in additionalHeaders {
                httpRequest.addValue(value, forHTTPHeaderField: header)
            }

            print(">>>Task")
            let task: URLSessionDataTask = session.dataTask(with: httpRequest) {
                (data: Data?, response: URLResponse?, error: Error?) in

                print(">>>Callback")
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
        } catch (let encodingError) {
            fail(encodingError)
        }

        return nil
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
