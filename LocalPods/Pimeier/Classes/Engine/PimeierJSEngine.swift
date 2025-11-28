//
//  PimeierJSEngine.swift
//  Pimeier
//
//  Created by AI Assistant
//

import Foundation
import JavaScriptCore
import UIKit

/// Pimeier JavaScript 引擎封装
/// 负责管理 JS 上下文，执行脚本，以及 Native 与 JS 的交互
public class PimeierJSEngine {
    
    // MARK: - Properties
    
    /// JS 上下文
    private var context: JSContext
    
    /// 当前的数据模型 (ViewModel)
    private var viewModel: JSValue?
    
    /// UI 刷新回调
    public var onRenderRequest: (() -> Void)?
    
    // MARK: - Initialization
    
    public init() {
        // 初始化 JSContext
        // 使用默认的 VirtualMachine，确保在同一线程操作
        self.context = JSContext()
        setupContext()
    }
    
    // MARK: - Context Setup
    
    private func setupContext() {
        context.exceptionHandler = { context, exception in
            print("❌ [JS Exception] \(exception?.toString() ?? "Unknown")")
        }
        
        // 1. 注入控制台日志功能
        let consoleLog: @convention(block) (String) -> Void = { message in
            print("📜 [JS Console] \(message)")
        }
        context.setObject(consoleLog, forKeyedSubscript: "log" as NSCopying & NSObjectProtocol)
        
        // 2. 注入 Alert 功能
        let alert: @convention(block) (String) -> Void = { message in
            DispatchQueue.main.async {
                // 递归查找最顶层的 Presented ViewController
                func getTopViewController(base: UIViewController?) -> UIViewController? {
                    if let nav = base as? UINavigationController {
                        return getTopViewController(base: nav.visibleViewController)
                    }
                    if let tab = base as? UITabBarController, let selected = tab.selectedViewController {
                        return getTopViewController(base: selected)
                    }
                    if let presented = base?.presentedViewController {
                        return getTopViewController(base: presented)
                    }
                    return base
                }

                if let rootVC = UIApplication.shared.keyWindow?.rootViewController,
                   let topVC = getTopViewController(base: rootVC) {
                    let alert = UIAlertController(title: "JS Alert", message: message, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    topVC.present(alert, animated: true)
                }
            }
        }
        context.setObject(alert, forKeyedSubscript: "alert" as NSCopying & NSObjectProtocol)
        
        // 3. 注入渲染触发器
        // JS 中调用 render() 将触发 Native 重新渲染
        let render: @convention(block) () -> Void = { [weak self] in
            print("⚡️ [JS] 请求重新渲染")
            self?.onRenderRequest?()
        }
        context.setObject(render, forKeyedSubscript: "render" as NSCopying & NSObjectProtocol)
        
        // 4. 注入 Bridge 通道
        // 签名: (module, method, params, successCallback, failureCallback)
        let bridgeInvoke: @convention(block) (String, String, [String: Any], JSValue, JSValue) -> Void = { module, method, params, successCallback, failureCallback in
            
            // 调用 BridgeManager
            BridgeManager.shared.handleInvoke(module: module, method: method, params: params, onSuccess: { (successResult: Any?) in
                // 成功回调
                // 注意：call(withArguments:) 是线程安全的，JSC 会处理同步
                successCallback.call(withArguments: [successResult ?? NSNull()])
            }, onFailure: { (errorMessage: String) in
                // 失败回调
                failureCallback.call(withArguments: [errorMessage])
            })
        }
        context.setObject(bridgeInvoke, forKeyedSubscript: "__pimeier_bridge_invoke" as NSCopying & NSObjectProtocol)
        
        // 5. 注入 JS SDK Shim
        // 这是一个简单的 SDK 层，将底层的回调风格封装为 Promise
        // 同时提供了方便的命名空间访问
        let sdkScript = """
        var Pimeier = {
            // 通用调用接口
            invoke: function(module, method, params) {
                return new Promise(function(resolve, reject) {
                    __pimeier_bridge_invoke(module, method, params || {}, 
                        function(res) { resolve(res); }, 
                        function(err) { reject(err); }
                    );
                });
            },
            
            // Toast 模块
            Toast: {
                show: function(message) { return Pimeier.invoke('Toast', 'show', {message: message}); }
            },
            
            // Device 模块
            Device: {
                getInfo: function() { return Pimeier.invoke('Device', 'getInfo'); },
                vibrate: function() { return Pimeier.invoke('Device', 'vibrate'); }
            }
        };
        log("🚀 [JS SDK] Pimeier Native Bridge Ready");
        """
        context.evaluateScript(sdkScript)
    }
    
    // MARK: - Script Execution
    
    /// 加载并执行脚本
    public func loadScript(_ script: String) {
        // print("📜 [JSEngine] 执行脚本...")
        context.evaluateScript(script)
        
        // 尝试获取 viewModel 全局变量
        // 约定：JS 脚本必须定义一个全局对象 `viewModel`
        if let vm = context.objectForKeyedSubscript("viewModel"), !vm.isUndefined {
            self.viewModel = vm
            // print("✅ [JSEngine] ViewModel 已加载")
        } else {
            print("⚠️ [JSEngine] 未找到 'viewModel' 全局对象")
        }
    }
    
    /// 执行表达式并返回结果
    public func evaluate(_ script: String) -> JSValue? {
        let result = context.evaluateScript(script)
        // 增加调试日志
        // print("🔍 [JSEngine] Eval: \(script) -> \(result?.toString() ?? "nil")")
        return result
    }
    
    /// 调用 JS 函数
    public func callFunction(_ name: String, with arguments: [Any] = []) -> JSValue? {
        if let function = context.objectForKeyedSubscript(name), !function.isUndefined {
            // print("▶️ [JSEngine] Calling function: \(name)")
            let result = function.call(withArguments: arguments)
            return result
        }
        print("❌ [JSEngine] 未找到函数: \(name)")
        return nil
    }
    
    // MARK: - Data Access
    
    /// 获取当前 ViewModel 数据
    public func getViewModel() -> JSValue? {
        return viewModel
    }
    
    /// 从 JSValue 中获取属性
    /// 支持路径访问，如 "user.name"
    public func getValue(for path: String, in object: JSValue? = nil) -> JSValue? {
        let target = object ?? context.globalObject
        
        let keys = path.split(separator: ".")
        var current = target
        
        for key in keys {
            if let next = current?.objectForKeyedSubscript(String(key)), !next.isUndefined {
                current = next
            } else {
                return nil
            }
        }
        
        return current
    }
    
    /// 设置全局变量
    public func setObject(_ object: Any, forKey key: String) {
        context.setObject(object, forKeyedSubscript: key as NSCopying & NSObjectProtocol)
    }
    
    /// 创建 JSValue
    public func createValue(from object: Any) -> JSValue? {
        return JSValue(object: object, in: context)
    }
    
    /// 从 JSON 字符串创建 JSValue (更安全的数据传递方式)
    public func createValue(fromJson json: String) -> JSValue? {
        let parser = context.evaluateScript("(function(json) { return JSON.parse(json); })")
        return parser?.call(withArguments: [json])
    }
}
