//
//  PimeierModule.swift
//  Pimeier
//
//  Created by AI Assistant
//

import Foundation

/// Bridge 模块调用回调
/// - success: 成功回调 (传递结果)
/// - failure: 失败回调 (传递错误信息)
public typealias PimeierModuleCallback = (success: (Any?) -> Void, failure: (String) -> Void)

/// Bridge 模块方法定义
/// 接收参数字典和回调
public typealias PimeierModuleMethod = (_ params: [String: Any], _ callback: PimeierModuleCallback) -> Void

/// Pimeier Native 模块协议
/// 所有扩展能力模块都必须遵循此协议
public protocol PimeierModule {
    
    /// 必须提供无参初始化器
    init()
    
    /// 模块名称 (JS 端调用的对象名)
    /// e.g. "Toast" -> Pimeier.Toast
    static var moduleName: String { get }
    
    /// 模块方法映射表
    /// key: 方法名 (JS 端调用的函数名)
    /// value: 方法实现闭包
    func methods() -> [String: PimeierModuleMethod]
}
