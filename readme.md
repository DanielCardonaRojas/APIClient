# API Client

A simple networking abstraction inspired by: http://kean.github.io/post/api-client
This is a work in progress (not battle tested).


# Installation

## Carthage

```shell 
github "DanielCardonaRojas/APIClient" ~> 1.0.1
```

## Cocoapods

```shell
pod 'APIClient', :git => 'https://github.com/DanielCardonaRojas/APIClient', :tag => '1.0.1', :branch => 'master'
```

## SwiftPM
```shell
.package(url: "https://github.com/DanielCardonaRojas/APIClient", .upToNextMajor(from: "1.0.0"))
```

# Usage

1. Create a client object pointing to some base url

```swift
lazy var client: APIClient = {
	let configuration = URLSessionConfiguration.default
	let client = APIClient(baseURL: "https://jsonplaceholder.typicode.com", configuration: configuration)
	return client
}()
```

2. Define a declerative API

```swift
struct Todo: Codable {
    let title: String
    let completed: Bool
}

enum API {
    enum Todos {
        static func get() -> Endpoint<Todo> {
            return Endpoint<Todo>(method: .get, path: "/todos/1")
        }
    }
}
```

3. Consume the API (Comes with Callback and combine API), refer to the section below to integrate with PromiseKit or RxSwift

```swift
// Callback API
client.request(endpoint, success: { item in
	print("\(item)")
}, fail: { error in
	print("Error \(error.localizedDescription)")
})

// Combine API
let publisher: AnyPublisher<Todo, Error>? = client.request(endpoint)

self.cancellable = publisher?.sink(receiveCompletion: { completion in
	if case let .failure(error) = completion {
		print("Error \(error.localizedDescription)")
	}
}, receiveValue: { value in
	print("\(value)")
})
```


# PromiseKit Integration

Integrating PromiseKit can be done through the following extension: 

```swift
import PromiseKit

extension APIClient {
    func request<Response, T>(_ requestConvertible: T,
                              additionalHeaders headers: [String: String]? = nil,
                              additionalQuery queryParameters: [String: String]? = nil,
                              baseUrl: URL? = nil) -> Promise<T.Result>
        where T: URLResponseCapable, T: URLRequestConvertible, T.Result == Response {
            return Promise { seal in
                self.request(requestConvertible, additionalHeaders: headers, additionalQuery: queryParameters, success: { response in
                    seal.fulfill(response)
                }, fail: { error in
                    seal.reject(error)
                })

            }
    }
}

```


# RxSwift Integration

Use this extension


```shell
import RxSwift

extension APIClient {
    
    func request<Response, T>(_ requestConvertible: T,
                              additionalHeaders headers: [String: String]? = nil,
                              additionalQuery queryParameters: [String: String]? = nil,
                              baseUrl: URL? = nil) -> Observable<T.Result>
        where T: URLResponseCapable, T: URLRequestConvertible, T.Result == Response {
            
            return Observable.create({ observer in
                let dataTask = self.request(requestConvertible, additionalHeaders: headers, additionalQuery: queryParameters, baseUrl: baseUrl, success: { response in
                    observer.onNext(response)
                    observer.onCompleted()
                }, fail: {error in
                    observer.onError(error)
                })
                
                return Disposables.create {
                    dataTask?.cancel()
                }
            })
    }
}
```


