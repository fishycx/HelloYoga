//
//  LocalDevServer.swift
//  Pimeier
//
//  Created by AI Assistant
//

import Foundation

/// 本地开发服务器配置
public class LocalDevServer {
    
    public static let shared = LocalDevServer()
    
    /// 是否启用本地开发模式
    public var isEnabled: Bool {
        get {
            // 默认在 Debug 模式下启用
            #if DEBUG
            return UserDefaults.standard.bool(forKey: "LocalDevServerEnabled")
            #else
            return false
            #endif
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "LocalDevServerEnabled")
        }
    }
    
    /// 本地服务器地址（默认 localhost:8080）
    public var baseURL: String {
        get {
            return UserDefaults.standard.string(forKey: "LocalDevServerURL") ?? "http://localhost:8080"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "LocalDevServerURL")
        }
    }
    
    private init() {
        // 在 Debug 模式下默认启用
        #if DEBUG
        if UserDefaults.standard.object(forKey: "LocalDevServerEnabled") == nil {
            isEnabled = true
        }
        #endif
    }
    
    /// 获取文件的完整 URL
    public func getFileURL(_ fileName: String) -> String {
        return "\(baseURL)/\(fileName)"
    }
    
    /// 获取 manifest.json 的 URL
    public func getManifestURL() -> String {
        return getFileURL("manifest.json")
    }
    
    /// 检查本地服务器是否可用
    public func checkServerAvailable(completion: @escaping (Bool) -> Void) {
        guard isEnabled else {
            completion(false)
            return
        }
        
        // 注意：如果服务器无法访问，这里会因为 URL 构造失败而崩溃
        // 应该做安全处理，但为了兼容旧代码，我们先保留 getManifestURL 的调用
        // 如果 manifest.json 不存在，也可以尝试根路径
        
        guard let url = URL(string: getManifestURL()) else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 2.0
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            let available = (error == nil && (response as? HTTPURLResponse)?.statusCode == 200)
            DispatchQueue.main.async {
                completion(available)
            }
        }
        
        task.resume()
    }
    
    // MARK: - Remote Polling
    
    private var pollingTimer: Timer?
    private var watchedFiles: [String] = []
    private var fileLastModifiedDates: [String: String] = [:]
    private var isPolling = false
    
    /// 启动轮询
    public func startPolling(files: [String]) {
        // 停止之前的轮询
        stopPolling()
        
        guard isEnabled && !files.isEmpty else { return }
        
        print("📡 [LocalDevServer] 开始远程轮询文件: \(files)")
        
        watchedFiles = files
        isPolling = true
        
        // 立即检查一次
        checkFileChanges()
        
        // 启动定时器 (每秒检查一次)
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            // print("💓 [Polling] Heartbeat...") // 可选：如果日志太乱可注释
            self?.checkFileChanges()
        }
    }
    
    /// 停止轮询
    public func stopPolling() {
        if isPolling {
            print("🛑 [LocalDevServer] 停止远程轮询")
        }
        pollingTimer?.invalidate()
        pollingTimer = nil
        watchedFiles = []
        // 不清空 fileLastModifiedDates，以便重新开始时能对比
        isPolling = false
    }
    
    /// 检查文件变化
    private func checkFileChanges() {
        for fileName in watchedFiles {
            checkFileChange(fileName: fileName)
        }
    }
    
    private func checkFileChange(fileName: String) {
        guard let url = URL(string: getFileURL(fileName)) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD" // 只请求头信息，不下载内容
        request.timeoutInterval = 2.0
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ [LocalDevServer] HEAD 请求失败: \(fileName) - \(error.localizedDescription)")
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else { return }
            
            // print("🔍 [HEAD] \(fileName) - Status: \(httpResponse.statusCode)")
            
            guard httpResponse.statusCode == 200,
                  let lastModified = httpResponse.allHeaderFields["Last-Modified"] as? String else {
                // print("⚠️ [HEAD] 无 Last-Modified 或非 200: \(fileName)")
                return
            }
            
            DispatchQueue.main.async {
                // 检查 Last-Modified 是否变化
                if let oldDate = self.fileLastModifiedDates[fileName] {
                    if oldDate != lastModified {
                        print("📡 [Node 2] 发现远程文件变化: \(fileName)")
                        print("   🔹 旧时间: \(oldDate)")
                        print("   🔹 新时间: \(lastModified)")
                        
                        // 更新记录
                        self.fileLastModifiedDates[fileName] = lastModified
                        
                        // 下载并更新
                        self.downloadAndUpdateFile(fileName: fileName)
                    }
                } else {
                    // 第一次记录
                    // print("📡 [Init] 首次记录文件时间: \(fileName) -> \(lastModified)")
                    self.fileLastModifiedDates[fileName] = lastModified
                }
            }
        }.resume()
    }
    
    /// 下载并更新文件
    private func downloadAndUpdateFile(fileName: String) {
        guard let url = URL(string: getFileURL(fileName)) else { return }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 5.0
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil,
                  let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("❌ [LocalDevServer] 下载文件失败: \(fileName)")
                return
            }
            
            DispatchQueue.main.async {
                // 保存到缓存
                if FileCacheManager.saveToCache(data, fileName: fileName) {
                    print("📥 [Node 3] 远程文件下载成功并缓存: \(fileName)")
                    
                    // 发送通知（复用 FileWatcher 的通知名称，因为接收方逻辑是一样的）
                    print("🔔 [Node 4] 发送文件变更通知...")
                    NotificationCenter.default.post(
                        name: Notification.Name("FileChanged"),
                        object: nil,
                        userInfo: ["fileName": fileName, "source": "remote"]
                    )
                }
            }
        }.resume()
    }
}
