//
//  PimeierListView.swift
//  Pimeier
//
//  Created by AI Assistant
//

import UIKit
import YogaKit
import Foundation

// 用于存储 cell 的模板类型
private var AssociatedTemplateTypeKey: UInt8 = 0

extension UICollectionViewCell {
    var pimeierTemplateType: String? {
        get {
            return objc_getAssociatedObject(self, &AssociatedTemplateTypeKey) as? String
        }
        set {
            objc_setAssociatedObject(self, &AssociatedTemplateTypeKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

public class PimeierListView: UICollectionView, PimeierComponent, UICollectionViewDelegateFlowLayout, TemplateConsumer, PimeierRendererAware {
    
    // MARK: - Types
    
    enum Section {
        case main
    }
    
    struct Item: Hashable {
        let id: String
        let index: Int
        let data: [String: Any]
        let templateType: String // 模板类型，用于选择不同的 cell 样式
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
        
        static func == (lhs: Item, rhs: Item) -> Bool {
            return lhs.id == rhs.id
        }
    }
    
    // MARK: - Properties
    
    private var diffableDataSource: UICollectionViewDiffableDataSource<Section, Item>!
    private weak var renderer: PimeierRenderer?
    private var templates: [String: LayoutNode] = [:] // 支持多个模板类型
    private var defaultTemplateType: String = "item" // 默认模板类型
    
    private var dataPath: String?
    private var onItemClickScript: String?
    private var onRefreshScript: String?
    private var pendingDataUpdate = false // 标记是否有待处理的数据更新
    
    // MARK: - Init
    
    public required init() {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 10
        layout.minimumInteritemSpacing = 10
        
        super.init(frame: .zero, collectionViewLayout: layout)
        
        self.backgroundColor = .clear
        self.delegate = self
        
        // 清理旧的注册信息（避免缓存问题）
        // 注意：UICollectionView 的 register 是持久性的，需要清理
        self.templates.removeAll()
        self.pendingDataUpdate = false
        
        // 注册默认的 cell identifier（向后兼容）
        self.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "Cell")
        
        // 默认配置
        self.alwaysBounceVertical = true
        self.showsVerticalScrollIndicator = true
        
        if #available(iOS 11.0, *) {
            self.contentInsetAdjustmentBehavior = .never
        }
        
        setupRefreshControl()
        configureDataSource()
        // loadDummyData() // 只有在没有数据绑定时才加载 Dummy
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupRefreshControl() {
        let refresh = UIRefreshControl()
        refresh.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        self.refreshControl = refresh
    }
    
    @objc private func handleRefresh() {
        guard let script = onRefreshScript, let renderer = renderer else {
            refreshControl?.endRefreshing()
            return
        }
        // 执行刷新脚本
        _ = renderer.evaluateScript(script)
    }
    
    // MARK: - Protocol Implementation
    
    public func setRenderer(_ renderer: PimeierRenderer) {
        print("🔗 [ListView] setRenderer called")
        self.renderer = renderer
        // 不要立即调用 updateData()，因为此时模板可能还没注册
        // updateData() 会在 registerTemplate() 完成后被调用（如果 dataPath 已设置）
        print("🔗 [ListView] renderer set, will update data after templates are registered")
    }
    
    public func registerTemplate(_ node: LayoutNode, forType type: String) {
        print("📋 [ListView] registerTemplate called: type=\(type), node.type=\(node.type), children.count=\(node.children.count)")
        print("📋 [ListView] 注册前已存在的模板: \(templates.keys.sorted())")
        
        // 如果模板已存在，先清理（避免缓存问题）
        if templates[type] != nil {
            print("⚠️ [ListView] Template '\(type)' already exists, replacing it")
        }
        
        templates[type] = node
        
        // 自动注册对应的 cell identifier
        let identifier = cellIdentifier(for: type)
        // 注意：UICollectionView 的 register 是幂等的，重复注册不会出错
        self.register(UICollectionViewCell.self, forCellWithReuseIdentifier: identifier)
        print("✅ [ListView] Template '\(type)' registered successfully (total: \(templates.count))")
        print("✅ [ListView] Cell identifier '\(identifier)' registered for template type '\(type)'")
        print("✅ [ListView] 当前所有已注册的模板: \(templates.keys.sorted())")
        
        // 如果注册的是 "item" 类型，设置为默认模板
        if type == "item" {
            defaultTemplateType = "item"
        }
        
        // 如果 renderer 和 dataPath 都已设置，延迟调用 updateData()
        // 这样可以确保所有模板都注册完成后再更新数据
        if renderer != nil && dataPath != nil && !pendingDataUpdate {
            pendingDataUpdate = true
            // 使用异步调用，确保当前模板注册完成，并且所有模板都注册完成
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.pendingDataUpdate = false
                print("🔄 [ListView] Templates registered, calling updateData() now (templates: \(self.templates.keys.sorted()))")
                self.updateData()
            }
        }
    }
    
    /// 清理所有模板和注册信息（用于重新加载时清理缓存）
    public func clearTemplates() {
        print("🧹 [ListView] Clearing all templates and registrations")
        templates.removeAll()
        pendingDataUpdate = false
        // 注意：UICollectionView 的 register 无法直接清理，但新的注册会覆盖旧的
    }
    
    // MARK: - Helper Methods
    
    /// 根据模板类型生成对应的 cell identifier
    /// - Parameter templateType: 模板类型
    /// - Returns: Cell identifier (格式: "Cell_{templateType}")
    private func cellIdentifier(for templateType: String) -> String {
        return "Cell_\(templateType)"
    }
    
    // MARK: - Configuration
    
    private func configureDataSource() {
        diffableDataSource = UICollectionViewDiffableDataSource<Section, Item>(collectionView: self) { [weak self] (collectionView, indexPath, item) -> UICollectionViewCell? in
            guard let self = self else {
                print("❌ [ListView] Cell配置失败: self is nil")
                return collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath)
            }
            
            // 根据 templateType 选择对应的 cell identifier
            let templateType = item.templateType
            let identifier = self.cellIdentifier(for: templateType)
            
            // 检查该 identifier 是否已注册，如果没有则使用默认的 "Cell"
            let cellIdentifier: String
            if self.templates[templateType] != nil {
                cellIdentifier = identifier
            } else {
                // 向后兼容：如果模板不存在，使用默认 identifier
                cellIdentifier = "Cell"
                print("⚠️ [ListView] Template '\(templateType)' not found, using default cell identifier")
            }
            
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellIdentifier, for: indexPath)
            
            // 检查 cell 是否已经配置过相同类型的模板（用于日志和优化提示）
            let wasConfigured = cell.pimeierTemplateType == templateType
            
            // 清理旧视图（由于数据绑定是动态的，需要始终重新渲染以更新数据）
            cell.contentView.subviews.forEach { $0.removeFromSuperview() }
            // 更新存储的模板类型
            cell.pimeierTemplateType = templateType
            
            print("🎨 [ListView] 配置 Cell [\(indexPath.item)]: templateType=\(templateType), identifier=\(cellIdentifier), wasConfigured=\(wasConfigured), templates.count=\(self.templates.count), renderer=\(self.renderer != nil ? "exists" : "nil")")
            print("🎨 [ListView] Item data: \(item.data)")
            
            // 根据 templateType 选择对应的模板
            print("🔍 [ListView] 查找模板: templateType=\(templateType), 已注册的模板: \(self.templates.keys.sorted())")
            
            // 直接查找指定类型的模板，不要回退到默认模板
            // 如果找不到，说明模板还没注册或者类型错误
            var template = self.templates[templateType]
            
            if template == nil {
                // 如果找不到指定模板，尝试使用默认模板（向后兼容）
                print("⚠️ [ListView] 模板 '\(templateType)' 不存在，尝试使用默认模板 '\(self.defaultTemplateType)'")
                template = self.templates[self.defaultTemplateType]
                
                if template == nil {
                    print("❌ [ListView] 未找到模板 '\(templateType)'，且默认模板 '\(self.defaultTemplateType)' 也不存在！")
                    print("❌ [ListView] 已注册的模板类型: \(self.templates.keys.sorted())")
                    print("❌ [ListView] 这可能是模板注册时机问题，或者 templateType 字段错误")
                }
            }
            
            // 使用模版渲染（由于数据绑定是动态的，需要始终重新渲染）
            if let template = template, let renderer = self.renderer {
                print("✅ [ListView] 使用模板渲染 Cell [\(indexPath.item)]")
                print("📋 [ListView] Template children count: \(template.children.count)")
                
                // 模板节点的第一个子节点才是实际要渲染的内容
                guard let templateContent = template.children.first else {
                    print("❌ [ListView] Template 没有子节点！")
                    return cell
                }
                
                // 构造上下文数据
                let contextData: [String: Any] = ["item": item.data, "index": indexPath.item]
                
                // 使用 JSON 序列化方式传递数据，避免 Bridge 问题
                if let jsonData = try? JSONSerialization.data(withJSONObject: contextData, options: []),
                   let jsonString = String(data: jsonData, encoding: .utf8),
                   let jsValue = renderer.createJSValue(fromJson: jsonString) {
                    
                    print("🎨 [ListView] 开始渲染模板内容，context: \(jsonString.prefix(100))")
                    print("🎨 [ListView] Cell bounds: \(cell.contentView.bounds)")
                    print("🎨 [ListView] Template content type: \(templateContent.type.rawValue)")
                    
                    // 如果 bounds 为 0，先设置一个临时大小
                    if cell.contentView.bounds.width == 0 || cell.contentView.bounds.height == 0 {
                        cell.contentView.bounds = CGRect(x: 0, y: 0, width: collectionView.bounds.width, height: 70)
                        print("🎨 [ListView] 临时设置 cell bounds: \(cell.contentView.bounds)")
                    }
                    
                    // 渲染模板的内容节点（而不是 template 节点本身）
                    if let renderedView = renderer.render(node: templateContent, in: cell.contentView, with: jsValue) {
                        print("✅ [ListView] 模板渲染成功，生成了 \(renderedView.subviews.count) 个子视图")
                        // 确保渲染的视图填充 cell
                        renderedView.frame = cell.contentView.bounds
                        renderedView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                        
                        // 确保 contentView 不会拦截触摸事件（对于交互式控件很重要）
                        cell.contentView.isUserInteractionEnabled = true
                        
                        // 确保所有交互式控件可以接收触摸事件
                        func enableInteractionForControls(in view: UIView) {
                            if view is UISwitch || view is UISlider || view is UIButton || view is UITextField {
                                view.isUserInteractionEnabled = true
                                // 确保父视图不会拦截触摸
                                var parent = view.superview
                                while parent != nil && parent != cell.contentView {
                                    parent?.isUserInteractionEnabled = true
                                    parent = parent?.superview
                                }
                            }
                            for subview in view.subviews {
                                enableInteractionForControls(in: subview)
                            }
                        }
                        enableInteractionForControls(in: renderedView)
                        
                        // 强制布局
                        cell.contentView.setNeedsLayout()
                        cell.contentView.layoutIfNeeded()
                    } else {
                        print("❌ [ListView] 模板渲染返回 nil")
                    }
                } else {
                    print("❌ [ListView] 无法创建 JSValue 上下文")
                }
            } else {
                // 默认样式 (Fallback)
                print("⚠️ [ListView] 使用默认样式 (Fallback)")
                cell.contentView.backgroundColor = .systemBlue
                cell.contentView.layer.cornerRadius = 8
                
                let label = UILabel(frame: cell.contentView.bounds)
                label.text = "Item \(item.index) (Default)"
                label.textColor = .white
                label.textAlignment = .center
                label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                cell.contentView.addSubview(label)
            }
            
            return cell
        }
    }
    
    private func updateData() {
        print("📊 [ListView] updateData() called. dataPath: \(dataPath ?? "nil"), renderer: \(renderer != nil ? "exists" : "nil")")
        print("📊 [ListView] 当前已注册的模板: \(templates.keys.sorted())")
        
        guard let dataPath = dataPath, let renderer = renderer else {
            print("⚠️ [ListView] Cannot update data: missing dataPath or renderer")
            return
        }
        
        print("📊 [ListView] Evaluating: \(dataPath)")
        
        // 先检查 viewModel 是否存在
        if let viewModel = renderer.evaluateScript("viewModel") {
            print("📊 [ListView] viewModel exists: isObject=\(viewModel.isObject), isUndefined=\(viewModel.isUndefined)")
            if let vmDict = viewModel.toDictionary() {
                print("📊 [ListView] viewModel keys: \(vmDict.keys)")
            }
        } else {
            print("❌ [ListView] viewModel is nil!")
        }
        
        if let jsValue = renderer.evaluateScript(dataPath) {
            print("📊 [ListView] JSValue type: isArray=\(jsValue.isArray), isObject=\(jsValue.isObject), isUndefined=\(jsValue.isUndefined)")
            
            if jsValue.isArray {
                let count = Int(jsValue.objectForKeyedSubscript("length").toInt32())
                print("📊 [ListView] Array length: \(count)")
                
                var newItems: [Item] = []
                
                for i in 0..<count {
                    let itemValue = jsValue.atIndex(i)
                    let itemData = itemValue?.toDictionary() as? [String: Any] ?? [:]
                    
                    // 优先使用 id，如果没有则生成随机 ID (注意：这可能导致 Diffable 动画异常，如果有稳定 ID 最好)
                    // 如果数据没有 ID，使用 index + hash 可能更好
                    let id = (itemData["id"] as? String) ?? UUID().uuidString
                    
                    // 从数据中读取 templateType，如果没有则使用默认值
                    // 支持多种字段名：templateType, type, cellType, template
                    let templateType = (itemData["templateType"] as? String) ??
                                     (itemData["type"] as? String) ??
                                     (itemData["cellType"] as? String) ??
                                     (itemData["template"] as? String) ??
                                     self.defaultTemplateType
                    
                    print("📊 [ListView] Item [\(i)] templateType=\(templateType), 模板是否存在: \(self.templates[templateType] != nil)")
                    
                    newItems.append(Item(id: id, index: i, data: itemData, templateType: templateType))
                }
                
                print("📊 [ListView] Created \(newItems.count) items")
                
                var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
                snapshot.appendSections([.main])
                snapshot.appendItems(newItems)
                // 如果是首次加载或完全刷新，可能不需要动画
                diffableDataSource.apply(snapshot, animatingDifferences: true)
                print("✅ [ListView] Snapshot applied")
            } else {
                print("⚠️ [ListView] JSValue is not an array")
            }
        } else {
            print("❌ [ListView] Failed to evaluate dataPath: \(dataPath)")
        }
    }
    
    // MARK: - PimeierComponent
    
    public func applyAttributes(_ attributes: [String : String]) {
        print("📝 [ListView] applyAttributes called with keys: \(attributes.keys)")
        
        if let direction = attributes["scrollDirection"] {
            if let layout = self.collectionViewLayout as? UICollectionViewFlowLayout {
                layout.scrollDirection = (direction == "horizontal") ? .horizontal : .vertical
            }
        }
        
        var top: CGFloat = 0
        var left: CGFloat = 0
        var bottom: CGFloat = 0
        var right: CGFloat = 0
        
        if let p = attributes["padding"]?.floatValue {
            let val = CGFloat(p)
            top = val; left = val; bottom = val; right = val
        }
        if let pt = attributes["paddingTop"]?.floatValue { top = CGFloat(pt) }
        if let pl = attributes["paddingLeft"]?.floatValue { left = CGFloat(pl) }
        if let pb = attributes["paddingBottom"]?.floatValue { bottom = CGFloat(pb) }
        if let pr = attributes["paddingRight"]?.floatValue { right = CGFloat(pr) }
        
        if top > 0 || left > 0 || bottom > 0 || right > 0 {
            self.contentInset = UIEdgeInsets(top: top, left: left, bottom: bottom, right: right)
        }
        
        // Data Binding (支持 data 和 dataSource 两种属性名)
        if let data = attributes["data"] ?? attributes["dataSource"] {
            print("📝 [ListView] applyAttributes: data/dataSource='\(data)'")
            self.dataPath = data
            // 不要立即调用 updateData()，因为此时模板可能还没注册
            // 等待 setRenderer 被调用时再更新数据（此时模板应该已经注册完成）
            print("⏳ [ListView] dataPath set, will update data when setRenderer is called (templates may not be registered yet)")
        } else {
            // 临时测试：如果属性不存在，使用硬编码的默认值
            print("⚠️ [ListView] data/dataSource not found in attributes, using default: viewModel.todoList")
            self.dataPath = "viewModel.todoList"
            // 不要立即调用 updateData()，等待 setRenderer 被调用
            print("⏳ [ListView] will update data when setRenderer is called")
        }
        
        // 支持设置默认模板类型
        if let defaultType = attributes["defaultTemplateType"] {
            self.defaultTemplateType = defaultType
            print("📋 [ListView] 默认模板类型设置为: \(defaultType)")
        }
        
        // Interactions
        if let click = attributes["onItemClick"] {
            self.onItemClickScript = click
        }
        
        if let refresh = attributes["onRefresh"] {
            self.onRefreshScript = refresh
        }
        
        // Refresh State Binding
        if let refreshing = attributes["refreshing"] {
            let isRefreshing = (refreshing == "true")
            if isRefreshing && !(refreshControl?.isRefreshing ?? false) {
                refreshControl?.beginRefreshing()
            } else if !isRefreshing && (refreshControl?.isRefreshing ?? false) {
                refreshControl?.endRefreshing()
            }
        }
    }
    
    // MARK: - UICollectionViewDelegate
    
    // 检查点击位置是否在交互式控件上（如 Switch、Slider、Button 等）
    private func isPointOnInteractiveControl(_ point: CGPoint, in cell: UICollectionViewCell) -> Bool {
        // 使用 hitTest 来查找点击位置下的视图
        let hitView = cell.contentView.hitTest(point, with: nil)
        
        // 递归向上查找，看是否命中交互式控件
        var currentView: UIView? = hitView
        while let view = currentView {
            // 如果是交互式控件，返回 true
            if view is UISwitch || view is UISlider || view is UIButton || view is UITextField {
                print("✅ [ListView] 检测到交互式控件: \(type(of: view))")
                return true
            }
            // 如果已经到达 cell 的 contentView，停止查找
            if view == cell.contentView {
                break
            }
            currentView = view.superview
        }
        
        return false
    }
    
    // 在 cell 被选中之前检查是否应该允许选择
    public func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        // 获取当前触摸位置
        guard let cell = collectionView.cellForItem(at: indexPath) else {
            return true
        }
        
        // 尝试从手势识别器获取触摸位置
        var touchPoint: CGPoint?
        
        // 方法1: 从 pan gesture 获取
        let panGesture = collectionView.panGestureRecognizer
        if panGesture.state != .possible {
            touchPoint = panGesture.location(in: cell)
        }
        
        // 方法2: 从 tap gesture 获取（如果有）
        if touchPoint == nil {
            for gesture in collectionView.gestureRecognizers ?? [] {
                if let tapGesture = gesture as? UITapGestureRecognizer,
                   tapGesture.state != .possible {
                    touchPoint = tapGesture.location(in: cell)
                    break
                }
            }
        }
        
        // 如果找到了触摸位置，检查是否在交互式控件上
        if let point = touchPoint {
            if isPointOnInteractiveControl(point, in: cell) {
                print("🚫 [ListView] 点击位置在交互式控件上，不触发 cell 选择")
                return false
            }
        }
        
        return true
    }
    
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let item = diffableDataSource.itemIdentifier(for: indexPath),
              let script = onItemClickScript,
              let renderer = renderer else { return }
        
        // 触发点击事件，注入 item 和 index
        let contextData: [String: Any] = ["item": item.data, "index": indexPath.item]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: contextData, options: []),
           let jsonString = String(data: jsonData, encoding: .utf8),
           let jsContext = renderer.createJSValue(fromJson: jsonString) {
            
            _ = renderer.evaluateExpression(script, with: jsContext)
        }
        
        // 取消选择，避免高亮状态
        collectionView.deselectItem(at: indexPath, animated: true)
    }
    
    // MARK: - UICollectionViewDelegateFlowLayout
    
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = collectionView.bounds.width - self.contentInset.left - self.contentInset.right
        return CGSize(width: max(0, width), height: 80) // 稍微增加高度以适应更复杂的模版
    }
}

extension String {
    var floatValue: Float? {
        return Float(self)
    }
}
