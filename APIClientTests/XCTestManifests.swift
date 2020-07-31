//
//  File.swift
//  
//
//  Created by Daniel Cardona Rojas on 15/05/20.
//


import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(APIClientTests.allTests),
    ]
}
#endif
