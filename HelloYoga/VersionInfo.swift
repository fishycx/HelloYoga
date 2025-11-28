//
//  VersionInfo.swift
//  HelloYoga
//
//  Created by AI Assistant
//

import Foundation

/// 文件版本信息
struct FileVersionInfo: Codable {
    let version: String
    let url: String
    let md5: String?
    
    enum CodingKeys: String, CodingKey {
        case version
        case url
        case md5
    }
}

/// 版本信息
struct VersionInfo: Codable {
    let version: String
    let files: [String: FileVersionInfo]
    
    enum CodingKeys: String, CodingKey {
        case version
        case files
    }
    
    /// 从 JSON 数据创建
    static func from(data: Data) -> VersionInfo? {
        let decoder = JSONDecoder()
        return try? decoder.decode(VersionInfo.self, from: data)
    }
    
    /// 从 JSON 字符串创建
    static func from(jsonString: String) -> VersionInfo? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        return from(data: data)
    }
    
    /// 转换为 JSON 数据
    func toData() -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return try? encoder.encode(self)
    }
    
    /// 转换为 JSON 字符串
    func toJSONString() -> String? {
        guard let data = toData() else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

