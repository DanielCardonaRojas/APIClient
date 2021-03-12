//
//  MockAPIClientTests.swift
//  APIClientTests
//
//  Created by Daniel Cardona Rojas on 12/03/21.
//  Copyright © 2021 Daniel Cardona Rojas. All rights reserved.
//

import XCTest
import Foundation
@testable import APIClient

struct User: Codable, Equatable {
    let name: String
    
    static func fake() -> User {
        return User(name: "FakeUser")
    }
}

struct Pet: Codable, Equatable {
    let name: String
    
    static func fake() -> Pet {
        return Pet(name: "FakeUser")
    }
}

class MockAPIClientTests: XCTestCase {
    var sut: APIClientHijacker!
    
    override func setUp() {
        sut = APIClientHijacker.sharedInstance
    }
    
    override func tearDown() {
        sut.clear()
    }
    
    func testCanregisterSubstituteMatcherMatchingAllEndpointOfType() {
        sut.registerSubstitute(User.fake(), matchingRequestBy: .any)
        let endpoint = Endpoint<User>(method: .get, path: "/")
        let substitute = sut.hijack(endpoint: endpoint)
        XCTAssert(substitute != nil)
        XCTAssert(User.fake() ~= substitute!)
    }
    
    func testMatchMethodReturnsNilForUnregisterSubstituteedType() {
        sut.registerSubstitute(User.fake(), matchingRequestBy: .any)
        let endpoint = Endpoint<Pet>(method: .get, path: "/")
        let substitute = sut.hijack(endpoint: endpoint)
        XCTAssert(substitute == nil)
    }
    
    func testCanRegistherMatcherMatchingMethod() {
        sut.registerSubstitute(User.fake(), matchingRequestBy: .method(.post))
        let endpoint = Endpoint<User>(method: .post, path: "/")
        let substitute = sut.hijack(endpoint: endpoint)
        XCTAssert(substitute != nil)
        XCTAssert(User.fake() ~= substitute!)
        
    }
    
    func testSubstituteIsNilWhenMatchKindIsMethodAndDoesNotMatchEndpointMethod() {
        sut.registerSubstitute(User.fake(), matchingRequestBy: .method(.post))
        let endpoint = Endpoint<User>(method: .get, path: "/")
        let substitute = sut.hijack(endpoint: endpoint)
        XCTAssert(substitute == nil)
    }
    
    func testCanMatchPath() {
        sut.registerSubstitute(User.fake(), matchingRequestBy: .path("/users/1"))
        let endpoint = Endpoint<User>(method: .post, path: "/users/1")
        let substitute = sut.hijack(endpoint: endpoint)
        XCTAssert(substitute != nil)
        XCTAssert(User.fake() ~= substitute!)
    }
    
    func testReturnsNilWhenPathDoesNothijack() {
        sut.registerSubstitute(User.fake(), matchingRequestBy: .path("/users/1"))
        let endpoint = Endpoint<User>(method: .post, path: "/admins/1")
        let substitute = sut.hijack(endpoint: endpoint)
        XCTAssert(substitute == nil)
    }
    
    func testCanMatchPathSegment() {
        sut.registerSubstitute(User.fake(), matchingRequestBy: .path("/users/*"))
        let endpoint = Endpoint<User>(method: .post, path: "/users/1")
        let substitute = sut.hijack(endpoint: endpoint)
        XCTAssert(substitute != nil)
        XCTAssert(User.fake() ~= substitute!)
    }
    
    func testCanMatchPathWithRegex() {
        sut.registerSubstitute(User.fake(), matchingRequestBy: .path(#"/.+/\d"#))
        let endpoint = Endpoint<User>(method: .post, path: "/users/1")
        let substitute = sut.hijack(endpoint: endpoint)
        XCTAssert(substitute != nil)
        XCTAssert(User.fake() ~= substitute!)
    }
}


extension Result where Success: Equatable {
    
    static func ~=(lhs: Success, rhs: Result) -> Bool {
        switch rhs {
        case .failure(_):
            return false
        case .success(let value):
            return lhs == value
        }
        
    }
}
