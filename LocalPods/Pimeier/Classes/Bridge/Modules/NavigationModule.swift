//
//  NavigationModule.swift
//  Pimeier
//
//  Created by AI Assistant
//

import UIKit

/// 导航模块
/// 提供页面跳转、返回等功能
public class NavigationModule: PimeierModule {
    public static let moduleName = "Navigation"
    
    public required init() {}
    
    public func methods() -> [String: PimeierModuleMethod] {
        return [
            "pushPage": pushPage,
            "popPage": popPage,
            "openPage": openPage
        ]
    }
    
    /// 推入新页面（在导航栈中）
    /// 参数: {
    ///   "pageId": "news_detail",  // 页面 ID（对应 templateID）
    ///   "params": { "newsId": "123", "title": "新闻标题" }  // 可选，传递给新页面的参数
    /// }
    private func pushPage(params: [String: Any], callback: PimeierModuleCallback) {
        guard let pageId = params["pageId"] as? String else {
            callback.failure("Missing parameter: pageId")
            return
        }
        
        DispatchQueue.main.async {
            // 获取当前最顶层的 ViewController
            guard let topVC = self.getTopViewController() else {
                callback.failure("No view controller found")
                return
            }
            
            // 检查是否有导航控制器
            guard let navController = topVC.navigationController else {
                // 如果没有导航控制器，尝试 present
                self.presentPage(pageId: pageId, params: params["params"] as? [String: Any], from: topVC, callback: callback)
                return
            }
            
            // 创建新的 PimeierViewController
            let newVC = PimeierViewController(templateID: pageId)
            newVC.title = pageId
            
            // 如果有参数，通过 JS 引擎传递（需要在 PimeierViewController 中实现参数接收）
            if let pageParams = params["params"] as? [String: Any] {
                // 将参数存储到 viewController 的某个属性中，供 JS 使用
                // 这里可以通过 UserDefaults 或关联对象传递
                // 简单方案：通过 UserDefaults 传递（仅用于开发，生产环境建议使用更好的方案）
                if let paramsData = try? JSONSerialization.data(withJSONObject: pageParams),
                   let paramsString = String(data: paramsData, encoding: .utf8) {
                    UserDefaults.standard.set(paramsString, forKey: "PimeierPageParams_\(pageId)")
                }
            }
            
            navController.pushViewController(newVC, animated: true)
            callback.success(nil)
        }
    }
    
    /// 弹出当前页面
    private func popPage(params: [String: Any], callback: PimeierModuleCallback) {
        DispatchQueue.main.async {
            guard let topVC = self.getTopViewController() else {
                callback.failure("No view controller found")
                return
            }
            
            if let navController = topVC.navigationController, navController.viewControllers.count > 1 {
                navController.popViewController(animated: true)
                callback.success(nil)
            } else if topVC.presentingViewController != nil {
                topVC.dismiss(animated: true) {
                    callback.success(nil)
                }
            } else {
                callback.failure("Cannot pop: no previous page")
            }
        }
    }
    
    /// 打开新页面（present 方式）
    /// 参数: {
    ///   "pageId": "news_detail",
    ///   "params": { "newsId": "123" }
    /// }
    private func openPage(params: [String: Any], callback: PimeierModuleCallback) {
        guard let pageId = params["pageId"] as? String else {
            callback.failure("Missing parameter: pageId")
            return
        }
        
        DispatchQueue.main.async {
            guard let topVC = self.getTopViewController() else {
                callback.failure("No view controller found")
                return
            }
            
            self.presentPage(pageId: pageId, params: params["params"] as? [String: Any], from: topVC, callback: callback)
        }
    }
    
    /// 以 present 方式打开页面
    private func presentPage(pageId: String, params: [String: Any]?, from: UIViewController, callback: PimeierModuleCallback) {
        let newVC = PimeierViewController(templateID: pageId)
        newVC.title = pageId
        
        // 传递参数
        if let pageParams = params,
           let paramsData = try? JSONSerialization.data(withJSONObject: pageParams),
           let paramsString = String(data: paramsData, encoding: .utf8) {
            UserDefaults.standard.set(paramsString, forKey: "PimeierPageParams_\(pageId)")
        }
        
        let navController = UINavigationController(rootViewController: newVC)
        navController.modalPresentationStyle = .fullScreen
        from.present(navController, animated: true) {
            callback.success(nil)
        }
    }
    
    /// 获取最顶层的 ViewController
    private func getTopViewController() -> UIViewController? {
        guard let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) ?? UIApplication.shared.windows.first,
              let rootVC = window.rootViewController else {
            return nil
        }
        
        func getTop(base: UIViewController?) -> UIViewController? {
            if let nav = base as? UINavigationController {
                return getTop(base: nav.visibleViewController)
            }
            if let tab = base as? UITabBarController, let selected = tab.selectedViewController {
                return getTop(base: selected)
            }
            if let presented = base?.presentedViewController {
                return getTop(base: presented)
            }
            return base
        }
        
        return getTop(base: rootVC)
    }
}

