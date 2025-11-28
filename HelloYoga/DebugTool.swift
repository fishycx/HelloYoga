//
//  DebugTool.swift
//  HelloYoga
//
//  Created by AI Assistant
//

import UIKit
import Pimeier

/// 调试工具管理器
class DebugTool {
    
    static let shared = DebugTool()
    
    private var floatingButton: UIButton?
    private var isVisible = false
    
    private init() {}
    
    /// 显示悬浮调试按钮
    func showFloatingButton(in window: UIWindow) {
        guard floatingButton == nil else { return }
        
        let button = UIButton(type: .custom)
        button.setTitle("🐛", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 20)
        button.backgroundColor = UIColor.systemPurple.withAlphaComponent(0.9)
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 25
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 8
        button.layer.shadowOpacity = 0.3
        
        // 添加拖动手势
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        button.addGestureRecognizer(panGesture)
        
        button.addTarget(self, action: #selector(floatingButtonTapped), for: .touchUpInside)
        
        window.addSubview(button)
        button.translatesAutoresizingMaskIntoConstraints = false
        
        // 初始位置：右下角
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 50),
            button.heightAnchor.constraint(equalToConstant: 50),
            button.trailingAnchor.constraint(equalTo: window.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            button.bottomAnchor.constraint(equalTo: window.safeAreaLayoutGuide.bottomAnchor, constant: -100)
        ])
        
        floatingButton = button
        isVisible = true
        
        // 添加动画
        button.alpha = 0
        button.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5, options: [], animations: {
            button.alpha = 1
            button.transform = .identity
        }, completion: nil)
    }
    
    /// 隐藏悬浮按钮
    func hideFloatingButton() {
        guard let button = floatingButton else { return }
        
        UIView.animate(withDuration: 0.3) {
            button.alpha = 0
            button.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        } completion: { _ in
            button.removeFromSuperview()
            self.floatingButton = nil
            self.isVisible = false
        }
    }
    
    /// 切换悬浮按钮显示/隐藏
    func toggleFloatingButton(in window: UIWindow) {
        if isVisible {
            hideFloatingButton()
        } else {
            showFloatingButton(in: window)
        }
    }
    
    @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        guard let button = floatingButton,
              let window = button.window else { return }
        
        let translation = gesture.translation(in: window)
        
        switch gesture.state {
        case .changed:
            button.center = CGPoint(
                x: button.center.x + translation.x,
                y: button.center.y + translation.y
            )
            gesture.setTranslation(.zero, in: window)
            
        case .ended:
            // 吸附到边缘
            let safeArea = window.safeAreaLayoutGuide.layoutFrame
            let buttonFrame = button.frame
            let centerX = button.center.x
            let centerY = button.center.y
            let safeWidth = safeArea.width
            let safeHeight = safeArea.height
            
            var newX = centerX
            var newY = centerY
            
            // 水平吸附
            if centerX < safeWidth / 2 {
                newX = 25 + buttonFrame.width / 2  // 左边缘
            } else {
                newX = safeWidth - 25 - buttonFrame.width / 2  // 右边缘
            }
            
            // 垂直限制在安全区域内
            newY = max(safeArea.minY + buttonFrame.height / 2 + 20,
                      min(safeArea.maxY - buttonFrame.height / 2 - 20, newY))
            
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: [], animations: {
                button.center = CGPoint(x: newX, y: newY)
            }, completion: nil)
            
        default:
            break
        }
    }
    
    @objc func floatingButtonTapped() {
        guard let window = floatingButton?.window,
              let rootViewController = window.rootViewController else { return }
        
        // 找到最顶层的视图控制器
        var topViewController = rootViewController
        while let presented = topViewController.presentedViewController {
            topViewController = presented
        }
        
        // 处理 NavigationController 和 TabBarController
        var activeVC = topViewController
        if let nav = activeVC as? UINavigationController {
            activeVC = nav.visibleViewController ?? nav
        } else if let tab = activeVC as? UITabBarController {
            activeVC = tab.selectedViewController ?? tab
        }
        
        print("🔎 [DebugTool] 捕获到的顶层控制器: \(type(of: activeVC))")
        
        // 显示调试工具页面
        let debugVC = DebugToolViewController()
        
        // 如果顶层视图控制器是 PimeierViewController，传递布局信息
        if let pimeierVC = activeVC as? PimeierViewController {
            let templateID = pimeierVC.templateID
            // 修正：直接传递 templateID，让 DebugToolVC 内部去拼接 _layout.xml
            debugVC.currentLayoutInfo = (xmlFile: templateID, jsonFile: templateID, name: templateID)
            print("✅ [DebugTool] 已绑定模版: \(templateID)")
            
            debugVC.onReloadLayout = { [weak pimeierVC] in
                pimeierVC?.loadTemplate()
            }
            debugVC.onScanQRCode = { [weak pimeierVC] (url: String) in
                LocalDevServer.shared.baseURL = url
                LocalDevServer.shared.isEnabled = true
                pimeierVC?.loadTemplate()
            }
        } else {
            print("⚠️ [DebugTool] 当前不是 Pimeier 页面，未绑定模版信息")
        }
        
        let navController = UINavigationController(rootViewController: debugVC)
        navController.modalPresentationStyle = .pageSheet
        
        if #available(iOS 15.0, *) {
            if let sheet = navController.sheetPresentationController {
                sheet.detents = [.medium(), .large()]
                sheet.prefersGrabberVisible = true
            }
        }
        
        topViewController.present(navController, animated: true)
    }
}

