//
//  APIClientPublisherTests.swift
//  APIClientTests
//
//  Created by Daniel Rojas on 9/02/21.
//  Copyright © 2021 Daniel Cardona Rojas. All rights reserved.
//

import XCTest
@testable import APIClient
import Combine

@available(OSX 10.15, *)
@available(iOS 13.0, *)
class APIClientPublisherTests: XCTestCase {
    let tBaseUrl = URL(string: "www.google.com")!
    var disposables = Set<AnyCancellable>()

    func testChainedResponse() {
        let expectation  = XCTestExpectation()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let client = APIClient(baseURL: tBaseUrl, configuration: configuration)
        var callCount = 0

        MockURLProtocol.requestHandler = { _ in
            if callCount == 0 {
                callCount += 1
                return HTTPURLResponse.fakeResponseFrom(file: "posts.json")
            } else {
                return HTTPURLResponse.fakeResponseFrom(file: "post_detail.json")
            }
        }

        let endpoint: Endpoint<[Post]> = Endpoint(method: .get, path: "/posts")

        APIClientPublisher(client: client, endpoint: endpoint).chain({
            Endpoint<PostDetail>(method: .get, path: "/posts/\($0.first!.id)")
        }).receive(on: RunLoop.main)
        .sink(receiveCompletion: { _ in

        }, receiveValue: { _ in
            expectation.fulfill()
        }).store(in: &disposables)

        wait(for: [expectation], timeout: 1.0)

    }

}
