//
//  Bundle+Extensions.swift
//  APIClient
//
//  Created by Daniel Cardona Rojas on 11/04/21.
//  Copyright © 2021 Daniel Cardona Rojas. All rights reserved.
//

import Foundation

private class BundleFinder {}

extension Foundation.Bundle {
    /// Returns the resource bundle associated with the current Swift module.
    public static func module(for aClass: AnyClass) -> Bundle {
        let bundleName = "APIClient_APIClientTests"

        let candidates = [
            // Bundle should be present here when the package is linked into an App.
            Bundle.main.resourceURL,

            // Bundle should be present here when the package is linked into a framework.
            Bundle(for: BundleFinder.self).resourceURL,
            // For command-line tools.
            Bundle.main.bundleURL,
        ]

        for candidate in candidates {
            let bundlePath = candidate?.appendingPathComponent(bundleName + ".bundle")
            if let bundle = bundlePath.flatMap(Bundle.init(url:)) {
                return bundle
            }
        }
        
        return Bundle(for: aClass)
    }
    
    public static var module: Bundle = {
        let bundleName = "APIClient_APIClientTests"

        let candidates = [
            // Bundle should be present here when the package is linked into an App.
            Bundle.main.resourceURL,

            // Bundle should be present here when the package is linked into a framework.
            Bundle(for: BundleFinder.self).resourceURL,
            // For command-line tools.
            Bundle.main.bundleURL,
        ]

        for candidate in candidates {
            let bundlePath = candidate?.appendingPathComponent(bundleName + ".bundle")
            if let bundle = bundlePath.flatMap(Bundle.init(url:)) {
                return bundle
            }
        }
        
        return Bundle(for: BundleFinder.self)
    }()
}

extension Bundle {
    /// Load data from file especified by Package.swift or in Xcode defined bundle
    public func dataFor(_ file: String) throws -> Data {
        let fileName = String(file.prefix(while: { $0 != "." }))
        var fileExtension = String(file.drop(while: { $0 != "."}))
        fileExtension.removeFirst()
        
        let packageUrl = self.url(forResource: fileName, withExtension: fileExtension)
        let resourceUrl = self.resourceURL?.appendingPathComponent(file)

        guard let url = resourceUrl ?? packageUrl  else {
            throw NSError()
        }

        let data = try Data(contentsOf: URL(fileURLWithPath: url.path))
        return data
    }
}
