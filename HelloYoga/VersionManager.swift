//
//  VersionManager.swift
//  HelloYoga
//
//  Created by AI Assistant
//

import Foundation

/// 版本管理器
class VersionManager {
    
    private static let userDefaultsKey = "HotUpdateVersionInfo"
    
    /// 获取本地版本信息
    static func getLocalVersion() -> VersionInfo? {
        // 首先尝试从清单文件读取
        if let manifest = Manifest.loadLocal() {
            return manifest
        }
        
        // 如果清单文件不存在，尝试从 UserDefaults 读取
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let versionInfo = VersionInfo.from(data: data) {
            return versionInfo
        }
        
        return nil
    }
    
    /// 保存本地版本信息
    static func saveLocalVersion(_ versionInfo: VersionInfo) -> Bool {
        // 保存到清单文件
        let saved = Manifest.save(versionInfo)
        
        // 同时保存到 UserDefaults 作为备份
        if let data = versionInfo.toData() {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
        
        return saved
    }
    
    /// 获取文件的本地版本号
    static func getLocalFileVersion(_ fileName: String) -> String? {
        return getLocalVersion()?.files[fileName]?.version
    }
    
    /// 检查是否有更新
    static func hasUpdate(local: VersionInfo?, remote: VersionInfo) -> Bool {
        guard let local = local else { return true }
        
        // 比较整体版本号
        if Manifest.compareVersion(local.version, remote.version) < 0 {
            return true
        }
        
        // 检查是否有文件需要更新
        for (fileName, remoteFileInfo) in remote.files {
            if Manifest.needsUpdate(local: local, remote: remote, fileName: fileName) {
                return true
            }
        }
        
        return false
    }
    
    /// 获取需要更新的文件列表
    static func getFilesToUpdate(local: VersionInfo?, remote: VersionInfo) -> [String] {
        guard let local = local else {
            return Array(remote.files.keys)
        }
        
        var filesToUpdate: [String] = []
        
        for (fileName, _) in remote.files {
            if Manifest.needsUpdate(local: local, remote: remote, fileName: fileName) {
                filesToUpdate.append(fileName)
            }
        }
        
        return filesToUpdate
    }
    
    /// 清除本地版本信息
    static func clearLocalVersion() {
        Manifest.remove()
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }
}

