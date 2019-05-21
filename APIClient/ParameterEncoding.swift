//
//  ParameterEncoding.swift
//  APIClient
//
//  Created by Daniel Cardona Rojas on 5/20/19.
//  Copyright © 2019 Daniel Cardona Rojas. All rights reserved.
//

public typealias Parameters = [String: Any]
public typealias MixedLocationParams = [ParameterEncoding.Location: Parameters]
public typealias Path = String

public enum Method: String {
    case get = "GET", post = "POST", put = "PUT", patch = "PATCH", delete = "DELETE"
}

public struct ParameterEncoding {
    public enum Location: String {
        case queryString, httpBody
        
        static func defaultLocation(for method: Method) -> Location {
            switch method {
            case .get:
                return .queryString
            default:
                return .httpBody
            }
        }
    }
    
    public enum BodyEncoding {
        case formUrlEncoded, jsonEncoded
        var contentType: String? {
            switch self {
            case .formUrlEncoded:
                return "application/x-www-form-urlencoded; charset=utf-8"
            case .jsonEncoded:
                return "application/json; charset=UTF-8"
            }
        }
    }
    
    let location: Location?
    let bodyEncoding: BodyEncoding
    
    public init(preferredBodyEncoding: BodyEncoding = .jsonEncoded, location: Location? = nil) {
        self.location = location
        self.bodyEncoding = preferredBodyEncoding
    }
    
    public static func preferredBodyEncoding(_ encoding: BodyEncoding) -> ParameterEncoding {
        return ParameterEncoding(preferredBodyEncoding: encoding, location: nil)
    }
    
    public static let methodDependent = ParameterEncoding(preferredBodyEncoding: .jsonEncoded, location: nil)
    
}
