//
//  RequestBuilder.swift
//
//  Created by Daniel Cardona Rojas on 5/06/20.
//  Copyright © 2020 Daniel Cardona Rojas. All rights reserved.
//

import Foundation

public typealias Path = String

public class RequestBuilder: CustomStringConvertible, CustomDebugStringConvertible {
    public var debugDescription: String {
        let payload = body.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        return "\(description) \n \(payload)"
    }

    public var description: String {
        "\(method.rawValue) \(path)"
    }

    public private(set) var baseURL: String?

    public enum Method: String {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case patch = "PATCH"
        case delete = "DELETE"
    }

    public enum Encoding {
        case formUrlEncoded, jsonEncoded
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
    public static func post(_ path: Path) -> RequestBuilder {
        let fixedPath = path.hasPrefix("/") ? path : "/" + path
        return RequestBuilder(method: .post, path: fixedPath)

    }

    public static func get(_ path: Path) -> RequestBuilder {
        return RequestBuilder(method: .get, path: path)

    }

    public static func put(_ path: Path) -> RequestBuilder {
        return RequestBuilder(method: .put, path: path)

    }

    public static func patch(_ path: Path) -> RequestBuilder {
        return RequestBuilder(method: .put, path: path)

    }

    // MARK: - Builders

    public func baseURL(_ string: String) -> RequestBuilder {
        self.baseURL = URL(string: string)?.absoluteString
        return self
    }

    public func body(_ body: Data) -> RequestBuilder {
        self.body = body
        return self
    }

    public func jsonBody<T: Encodable>(_ payload: T) -> RequestBuilder {
        let data = try? JSONEncoder().encode(payload)
        self.body = data
        return addHeader("Content-Type", value: Encoding.jsonEncoded.mimeType)
    }

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

    public func addHeader(_ header: String, value: String) -> RequestBuilder {
        if headers == nil { headers = [:] }
        self.headers?[header] = value
        return self
    }

    public func query(_ query: QueryParams) -> RequestBuilder {
        self.queryParameters = query
        return self
    }

    public func addQuery(_ query: String, value: String) -> RequestBuilder {
        if queryParameters == nil { queryParameters = [:] }
        queryParameters?[query] = value
        return self
    }
}

extension RequestBuilder: URLRequestConvertible {
    public func asURLRequest(baseURL: URL?) throws -> URLRequest {
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
