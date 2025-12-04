//
//  NetworkModule.swift
//  Pimeier
//
//  Created by AI Assistant
//

import Foundation

/// 网络请求模块
/// 提供 HTTP/HTTPS 请求、文件上传/下载、WebSocket 等功能
public class NetworkModule: PimeierModule {
    public static let moduleName = "Network"
    
    // 请求拦截器数组
    private var requestInterceptors: [(URLRequest) -> URLRequest] = []
    // 响应拦截器数组
    private var responseInterceptors: [(Data?, URLResponse?, Error?) -> (Data?, URLResponse?, Error?)] = []
    
    public required init() {}
    
    public func methods() -> [String: PimeierModuleMethod] {
        return [
            "request": request,
            "get": get,
            "post": post,
            "put": put,
            "delete": delete,
            "upload": upload,
            "download": download,
            "addRequestInterceptor": addRequestInterceptor,
            "addResponseInterceptor": addResponseInterceptor
        ]
    }
    
    // MARK: - REST API Methods
    
    /// 通用请求方法
    /// 参数: {
    ///   "url": "https://api.example.com/data",
    ///   "method": "GET|POST|PUT|DELETE" (默认 GET),
    ///   "headers": {"Authorization": "Bearer token", ...},
    ///   "body": "JSON字符串" 或 {"key": "value"} 字典,
    ///   "timeout": 30 (秒，默认 30)
    /// }
    private func request(params: [String: Any], callback: PimeierModuleCallback) {
        guard let urlString = params["url"] as? String,
              let url = URL(string: urlString) else {
            callback.failure("Missing or invalid parameter: url")
            return
        }
        
        let method = (params["method"] as? String)?.uppercased() ?? "GET"
        let timeout = (params["timeout"] as? Double) ?? 30.0
        let headers = params["headers"] as? [String: String] ?? [:]
        let body = params["body"]
        
        // 创建请求
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = timeout
        
        // 设置请求头
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // 处理请求体
        if let body = body {
            if let bodyString = body as? String {
                // 如果是字符串，尝试解析为 JSON
                if let bodyData = bodyString.data(using: .utf8) {
                    request.httpBody = bodyData
                    if !headers.keys.contains(where: { $0.lowercased() == "content-type" }) {
                        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    }
                }
            } else if let bodyDict = body as? [String: Any] {
                // 如果是字典，转换为 JSON
                if let jsonData = try? JSONSerialization.data(withJSONObject: bodyDict, options: []) {
                    request.httpBody = jsonData
                    if !headers.keys.contains(where: { $0.lowercased() == "content-type" }) {
                        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    }
                }
            }
        }
        
        // 应用请求拦截器
        for interceptor in requestInterceptors {
            request = interceptor(request)
        }
        
        // 执行请求
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            // 应用响应拦截器
            var finalData = data
            var finalResponse = response
            var finalError = error
            
            if let self = self {
                for interceptor in self.responseInterceptors {
                    let result = interceptor(finalData, finalResponse, finalError)
                    finalData = result.0
                    finalResponse = result.1
                    finalError = result.2
                }
            }
            
            DispatchQueue.main.async {
                if let error = finalError {
                    callback.failure("Network error: \(error.localizedDescription)")
                    return
                }
                
                guard let httpResponse = finalResponse as? HTTPURLResponse else {
                    callback.failure("Invalid response type")
                    return
                }
                
                // 构建响应对象
                var responseDict: [String: Any] = [
                    "statusCode": httpResponse.statusCode,
                    "headers": httpResponse.allHeaderFields
                ]
                
                // 解析响应数据
                if let data = finalData {
                    // 尝试解析为 JSON
                    if let json = try? JSONSerialization.jsonObject(with: data, options: []) {
                        responseDict["data"] = json
                    } else if let string = String(data: data, encoding: .utf8) {
                        responseDict["data"] = string
                    } else {
                        responseDict["data"] = data.base64EncodedString()
                    }
                }
                
                // 检查状态码
                if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                    callback.success(responseDict)
                } else {
                    let errorMsg = (responseDict["data"] as? [String: Any])?["message"] as? String
                        ?? (responseDict["data"] as? String)
                        ?? "HTTP \(httpResponse.statusCode)"
                    callback.failure(errorMsg)
                }
            }
        }
        
        task.resume()
    }
    
    /// GET 请求
    /// 参数: { "url": "...", "headers": {...}, "timeout": 30 }
    private func get(params: [String: Any], callback: PimeierModuleCallback) {
        var newParams = params
        newParams["method"] = "GET"
        request(params: newParams, callback: callback)
    }
    
    /// POST 请求
    /// 参数: { "url": "...", "body": {...}, "headers": {...}, "timeout": 30 }
    private func post(params: [String: Any], callback: PimeierModuleCallback) {
        var newParams = params
        newParams["method"] = "POST"
        request(params: newParams, callback: callback)
    }
    
    /// PUT 请求
    /// 参数: { "url": "...", "body": {...}, "headers": {...}, "timeout": 30 }
    private func put(params: [String: Any], callback: PimeierModuleCallback) {
        var newParams = params
        newParams["method"] = "PUT"
        request(params: newParams, callback: callback)
    }
    
    /// DELETE 请求
    /// 参数: { "url": "...", "headers": {...}, "timeout": 30 }
    private func delete(params: [String: Any], callback: PimeierModuleCallback) {
        var newParams = params
        newParams["method"] = "DELETE"
        request(params: newParams, callback: callback)
    }
    
    // MARK: - File Upload
    
    /// 文件上传
    /// 参数: {
    ///   "url": "https://api.example.com/upload",
    ///   "filePath": "/path/to/file" (Bundle 或 Documents 路径),
    ///   "fieldName": "file" (表单字段名，默认 "file"),
    ///   "formData": {"key": "value"} (其他表单字段),
    ///   "headers": {...}
    /// }
    private func upload(params: [String: Any], callback: PimeierModuleCallback) {
        guard let urlString = params["url"] as? String,
              let url = URL(string: urlString) else {
            callback.failure("Missing or invalid parameter: url")
            return
        }
        
        guard let filePath = params["filePath"] as? String else {
            callback.failure("Missing parameter: filePath")
            return
        }
        
        // 获取文件数据
        var fileData: Data?
        var fileName: String?
        
        // 尝试从 Bundle 加载
        if let bundlePath = Bundle.main.path(forResource: filePath, ofType: nil),
           let data = try? Data(contentsOf: URL(fileURLWithPath: bundlePath)) {
            fileData = data
            fileName = (filePath as NSString).lastPathComponent
        }
        // 尝试从 Documents 目录加载
        else if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fullPath = documentsPath.appendingPathComponent(filePath)
            if let data = try? Data(contentsOf: fullPath) {
                fileData = data
                fileName = (filePath as NSString).lastPathComponent
            }
        }
        
        guard let data = fileData, let name = fileName else {
            callback.failure("File not found: \(filePath)")
            return
        }
        
        let fieldName = (params["fieldName"] as? String) ?? "file"
        let formData = params["formData"] as? [String: String] ?? [:]
        let headers = params["headers"] as? [String: String] ?? [:]
        
        // 创建 multipart/form-data 请求体
        let boundary = "----PimeierBoundary\(UUID().uuidString)"
        var body = Data()
        
        // 添加表单字段
        for (key, value) in formData {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        
        // 添加文件
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(name)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        // 创建请求
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("\(body.count)", forHTTPHeaderField: "Content-Length")
        
        // 设置其他请求头
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // 应用请求拦截器
        for interceptor in requestInterceptors {
            request = interceptor(request)
        }
        
        request.httpBody = body
        
        // 执行上传
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            var finalData = data
            var finalResponse = response
            var finalError = error
            
            if let self = self {
                for interceptor in self.responseInterceptors {
                    let result = interceptor(finalData, finalResponse, finalError)
                    finalData = result.0
                    finalResponse = result.1
                    finalError = result.2
                }
            }
            
            DispatchQueue.main.async {
                if let error = finalError {
                    callback.failure("Upload error: \(error.localizedDescription)")
                    return
                }
                
                guard let httpResponse = finalResponse as? HTTPURLResponse else {
                    callback.failure("Invalid response type")
                    return
                }
                
                var responseDict: [String: Any] = [
                    "statusCode": httpResponse.statusCode,
                    "headers": httpResponse.allHeaderFields
                ]
                
                if let data = finalData {
                    if let json = try? JSONSerialization.jsonObject(with: data, options: []) {
                        responseDict["data"] = json
                    } else if let string = String(data: data, encoding: .utf8) {
                        responseDict["data"] = string
                    }
                }
                
                if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                    callback.success(responseDict)
                } else {
                    callback.failure("Upload failed with status \(httpResponse.statusCode)")
                }
            }
        }
        
        task.resume()
    }
    
    // MARK: - File Download
    
    /// 文件下载
    /// 参数: {
    ///   "url": "https://example.com/file.pdf",
    ///   "savePath": "documents/filename.pdf" (可选，默认保存到 Documents),
    ///   "headers": {...}
    /// }
    private func download(params: [String: Any], callback: PimeierModuleCallback) {
        guard let urlString = params["url"] as? String,
              let url = URL(string: urlString) else {
            callback.failure("Missing or invalid parameter: url")
            return
        }
        
        let savePath = params["savePath"] as? String
        let headers = params["headers"] as? [String: String] ?? [:]
        
        // 创建请求
        var request = URLRequest(url: url)
        
        // 设置请求头
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // 应用请求拦截器
        for interceptor in requestInterceptors {
            request = interceptor(request)
        }
        
        // 执行下载
        let task = URLSession.shared.downloadTask(with: request) { [weak self] tempURL, response, error in
            var finalResponse = response
            var finalError = error
            
            if let self = self {
                for interceptor in self.responseInterceptors {
                    let result = interceptor(nil, finalResponse, finalError)
                    finalResponse = result.1
                    finalError = result.2
                }
            }
            
            DispatchQueue.main.async {
                if let error = finalError {
                    callback.failure("Download error: \(error.localizedDescription)")
                    return
                }
                
                guard let httpResponse = finalResponse as? HTTPURLResponse else {
                    callback.failure("Invalid response type")
                    return
                }
                
                guard httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 else {
                    callback.failure("Download failed with status \(httpResponse.statusCode)")
                    return
                }
                
                guard let tempURL = tempURL else {
                    callback.failure("No temporary file URL")
                    return
                }
                
                // 确定保存路径
                let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let finalURL: URL
                
                if let savePath = savePath {
                    finalURL = documentsURL.appendingPathComponent(savePath)
                } else {
                    // 使用原始文件名
                    let fileName = url.lastPathComponent.isEmpty ? "download_\(Date().timeIntervalSince1970)" : url.lastPathComponent
                    finalURL = documentsURL.appendingPathComponent(fileName)
                }
                
                // 创建目录（如果需要）
                let directoryURL = finalURL.deletingLastPathComponent()
                try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
                
                // 移动文件
                do {
                    // 如果目标文件已存在，先删除
                    if FileManager.default.fileExists(atPath: finalURL.path) {
                        try FileManager.default.removeItem(at: finalURL)
                    }
                    try FileManager.default.moveItem(at: tempURL, to: finalURL)
                    
                    callback.success([
                        "filePath": finalURL.path,
                        "statusCode": httpResponse.statusCode
                    ])
                } catch {
                    callback.failure("Failed to save file: \(error.localizedDescription)")
                }
            }
        }
        
        task.resume()
    }
    
    // MARK: - Interceptors
    
    /// 添加请求拦截器
    /// 参数: { "interceptor": "function(request) { return request; }" }
    /// 注意: 当前版本暂不支持 JS 函数拦截器，仅支持 Native 拦截器
    private func addRequestInterceptor(params: [String: Any], callback: PimeierModuleCallback) {
        // TODO: 实现 JS 函数拦截器支持
        callback.failure("Request interceptor not yet supported in JS")
    }
    
    /// 添加响应拦截器
    /// 参数: { "interceptor": "function(data, response, error) { return [data, response, error]; }" }
    /// 注意: 当前版本暂不支持 JS 函数拦截器，仅支持 Native 拦截器
    private func addResponseInterceptor(params: [String: Any], callback: PimeierModuleCallback) {
        // TODO: 实现 JS 函数拦截器支持
        callback.failure("Response interceptor not yet supported in JS")
    }
}

