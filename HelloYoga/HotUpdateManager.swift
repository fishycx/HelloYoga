//
//  HotUpdateManager.swift
//  HelloYoga
//
//  Created by AI Assistant
//

import Foundation
import Pimeier

/// 热更新管理器
class HotUpdateManager {
    
    static let shared = HotUpdateManager()
    
    /// 更新完成通知
    static let updateCompletedNotification = Notification.Name("HotUpdateCompleted")
    /// 更新失败通知
    static let updateFailedNotification = Notification.Name("HotUpdateFailed")
    
    private var isUpdating = false
    private var updateQueue: [String] = []
    private var currentUpdateIndex = 0
    
    /// 服务器基础 URL（需要配置）
    var serverBaseURL: String {
        get {
            // 如果启用了本地开发服务器，优先使用本地服务器
            if LocalDevServer.shared.isEnabled {
                return LocalDevServer.shared.baseURL
            }
            return UserDefaults.standard.string(forKey: "HotUpdateServerURL") ?? ""
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "HotUpdateServerURL")
        }
    }
    
    private init() {}
    
    /// 检查更新
    func checkUpdate(completion: @escaping (Bool, VersionInfo?) -> Void) {
        let baseURL = serverBaseURL
        guard !baseURL.isEmpty else {
            print("⚠️ 服务器 URL 未配置")
            completion(false, nil)
            return
        }
        
        let manifestURL = URL(string: "\(baseURL)/manifest.json")!
        
        print("🔍 开始检查更新...")
        print("   URL: \(manifestURL.absoluteString)")
        
        let task = URLSession.shared.dataTask(with: manifestURL) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ 检查更新失败: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(false, nil)
                }
                return
            }
            
            guard let data = data,
                  let remoteVersion = VersionInfo.from(data: data) else {
                print("❌ 无法解析远程版本信息")
                DispatchQueue.main.async {
                    completion(false, nil)
                }
                return
            }
            
            let localVersion = VersionManager.getLocalVersion()
            let hasUpdate = VersionManager.hasUpdate(local: localVersion, remote: remoteVersion)
            
            print("📊 版本信息:")
            print("   本地版本: \(localVersion?.version ?? "无")")
            print("   远程版本: \(remoteVersion.version)")
            print("   需要更新: \(hasUpdate ? "是" : "否")")
            
            DispatchQueue.main.async {
                completion(hasUpdate, remoteVersion)
            }
        }
        
        task.resume()
    }
    
    /// 下载并应用更新
    func update(remoteVersion: VersionInfo, completion: @escaping (Bool, String?) -> Void) {
        guard !isUpdating else {
            print("⚠️ 更新正在进行中，请稍候...")
            completion(false, "更新正在进行中")
            return
        }
        
        isUpdating = true
        currentUpdateIndex = 0
        
        let localVersion = VersionManager.getLocalVersion()
        let filesToUpdate = VersionManager.getFilesToUpdate(local: localVersion, remote: remoteVersion)
        
        guard !filesToUpdate.isEmpty else {
            print("✅ 所有文件都是最新版本")
            isUpdating = false
            completion(true, nil)
            return
        }
        
        print("📥 开始下载更新，共 \(filesToUpdate.count) 个文件")
        updateQueue = filesToUpdate
        
        downloadNextFile(remoteVersion: remoteVersion) { [weak self] success, error in
            guard let self = self else { return }
            
            self.isUpdating = false
            
            if success {
                // 保存新的版本信息
                VersionManager.saveLocalVersion(remoteVersion)
                
                print("✅ 更新完成")
                NotificationCenter.default.post(name: HotUpdateManager.updateCompletedNotification, object: nil)
                completion(true, nil)
            } else {
                print("❌ 更新失败: \(error ?? "未知错误")")
                NotificationCenter.default.post(name: HotUpdateManager.updateFailedNotification,
                                               object: nil,
                                               userInfo: ["error": error ?? "未知错误"])
                completion(false, error)
            }
        }
    }
    
    /// 下载下一个文件
    private func downloadNextFile(remoteVersion: VersionInfo, completion: @escaping (Bool, String?) -> Void) {
        guard currentUpdateIndex < updateQueue.count else {
            completion(true, nil)
            return
        }
        
        let fileName = updateQueue[currentUpdateIndex]
        guard let fileInfo = remoteVersion.files[fileName] else {
            print("⚠️ 文件信息不存在: \(fileName)")
            currentUpdateIndex += 1
            downloadNextFile(remoteVersion: remoteVersion, completion: completion)
            return
        }
        
        let fileURL = URL(string: fileInfo.url)!
        
        print("📥 [\(currentUpdateIndex + 1)/\(updateQueue.count)] 下载文件: \(fileName)")
        
        let task = URLSession.shared.dataTask(with: fileURL) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ 下载失败: \(fileName) - \(error.localizedDescription)")
                completion(false, "下载失败: \(error.localizedDescription)")
                return
            }
            
            guard let data = data else {
                print("❌ 下载数据为空: \(fileName)")
                completion(false, "下载数据为空")
                return
            }
            
            // 验证 MD5（如果提供了）
            if let expectedMD5 = fileInfo.md5, !expectedMD5.isEmpty {
                if !FileCacheManager.verifyMD5(data: data, expectedMD5: expectedMD5) {
                    print("❌ MD5 校验失败: \(fileName)")
                    completion(false, "MD5 校验失败")
                    return
                }
                print("✅ MD5 校验通过: \(fileName)")
            }
            
            // 保存到缓存
            if FileCacheManager.saveToCache(data, fileName: fileName) {
                print("✅ 文件下载完成: \(fileName)")
                self.currentUpdateIndex += 1
                self.downloadNextFile(remoteVersion: remoteVersion, completion: completion)
            } else {
                completion(false, "保存文件失败")
            }
        }
        
        task.resume()
    }
    
    /// 手动触发更新检查
    func manualUpdate(completion: @escaping (Bool, String?) -> Void) {
        checkUpdate { [weak self] hasUpdate, remoteVersion in
            guard let self = self else {
                completion(false, "管理器已释放")
                return
            }
            
            if hasUpdate, let remoteVersion = remoteVersion {
                self.update(remoteVersion: remoteVersion, completion: completion)
            } else {
                completion(true, nil)
            }
        }
    }
    
    /// 获取更新状态
    func isUpdatingNow() -> Bool {
        return isUpdating
    }
}

