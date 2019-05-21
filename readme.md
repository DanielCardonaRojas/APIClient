# API Client

A simple networking abstraction inspired by: http://kean.github.io/post/api-client
This is a work in progress (not battle tested).


# Installation

## Carthage

```shell 
github "DanielCardonaRojas/APIClient" ~> 1.0.0
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


