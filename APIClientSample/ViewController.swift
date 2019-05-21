//
//  ViewController.swift
//  APIClientSample
//
//  Created by Daniel Cardona Rojas on 5/21/19.
//  Copyright © 2019 Daniel Cardona Rojas. All rights reserved.
//

import UIKit
import APIClient

class ViewController: UIViewController {

    lazy var client: APIClient = {
        let configuration = URLSessionConfiguration.default
        let client = APIClient(baseURL: "https://jsonplaceholder.typicode.com", configuration: configuration)
        return client
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let endpoint = API.Todos.get()
        
        client.request(endpoint, success: { item in
            print("\(item)")
        }, fail: { error in
            print("Error \(error.localizedDescription)")
        })
    }

}

