//
//  APIClient+Combine.swift
//  APIClient
//
//  Created by Daniel Cardona Rojas on 18/12/19.
//  Copyright © 2019 Daniel Cardona Rojas. All rights reserved.
//

import Foundation
import Combine

@available(OSX 10.15, *)
@available(iOS 13.0, *)
extension APIClient {
    /**
     Executes an http request.

     
     - Parameter requestConvertible: Object conforming to URLResponseCapable & URLRequestConvertible (usually Endpoint)
     - Parameter baseUrl: Ovewrite the base url for this request.
     - Returns: A publisher of type AnyPublisher<Response, Error>
     
     Note: status codes > 400 will be transformed into a NetworkError type
     This makes no assumptions on what thread this should be called on. Usually just remember to call with:
         
            apiClient.recieve(on: RunLoop.main).sink(...)

     
     */
    public func request<T>(_ requestConvertible: Endpoint<T>,
                                     additionalHeaders headers: [String: String]? = nil,
                                     additionalQuery queryParameters: [String: String]? = nil,
                                     baseUrl: URL? = nil) -> AnyPublisher<T, Error>
        {

            var httpRequest = requestConvertible.asURLRequest(baseURL: baseUrl ?? self.baseURL)
            let additionalQueryItems = queryParameters?.map({ (k, v) in URLQueryItem(name: k, value: v) }) ?? []
            httpRequest.allHTTPHeaderFields = headers
            httpRequest.addQueryItems(additionalQueryItems)
        
        
            if let hijackingClient = hijacker, let match = hijackingClient.hijack(endpoint: requestConvertible) {
                return Future { promise in
                    promise(match)
                }.eraseToAnyPublisher()
            }

            let publisher = session.dataTaskPublisher(for: httpRequest)

            return publisher
                .tryMap({ data, response in
                    let httpResponse = response as! HTTPURLResponse
                    if httpResponse.isOK {
                        return try requestConvertible.handle(data: data)
                    } else {
                        throw NetworkError(statusCode: httpResponse.statusCode, data: data)
                    }
                }).eraseToAnyPublisher()
    }
}

@available(OSX 10.15, *)
@available(iOS 13.0, *)
/// A convenience Combine Publisher  that allows chaining a series of Endpoint using the same APIClient instance.
public struct APIClientPublisher<Response>: Publisher {
    public typealias Output = Response
    public typealias Failure = Error

    let client: APIClient
    var publisher: AnyPublisher<Response, Error>

    /**
         Start a http request sequence from a recycled APIClient and initial endpoint
     - Parameter client: The APIClient instance to be used for the sequence of requests
     - Parameter endpoint: The Endpoint for the first request
     */
    public init(client: APIClient, endpoint: Endpoint<Response>) {
        self.client = client
        publisher = client.request(endpoint)
    }

    private init(publisher: AnyPublisher<Response, Error>, client: APIClient) {
        self.publisher = publisher
        self.client = client
    }

    public func receive<S>(subscriber: S) where S: Subscriber, Self.Failure == S.Failure, Self.Output == S.Input {
        publisher.receive(subscriber: subscriber)
    }

    /**
     Make a next request depending  on the output of the previous
     - Parameter pipe: A closure receiving `Endpoint.Result` of the current endpoint and returning a new endpoint from that
     */
    public func chain<T>(_ pipe: @escaping (Response) -> Endpoint<T>) -> APIClientPublisher<T> {
        let newPublisher: AnyPublisher<T, Error> = publisher.flatMap({ (response: Response) -> AnyPublisher<T, Error> in
            let nextEndpoint = pipe(response)
            return client.request(nextEndpoint)
        }).eraseToAnyPublisher()

        return APIClientPublisher<T>(publisher: newPublisher.eraseToAnyPublisher(), client: client)
    }
}
