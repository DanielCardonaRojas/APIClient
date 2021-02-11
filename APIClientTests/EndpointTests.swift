//
//  EndpointTests.swift
//  APIClientTests
//
//  Created by Daniel Rojas on 9/02/21.
//  Copyright © 2021 Daniel Cardona Rojas. All rights reserved.
//

import XCTest
@testable import APIClient

class EndpointTests: XCTestCase {

    func testWillParsePathWithQueryParams() {
        let endpoint = Endpoint<Void>(method: .get, path: "some/path?q=1&location=colombia")
        XCTAssert(endpoint.builder.queryParameters?.count ?? 0 == 2)
    }

}
