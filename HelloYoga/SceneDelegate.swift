//
//  SceneDelegate.swift
//  HelloYoga
//
//  Created by YuChuanxing on 2025/11/11.
//

import UIKit
import Pimeier

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?


    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        // 使用测试控制器代替 Storyboard
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UINavigationController(rootViewController: TestViewController())  // 使用测试控制器并包裹在导航控制器中
        window.makeKeyAndVisible()
        self.window = window
        
        // 显示悬浮调试按钮
        #if DEBUG
        DebugTool.shared.showFloatingButton(in: window)
        #endif
        
        // 配置热更新服务器 URL（需要根据实际情况配置）
        // HotUpdateManager.shared.serverBaseURL = "https://your-server.com/hotupdate"
        
        // 检查本地开发服务器是否可用
        #if DEBUG
        LocalDevServer.shared.checkServerAvailable { available in
            if available {
                print("✅ 本地开发服务器可用: \(LocalDevServer.shared.baseURL)")
            } else {
                print("⚠️ 本地开发服务器不可用，请确保已启动本地服务器")
                print("   启动方法: cd HelloYoga/HelloYoga && python3 -m http.server 8080")
            }
        }
        #endif
        
        // 应用启动时检查更新
        // UpdateChecker.shared.checkUpdateOnLaunch()
        
        // 启动定时检查（可选，默认 1 小时检查一次）
        // UpdateChecker.shared.setCheckInterval(3600) // 1 小时
        // UpdateChecker.shared.startPeriodicCheck()
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }


}
