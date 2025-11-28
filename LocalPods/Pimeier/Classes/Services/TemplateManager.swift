//
//  TemplateManager.swift
//  Pimeier
//
//  Created by AI Assistant
//

import Foundation

/// 模版管理器
/// 负责 Pimeier 页面模版的发现、路径解析和状态管理
public class TemplateManager {
    
    /// 单例
    public static let shared = TemplateManager()
    
    /// 当前选中的模版 ID
    public var currentTemplateID: String = "home_v1" {
        didSet {
            // 通知模版变更
            onTemplateChanged?(currentTemplateID)
        }
    }
    
    /// 模版变更回调
    public var onTemplateChanged: ((String) -> Void)?
    
    private init() {}
    
    private let rootDirectoryName = "pimeierPages"
    
    /// 获取所有可用模版列表
    public func listTemplates() -> [String] {
        var templates = Set<String>()
        
        // 1. 扫描 Bundle (兼容 Flat Mode 和 Folder Reference)
        if let resourcePath = Bundle.main.resourcePath {
             if let items = try? FileManager.default.contentsOfDirectory(atPath: resourcePath) {
                for item in items {
                    // 策略 A: 查找根目录下的 {id}_layout.xml (Flat Mode)
                    if item.hasSuffix("_layout.xml") {
                        let templateName = item.replacingOccurrences(of: "_layout.xml", with: "")
                        templates.insert(templateName)
                    }
                }
            }
            
            // 策略 B: 查找 pimeierPages 子目录 (Folder Reference)
            let pimeierPath = (resourcePath as NSString).appendingPathComponent(rootDirectoryName)
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: pimeierPath, isDirectory: &isDir), isDir.boolValue {
                if let items = try? FileManager.default.contentsOfDirectory(atPath: pimeierPath) {
                    for item in items {
                    if item.hasPrefix(".") { continue }
                    
                        let itemPath = (pimeierPath as NSString).appendingPathComponent(item)
                        var isSubDir: ObjCBool = false
                        if FileManager.default.fileExists(atPath: itemPath, isDirectory: &isSubDir), isSubDir.boolValue {
                        templates.insert(item)
                        }
                    }
                }
            }
        }
        
        // 2. 扫描 Cache (Documents/HotUpdate/pimeierPages/{id})
        let cacheDir = FileCacheManager.getCacheDirectory().appendingPathComponent(rootDirectoryName)
        if let items = try? FileManager.default.contentsOfDirectory(atPath: cacheDir.path) {
            for item in items {
                if item.hasPrefix(".") { continue }
                
                let itemPath = cacheDir.appendingPathComponent(item).path
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: itemPath, isDirectory: &isDir), isDir.boolValue {
                    templates.insert(item)
                }
            }
        }
        
        // 3. 无 Hardcode Fallback
        // 仅依靠文件系统扫描。如果为空，则列表为空。
        
        return Array(templates).sorted()
    }
    
    /// 获取模版文件的 URL
    /// 优先查找 Cache，其次 Bundle
    /// - Parameters:
    ///   - templateId: 模版ID
    ///   - fileName: 文件名 (例如 "todo_list_layout.xml")
    public func getTemplateURL(templateId: String, fileName: String) -> URL? {
        let fileManager = FileManager.default
        
        // 1. 检查 Cache
        // 路径策略：pimeierPages/{id}/{fileName}
        let relPath = "\(rootDirectoryName)/\(templateId)/\(fileName)"
        let cacheURL = FileCacheManager.getCachedFilePath(for: relPath)
        if fileManager.fileExists(atPath: cacheURL.path) {
            // print("📂 [TemplateManager] 命中缓存: \(fileName)")
            return cacheURL
        }
        
        // 2. 检查 Bundle
        // 策略：Bundle 根目录下直接查找 fileName (因为被 Xcode 展平了)
        if let url = Bundle.main.url(forResource: fileName, withExtension: nil) {
            // print("📦 [TemplateManager] 使用 Bundle (Flat): \(fileName)")
            return url
        }
        
        // 3. 兼容旧路径 (pimeierPages/{id}/{fileName})
        if let url = Bundle.main.url(forResource: fileName, withExtension: nil, subdirectory: "\(rootDirectoryName)/\(templateId)") {
            return url
        }
        
        return nil
    }
    
    /// 重置模版缓存 (删除缓存，强制使用 Bundle 版本)
    public func resetTemplate(templateId: String) {
        let relPath = "\(rootDirectoryName)/\(templateId)"
        let cacheURL = FileCacheManager.getCachedFilePath(for: relPath)
        do {
            if FileManager.default.fileExists(atPath: cacheURL.path) {
            try FileManager.default.removeItem(at: cacheURL)
                print("✅ [TemplateManager] 已重置 \(templateId) 模版缓存")
            }
        } catch {
            print("⚠️ [TemplateManager] 重置 \(templateId) 失败: \(error)")
        }
    }
    
    public func resetTodoTemplate() {
        resetTemplate(templateId: "todo_list")
    }
}
