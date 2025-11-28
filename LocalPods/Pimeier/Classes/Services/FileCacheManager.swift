//
//  FileCacheManager.swift
//  Pimeier
//
//  Created by AI Assistant
//

import Foundation
import CommonCrypto

/// 文件缓存管理器
public class FileCacheManager {
    
    /// 缓存目录名称
    private static let cacheDirectoryName = "HotUpdate"
    
    /// 获取缓存目录
    public static func getCacheDirectory() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent(cacheDirectoryName)
    }
    
    /// 确保缓存目录存在
    public static func ensureCacheDirectory() -> Bool {
        let cacheDir = getCacheDirectory()
        
        if !FileManager.default.fileExists(atPath: cacheDir.path) {
            do {
                try FileManager.default.createDirectory(at: cacheDir,
                                                       withIntermediateDirectories: true,
                                                       attributes: nil)
                return true
            } catch {
                print("❌ 创建缓存目录失败: \(error)")
                return false
            }
        }
        return true
    }
    
    /// 获取文件在缓存中的路径
    public static func getCachedFilePath(for fileName: String) -> URL {
        return getCacheDirectory().appendingPathComponent(fileName)
    }
    
    /// 检查文件是否存在于缓存中
    public static func fileExistsInCache(_ fileName: String) -> Bool {
        let path = getCachedFilePath(for: fileName)
        return FileManager.default.fileExists(atPath: path.path)
    }
    
    /// 从缓存读取文件
    public static func readFromCache(_ fileName: String) -> Data? {
        let path = getCachedFilePath(for: fileName)
        guard FileManager.default.fileExists(atPath: path.path) else { return nil }
        return try? Data(contentsOf: path)
    }
    
    /// 确保文件的父目录存在
    private static func ensureFileDirectory(for fileURL: URL) -> Bool {
        let directory = fileURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: directory.path) {
            do {
                try FileManager.default.createDirectory(at: directory,
                                                       withIntermediateDirectories: true,
                                                       attributes: nil)
                return true
            } catch {
                print("❌ 创建文件父目录失败: \(error) - \(directory.path)")
                return false
            }
        }
        return true
    }
    
    /// 保存文件到缓存
    public static func saveToCache(_ data: Data, fileName: String) -> Bool {
        // 1. 确保根缓存目录存在
        guard ensureCacheDirectory() else { return false }
        
        let path = getCachedFilePath(for: fileName)
        
        // 2. 确保文件的中间目录存在
        guard ensureFileDirectory(for: path) else { return false }
        
        do {
            try data.write(to: path)
            print("💾 [FileCache] 写入缓存路径: \(path.path)")
            return true
        } catch {
            print("❌ 保存文件到缓存失败: \(error) - \(path.path)")
            return false
        }
    }
    
    /// 删除缓存文件
    public static func removeFromCache(_ fileName: String) -> Bool {
        let path = getCachedFilePath(for: fileName)
        
        guard FileManager.default.fileExists(atPath: path.path) else { return true }
        
        do {
            try FileManager.default.removeItem(at: path)
            print("✅ 已删除缓存文件: \(fileName)")
            return true
        } catch {
            print("❌ 删除缓存文件失败: \(error)")
            return false
        }
    }
    
    /// 清空所有缓存
    public static func clearCache() -> Bool {
        let cacheDir = getCacheDirectory()
        
        guard FileManager.default.fileExists(atPath: cacheDir.path) else { return true }
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: cacheDir,
                                                                   includingPropertiesForKeys: nil)
            for file in files {
                try FileManager.default.removeItem(at: file)
            }
            print("✅ 已清空所有缓存")
            return true
        } catch {
            print("❌ 清空缓存失败: \(error)")
            return false
        }
    }
    
    /// 计算文件的 MD5 值
    public static func md5Hash(of data: Data) -> String {
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        _ = data.withUnsafeBytes { bytes in
            CC_MD5(bytes.baseAddress, CC_LONG(data.count), &digest)
        }
        
        return digest.map { String(format: "%02x", $0) }.joined()
    }
    
    /// 验证文件 MD5
    public static func verifyMD5(data: Data, expectedMD5: String) -> Bool {
        let actualMD5 = md5Hash(of: data)
        return actualMD5.lowercased() == expectedMD5.lowercased()
    }
    
    /// 获取缓存文件大小（字节）
    public static func getCacheSize() -> Int64 {
        let cacheDir = getCacheDirectory()
        guard FileManager.default.fileExists(atPath: cacheDir.path) else { return 0 }
        
        var totalSize: Int64 = 0
        
        if let files = try? FileManager.default.contentsOfDirectory(at: cacheDir,
                                                                     includingPropertiesForKeys: [.fileSizeKey]) {
            for file in files {
                if let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += Int64(size)
                }
            }
        }
        
        return totalSize
    }
}
