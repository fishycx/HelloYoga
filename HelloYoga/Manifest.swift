//
//  Manifest.swift
//  HelloYoga
//
//  Created by AI Assistant
//

import Foundation
import Pimeier

/// 清单文件管理器
struct Manifest {
    
    /// 清单文件名
    static let fileName = "manifest.json"
    
    /// 获取清单文件路径
    static func getManifestPath() -> URL {
        return FileCacheManager.getCacheDirectory().appendingPathComponent(fileName)
    }
    
    /// 读取本地清单
    static func loadLocal() -> VersionInfo? {
        let path = getManifestPath()
        guard FileManager.default.fileExists(atPath: path.path),
              let data = try? Data(contentsOf: path) else {
            return nil
        }
        return VersionInfo.from(data: data)
    }
    
    /// 保存清单到本地
    static func save(_ versionInfo: VersionInfo) -> Bool {
        let path = getManifestPath()
        guard let data = versionInfo.toData() else { return false }
        
        do {
            try FileManager.default.createDirectory(at: path.deletingLastPathComponent(),
                                                   withIntermediateDirectories: true,
                                                   attributes: nil)
            try data.write(to: path)
            return true
        } catch {
            print("❌ 保存清单文件失败: \(error)")
            return false
        }
    }
    
    /// 删除本地清单
    static func remove() {
        let path = getManifestPath()
        try? FileManager.default.removeItem(at: path)
    }
    
    /// 检查文件是否需要更新
    static func needsUpdate(local: VersionInfo?, remote: VersionInfo, fileName: String) -> Bool {
        guard let local = local else { return true }
        
        let localFileVersion = local.files[fileName]?.version
        let remoteFileVersion = remote.files[fileName]?.version
        
        guard let localVersion = localFileVersion,
              let remoteVersion = remoteFileVersion else {
            return remoteFileVersion != nil
        }
        
        return compareVersion(localVersion, remoteVersion) < 0
    }
    
    /// 比较版本号
    /// 返回: -1 表示 version1 < version2, 0 表示相等, 1 表示 version1 > version2
    static func compareVersion(_ version1: String, _ version2: String) -> Int {
        let v1Components = version1.split(separator: ".").compactMap { Int($0) }
        let v2Components = version2.split(separator: ".").compactMap { Int($0) }
        
        let maxLength = max(v1Components.count, v2Components.count)
        
        for i in 0..<maxLength {
            let v1 = i < v1Components.count ? v1Components[i] : 0
            let v2 = i < v2Components.count ? v2Components[i] : 0
            
            if v1 < v2 { return -1 }
            if v1 > v2 { return 1 }
        }
        
        return 0
    }
}

