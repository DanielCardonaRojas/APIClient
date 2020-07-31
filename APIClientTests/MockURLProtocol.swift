//
//  MockURLProtocol.swift
//  APIClientTests
//
//  Created by Daniel Cardona Rojas on 31/07/20.
//  Copyright © 2020 Daniel Cardona Rojas. All rights reserved.
//

import Foundation

@objc class MockURLProtocol: URLProtocol {

    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data?))?

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }


    override class func canInit(with task: URLSessionTask) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    public override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            fatalError("Handler is unavailable.")
        }

        do {
            // 2. Call handler with received request and capture the tuple of response and data.
            let (response, data) = try handler(request)

            // 3. Send received response to the client.
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)

            if let data = data {
                // 4. Send received data to the client.
                client?.urlProtocol(self, didLoad: data)
            }

            // 5. Notify request has been finished.
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            // 6. Notify received error.
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    // this method is required but doesn't need to do anything
    override func stopLoading() {

    }
}


extension HTTPURLResponse {
    static func fakeResponseFrom(statusCode: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: URL(string: "https://jsonplaceholder.typicode.com")!, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
    }
}
