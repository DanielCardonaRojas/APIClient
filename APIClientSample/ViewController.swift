//
//  ViewController.swift
//  APIClientSample
//
//  Created by Daniel Cardona Rojas on 5/21/19.
//  Copyright © 2019 Daniel Cardona Rojas. All rights reserved.
//

import UIKit
import APIClient
import Combine

class ViewController: UIViewController {

    lazy var client: APIClient = {
        let configuration = URLSessionConfiguration.default
        let url = URL(string: "https://jsonplaceholder.typicode.com")!
        let client = APIClient(baseURL: url, configuration: configuration)
        return client
    }()

    var disposables = Set<AnyCancellable>()

    override func viewDidLoad() {
        super.viewDidLoad()
        let endpoint = API.Todos.get()

        // Callback API
        client.request(endpoint, success: { item in
            print("\(item)")
        }, fail: { error in
            print("Error \(error.localizedDescription)")
        })

        // Combine API
        let publisher: AnyPublisher<Todo, Error> = client.request(endpoint)

        publisher.sink(receiveCompletion: { completion in
            if case let .failure(error) = completion {
                print("Error \(error.localizedDescription)")
            }
        }, receiveValue: { value in
            print("\(value)")
        }).store(in: &disposables)
    }

}
