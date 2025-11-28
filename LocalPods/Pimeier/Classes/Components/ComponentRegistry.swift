//
//  ComponentRegistry.swift
//  Pimeier
//
//  Created by AI Assistant
//

import UIKit

/// 组件注册表
/// 负责管理自定义组件的注册和实例化
public class ComponentRegistry {
    
    public static let shared = ComponentRegistry()
    
    private init() {}
    
    /// 已注册的组件类
    /// key: 标签名 (e.g. "circle")
    /// value: 组件类 (e.g. CircleView.self)
    private var components: [String: PimeierComponent.Type] = [:]
    
    /// 注册组件
    /// - Parameters:
    ///   - componentClass: 组件类 (必须遵循 PimeierComponent 协议)
    ///   - tagName: XML 标签名
    public func register(_ componentClass: PimeierComponent.Type, forTagName tagName: String) {
        let normalizedTag = tagName.lowercased()
        components[normalizedTag] = componentClass
        print("🧩 [Registry] Registered component: <\(normalizedTag)> -> \(componentClass)")
    }
    
    /// 创建组件实例
    /// - Parameter tagName: XML 标签名
    /// - Returns: 组件实例 (UIView)
    public func createView(tagName: String) -> UIView? {
        let normalizedTag = tagName.lowercased()
        guard let componentClass = components[normalizedTag] else {
            print("❌ [Registry] Component not found: <\(normalizedTag)> (Available: \(components.keys))")
            return nil
        }
        return componentClass.init()
    }
    
    /// 检查是否已注册某个标签
    public func hasComponent(tagName: String) -> Bool {
        return components[tagName.lowercased()] != nil
    }
}
