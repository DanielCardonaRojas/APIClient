//
//  APIClient.swift
//  APIClient
//
//  Created by Daniel Cardona Rojas on 5/20/19.
//  Copyright © 2019 Daniel Cardona Rojas. All rights reserved.
//

import Foundation

public protocol URLRequestConvertible {
    func asURLRequest(baseURL: URL) throws -> URLRequest
}

public protocol URLResponseCapable {
    associatedtype Result
    func handle(data: Data) throws -> Result
}

public class APIClient {
    
    private var baseURL: URL?
    lazy var session: URLSession = {
        return URLSession(configuration: .default)
    }()
    
    public init(baseURL: String, configuration: URLSessionConfiguration? = nil) {
        if let config = configuration {
            self.session = URLSession(configuration: config)
        }
        self.baseURL = URL(string: baseURL)
    }
    
    @discardableResult
    public func request<Response, T>(_ requestConvertible: T,
                              additionalHeaders headers: [String: String]? = nil,
                              additionalQuery queryParameters: [String: String]? = nil,
                              baseUrl: URL? = nil,
                              success: @escaping (Response) -> Void,
                              fail: @escaping (Error) -> Void) -> URLSessionDataTask?
        where T: URLResponseCapable, T: URLRequestConvertible, T.Result == Response {
            guard let base = baseUrl ?? self.baseURL else {
                return nil
            }
            
            
            do {
                var httpRequest = try requestConvertible.asURLRequest(baseURL: base)
                let additionalQueryItems = queryParameters?.map({ (k, v) in URLQueryItem(name: k, value: v) }) ?? []
                httpRequest.allHTTPHeaderFields = headers
                httpRequest.addQueryItems(additionalQueryItems)
                let task: URLSessionDataTask = session.dataTask(with: httpRequest) { (data: Data?, response: URLResponse?, error: Error?) in
                    if let data = data {
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
            } catch(let encodingError) {
                fail(encodingError)
            }
            
            return nil
    }
    
}


extension URLRequest {
    mutating func addQueryItems(_ items: [URLQueryItem]) {
        guard let url = self.url, items.count > 0 else {
            return
        }
        var cmps = URLComponents(string: url.absoluteString)
        let currentItems = cmps?.queryItems ?? []
        cmps?.queryItems = currentItems + items
        self.url = cmps?.url
    }
}
