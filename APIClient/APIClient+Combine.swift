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
    public func request<Response, T>(_ requestConvertible: T,
                              additionalHeaders headers: [String: String]? = nil,
                              additionalQuery queryParameters: [String: String]? = nil,
                              baseUrl: URL? = nil) -> AnyPublisher<Response, Error>
        where T: URLResponseCapable & URLRequestConvertible, T.Result == Response {

            var httpRequest = requestConvertible.asURLRequest(baseURL: baseUrl ?? self.baseURL)
            let additionalQueryItems = queryParameters?.map({ (k, v) in URLQueryItem(name: k, value: v) }) ?? []
            httpRequest.allHTTPHeaderFields = headers
            httpRequest.addQueryItems(additionalQueryItems)


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
