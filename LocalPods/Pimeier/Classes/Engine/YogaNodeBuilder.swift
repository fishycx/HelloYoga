//
//  YogaNodeBuilder.swift
//  Pimeier
//
//  Created by AI Assistant
//

import UIKit
import YogaKit

// 定义一个全局的 measure 函数
func measureLabel(node: YGNodeRef?, width: Float, widthMode: YGMeasureMode, height: Float, heightMode: YGMeasureMode) -> YGSize {
    guard let node = node else { return YGSize(width: 0, height: 0) }
    
    // 从 context 获取 UILabel
    let context = YGNodeGetContext(node)
    guard context != nil else { return YGSize(width: 0, height: 0) }
    
    let label = Unmanaged<UILabel>.fromOpaque(context!).takeUnretainedValue()
    
    // 准备测量约束
    let constrainedWidth = (widthMode == .undefined) ? CGFloat.greatestFiniteMagnitude : CGFloat(width)
    let constrainedHeight = (heightMode == .undefined) ? CGFloat.greatestFiniteMagnitude : CGFloat(height)
    
    let size = label.sizeThatFits(CGSize(width: constrainedWidth, height: constrainedHeight))
    
    // 返回测量结果（向上取整以避免渲染截断）
    return YGSize(width: Float(ceil(size.width)), height: Float(ceil(size.height)))
}

/// Yoga 节点构建器
public class YogaNodeBuilder {
    
    /// 视图和节点的映射关系
    public private(set) var viewNodeMap: [UIView: YGNodeRef] = [:]
    
    /// ScrollView 和刷新控制器的映射关系
    private var scrollViewRefreshControls: [UIScrollView: RefreshControl] = [:]
    private var scrollViewLoadMoreControls: [UIScrollView: LoadMoreControl] = [:]
    
    /// 通过 ID 查找视图
    private var viewIdMap: [String: UIView] = [:]
    
    public init() {}
    
    /// 从布局节点构建 UIView 树和 Yoga 节点树
    public func buildViewTree(from layoutNode: LayoutNode, parent: UIView? = nil) -> UIView? {
        // 创建视图
        let view = createView(for: layoutNode)
        
        // 创建 Yoga 节点
        guard let yogaNode = YGNodeNew() else {
            print("❌ 无法创建 Yoga 节点")
            return nil
        }
        viewNodeMap[view] = yogaNode
        
        // 设置 Context (用于 measure 函数)
        if let label = view as? UILabel {
            YGNodeSetContext(yogaNode, UnsafeMutableRawPointer(Unmanaged.passUnretained(label).toOpaque()))
            YGNodeSetMeasureFunc(yogaNode, measureLabel)
        }
        
        // 应用 Yoga 样式
        let yogaStyle = YogaStyle.from(attributes: layoutNode.attributes)
        applyYogaStyle(yogaStyle, to: yogaNode)
        
        // 应用 UI 样式
        let viewStyle = ViewStyle.from(attributes: layoutNode.attributes)
        applyViewStyle(viewStyle, to: view)
        
        // 如果是自定义组件，应用自定义属性
        if let pimeierComponent = view as? PimeierComponent {
            pimeierComponent.applyAttributes(layoutNode.attributes)
        }
        
        // 如果视图有 ID，记录到映射表
        if let viewId = viewStyle.dataId {
            viewIdMap[viewId] = view
        }
        
        // 递归构建子节点
        var refreshView: UIView?
        var loadMoreView: UIView?
        var yogaChildIndex = 0
        
        for childLayout in layoutNode.children {
            // 检查是否是刷新视图或加载更多视图
            if childLayout.type == .refreshView {
                // 刷新视图不添加到 Yoga 树，而是单独处理
                refreshView = buildRefreshView(from: childLayout)
                continue
            } else if childLayout.type == .loadMoreView {
                // 加载更多视图不添加到 Yoga 树，而是单独处理
                loadMoreView = buildLoadMoreView(from: childLayout)
                continue
            }
            
            // 普通子节点正常处理
            if let childView = buildViewTree(from: childLayout, parent: view) {
                view.addSubview(childView)
                
                // 将子节点添加到 Yoga 树
                if let childYogaNode = viewNodeMap[childView] {
                    YGNodeInsertChild(yogaNode, childYogaNode, UInt32(yogaChildIndex))
                    yogaChildIndex += 1
                }
            }
        }
        
        // 如果是 ScrollView，处理刷新配置
        if let scrollView = view as? UIScrollView {
            setupRefreshControls(for: scrollView, layoutNode: layoutNode, refreshView: refreshView, loadMoreView: loadMoreView)
        }
        
        return view
    }
    
    /// 动态添加子视图并注册到 Yoga 树
    public func addChild(_ child: UIView, to parent: UIView, attributes: [String: String] = [:]) {
        guard let parentNode = viewNodeMap[parent] else {
            print("❌ 无法添加子视图：父视图未注册到 Yoga")
            return
        }
        
        // 创建 Yoga 节点
        guard let childNode = YGNodeNew() else {
            print("❌ 无法为子视图创建 Yoga 节点")
            return
        }
        viewNodeMap[child] = childNode
        
        // 设置 Context (用于 measure 函数)
        if let label = child as? UILabel {
            YGNodeSetContext(childNode, UnsafeMutableRawPointer(Unmanaged.passUnretained(label).toOpaque()))
            YGNodeSetMeasureFunc(childNode, measureLabel)
        }
        
        // 应用样式
        let yogaStyle = YogaStyle.from(attributes: attributes)
        applyYogaStyle(yogaStyle, to: childNode)
        
        let viewStyle = ViewStyle.from(attributes: attributes)
        applyViewStyle(viewStyle, to: child)
        
        // 添加到视图层级
        parent.addSubview(child)
        
        // 添加到 Yoga 树
        let childCount = YGNodeGetChildCount(parentNode)
        YGNodeInsertChild(parentNode, childNode, childCount)
        
        // 更新 ID 映射（如果需要）
        if let id = viewStyle.dataId {
            viewIdMap[id] = child
        }
    }
    
    /// 将已经存在的视图（及其 Yoga 节点）挂载到父视图
    /// 通常用于将 inflateLayout 生成的子树添加到主树中
    public func attachChild(_ child: UIView, to parent: UIView) {
        guard let parentNode = viewNodeMap[parent] else {
            print("❌ 无法挂载子视图：父视图未注册到 Yoga")
            return
        }
        
        guard let childNode = viewNodeMap[child] else {
            print("❌ 无法挂载子视图：子视图未注册到 Yoga")
            return
        }
        
        // 1. 建立视图层级关系
        parent.addSubview(child)
        
        // 2. 建立 Yoga 节点层级关系
        // 检查 childNode 是否已经是 parentNode 的子节点，避免重复添加
        // Yoga 没有直接的 API 检查 parent，但我们可以检查 childCount 并遍历
        // 简单起见，我们直接插入到末尾
        
        // 移除旧父节点（如果存在）的关联？
        // YGNodeRemoveChild(childNode.parent, childNode) // Yoga C API 不一定暴露了 parent
        
        let childCount = YGNodeGetChildCount(parentNode)
        YGNodeInsertChild(parentNode, childNode, childCount)
        
        // print("🔗 已挂载视图 [\(child.accessibilityIdentifier ?? "")] 到 [\(parent.accessibilityIdentifier ?? "")]")
    }
    
    /// 计算布局并应用到视图
    public func calculateLayout(for view: UIView, width: CGFloat, height: CGFloat) {
        guard let rootNode = viewNodeMap[view] else {
            print("⚠️ 未找到视图对应的 Yoga 节点")
            return
        }
        
        // print("📐 设置根节点尺寸: \(width) x \(height)")
        
        // 1. 强制设置根视图的 Frame (UIKit)
        // 这一步非常重要！因为 applyLayout 通常只设置子视图的 frame
        view.frame = CGRect(x: 0, y: 0, width: width, height: height)
        
        // 2. 强制设置 Yoga 根节点尺寸 (Yoga)
        YGNodeStyleSetWidth(rootNode, Float(width))
        YGNodeStyleSetHeight(rootNode, Float(height))
        
        // 3. 计算布局
        YGNodeCalculateLayout(rootNode, Float(width), Float(height), YGDirection.LTR)
        
        // 打印布局结果以便调试
        // let layoutWidth = YGNodeLayoutGetWidth(rootNode)
        // let layoutHeight = YGNodeLayoutGetHeight(rootNode)
        // print("✅ 布局计算完成: \(layoutWidth) x \(layoutHeight)")
        
        // 4. 应用布局到子视图
        // 注意：我们不需要对 root view 再次应用 layout，因为我们已经在步骤 1 中手动设置了
        // 但我们需要递归应用到它的所有子视图
        applyLayoutToChildren(of: view, node: rootNode)
        
        // 5. 在所有布局完成后，重新计算所有 ScrollView 的 contentSize
        // 这确保所有子视图的 frame 都已正确设置
        recalculateAllScrollViewContentSizes(in: view)
        
        // 6. 更新所有刷新视图的 frame
        updateRefreshViewsFrames()
    }
    
    /// 递归查找并重新计算所有 ScrollView 的 contentSize
    private func recalculateAllScrollViewContentSizes(in view: UIView) {
        if let scrollView = view as? UIScrollView,
           let node = viewNodeMap[scrollView] {
            calculateScrollViewContentSize(scrollView: scrollView, node: node)
        }
        
        // 递归处理子视图
        for subview in view.subviews {
            recalculateAllScrollViewContentSizes(in: subview)
        }
    }
    
    /// 递归应用布局到子视图
    private func applyLayoutToChildren(of view: UIView, node: YGNodeRef) {
        let childCount = YGNodeGetChildCount(node)
        
        for i in 0..<childCount {
            guard let childNode = YGNodeGetChild(node, i) else { continue }
            
            // 在 view.subviews 中查找对应的视图
            // 注意：UIScrollView 会自动添加滚动条指示器，所以不能简单假设 subviews 的顺序
            // 我们必须通过 viewNodeMap 查找
            
            if let childView = view.subviews.first(where: { viewNodeMap[$0] == childNode }) {
                // 应用布局到这个子视图
                let left = CGFloat(YGNodeLayoutGetLeft(childNode))
                let top = CGFloat(YGNodeLayoutGetTop(childNode))
                let width = CGFloat(YGNodeLayoutGetWidth(childNode))
                let height = CGFloat(YGNodeLayoutGetHeight(childNode))
                
                childView.frame = CGRect(x: left, y: top, width: width, height: height)
                
                // 调试日志
                if let id = childView.accessibilityIdentifier {
                    // print("📍 布局子视图 [\(id)]: \(childView.frame)")
                }
                
                // 递归处理孙子视图
                applyLayoutToChildren(of: childView, node: childNode)
            } else {
                print("⚠️ 警告: 找不到 Yoga 节点对应的子视图 (index: \(i))")
            }
        }
        
        // 注意：contentSize 的计算现在在 calculateLayout 的最后统一进行
        // 这样可以确保所有子视图的 frame 都已设置完成
    }
    
    /// 计算 ScrollView 的 contentSize
    /// 递归计算 ScrollView 内部所有视图的最大边界，过滤掉滚动条指示器
    private func calculateScrollViewContentSize(scrollView: UIScrollView, node: YGNodeRef) {
        // 检查 ScrollView 的 bounds 是否有效
        guard scrollView.bounds.width > 0 && scrollView.bounds.height > 0 else {
            print("⚠️ ScrollView bounds 无效: \(scrollView.bounds)，延迟计算 contentSize")
            // 延迟到下一个 runloop 再计算
            DispatchQueue.main.async {
                if scrollView.bounds.width > 0 && scrollView.bounds.height > 0 {
                    self.calculateScrollViewContentSize(scrollView: scrollView, node: node)
                }
            }
            return
        }
        
        // 递归计算所有子视图的最大边界
        var maxX: CGFloat = 0
        var maxY: CGFloat = 0
        
        // 递归函数：计算视图及其所有子视图的最大边界
        func calculateMaxBounds(for view: UIView, node: YGNodeRef, depth: Int = 0) {
            // 只计算我们创建的视图（在 viewNodeMap 中的），过滤掉滚动条指示器
            guard viewNodeMap[view] != nil else { return }
            
            let indent = String(repeating: "  ", count: depth)
            let viewType = String(describing: type(of: view))
            let viewId = view.accessibilityIdentifier ?? "无ID"
            
            // 使用实际的 frame（已经通过 Yoga 布局设置）
            let currentMaxX = view.frame.maxX
            let currentMaxY = view.frame.maxY
            
            // 更新最大值
            if currentMaxX > maxX {
                maxX = currentMaxX
                // print("\(indent)📏 [\(viewType)] \(viewId) 更新 maxX: \(currentMaxX)")
            }
            if currentMaxY > maxY {
                maxY = currentMaxY
                // print("\(indent)📏 [\(viewType)] \(viewId) 更新 maxY: \(currentMaxY) (frame: \(view.frame))")
            }
            
            // 递归处理所有子视图
            let childCount = YGNodeGetChildCount(node)
            for i in 0..<childCount {
                guard let childNode = YGNodeGetChild(node, i) else { continue }
                
                // 找到对应的子视图
                if let childView = view.subviews.first(where: { viewNodeMap[$0] == childNode }) {
                    calculateMaxBounds(for: childView, node: childNode, depth: depth + 1)
                }
            }
        }
        
        // 从 ScrollView 的直接子节点开始递归计算
        let childCount = YGNodeGetChildCount(node)
        var contentContainerView: UIView?
        
        for i in 0..<childCount {
            guard let childNode = YGNodeGetChild(node, i) else { continue }
            
            if let childView = scrollView.subviews.first(where: { viewNodeMap[$0] == childNode }) {
                // 保存内容容器视图（通常是第一个子视图）
                if contentContainerView == nil {
                    contentContainerView = childView
                }
                
                // 递归计算所有子视图的最大边界
                calculateMaxBounds(for: childView, node: childNode)
                
                // 特别处理：如果内容容器的高度小于其子视图的最大 Y 值
                // 说明 Yoga 计算的高度不正确，我们使用子视图的实际最大 Y 值
                if childView.frame.height < maxY - childView.frame.origin.y {
                    print("⚠️ 内容容器高度 (\(childView.frame.height)) 小于子视图最大 Y (\(maxY - childView.frame.origin.y))，使用子视图的实际高度")
                }
            }
        }
        
        // 获取 Yoga 的 padding 设置
        let paddingRight = CGFloat(YGNodeLayoutGetPadding(node, YGEdge.right))
        let paddingBottom = CGFloat(YGNodeLayoutGetPadding(node, YGEdge.bottom))
        
        // 确保 maxY 至少等于内容容器的高度（如果内容容器存在）
        if let container = contentContainerView {
            let containerMaxY = container.frame.maxY
            let containerHeight = container.frame.height
            
            // print("📦 内容容器信息:")
            // print("   - Frame: \(container.frame)")
            // print("   - Container maxY: \(containerMaxY)")
            // print("   - Container height: \(containerHeight)")
            // print("   - 当前计算的 maxY: \(maxY)")
            
            // 如果容器的高度明显小于其子视图的最大 Y 值，说明 Yoga 计算有误
            // 我们应该使用子视图的实际最大 Y 值
            if containerHeight > 0 && maxY > containerMaxY {
                print("   ⚠️ 容器高度 (\(containerHeight)) 小于子视图最大 Y (\(maxY))，使用子视图的实际高度")
            }
            
            maxY = max(maxY, containerMaxY)
        }
        
        // 计算最终的 contentSize
        // contentWidth 应该至少等于 ScrollView 的宽度
        let contentWidth = max(scrollView.bounds.width, maxX + paddingRight)
        // contentHeight 应该是所有内容的最大 Y 值加上底部 padding
        var contentHeight = maxY + paddingBottom
        
        // 如果启用了下拉刷新或上拉加载更多，确保 contentSize 至少比 bounds 大一点
        // 这样用户才能滚动，从而触发刷新或加载更多功能
        let hasRefreshControl = scrollViewRefreshControls[scrollView] != nil
        let hasLoadMoreControl = scrollViewLoadMoreControls[scrollView] != nil
        
        if (hasRefreshControl || hasLoadMoreControl) && contentHeight <= scrollView.bounds.height {
            // 如果内容高度不足，但启用了刷新功能，至少让 contentSize 比 bounds 大一些
            // 这样 ScrollView 就可以滚动，从而可以测试刷新功能
            // 使用 max 确保至少比 bounds 大 10pt，这样滚动更明显
            contentHeight = max(contentHeight, scrollView.bounds.height + 10.0)
            print("⚠️ 内容高度不足，但启用了刷新功能，调整 contentSize 为: \(contentHeight) (bounds.height: \(scrollView.bounds.height))")
        }
        
        // 但是，如果 maxY 为 0 或很小，说明计算有问题，我们需要使用备用方法
        if maxY < 10 {
            print("⚠️ maxY 异常小 (\(maxY))，使用备用方法计算")
            // 遍历所有 subviews，找到最大的 maxY
            var fallbackMaxY: CGFloat = 0
            for subview in scrollView.subviews {
                if viewNodeMap[subview] != nil {
                    let subviewMaxY = subview.frame.maxY
                    fallbackMaxY = max(fallbackMaxY, subviewMaxY)
                    print("   - 子视图 [\(type(of: subview))]: frame=\(subview.frame), maxY=\(subviewMaxY)")
                }
            }
            if fallbackMaxY > 0 {
                maxY = fallbackMaxY
                print("   ✅ 使用备用 maxY: \(fallbackMaxY)")
                // 如果使用了备用方法，重新计算 contentHeight
                contentHeight = maxY + paddingBottom
            }
        }
        
        // 使用调整后的 contentHeight（如果启用了刷新功能，可能已经被调整过）
        let finalContentHeight = contentHeight
        scrollView.contentSize = CGSize(width: contentWidth, height: finalContentHeight)
        
        // print("\n📜 ========== ScrollView 详细信息 ==========")
        // print("Bounds: \(scrollView.bounds)")
        // print("Frame: \(scrollView.frame)")
        // print("ContentSize: \(scrollView.contentSize)")
        // print("isScrollEnabled: \(scrollView.isScrollEnabled)")
        // print("----------------------------------------")
        // print("内容最大边界: x=\(maxX), y=\(maxY)")
        // print("Padding: right=\(paddingRight), bottom=\(paddingBottom)")
        // print("计算出的 contentSize: \(contentWidth) x \(finalContentHeight)")
        // print("可滚动判断: contentHeight(\(finalContentHeight)) > bounds.height(\(scrollView.bounds.height))")
        
        if finalContentHeight > scrollView.bounds.height {
            // print("✅ 可以滚动！内容高度 (\(finalContentHeight)) > ScrollView 高度 (\(scrollView.bounds.height))")
        } else {
            // print("❌ 无法滚动！内容高度 (\(finalContentHeight)) <= ScrollView 高度 (\(scrollView.bounds.height))")
            // print("   可能原因：")
            // print("   1. 内容确实不足，不需要滚动")
            // print("   2. contentSize 计算错误")
            // print("   3. ScrollView 的 bounds 设置错误")
        }
        // print("========================================\n")
    }
    
    // 废弃旧的 applyLayout 方法，改用上面的逻辑
    private func applyLayout(to view: UIView, node: YGNodeRef) {
        // 旧方法保留用于兼容，但建议不再使用
        applyLayoutToChildren(of: view, node: node)
    }
    
    /// 清理 Yoga 节点
    public func cleanup() {
        for (_, node) in viewNodeMap {
            // 注意：只释放根节点，子节点会被递归释放
        }
        
        // 找到所有根节点并释放
        let allNodes = Set(viewNodeMap.values)
        var childNodes = Set<YGNodeRef>()
        
        for node in allNodes {
            let childCount = YGNodeGetChildCount(node)
            for i in 0..<childCount {
                if let child = YGNodeGetChild(node, i) {
                    childNodes.insert(child)
                }
            }
        }
        
        let rootNodes = allNodes.subtracting(childNodes)
        for rootNode in rootNodes {
            YGNodeFreeRecursive(rootNode)
        }
        
        viewNodeMap.removeAll()
        scrollViewRefreshControls.removeAll()
        scrollViewLoadMoreControls.removeAll()
        viewIdMap.removeAll()
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: - Private Methods
    
    private func createView(for node: LayoutNode) -> UIView {
        switch node.type {
        case .text:
            let label = UILabel()
            label.numberOfLines = 0
            return label
            
        case .button:
            let button = UIButton(type: .system)
            return button
            
        case .image:
            let imageView = UIImageView()
            imageView.contentMode = .scaleAspectFit
            return imageView
            
        case .input:
            let textField = UITextField()
            textField.borderStyle = .roundedRect
            return textField
            
        case .scrollView:
            let scrollView = UIScrollView()
            // 显式启用滚动功能
            scrollView.isScrollEnabled = true
            scrollView.showsVerticalScrollIndicator = true
            scrollView.showsHorizontalScrollIndicator = false
            scrollView.alwaysBounceVertical = true
            return scrollView
            
        case .refreshView, .loadMoreView:
            // 刷新视图和加载更多视图是普通视图容器
            return UIView()
            
        case .container, .view, .header, .footer, .content:
            return UIView()
            
        case .custom:
            // 处理自定义组件
            if let customType = node.customType {
                // print("🛠️ [Builder] Creating custom view for tag: <\(customType)>")
                if let view = ComponentRegistry.shared.createView(tagName: customType) {
                    // print("✅ [Builder] Created \(type(of: view))")
                    return view
                }
            }
            // 如果找不到自定义组件，退化为普通 UIView
            print("⚠️ [Builder] 未找到自定义组件: \(node.customType ?? "unknown")，退化为 UIView")
            return UIView()
        }
    }
    
    private func randomColor() -> UIColor {
        let red = CGFloat.random(in: 0.8...1.0)
        let green = CGFloat.random(in: 0.8...1.0)
        let blue = CGFloat.random(in: 0.8...1.0)
        return UIColor(red: red, green: green, blue: blue, alpha: 0.5)
    }
    
    // MARK: - Refresh View Builders
    
    /// 构建刷新视图（不参与 Yoga 布局）
    private func buildRefreshView(from layoutNode: LayoutNode) -> UIView {
        let refreshView = UIView()
        
        // 应用 UI 样式
        let viewStyle = ViewStyle.from(attributes: layoutNode.attributes)
        applyViewStyle(viewStyle, to: refreshView)
        
        // 如果视图有 ID，记录到映射表
        if let viewId = viewStyle.dataId {
            viewIdMap[viewId] = refreshView
        }
        
        // 递归构建子视图（用于自定义内容）
        for childLayout in layoutNode.children {
            if let childView = buildViewTree(from: childLayout, parent: refreshView) {
                refreshView.addSubview(childView)
            }
        }
        
        return refreshView
    }
    
    /// 构建加载更多视图（不参与 Yoga 布局）
    private func buildLoadMoreView(from layoutNode: LayoutNode) -> UIView {
        let loadMoreView = UIView()
        
        // 应用 UI 样式
        let viewStyle = ViewStyle.from(attributes: layoutNode.attributes)
        applyViewStyle(viewStyle, to: loadMoreView)
        
        // 如果视图有 ID，记录到映射表
        if let viewId = viewStyle.dataId {
            viewIdMap[viewId] = loadMoreView
        }
        
        // 递归构建子视图（用于自定义内容）
        for childLayout in layoutNode.children {
            if let childView = buildViewTree(from: childLayout, parent: loadMoreView) {
                loadMoreView.addSubview(childView)
            }
        }
        
        return loadMoreView
    }
    
    // MARK: - Refresh Controls Setup
    
    private func setupRefreshControls(for scrollView: UIScrollView, layoutNode: LayoutNode, refreshView: UIView?, loadMoreView: UIView?) {
        let config = ScrollViewRefreshConfig.from(attributes: layoutNode.attributes)
        
        // 设置下拉刷新
        if config.enablePullToRefresh {
            var finalRefreshView: RefreshViewProtocol?
            
            // 检查是否有自定义刷新视图
            if let refreshViewId = config.refreshViewId, let customView = viewIdMap[refreshViewId] as? RefreshViewProtocol {
                finalRefreshView = customView
            } else if let customRefreshView = refreshView as? RefreshViewProtocol {
                finalRefreshView = customRefreshView
            } else {
                // 使用默认刷新视图
                finalRefreshView = DefaultRefreshView()
            }
            
            if let refreshView = finalRefreshView {
                let refreshControl = RefreshControl(
                    scrollView: scrollView,
                    refreshView: refreshView,
                    threshold: config.refreshThreshold
                )
                scrollViewRefreshControls[scrollView] = refreshControl
            }
        }
        
        // 设置上拉加载更多
        if config.enableLoadMore {
            var finalLoadMoreView: LoadMoreViewProtocol?
            
            // 检查是否有自定义加载更多视图
            if let loadMoreViewId = config.loadMoreViewId, let customView = viewIdMap[loadMoreViewId] as? LoadMoreViewProtocol {
                finalLoadMoreView = customView
            } else if let customLoadMoreView = loadMoreView as? LoadMoreViewProtocol {
                finalLoadMoreView = customLoadMoreView
            } else {
                // 使用默认加载更多视图
                finalLoadMoreView = DefaultLoadMoreView()
            }
            
            if let loadMoreView = finalLoadMoreView {
                let loadMoreControl = LoadMoreControl(
                    scrollView: scrollView,
                    loadMoreView: loadMoreView,
                    threshold: config.loadMoreThreshold
                )
                scrollViewLoadMoreControls[scrollView] = loadMoreControl
            }
        }
    }
    
    /// 获取 ScrollView 的刷新控制器
    public func getRefreshControl(for scrollView: UIScrollView) -> RefreshControl? {
        return scrollViewRefreshControls[scrollView]
    }
    
    /// 获取 ScrollView 的加载更多控制器
    public func getLoadMoreControl(for scrollView: UIScrollView) -> LoadMoreControl? {
        return scrollViewLoadMoreControls[scrollView]
    }
    
    /// 更新所有刷新视图的 frame（当 ScrollView 尺寸变化时调用）
    public func updateRefreshViewsFrames() {
        for (scrollView, refreshControl) in scrollViewRefreshControls {
            refreshControl.updateFrame()
        }
        for (scrollView, loadMoreControl) in scrollViewLoadMoreControls {
            loadMoreControl.updateFrame()
        }
    }
    
    private func applyYogaStyle(_ style: YogaStyle, to node: YGNodeRef) {
        // Flex 属性
        if let flexDirection = style.flexDirectionVal {
            YGNodeStyleSetFlexDirection(node, flexDirection)
        }
        if let justifyContent = style.justifyContent {
            YGNodeStyleSetJustifyContent(node, justifyContent)
        }
        if let alignItems = style.alignItems {
            YGNodeStyleSetAlignItems(node, alignItems)
        }
        if let alignSelf = style.alignSelf {
            YGNodeStyleSetAlignSelf(node, alignSelf)
        }
        if let flexWrap = style.flexWrap {
            YGNodeStyleSetFlexWrap(node, flexWrap)
        }
        if let flex = style.flex {
            YGNodeStyleSetFlex(node, flex)
        }
        if let flexGrow = style.flexGrow {
            YGNodeStyleSetFlexGrow(node, flexGrow)
        }
        if let flexShrink = style.flexShrink {
            YGNodeStyleSetFlexShrink(node, flexShrink)
        }
        
        // 尺寸属性
        if let width = style.width {
            applyValue(width, setter: { YGNodeStyleSetWidth(node, $0) },
                      percentSetter: { YGNodeStyleSetWidthPercent(node, $0) },
                      autoSetter: { YGNodeStyleSetWidthAuto(node) })
        }
        if let height = style.height {
            applyValue(height, setter: { YGNodeStyleSetHeight(node, $0) },
                      percentSetter: { YGNodeStyleSetHeightPercent(node, $0) },
                      autoSetter: { YGNodeStyleSetHeightAuto(node) })
        }
        
        // Padding
        if let padding = style.padding {
            applyEdgeValue(padding, edge: YGEdge.all, node: node, type: .padding)
        }
        if let paddingTop = style.paddingTop {
            applyEdgeValue(paddingTop, edge: YGEdge.top, node: node, type: .padding)
        }
        if let paddingRight = style.paddingRight {
            applyEdgeValue(paddingRight, edge: YGEdge.right, node: node, type: .padding)
        }
        if let paddingBottom = style.paddingBottom {
            applyEdgeValue(paddingBottom, edge: YGEdge.bottom, node: node, type: .padding)
        }
        if let paddingLeft = style.paddingLeft {
            applyEdgeValue(paddingLeft, edge: YGEdge.left, node: node, type: .padding)
        }
        
        // Margin
        if let margin = style.margin {
            applyEdgeValue(margin, edge: YGEdge.all, node: node, type: .margin)
        }
        if let marginTop = style.marginTop {
            applyEdgeValue(marginTop, edge: YGEdge.top, node: node, type: .margin)
        }
        if let marginRight = style.marginRight {
            applyEdgeValue(marginRight, edge: YGEdge.right, node: node, type: .margin)
        }
        if let marginBottom = style.marginBottom {
            applyEdgeValue(marginBottom, edge: YGEdge.bottom, node: node, type: .margin)
        }
        if let marginLeft = style.marginLeft {
            applyEdgeValue(marginLeft, edge: YGEdge.left, node: node, type: .margin)
        }
        
        // Position
        if let position = style.position {
            YGNodeStyleSetPositionType(node, position)
        }
        if let top = style.top {
            applyEdgeValue(top, edge: YGEdge.top, node: node, type: .position)
        }
        if let right = style.right {
            applyEdgeValue(right, edge: YGEdge.right, node: node, type: .position)
        }
        if let bottom = style.bottom {
            applyEdgeValue(bottom, edge: YGEdge.bottom, node: node, type: .position)
        }
        if let left = style.left {
            applyEdgeValue(left, edge: YGEdge.left, node: node, type: .position)
        }
        
        // 其他
        if let aspectRatio = style.aspectRatio {
            YGNodeStyleSetAspectRatio(node, aspectRatio)
        }
    }
    
    private enum EdgeValueType {
        case padding, margin, position
    }
    
    private func applyEdgeValue(_ value: YGValue, edge: YGEdge, node: YGNodeRef, type: EdgeValueType) {
        switch type {
        case .padding:
            if value.unit == .percent {
                YGNodeStyleSetPaddingPercent(node, edge, value.value)
            } else if value.unit == .point {
                YGNodeStyleSetPadding(node, edge, value.value)
            }
        case .margin:
            if value.unit == .percent {
                YGNodeStyleSetMarginPercent(node, edge, value.value)
            } else if value.unit == .point {
                YGNodeStyleSetMargin(node, edge, value.value)
            } else if value.unit == .auto {
                YGNodeStyleSetMarginAuto(node, edge)
            }
        case .position:
            if value.unit == .percent {
                YGNodeStyleSetPositionPercent(node, edge, value.value)
            } else if value.unit == .point {
                YGNodeStyleSetPosition(node, edge, value.value)
            }
        }
    }
    
    private func applyValue(_ value: YGValue,
                           setter: (Float) -> Void,
                           percentSetter: (Float) -> Void,
                           autoSetter: () -> Void) {
        switch value.unit {
        case .point:
            setter(value.value)
        case .percent:
            percentSetter(value.value)
        case .auto:
            autoSetter()
        default:
            break
        }
    }
    
    private func applyViewStyle(_ style: ViewStyle, to view: UIView) {
        // 基础样式
        if let backgroundColor = style.backgroundColor {
            view.backgroundColor = backgroundColor
        } else {
            // 🎨 调试模式：如果没有指定背景色，设置随机背景色
            // 排除 UILabel、UIButton 和自定义组件 (PimeierComponent)，避免太花哨或覆盖自定义绘制
            if !(view is UILabel) && !(view is UIImageView) && !(view is PimeierComponent) {
                // print("🎨 [Debug] Setting random background for \(type(of: view))")
                view.backgroundColor = randomColor()
            } else {
                // 确保自定义组件背景透明（如果它们在 init 中设置了）
                // print("🎨 [Debug] Skipping random background for \(type(of: view))")
            }
        }
        
        if let cornerRadius = style.cornerRadius {
            view.layer.cornerRadius = cornerRadius
            view.layer.masksToBounds = true
        }
        if let borderWidth = style.borderWidth {
            view.layer.borderWidth = borderWidth
        }
        if let borderColor = style.borderColor {
            view.layer.borderColor = borderColor.cgColor
        }
        if let opacity = style.opacity {
            view.alpha = opacity
        }
        if let isHidden = style.isHidden {
            view.isHidden = isHidden
        }
        
        // 文本样式
        if let label = view as? UILabel {
            if let text = style.text {
                label.text = text
            }
            if let textColor = style.textColor {
                label.textColor = textColor
            }
            if let fontSize = style.fontSize {
                let weight = style.fontWeight ?? .regular
                label.font = .systemFont(ofSize: fontSize, weight: weight)
            }
            if let textAlignment = style.textAlignment {
                label.textAlignment = textAlignment
            }
            if let numberOfLines = style.numberOfLines {
                label.numberOfLines = numberOfLines
            }
        }
        
        // 按钮样式
        if let button = view as? UIButton {
            if let title = style.title {
                button.setTitle(title, for: .normal)
            }
            if let titleColor = style.titleColor {
                button.setTitleColor(titleColor, for: .normal)
            }
            if let fontSize = style.fontSize {
                let weight = style.fontWeight ?? .regular
                button.titleLabel?.font = .systemFont(ofSize: fontSize, weight: weight)
            }
        }
        
        // 图片样式
        if let imageView = view as? UIImageView {
            if let imageName = style.imageName {
                imageView.image = UIImage(named: imageName)
            }
            if let contentMode = style.contentMode {
                imageView.contentMode = contentMode
            }
        }
        
        // 输入框样式
        if let textField = view as? UITextField {
            if let placeholder = style.placeholder {
                textField.placeholder = placeholder
            }
            if let placeholderColor = style.placeholderColor, let placeholder = style.placeholder {
                textField.attributedPlaceholder = NSAttributedString(
                    string: placeholder,
                    attributes: [.foregroundColor: placeholderColor]
                )
            }
            if let textColor = style.textColor {
                textField.textColor = textColor
            }
            if let fontSize = style.fontSize {
                let weight = style.fontWeight ?? .regular
                textField.font = .systemFont(ofSize: fontSize, weight: weight)
            }
            if let text = style.text {
                textField.text = text
            }
            if let borderStyle = style.borderStyle {
                textField.borderStyle = borderStyle
            }
            if let textAlignment = style.textAlignment {
                textField.textAlignment = textAlignment
            }
        }
        
        // 保存数据 ID（用于后续数据绑定）
        if let dataId = style.dataId {
            view.accessibilityIdentifier = dataId
        }
    }
}
