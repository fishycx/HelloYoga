//
//  ToastModule.swift
//  HelloYoga
//
//  Created by AI Assistant
//

import UIKit

public class ToastModule: PimeierModule {
    public static let moduleName = "Toast"
    
    public required init() {}
    
    public func methods() -> [String: PimeierModuleMethod] {
        return [
            "show": show
        ]
    }
    
    // show(message: string)
    private func show(params: [String: Any], callback: PimeierModuleCallback) {
        guard let message = params["message"] as? String else {
            callback.failure("Missing parameter: message")
            return
        }
        
        // 简单实现：使用 UIAlertController 显示，模拟 Toast
        // 注意：这里直接使用了 UIApplication，在扩展应用或 SceneDelegate 架构下可能需要调整，
        // 但对于当前 Demo 足够
        DispatchQueue.main.async {
            if let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) ?? UIApplication.shared.windows.first,
               let rootVC = window.rootViewController {
                
                // 递归查找最顶层
                func getTop(base: UIViewController?) -> UIViewController? {
                    if let nav = base as? UINavigationController { return getTop(base: nav.visibleViewController) }
                    if let tab = base as? UITabBarController { return getTop(base: tab.selectedViewController) }
                    if let presented = base?.presentedViewController { return getTop(base: presented) }
                    return base
                }
                
                if let target = getTop(base: rootVC) {
                    let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
                    target.present(alert, animated: true)
                    
                    // 1.5秒后自动消失
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        alert.dismiss(animated: true)
                    }
                    
                    callback.success(nil)
                } else {
                    callback.failure("No view controller to present toast")
                }
            } else {
                callback.failure("No key window found")
            }
        }
    }
}

