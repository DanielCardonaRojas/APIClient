//
//  RequestBuilder.swift
//
//  Created by Daniel Cardona Rojas on 5/06/20.
//  Copyright © 2020 Daniel Cardona Rojas. All rights reserved.
//

import Foundation

public typealias Path = String

/// A builder pattern to easily create http requests
///
/// Note: The base URL will be injected by the APIClient so only path if configured here.
public class RequestBuilder: CustomStringConvertible, CustomDebugStringConvertible {
    public var debugDescription: String {
        let payload = body.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        return "\(description) \n \(payload)"
    }

    public var description: String {
        "\(method.rawValue) \(path)"
    }

    public private(set) var baseURL: String?

    /// Enumeration of HTTP Verbs
    public enum Method: String {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case patch = "PATCH"
        case delete = "DELETE"
    }

    /// A type representing the encoding to be used for request body
    public enum Encoding {
        case formUrlEncoded, jsonEncoded
        
        /// The mime type assocciated with this encoding that will be placed in the Content-Type header
        var mimeType: String {
            switch self {
            case .formUrlEncoded:
                return "application/x-www-form-urlencoded; charset=utf-8"
            case .jsonEncoded:
                return "application/json; charset=UTF-8"
            }
        }
    }

    public typealias Headers = [String: String]
    public typealias QueryParams = [String: Any]

    let method: Method
    let path: Path
    private var headers: Headers?
    private var queryParameters: QueryParams?
    private var body: Data?

    init(method: Method, path: Path) {
        self.method = method
        self.path = path
    }

    // MARK: - Factories
    /// Creates a request builder for a POST request
    public static func post(_ path: Path) -> RequestBuilder {
        let fixedPath = path.hasPrefix("/") ? path : "/" + path
        return RequestBuilder(method: .post, path: fixedPath)

    }

    /// Creates a request builder for a GET request
    public static func get(_ path: Path) -> RequestBuilder {
        return RequestBuilder(method: .get, path: path)

    }

    /// Creates a request builder for a PUT request
    public static func put(_ path: Path) -> RequestBuilder {
        return RequestBuilder(method: .put, path: path)

    }

    /// Creates a request builder for a PATCH request
    public static func patch(_ path: Path) -> RequestBuilder {
        return RequestBuilder(method: .put, path: path)

    }

    // MARK: - Builders

    /// Sets the base url for the formed request
    /// Note: base url should not have a trailing / since this is added in paths.
    public func baseURL(_ string: String) -> RequestBuilder {
        self.baseURL = URL(string: string)?.absoluteString
        return self
    }

    /// Adds body content from raw data.
    public func body(_ body: Data) -> RequestBuilder {
        self.body = body
        return self
    }

    /// Adds a json payload to body given a codable value.
    ///
    /// Note this will also set the content-type to application/json
    public func jsonBody<T: Encodable>(_ payload: T) -> RequestBuilder {
        let data = try? JSONEncoder().encode(payload)
        self.body = data
        return addHeader("Content-Type", value: Encoding.jsonEncoded.mimeType)
    }
    
    /// Adds a json payload to body from a dictionary
    ///
    /// Note this will also set the content-type to application/json
    public func jsonBody(dict: [String: Any]) -> RequestBuilder {
        let data = try? JSONSerialization.data(withJSONObject: dict, options: [])
        self.body = data
        return addHeader("Content-Type", value: Encoding.jsonEncoded.mimeType)
    }

    /// Add a body payload encoded a form-url
    ///
    /// Note this will also set the content-type to application/x-www-form-urlencoded
    public func formUrlBody(_ params: [String: String], encoding: Encoding) -> RequestBuilder {
        let formUrlData: String? = params.map { (k, v) in
            let escapedKey =
                k.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? k

            let escapedValue =
                v.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? v

            return "\(escapedKey)=\(escapedValue)"
        }.joined(separator: "&")

        let data = formUrlData?.data(using: .utf8)

        self.body = data
        return addHeader("Content-Type", value: Encoding.formUrlEncoded.mimeType)
    }

    /// Adds header to request
    public func addHeader(_ header: String, value: String) -> RequestBuilder {
        if headers == nil { headers = [:] }
        self.headers?[header] = value
        return self
    }

    /// Adds multiple query paramater pairs to url
    public func query(_ query: QueryParams) -> RequestBuilder {
        self.queryParameters = query
        return self
    }

    /// Adds a single query parameter to url
    public func addQuery(_ query: String, value: String) -> RequestBuilder {
        if queryParameters == nil { queryParameters = [:] }
        queryParameters?[query] = value
        return self
    }
}

extension RequestBuilder: URLRequestConvertible {
    /// Transforms the RequestBuilder into a URLRequest
    public func asURLRequest(baseURL: URL?) -> URLRequest {
        let urlString = self.baseURL ?? baseURL?.absoluteString
        var urlComponents = URLComponents(string: urlString ?? "")
        let path = urlComponents.map { $0.path + self.path } ?? self.path
        urlComponents?.path = path

        if let queryParams = queryParameters as? [String: String] {
            let queryItems = queryParams.map({ (k, v) in URLQueryItem(name: k, value: v) })
            urlComponents?.queryItems = queryItems
        }

        var request = URLRequest(url: urlComponents!.url!)
        request.httpMethod = method.rawValue

        self.headers?.forEach({ header, value in request.setValue(value, forHTTPHeaderField: header)
        })

        request.httpBody = self.body
        return request
    }
}
