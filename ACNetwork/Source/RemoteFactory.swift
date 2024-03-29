//
//  RemoteFactory.swift
//  ACNetwork
//
//  Created by AppCraft LLC on 6/30/21.
//

import Foundation

public enum RemoteFactory {
    
    // MARK: - Public methods
    public static func request(path: String, parameters: [String: Any]?, headers: [String: String]?, method: HTTPMethod, bodyType: RequestBodyType = .json) -> URLRequest? {
        switch method {
        case .get,
             .head:
            return self.createRequestWithUrlParameters(path: path, parameters: parameters, headers: headers, method: method)
        case .post,
             .put,
             .patch,
             .delete:
            return self.createRequestWithBodyParameters(path: path, parameters: parameters, headers: headers, method: method, bodyType: bodyType)
        case .options,
             .trace,
             .connect:
            // TODO: Add support to other http methods
            NSLog("[ACNetwork:RemoteFactory] - ERROR: method \(method.stringValue) is not supporting now.")
        }
        return nil
    }
    
    public static func request<T: Codable>(path: String, object: T, headers: [String: String]?, method: HTTPMethod) -> URLRequest? {
        switch method {
        case .get,
             .head:
            NSLog("[ACNetwork:RemoteFactory] - ERROR: request with generic parameters does not support GET and HEAD methodы. Please use dictionary parameters instead.")
        case .post,
             .put,
             .patch,
             .delete:
            let urlString = path
            guard let url = URL(string: urlString) else { return nil }
            
            var request = URLRequest(url: url)
            request.httpMethod = method.stringValue
            
            let jsonEncoder = JSONEncoder()
            var jsonData: Data?
            do {
                jsonData = try jsonEncoder.encode(object)
            } catch let error {
                NSLog("[ACNetwork:RemoteFactory] - ERROR: could not serialize object, \(error.localizedDescription).")
            }
            request.httpBody = jsonData
            
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            if let headers = headers {
                for header in headers {
                    request.setValue(header.value, forHTTPHeaderField: header.key)
                }
            }
            
            return request
        case .options,
             .trace,
             .connect:
            // TODO: Add support to other http methods
            NSLog("[ACNetwork:RemoteFactory] - ERROR: method \(method.stringValue) is not supporting now.")
        }
        
        return nil
    }
    
    public static func upload(path: String, fileKey: String, files: [RemoteUploadModel], parameters: [String: Any]?, headers: [String: String]?) -> URLRequest? {
        let urlString = path
        guard let url = URL(string: urlString) else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethod.post.stringValue
        
        if let headers = headers {
            for header in headers {
                request.setValue(header.value, forHTTPHeaderField: header.key)
            }
        }
        
        let boundary = self.generateBoundaryString()
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = self.generateFormDataBody(boundary: boundary, parameters: parameters, fileKey: fileKey, files: files)
        
        return request
    }
    
    // MARK: - Private methods
    private static func createRequestWithUrlParameters(path: String, parameters: [String: Any]?, headers: [String: String]?, method: HTTPMethod) -> URLRequest? {
        var parameterString = ""
        if let parameters = parameters {
            parameterString = self.generateUrlString(with: parameters)
        }
        
        var urlString = path
        if !parameterString.isEmpty {
            urlString += "?" + parameterString
        }
        
        guard let url = URL(string: urlString) else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = method.stringValue
        
        if let headers = headers {
            for header in headers {
                request.setValue(header.value, forHTTPHeaderField: header.key)
            }
        }
        
        return request
    }
    
    private static func createRequestWithBodyParameters(path: String, parameters: [String: Any]?, headers: [String: String]?, method: HTTPMethod, bodyType: RequestBodyType) -> URLRequest? {
        let urlString = path
        guard let url = URL(string: urlString) else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.stringValue
        
        switch bodyType {
        case .json:
            var jsonData: Data?
            if let parameters = parameters {
                do {
                    jsonData = try JSONSerialization.data(withJSONObject: parameters, options: [])
                } catch let error {
                    NSLog("[ACNetwork:RemoteFactory] - ERROR: could not serialize dictionary, \(error.localizedDescription).")
                }
            }
            request.httpBody = jsonData
            
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        case .formData:
            let boundary = self.generateBoundaryString()
            
            if let parameters = parameters {
                request.httpBody = self.generateFormDataBody(boundary: boundary, parameters: parameters)
            }
            
            request.setValue("application/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        }
        
        if let headers = headers {
            for header in headers {
                request.setValue(header.value, forHTTPHeaderField: header.key)
            }
        }
        
        return request
    }
    
    static func generateUrlString(with parameters: [String: Any]) -> String {
        ParameterStringGenerator.generate(with: parameters)
    }
    
    private static func generateBoundaryString() -> String {
        "Boundary-\(UUID().uuidString)"
    }
    
    private static func generateFormDataBody(boundary: String, parameters: [String: Any]?, fileKey: String = "", files: [RemoteUploadModel] = []) -> Data {
        var body = Data()
        
        if let parameters = parameters {
            for (key, value) in parameters {
                body.append("--\(boundary)\r\n")
                body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
                body.append("\(value)\r\n")
            }
        }
        
        for file in files {
            let data = file.data
            let filename = file.filename
            let mimetype = data.mimeType
            
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"\(fileKey)\"; filename=\"\(filename)\"\r\n")
            body.append("Content-Type: \(mimetype)\r\n\r\n")
            body.append(data)
            body.append("\r\n")
        }
        
        body.append("--\(boundary)--\r\n")
        return body
    }
}
