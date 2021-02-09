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
/// The request configuration associated with this Endpoint is encoded in the RequestBuilder.

public final class Endpoint<Response>: CustomStringConvertible, CustomDebugStringConvertible {
    public var debugDescription: String {
        return "\(builder.debugDescription) expecting: \(Response.self)"
    }

    /// The closure responsible for decoding an http response.
    public let decode: (Data) throws -> Response
    
    /// The request builder instance used to configure the HTTP request.
    public var builder: RequestBuilder

    public var description: String {
        return "\(builder.description) expecting: \(Response.self)"
    }

    /**
     Constructs a new Endpoint

     - Parameter builder: An http request builder
     - Parameter decoder: Closure used to decode Data into the expected response type.
     */
    public init(builder: RequestBuilder, decode: @escaping (Data) throws -> Response) {
        self.builder = builder
        self.decode = decode
    }

    /**
     Transform Endpoint into a new one

      - Parameter f: Closure used to modify the reponse type.
     
      This is handy when you want to select a portion of the http response, e.g when the data of interest is
      enveloped by meta data.

     */
    public func map<N>(_ f: @escaping ((Response) throws -> N)) -> Endpoint<N> {
        let newDecodingFuntion: (Data) throws -> N = { data in
            return try f(self.decode(data))
        }
        return Endpoint<N>(builder: self.builder, decode: newDecodingFuntion)
    }

    /**
     Modify the underlying request builder ad-hoc
     - Parameter f: A function that further configures the http request
     */
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
    public func asURLRequest(baseURL: URL?)  -> URLRequest {
        return builder.asURLRequest(baseURL: baseURL)
    }
}

// MARK: - Smart constructors
extension Endpoint where Response == Void {
    public convenience init(
        method: RequestBuilder.Method,
        path: Path,
        _ builder: ((RequestBuilder) -> RequestBuilder)? = nil
    ) {
        let reqBuilder = builder?(RequestBuilder(method: method, path: path)) ?? RequestBuilder(method: method, path: path)

        self.init(builder: reqBuilder) { _ in
            return
        }
    }
}

extension Endpoint where Response == [String: Any] {
    public convenience init(
        method: RequestBuilder.Method,
        path: Path,
        _ builder: ((RequestBuilder) -> RequestBuilder)? = nil
    ) {

        let reqBuilder = builder?(RequestBuilder(method: method, path: path)) ?? RequestBuilder(method: method, path: path)

        self.init(builder: reqBuilder) {
            do {
                guard let jsonDict = try JSONSerialization.jsonObject(with: $0, options: []) as? [String: Any] else {
                    throw DecodingError.typeMismatch(Response.self, DecodingError.Context.init(codingPath: [], debugDescription: "Not castable into [String: Any]"))
                }
                return jsonDict
            } catch {
                throw error
            }
        }
    }
}

extension Endpoint where Response: Swift.Decodable {
    /**
    Creates and endpoint specification
     
    - Parameter method: The HTTP method (GET, POST, PUT, PATCH)
    - Parameter path: A path relative to the APIClient base url that will be executing this request.
    - Parameter decoder: A custom JSONDecoder (usefull for handling different date formats)
    - Parameter builder: A closure mutating and returning a new RequestBuilder
     */
    public convenience init(
        method: RequestBuilder.Method,
        path: Path,
        decoder: JSONDecoder? = nil,
        _ builder: ((RequestBuilder) -> RequestBuilder)? = nil
    ) {

        let reqBuilder = builder?(RequestBuilder(method: method, path: path)) ?? RequestBuilder(method: method, path: path)

        let jsonDecoder = decoder ?? JSONDecoder()
        
        if (decoder == nil) {
            let fullISO8610Formatter = DateFormatter()
            fullISO8610Formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
            jsonDecoder.dateDecodingStrategy = .formatted(fullISO8610Formatter)
        }

        self.init(builder: reqBuilder) {
            do {
//                let jsonDict = try? JSONSerialization.jsonObject(with: $0, options: [])
//                print(jsonDict)
                return try jsonDecoder.decode(Response.self, from: $0)
            } catch {
                throw error
            }
        }
    }
}
