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
    let tBaseUrl = URL(string: "google.com")!
    var client: APIClient!
    
    override func setUp() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        client = APIClient(baseURL: tBaseUrl, configuration: configuration)
    }

    func testBadStatusCodeIsTransformedIntoError() {
        let request = RequestBuilder.get("")
        let expectation  = XCTestExpectation()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let client = APIClient(baseURL: tBaseUrl, configuration: configuration)

        MockURLProtocol.requestHandler = { _ in
            HTTPURLResponse.fakeResponseFrom(statusCode: 401)
        }

        let endpoint = Endpoint(builder: request, decode: { $0 })

        client.request(endpoint, success: { _  in
        }, fail: { _ in
            expectation.fulfill()
        })

        wait(for: [expectation], timeout: 2.0)
    }
    
    func testCanParsePathAndQueryThroughURLComponents() {
        guard let components = URLComponents(string: "some/path?q=1&location=colombia") else {
            XCTFail()
            return
        }
        XCTAssert(components.query != nil)
        XCTAssert(components.queryItems?.count ?? 0 == 2)
        XCTAssert(components.host == nil)
    }
    

    @available(OSX 10.15, *)
    @available(iOS 13.0, *)
    func testBadStatusCodeIsTransformedIntoErrorForCombinePublisher() {
        let request = RequestBuilder.get("")
        let expectation  = XCTestExpectation()

        MockURLProtocol.requestHandler = { _ in
            HTTPURLResponse.fakeResponseFrom(statusCode: 401)
        }

        let endpoint = Endpoint(builder: request, decode: { $0 })

        let publisher = client.request(endpoint)
        let cancellable = publisher.receive(on: RunLoop.main).sink(receiveCompletion: { completion in
            if case .failure = completion {
                expectation.fulfill()
            }
        }, receiveValue: { _ in

        })

        wait(for: [expectation], timeout: 2.0)
        cancellable.cancel()
    }

    func testDefiningBaseUrlInEndpointOverridesTheGloballyConfigureForClient() {
        let request = RequestBuilder.get("/error/401").baseURL("https://jsonplaceholder.typicode.com")
        let expectation  = XCTestExpectation()

        MockURLProtocol.requestHandler = { request in
            if request.url?.absoluteString == "https://jsonplaceholder.typicode.com/error/401" {
                expectation.fulfill()
            }
            return HTTPURLResponse.fakeResponseFrom(statusCode: 401)
        }

        let endpoint = Endpoint(builder: request, decode: { $0 })

        client.request(endpoint, success: { _  in }, fail: { _ in })

        wait(for: [expectation], timeout: 2.0)
    }

    func testCanLoadJsonData() {
        let (_, data) = HTTPURLResponse.fakeResponseFrom(file: "posts.json")
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

        MockURLProtocol.requestHandler = { _ in
            HTTPURLResponse.fakeResponseFrom(file: "posts.json")
        }

        client.request(endpoint, success: { _  in
            expectation.fulfill()
        }, fail: { _ in
            invertedExpectation.fulfill()
        })

        wait(for: [expectation], timeout: 2.0)
    }

    func testWhenErrorDoesNotCallParsingHandler() {
        let expectation = XCTestExpectation()
        expectation.isInverted = true

        MockURLProtocol.requestHandler = { _ in HTTPURLResponse.fakeResponseFrom(statusCode: 401) }

        let endpoint = Endpoint(builder: RequestBuilder.get("/somePath"), decode: { _ in
            expectation.fulfill()
        })

        client.request(endpoint, success: { _ in }, fail: { _ in })

        wait(for: [expectation], timeout: 2.0)
    }
    
    func testReturnsResponseOfRegisterMockClientHijacker() {
        let expectation = XCTestExpectation()
        let noHttpExpectation = XCTestExpectation(description: "Does not execute real request")
        noHttpExpectation.isInverted = true
        
        APIClientHijacker.sharedInstance.registerSubstitute(User.fake(), matchingRequestBy: .any)
        
        client.hijacker = APIClientHijacker.sharedInstance
        
        let endpoint = Endpoint<User>(method: .get, path: "/")
        
        MockURLProtocol.requestHandler = { _ in
            noHttpExpectation.fulfill()
            return HTTPURLResponse.fakeResponseFrom(statusCode: 401)
        }
        
        client.request(endpoint, success: { response in
            if (response == User.fake()) {
                expectation.fulfill()
            }
        }, fail: { error in
            
        })

        wait(for: [expectation], timeout: 1.0)
    }
    

}

