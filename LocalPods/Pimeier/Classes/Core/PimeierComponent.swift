//
//  PimeierComponent.swift
//  Pimeier
//
//  Created by AI Assistant
//

import UIKit

/// Pimeier 自定义组件协议
/// 所有自定义 Native 组件必须遵循此协议
public protocol PimeierComponent: UIView {
    
    /// 必须提供无参初始化器
    init()
    
    /// 应用属性
    /// - Parameter attributes: XML 属性字典
    func applyAttributes(_ attributes: [String: String])
}
