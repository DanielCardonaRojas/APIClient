//
//  API.swift
//  APIClientSample
//
//  Created by Daniel Cardona Rojas on 5/21/19.
//  Copyright © 2019 Daniel Cardona Rojas. All rights reserved.
//

import APIClient

struct Todo: Codable {
    let title: String
    let completed: Bool
}

enum API {
    enum Todos {
        static func get() -> Endpoint<Todo> {
            return Endpoint<Todo>(method: .get, path: "/todos/1", { $0 })
        }
    }
}
