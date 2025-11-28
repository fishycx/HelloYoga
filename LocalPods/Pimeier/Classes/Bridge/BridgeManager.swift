//
//  BridgeManager.swift
//  Pimeier
//
//  Created by AI Assistant
//

import Foundation

/// Bridge 管理器
/// 负责模块注册、查找和消息分发
public class BridgeManager {
    
    public static let shared = BridgeManager()
    
    private init() {}
    
    /// 已注册的模块实例
    private var modules: [String: PimeierModule] = [:]
    
    /// 模块方法缓存 (Module -> (MethodName -> Implementation))
    private var methodCache: [String: [String: PimeierModuleMethod]] = [:]
    
    /// 注册模块类
    public func register(_ moduleClass: PimeierModule.Type) {
        let module = moduleClass.init()
        let name = moduleClass.moduleName
        
        modules[name] = module
        methodCache[name] = module.methods()
        
        print("🔌 [Bridge] Registered module: \(name)")
    }
    
    /// 处理 JS 调用
    /// - Parameters:
    ///   - module: 模块名
    ///   - method: 方法名
    ///   - params: 参数
    ///   - onSuccess: 成功回调
    ///   - onFailure: 失败回调
    public func handleInvoke(module: String, method: String, params: [String: Any], onSuccess: @escaping (Any?) -> Void, onFailure: @escaping (String) -> Void) {
        // print("Bridge invoke: \(module).\(method)(\(params))")
        
        guard let methods = methodCache[module] else {
            print("❌ [Bridge] Module not found: \(module)")
            onFailure("Module not found: \(module)")
            return
        }
        
        guard let implementation = methods[method] else {
            print("❌ [Bridge] Method not found: \(module).\(method)")
            onFailure("Method not found: \(method) in module \(module)")
            return
        }
        
        // 构造 PimeierModuleCallback 元组
        let callback: PimeierModuleCallback = (success: onSuccess, failure: onFailure)
        
        // 统一派发到主线程执行，因为大多数 Native 扩展涉及 UI
        DispatchQueue.main.async {
            implementation(params, callback)
        }
    }
}
