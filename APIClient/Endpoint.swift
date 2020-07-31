//
//  Endpoint.swift
//  APIClient
//
//  Created by Daniel Cardona Rojas on 5/20/19.
//  Copyright © 2019 Daniel Cardona Rojas. All rights reserved.
//

import Foundation

/// Typed high level abstraction of a service request and response
///
/// This class is parametrized over the response type expectation
public final class Endpoint<Response>: CustomStringConvertible, CustomDebugStringConvertible {
    public var debugDescription: String {
        return "\(builder.debugDescription) expecting: \(Response.self)"
    }

    public let decode: (Data) throws -> Response
    public var builder: RequestBuilder

    public var description: String {
        return "\(builder.description) expecting: \(Response.self)"
    }

    /**
     Constructs a new Endpoint

     - Parameter builder: An http request builder
     - Parameter decoder: Closure used to decode Data into the expcted type.
     */
    public init(builder: RequestBuilder, decode: @escaping (Data) throws -> Response) {
        self.builder = builder
        self.decode = decode
    }

    /**
     Transform Endpoint into a new one with modify response.

     - Parameter f: Closure used to modify the reponse type.

     */
    public func map<N>(_ f: @escaping ((Response) throws -> N)) -> Endpoint<N> {
        let newDecodingFuntion: (Data) throws -> N = { data in
            return try f(self.decode(data))
        }
        return Endpoint<N>(builder: self.builder, decode: newDecodingFuntion)
    }

    public func modifyRequest(_ f: (RequestBuilder) -> RequestBuilder) {
        self.builder = f(builder)
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
    public func asURLRequest(baseURL: URL?) throws -> URLRequest {
        return try builder.asURLRequest(baseURL: baseURL)
    }
}

// MARK: - Conviniences
extension Endpoint where Response: Swift.Decodable {
    public convenience init(
        method: RequestBuilder.Method,
        path: Path,
        _ builder: (RequestBuilder) -> RequestBuilder
    ) {

        let reqBuilder = builder(RequestBuilder(method: method, path: path))

        let decoder = JSONDecoder()
        let fullISO8610Formatter = DateFormatter()
        fullISO8610Formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        decoder.dateDecodingStrategy = .formatted(fullISO8610Formatter)

        self.init(builder: reqBuilder) {
            do {
                let jsonDict = try? JSONSerialization.jsonObject(with: $0, options: [])
                print(jsonDict)
                return try decoder.decode(Response.self, from: $0)
            } catch {
                throw error
            }
        }
    }
}
