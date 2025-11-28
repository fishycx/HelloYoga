//
//  PimeierViewController.swift
//  Pimeier
//
//  Created by AI Assistant
//

import UIKit
import YogaKit

/// Pimeier 页面容器
/// 负责加载、解析、渲染 Pimeier 页面模版，并处理热更新
open class PimeierViewController: UIViewController {
    
    // MARK: - Properties
    
    /// 模版 ID
    public let templateID: String
    
    /// 标准布局文件名
    public var layoutFileName: String {
        return "\(templateID)_layout.xml"
    }
    
    /// 标准数据文件名
    public var dataFileName: String {
        return "\(templateID)_data.json"
    }
    
    /// 标准逻辑文件名
    public var logicFileName: String {
        return "\(templateID)_logic.js"
    }
    
    /// JS 引擎
    private var jsEngine: PimeierJSEngine?
    
    /// Pimeier 渲染器 (Level 2)
    private var renderer: PimeierRenderer?
    
    /// XML 解析器
    private let xmlParser = XMLLayoutParser()
    
    /// Yoga 构建器
    internal var yogaBuilder: YogaNodeBuilder? {
        return renderer?.getBuilder()
    }
    
    /// 根内容视图
    private(set) public var rootContentView: UIView?
    
    // MARK: - Initialization
    
    public init(templateID: String) {
        self.templateID = templateID
        super.init(nibName: nil, bundle: nil)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        // 初始化 JS 引擎和渲染器
        setupJSEngine()
        
        loadTemplate()
        
        // 监听文件变化通知（用于热重载）
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFileChanged(_:)),
            name: FileWatcher.fileChangedNotification,
            object: nil
        )
    }
    
    private func setupJSEngine() {
        let engine = PimeierJSEngine()
        self.jsEngine = engine
        self.renderer = PimeierRenderer(jsEngine: engine)
        
        // 绑定渲染请求
        engine.onRenderRequest = { [weak self] in
            self?.refreshUI()
        }
    }
    
    open override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // 重新计算 Yoga 布局
        if let rootView = rootContentView {
            yogaBuilder?.calculateLayout(
                for: rootView,
                width: view.bounds.width,
                height: view.bounds.height
            )
            yogaBuilder?.updateRefreshViewsFrames()
        }
    }
    
    // MARK: - Template Loading
    
    /// 加载模版
    open func loadTemplate() {
        print("📋 [PimeierVC] 开始加载模版: \(templateID)")
        
        // 清理旧视图
        rootContentView?.removeFromSuperview()
        renderer?.cleanup()
        
        // 1. 获取资源路径
        guard let (xmlURL, dataURL) = findTemplateResources(id: templateID) else {
            showError("未找到模版资源: \(templateID)")
            return
        }
        
        print("📂 [Node 7] XML 路径: \(xmlURL.path.contains("HotUpdate") ? "🔥 CACHE" : "📦 BUNDLE") - \(xmlURL.lastPathComponent)")
        print("📂 [Node 7] JSON 路径: \(dataURL.path.contains("HotUpdate") ? "🔥 CACHE" : "📦 BUNDLE") - \(dataURL.lastPathComponent)")
        
        // 尝试加载 logic.js
        if let jsURL = TemplateManager.shared.getTemplateURL(templateId: templateID, fileName: logicFileName),
           let jsScript = try? String(contentsOf: jsURL) {
            print("📜 [PimeierVC] 加载逻辑脚本: \(logicFileName)")
            jsEngine?.loadScript(jsScript)
        }
        
        // 2. 解析 XML
        guard let xmlData = try? Data(contentsOf: xmlURL),
              let layoutNode = xmlParser.parse(data: xmlData) else {
            showError("无法解析布局文件")
            return
        }
        
        // 3. 加载初始数据 (ViewModel)
        // 总是尝试加载 pageData.json 并注入到 JS，以支持热重载更新数据
        if let jsonData = try? Data(contentsOf: dataURL),
           let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: []) {
            // 注入到 JS 全局对象 'viewModel'
            jsEngine?.setObject(jsonObject, forKey: "viewModel")
            print("💉 [Node 9] 注入最新 JSON 数据到 JS Context")
            // print("   📦 数据内容: \(jsonObject)")
        }
        
        // 4. 使用 Renderer 渲染视图树
        guard let rootView = renderer?.render(node: layoutNode, in: nil) else {
            showError("无法构建视图树")
            return
        }
        
        // 5. 添加到视图层级
        view.addSubview(rootView)
        rootContentView = rootView
        
        // 6. 初始布局计算
        view.setNeedsLayout()
        view.layoutIfNeeded()
        
        print("✅ [PimeierVC] 模版加载完成")
    }
    
    /// 刷新 UI (数据驱动重绘)
    private func refreshUI() {
        print("🔄 [PimeierVC] 刷新 UI...")
        
        guard let xmlURL = TemplateManager.shared.getTemplateURL(templateId: templateID, fileName: layoutFileName),
              let xmlData = try? Data(contentsOf: xmlURL),
              let layoutNode = xmlParser.parse(data: xmlData) else {
            return
        }
        
        // 使用 Renderer 重新渲染
        _ = renderer?.render(node: layoutNode, in: view)
        
        rootContentView = view.subviews.last
        
        view.setNeedsLayout()
        view.layoutIfNeeded()
    }
    
    /// 查找模版资源（XML 和 JSON）
    /// 优先查找 Cache，其次 Bundle
    private func findTemplateResources(id: String) -> (xml: URL, json: URL)? {
        let xmlURL = TemplateManager.shared.getTemplateURL(templateId: id, fileName: layoutFileName)
        let jsonURL = TemplateManager.shared.getTemplateURL(templateId: id, fileName: dataFileName)
        
        if let xmlURL = xmlURL, let jsonURL = jsonURL {
            return (xmlURL, jsonURL)
        }
        
        return nil
    }
    
    // MARK: - Component Inflation
    
    /// 动态加载并解析一个 XML 布局文件，返回生成的 UIView
    /// 主要用于列表项等动态组件的创建
    /// - Parameters:
    ///   - fileName: 模版目录下的文件名 (e.g. "item.xml")
    ///   - templateId: 模版 ID (默认为当前模版)
    public func inflateLayout(file fileName: String, templateId: String? = nil) -> UIView? {
        let targetTemplateId = templateId ?? self.templateID
        
        // 1. 获取文件路径
        guard let xmlURL = TemplateManager.shared.getTemplateURL(templateId: targetTemplateId, fileName: fileName) else {
            print("❌ [PimeierVC] inflateLayout: 未找到文件 \(fileName) (模版: \(targetTemplateId))")
            return nil
        }
        
        // 2. 解析 XML
        guard let xmlData = try? Data(contentsOf: xmlURL),
              let layoutNode = xmlParser.parse(data: xmlData) else {
            print("❌ [PimeierVC] inflateLayout: 解析失败 \(fileName)")
            return nil
        }
        
        // 3. 使用 Renderer 渲染视图树
        guard let view = renderer?.render(node: layoutNode, in: nil) else {
            print("❌ [PimeierVC] inflateLayout: 构建视图失败")
            return nil
        }
        
        return view
    }
    
    // MARK: - Hot Reload
    
    @objc private func handleFileChanged(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let fileName = userInfo["fileName"] as? String else { return }
        
        // 检查是否是当前模版的相关文件
        // 1. 完整匹配 (例如 "pimeierPages/todo_list/todo_list_layout.xml")
        // 2. 文件名匹配 (例如 "todo_list_layout.xml")
        
        let isRelevant = fileName.contains(layoutFileName) || 
                         fileName.contains(dataFileName) || 
                         fileName.contains(logicFileName)
        
        if isRelevant {
            print("👀 [Node 5] 页面捕获到相关变更: \(fileName)")
            print("🔄 [Node 6] 触发重载: loadTemplate()")
            DispatchQueue.main.async {
                self.loadTemplate()
            }
        } else {
            // print("🙈 [PimeierVC] 忽略无关变更: \(fileName)")
        }
    }
    
    // MARK: - Helpers
    
    private func showError(_ message: String) {
        print("❌ [PimeierVC] Error: \(message)")
        let alert = UIAlertController(title: "模版加载失败", message: message, preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "重试", style: .default) { [weak self] _ in
            self?.loadTemplate()
        })
        
        alert.addAction(UIAlertAction(title: "关闭", style: .cancel) { [weak self] _ in
            if let nav = self?.navigationController {
                nav.popViewController(animated: true)
            } else {
                self?.dismiss(animated: true)
            }
        })
        
        present(alert, animated: true)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        renderer?.cleanup()
        print("♻️ PimeierViewController 已释放")
    }
}
