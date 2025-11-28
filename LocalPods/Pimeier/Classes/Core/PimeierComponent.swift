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

/// 模版消费者协议
/// 如果组件需要消费子模版（例如 ListView 的 Item 模版），则遵循此协议
public protocol TemplateConsumer: AnyObject {
    /// 注册模版
    /// - Parameters:
    ///   - node: 模版布局节点
    ///   - type: 模版类型 (例如 "item", "header")
    func registerTemplate(_ node: LayoutNode, forType type: String)
}

/// 渲染器感知协议
/// 如果组件需要调用渲染器（例如动态创建子视图），则遵循此协议
public protocol PimeierRendererAware: AnyObject {
    func setRenderer(_ renderer: PimeierRenderer)
}
