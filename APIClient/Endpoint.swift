//
//  Endpoint.swift
//  APIClient
//
//  Created by Daniel Cardona Rojas on 5/20/19.
//  Copyright © 2019 Daniel Cardona Rojas. All rights reserved.
//

import Foundation

public final class Endpoint<Response>: CustomStringConvertible, CustomDebugStringConvertible {
    
    public let method: Method
    public let path: Path
    private (set) var parameters: MixedLocationParams = [:]
    public let decode: (Data) throws -> Response
    public let encoding: ParameterEncoding
    
    public var description: String {
        return "Endpoint \(method.rawValue) \(path) expecting: \(Response.self)"
    }
    
    public var debugDescription: String {
        let params = parameters.map({ (k, v) in "\(k.rawValue): \(v)" }).joined(separator: "|")
        return self.description + " \(params)"
    }
    
    public init(method: Method = .get,
         path: Path,
         parameters: MixedLocationParams,
         encoding: ParameterEncoding = .methodDependent,
         decode: @escaping (Data) throws -> Response) {
        self.method = method
        self.path = path.hasPrefix("/") ? path : "/" + path
        self.parameters = parameters
        self.decode = decode
        self.encoding = encoding
    }
    
    public init(method: Method = .get,
         path: Path,
         parameters: Parameters? = nil,
         encoding: ParameterEncoding = .methodDependent,
         decode: @escaping (Data) throws -> Response) {
        self.method = method
        self.path = path.hasPrefix("/") ? path : "/" + path
        self.decode = decode
        self.encoding = encoding
        if let params = parameters {
            self.addParameters(params)
        }
    }
    
    public func addParameters(_ params: Parameters, location: ParameterEncoding.Location? = nil) {
        let loc = location ?? ParameterEncoding.Location.defaultLocation(for: self.method)
        if let currentParams = parameters[loc] {
            let updated = currentParams.merging(params, uniquingKeysWith: { (k1, k2) in k1 })
            self.parameters[loc] = updated
        } else {
            self.parameters[loc] = params
        }
    }
    
    public func map<N>(_ f: @escaping ((Response) throws -> N)) -> Endpoint<N> {
        let newDecodingFuntion: (Data) throws -> N = { data in
            return try f(self.decode(data))
        }
        return Endpoint<N>(method: self.method, path: self.path, parameters: self.parameters, encoding: self.encoding, decode: newDecodingFuntion)
    }
    
}

// MARK: - URLRequestConvertible
extension Endpoint: URLResponseCapable {
    public typealias Result = Response
    public func handle(data: Data) throws -> Response {
        return try self.decode(data)
    }
}

extension Endpoint: URLRequestConvertible {
    public func asURLRequest(baseURL: URL) throws -> URLRequest {
        var urlComponents = URLComponents(string: baseURL.absoluteString)
        let path = urlComponents.map { $0.path + self.path } ?? self.path
        urlComponents?.path = path
        let bodyEncoding = encoding.bodyEncoding
        let bodyParameters = parameters[.httpBody]
        let queryParameters = parameters[.queryString]
        
        
        if let queryParams = queryParameters as? [String: String] {
            let queryItems = queryParams.map({ (k, v) in URLQueryItem(name: k, value: v) })
            urlComponents?.queryItems = queryItems
        }
        
        var request = URLRequest(url: urlComponents!.url!)
        request.httpMethod = method.rawValue
        
        if let contentType = bodyEncoding.contentType {
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        
        if let params = bodyParameters, bodyEncoding == .jsonEncoded {
            let data = try JSONSerialization.data(withJSONObject: params as Any, options: [])
            request.httpBody = data
        } else if let params = bodyParameters as? [String: String], bodyEncoding == .formUrlEncoded {
            let formUrlData: String? = params.map { (k, v) in
                let escapedKey = k.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? k
                let escapedValue = v.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? v
                return "\(escapedKey)=\(escapedValue)"
                }.joined(separator: "&")
            request.httpBody = formUrlData?.data(using: .utf8)
        }
        
        return request
    }
}


// MARK: - Conviniences
public extension Endpoint where Response: Swift.Decodable {
    convenience init(method: Method = .get, path: Path, parameters: Parameters? = nil, encoding: ParameterEncoding = .methodDependent) {
        self.init(method: method, path: path, parameters: parameters) {
            try JSONDecoder().decode(Response.self, from: $0)
        }
    }
}

public extension Endpoint where Response == Void {
    convenience init(method: Method = .get, path: Path, parameters: Parameters? = nil, encoding: ParameterEncoding = .methodDependent) {
        self.init( method: method, path: path, parameters: parameters, decode: { _ in () })
    }
}
