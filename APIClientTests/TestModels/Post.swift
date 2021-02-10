//
//  Post.swift
//  APIClientTests
//
//  Created by Daniel Rojas on 10/02/21.
//  Copyright © 2021 Daniel Cardona Rojas. All rights reserved.
//

import Foundation

struct Post: Codable {
    let id: Int
    let title: String
    let body: String
}

struct PostDetail: Codable {
    let id: Int
    let title: String
    let body: String
    let comments: [String]
}
