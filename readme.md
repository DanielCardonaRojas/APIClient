# API Client

![APIClientTests](https://github.com/DanielCardonaRojas/APIClient/workflows/APIClientTests/badge.svg)
![](https://img.shields.io/github/v/tag/DanielCardonaRojas/APIClient)
[![codecov](https://codecov.io/gh/DanielCardonaRojas/APIClient/branch/master/graph/badge.svg?token=SJPX8AG809)](https://codecov.io/gh/DanielCardonaRojas/APIClient)

A simple networking abstraction inspired by: http://kean.github.io/post/api-client

## Features

- Provides RequestBuilder easily create your requests
- Declarative definition of endpoints
- Define your endpoints mostly with relative paths to a base URL.
- Easily adaptable to use with common reactive frameworks (RxSwift, PromiseKit) via extensions
- Comes with Combine support.
- Chain multiple requests easily
- Mocks responses easily

## Documentation

Checkout the docs [here](https://danielcardonarojas.github.io/APIClient)

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

## Chaining multiple request

Alternatively to using the regular combine API of the APIClient class, APIClientPublisher
creates a custom publisher from a APIClient and allows to easily chain multiple endpoints creating
a sequence dependent requests.

```swift
let endpoint: Endpoint<[Post]> = Endpoint(method: .get, path: "/posts")

APIClientPublisher(client: client, endpoint: endpoint).chain({
    Endpoint<PostDetail>(method: .get, path: "/posts/\($0.first!.id)")
}).receive(on: RunLoop.main)
.sink(receiveCompletion: { _ in

}, receiveValue: { _ in
    expectation.fulfill()
}).store(in: &disposables)
```

## Retrying a request

There is no built interceptors in this package but retrying requests and other related effects
can be accomplished, using combine built in facilities.

Retrying requests can be accomplished using `tryCatch` and has been documented by many authors,
give [this](https://www.donnywals.com/retrying-a-network-request-with-a-delay-in-combine/) a read for more details

```swift
  // Copied from https://www.donnywals.com/retrying-a-network-request-with-a-delay-in-combine/
  .tryCatch({ error -> AnyPublisher<(data: Data, response: URLResponse), Error> in
    print("In the tryCatch")

    switch error {
    case DataTaskError.rateLimitted, DataTaskError.serverBusy:
      return dataTaskPublisher
        .delay(for: 3, scheduler: DispatchQueue.global())
        .eraseToAnyPublisher()
    default:
      throw error
    }
  })
  .retry(2)
```

## Mocking Responses

It is easy to add fake responses that will bypass any http calls.

```swift
let client: APIClient = ...


APIClientHijacker.sharedInstance.registerSubstitute(User.fake(), matchingRequestBy: .any)

client.hijacker = APIClientHijacker.sharedInstance


let endpoint = Endpoint<User>(method: .get, path: "/")

client.request(endpoint) // Will return fake User

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
