//
//  FileWatcher.swift
//  Pimeier
//
//  Created by AI Assistant
//

import Foundation

/// 文件监听器
public class FileWatcher {
    
    /// 文件变化通知
    public static let fileChangedNotification = Notification.Name("FileChanged")
    
    private var sources: [DispatchSourceFileSystemObject] = []
    private var filePaths: [String] = []
    private var watchedFiles: [String] = []  // 被监听的文件名列表
    private var fileModificationDates: [String: Date] = [:]
    private var isWatching = false
    private var pollingTimer: Timer?
    private var usePolling = false  // 是否使用轮询模式
    
    public init() {}
    
    /// 开始监听文件
    public func startWatching(files: [String], usePolling: Bool = false) {
        stopWatching()
        
        guard !files.isEmpty else { return }
        
        self.usePolling = usePolling
        self.watchedFiles = files
        
        if usePolling {
            startPolling()
        } else {
            startFileSystemWatching()
        }
        
        isWatching = true
    }
    
    /// 使用文件系统事件监听
    private func startFileSystemWatching() {
        print("👀 开始监听文件变化（文件系统事件模式）...")
        
        for fileName in watchedFiles {
            // 优先监听缓存文件，如果不存在则监听 Bundle 文件
            let cachePath = FileCacheManager.getCachedFilePath(for: fileName).path
            let fileComponents = fileName.components(separatedBy: ".")
            let bundlePath = Bundle.main.path(forResource: fileComponents.first,
                                             ofType: fileComponents.count > 1 ? fileComponents.last : nil)
            
            var filePath: String?
            
            if FileManager.default.fileExists(atPath: cachePath) {
                filePath = cachePath
                print("   📄 监听缓存文件: \(fileName)")
            } else if let bundlePath = bundlePath {
                filePath = bundlePath
                print("   📄 监听 Bundle 文件: \(fileName)")
            }
            
            guard let path = filePath else {
                print("   ⚠️ 文件不存在，跳过监听: \(fileName)")
                continue
            }
            
            // 记录初始修改时间
            if let attributes = try? FileManager.default.attributesOfItem(atPath: path),
               let modificationDate = attributes[.modificationDate] as? Date {
                fileModificationDates[fileName] = modificationDate
            }
            
            watchFile(at: path, fileName: fileName)
        }
    }
    
    /// 使用轮询模式监听
    private func startPolling() {
        print("👀 开始监听文件变化（轮询模式，间隔 1 秒）...")
        
        // 初始化文件修改时间
        for fileName in watchedFiles {
            let cachePath = FileCacheManager.getCachedFilePath(for: fileName).path
            let fileComponents = fileName.components(separatedBy: ".")
            let bundlePath = Bundle.main.path(forResource: fileComponents.first,
                                             ofType: fileComponents.count > 1 ? fileComponents.last : nil)
            
            var filePath: String?
            
            if FileManager.default.fileExists(atPath: cachePath) {
                filePath = cachePath
            } else if let bundlePath = bundlePath {
                filePath = bundlePath
            }
            
            if let path = filePath,
               let attributes = try? FileManager.default.attributesOfItem(atPath: path),
               let modificationDate = attributes[.modificationDate] as? Date {
                fileModificationDates[fileName] = modificationDate
                print("   📄 监听文件: \(fileName)")
            }
        }
        
        // 每秒检查一次文件变化
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkFilesForChanges()
        }
    }
    
    /// 检查文件是否有变化（轮询模式）
    private func checkFilesForChanges() {
        for fileName in watchedFiles {
            let cachePath = FileCacheManager.getCachedFilePath(for: fileName).path
            let fileComponents = fileName.components(separatedBy: ".")
            let bundlePath = Bundle.main.path(forResource: fileComponents.first,
                                             ofType: fileComponents.count > 1 ? fileComponents.last : nil)
            
            var filePath: String?
            
            if FileManager.default.fileExists(atPath: cachePath) {
                filePath = cachePath
            } else if let bundlePath = bundlePath {
                filePath = bundlePath
            }
            
            guard let path = filePath,
                  let attributes = try? FileManager.default.attributesOfItem(atPath: path),
                  let modificationDate = attributes[.modificationDate] as? Date else {
                continue
            }
            
            if let lastDate = fileModificationDates[fileName],
               modificationDate > lastDate {
                print("📝 检测到文件变化: \(fileName)")
                fileModificationDates[fileName] = modificationDate
                
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: FileWatcher.fileChangedNotification,
                        object: nil,
                        userInfo: ["fileName": fileName, "filePath": path]
                    )
                }
            }
        }
    }
    
    /// 监听单个文件
    private func watchFile(at path: String, fileName: String) {
        let fileURL = URL(fileURLWithPath: path)
        let fileDescriptor = open(path, O_EVTONLY)
        
        guard fileDescriptor >= 0 else {
            print("❌ 无法打开文件进行监听: \(path)")
            return
        }
        
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: .write,
            queue: DispatchQueue.global(qos: .background)
        )
        
        source.setEventHandler { [weak self] in
            let event = source.data
            if event.contains(.write) {
                print("📝 检测到文件变化: \(fileName)")
                
                // 延迟一点再发送通知，确保文件写入完成
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    NotificationCenter.default.post(
                        name: FileWatcher.fileChangedNotification,
                        object: nil,
                        userInfo: ["fileName": fileName, "filePath": path]
                    )
                }
            }
        }
        
        source.setCancelHandler {
            close(fileDescriptor)
        }
        
        source.resume()
        sources.append(source)
        filePaths.append(path)
    }
    
    /// 停止监听
    public func stopWatching() {
        guard isWatching else { return }
        
        print("🛑 停止监听文件变化")
        
        for source in sources {
            source.cancel()
        }
        
        pollingTimer?.invalidate()
        pollingTimer = nil
        
        sources.removeAll()
        filePaths.removeAll()
        watchedFiles.removeAll()
        fileModificationDates.removeAll()
        isWatching = false
    }
    
    /// 重新开始监听（用于文件路径变化时）
    public func refreshWatching(files: [String], usePolling: Bool = false) {
        stopWatching()
        startWatching(files: files, usePolling: usePolling)
    }
    
    deinit {
        stopWatching()
    }
}
