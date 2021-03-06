//
//  RemoteWorker.swift
//  ACNetwork
//
//  Created by AppCraft LLC on 6/30/21.
//

import Foundation

public protocol RemoteWorkerInterface: AnyObject {
    var isLoggingEnabled: Bool { get set }
    
    func execute(_ request: URLRequest, completion: @escaping (_ result: Data?, _ response: HTTPURLResponse?, _ error: Error?) -> Void) -> String
    func cancel(_ taskUid: String)
}

open class RemoteWorker: NSObject, RemoteWorkerInterface {
    
    // MARK: - Props
    public var isLoggingEnabled: Bool
    
    private weak var sessionDelegate: URLSessionDelegate?
    private var activeTasks: [String: URLSessionDataTask]
    private var urlSession: URLSession?
    
    // MARK: - Initialization
    public init(sessionConfiguration: URLSessionConfiguration? = nil, sessionDelegate: URLSessionDelegate? = nil) {
        self.activeTasks = [:]
        self.isLoggingEnabled = RemoteConfiguration.shared.isLoggingEnabled
        self.sessionDelegate = sessionDelegate
        
        super.init()
        
        if let sessionConfiguration = sessionConfiguration {
            self.urlSession = URLSession(configuration: sessionConfiguration, delegate: sessionDelegate, delegateQueue: nil)
        } else {
            self.urlSession = URLSession(configuration: RemoteConfiguration.shared.sessionConfiguration, delegate: sessionDelegate, delegateQueue: nil)
        }
    }
    
    // MARK: - RemoteWorkerInterface
    
    public func execute(_ request: URLRequest, completion: @escaping (_ result: Data?, _ response: HTTPURLResponse?, _ error: Error?) -> Void) -> String {
        let newTaskUid: String = UUID().uuidString
        
        let newTask = self.urlSession?.dataTask(with: request, completionHandler: { data, response, error in
            if self.isLoggingEnabled {
                NSLog("[ACNetwork:RemoteWorker] - REQUEST URL: \(request.url?.absoluteString ?? "UNKNOWN")")
                if let requestHeaders = request.allHTTPHeaderFields {
                    NSLog("[ACNetwork:RemoteWorker] - REQUEST HEADERS: \(requestHeaders)")
                }
                if let requestBody = request.httpBody, let requestBodyString = String(data: requestBody, encoding: .utf8) {
                    NSLog("[ACNetwork:RemoteWorker] - REQUEST BODY: \(requestBodyString)")
                }
                if let httpResponse = response as? HTTPURLResponse {
                    NSLog("[ACNetwork:RemoteWorker] - RESPONSE CODE: \(httpResponse.statusCode)")
                    if let responseHeaders = httpResponse.allHeaderFields as? [String: Any] {
                        NSLog("[ACNetwork:RemoteWorker] - RESPONSE HEADERS: \(responseHeaders)")
                    }
                }
                if let recievedData = data, let stringData = String(data: recievedData, encoding: .utf8) {
                    debugPrint("[ACNetwork:RemoteWorker] - RESPONSE DATA: \(stringData)")
                } else {
                    NSLog("[ACNetwork:RemoteWorker] - RESPONSE DATA: UNKNOWN")
                }
            }
            
            self.activeTasks[newTaskUid] = nil
            completion(data, response as? HTTPURLResponse, error)
        })
        
        self.activeTasks[newTaskUid] = newTask
        self.activeTasks[newTaskUid]?.resume()
        
        return newTaskUid
    }
    
    public func cancel(_ taskUid: String) {
        if self.activeTasks[taskUid] != nil {
            if self.isLoggingEnabled {
                NSLog("[ACNetwork:RemoteWorker] - WARNING: Task < \(taskUid) > canceled")
            }
            self.activeTasks[taskUid]?.cancel()
        }
    }
}
