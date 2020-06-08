//
//  Endpoint.swift
//  APIClient
//
//  Created by Daniel Cardona Rojas on 5/20/19.
//  Copyright © 2019 Daniel Cardona Rojas. All rights reserved.
//

import Foundation

public final class Endpoint<Response>: CustomStringConvertible, CustomDebugStringConvertible {

    public let decode: (Data) throws -> Response
    public let builder: RequestBuilder

    public var description: String {
        return "Endpoint \(builder.method.rawValue) \(builder.path) expecting: \(Response.self)"
    }

    public var debugDescription: String {
//        let params = builder.parameters.map({ (k, v) in "\(k.rawValue): \(v)" }).joined(separator: "|")
        return self.description //+ " \(params)"
    }

    init(builder: RequestBuilder, decode: @escaping (Data) throws -> Response) {
        self.builder = builder
        self.decode = decode
    }



    public func map<N>(_ f: @escaping ((Response) throws -> N)) -> Endpoint<N> {
        let newDecodingFuntion: (Data) throws -> N = { data in
            return try f(self.decode(data))
        }
        return Endpoint<N>(builder: self.builder, decode: newDecodingFuntion)
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
        return try builder.asURLRequest(baseURL: baseURL)
    }
}

// MARK: - Conviniences
extension Endpoint where Response: Swift.Decodable {
    public convenience init(
        method: RequestBuilder.Method,
        path: Path,
        _ builder: ((RequestBuilder) -> RequestBuilder)? =  nil) {


        let baseBuilder = RequestBuilder(method: method, path: path)
        let reqBuilder = builder.map({$0(baseBuilder)}) ?? baseBuilder

        self.init(builder: reqBuilder) {
            try JSONDecoder().decode(Response.self, from: $0)
        }
    }
}
