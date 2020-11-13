//
//  APIClientTests.swift
//  APIClientTests
//
//  Created by Daniel Cardona Rojas on 5/20/19.
//  Copyright © 2019 Daniel Cardona Rojas. All rights reserved.
//

import XCTest
@testable import APIClient

class APIClientTests: XCTestCase {

    func testBadStatusCodeIsTransformedIntoError()  {
        let request = RequestBuilder.get("")
        let expectation  = XCTestExpectation()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let client = APIClient(baseURL: "", configuration: configuration)

        MockURLProtocol.requestHandler = { request in
            HTTPURLResponse.fakeResponseFrom(statusCode: 401)
        }

        let endpoint = Endpoint(builder: request, decode: { $0 })

        client.request(endpoint, success: { value  in
        }, fail: { error in
            expectation.fulfill()
        })

        wait(for: [expectation], timeout: 2.0)
    }

    @available(iOS 13.0, *)
    func testBadStatusCodeIsTransformedIntoErrorForCombinePublisher()  {
        let request = RequestBuilder.get("")
        let expectation  = XCTestExpectation()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let client = APIClient(baseURL: "", configuration: configuration)

        MockURLProtocol.requestHandler = { request in
            HTTPURLResponse.fakeResponseFrom(statusCode: 401)
        }

        let endpoint = Endpoint(builder: request, decode: { $0 })

        let publisher = client.request(endpoint)
        let cancellable = publisher?.receive(on: RunLoop.main).sink(receiveCompletion: { completion in
            if case .failure = completion {
                expectation.fulfill()
            }
        }, receiveValue: { _ in

        })

        wait(for: [expectation], timeout: 2.0)
        cancellable?.cancel()
    }

    func testDefiningBaseUrlInEndpointOverridesTheGloballyConfigureForClient() {
        let request = RequestBuilder.get("/error/401").baseURL("https://jsonplaceholder.typicode.com")
        let expectation  = XCTestExpectation()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let client = APIClient(baseURL: "", configuration: configuration)

        MockURLProtocol.requestHandler = { request in
            if request.url?.absoluteString == "https://jsonplaceholder.typicode.com/error/401" {
                expectation.fulfill()
            }
            return HTTPURLResponse.fakeResponseFrom(statusCode: 401)
        }

        let endpoint = Endpoint(builder: request, decode: { $0 })

        client.request(endpoint, success: { value  in }, fail: { error in })

        wait(for: [expectation], timeout: 2.0)
    }

    func testCanLoadJsonData() {
        let (response, data) = HTTPURLResponse.fakeResponseFrom(file: "posts.json")
        XCTAssert((data?.count ?? 0) > 0)
        XCTAssert(data != nil)
    }

    func testCanDecodeJsonContent() {
        let request = RequestBuilder(method: .get, path: "")
        let endpoint = Endpoint(builder: request, decode: {
            return try JSONDecoder().decode([Post].self, from: $0)
        })

        let expectation  = XCTestExpectation()
        let invertedExpectation = XCTestExpectation()
        invertedExpectation.isInverted = true
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]

        MockURLProtocol.requestHandler =  { _ in
            HTTPURLResponse.fakeResponseFrom(file: "posts.json")
        }

        let client = APIClient(baseURL: "", configuration: configuration)

        client.request(endpoint, success: { value  in
            expectation.fulfill()
        }, fail: { err in
            invertedExpectation.fulfill()
        })

        wait(for: [expectation], timeout: 2.0)
    }

    func testWhenErrorDoesNotCallParsingHandler() {
        let expectation = XCTestExpectation()
        expectation.isInverted = true
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]

        MockURLProtocol.requestHandler = { _ in HTTPURLResponse.fakeResponseFrom(statusCode: 401) }

        let endpoint = Endpoint(builder: RequestBuilder.get("/somePath"), decode: { data in
            expectation.fulfill()
        })
        let client = APIClient(baseURL: "", configuration: configuration)
        client.request(endpoint, success: { _ in }, fail: { _ in })

        wait(for: [expectation], timeout: 2.0)
    }

}

struct Post: Codable {
    let id: Int
    let title: String
    let body: String
}
