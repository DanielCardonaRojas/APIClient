//
//  APIClient+Combine.swift
//  APIClient
//
//  Created by Daniel Cardona Rojas on 18/12/19.
//  Copyright © 2019 Daniel Cardona Rojas. All rights reserved.
//

import Foundation
import Combine

@available(iOS 13.0, *)
extension APIClient {
    public func request<Response, T>(_ requestConvertible: T,
                              additionalHeaders headers: [String: String]? = nil,
                              additionalQuery queryParameters: [String: String]? = nil,
                              baseUrl: URL? = nil) -> AnyPublisher<Response, Error>?
        where T: URLResponseCapable & URLRequestConvertible, T.Result == Response {

            guard let base = baseUrl ?? self.baseURL else {
                return nil
            }


            var httpRequest = try! requestConvertible.asURLRequest(baseURL: base)
            let additionalQueryItems = queryParameters?.map({ (k, v) in URLQueryItem(name: k, value: v) }) ?? []
            httpRequest.allHTTPHeaderFields = headers
            httpRequest.addQueryItems(additionalQueryItems)


            let publisher = session.dataTaskPublisher(for: httpRequest)

            let result = publisher.tryMap({ data, response in
                return try requestConvertible.handle(data: data)
                }).eraseToAnyPublisher()

            return result
    }
}
