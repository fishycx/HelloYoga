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
    
    /// 通过 ID 查找视图
    private var viewIdMap: [String: UIView] = [:]
    
    /// 视图创建回调 (用于依赖注入)
    public var onViewCreated: ((UIView) -> Void)?
    
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
        var yogaChildIndex = 0
        
        for childLayout in layoutNode.children {
            // 忽略已废弃的 refreshView 和 loadMoreView
            if childLayout.type == .refreshView || childLayout.type == .loadMoreView {
                continue
            }
            
            // 处理模版定义节点
            if childLayout.type == .template {
                if let consumer = view as? TemplateConsumer {
                    let type = childLayout.attributes["type"] ?? "default"
                    consumer.registerTemplate(childLayout, forType: type)
                }
                // 模版节点不添加到视图层级中
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
        let childCount = YGNodeGetChildCount(parentNode)
        YGNodeInsertChild(parentNode, childNode, childCount)
    }
    
    /// 计算布局并应用到视图
    public func calculateLayout(for view: UIView, width: CGFloat, height: CGFloat) {
        guard let rootNode = viewNodeMap[view] else {
            print("⚠️ 未找到视图对应的 Yoga 节点")
            return
        }
        
        // 1. 强制设置根视图的 Frame (UIKit)
        view.frame = CGRect(x: 0, y: 0, width: width, height: height)
        
        // 2. 强制设置 Yoga 根节点尺寸 (Yoga)
        YGNodeStyleSetWidth(rootNode, Float(width))
        YGNodeStyleSetHeight(rootNode, Float(height))
        
        // 3. 计算布局
        YGNodeCalculateLayout(rootNode, Float(width), Float(height), YGDirection.LTR)
        
        // 4. 应用布局到子视图
        applyLayoutToChildren(of: view, node: rootNode)
        
        // 5. 更新所有 ScrollView 的 contentSize
        updateAllScrollViewContentSizes(in: view)
    }
    
    /// 递归查找并更新所有 ScrollView 的 contentSize
    private func updateAllScrollViewContentSizes(in view: UIView) {
        if let scrollView = view as? UIScrollView,
           let node = viewNodeMap[scrollView] {
            updateScrollViewContentSize(scrollView, node: node)
        }
        
        for subview in view.subviews {
            updateAllScrollViewContentSizes(in: subview)
        }
    }
    
    /// 更新单个 ScrollView 的 contentSize
    private func updateScrollViewContentSize(_ scrollView: UIScrollView, node: YGNodeRef) {
        var maxX: CGFloat = 0
        var maxY: CGFloat = 0
        
        let childCount = YGNodeGetChildCount(node)
        for i in 0..<childCount {
            guard let childNode = YGNodeGetChild(node, i) else { continue }
            
            // 查找对应的 View
            if let childView = scrollView.subviews.first(where: { viewNodeMap[$0] == childNode }) {
                maxX = max(maxX, childView.frame.maxX)
                maxY = max(maxY, childView.frame.maxY)
            }
        }
        
        let paddingRight = CGFloat(YGNodeLayoutGetPadding(node, YGEdge.right))
        let paddingBottom = CGFloat(YGNodeLayoutGetPadding(node, YGEdge.bottom))
        
        // 简单的 contentSize 计算
        scrollView.contentSize = CGSize(width: max(scrollView.bounds.width, maxX + paddingRight),
                                      height: maxY + paddingBottom)
    }
    
    /// 递归应用布局到子视图
    private func applyLayoutToChildren(of view: UIView, node: YGNodeRef) {
        let childCount = YGNodeGetChildCount(node)
        
        for i in 0..<childCount {
            guard let childNode = YGNodeGetChild(node, i) else { continue }
            
            // 在 view.subviews 中查找对应的视图
            if let childView = view.subviews.first(where: { viewNodeMap[$0] == childNode }) {
                // 应用布局到这个子视图
                let left = CGFloat(YGNodeLayoutGetLeft(childNode))
                let top = CGFloat(YGNodeLayoutGetTop(childNode))
                let width = CGFloat(YGNodeLayoutGetWidth(childNode))
                let height = CGFloat(YGNodeLayoutGetHeight(childNode))
                
                childView.frame = CGRect(x: left, y: top, width: width, height: height)
                
                // 递归处理孙子视图
                applyLayoutToChildren(of: childView, node: childNode)
            }
        }
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
        viewIdMap.removeAll()
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: - Private Methods
    
    private func createView(for node: LayoutNode) -> UIView {
        let view: UIView
        switch node.type {
        case .text:
            let label = UILabel()
            label.numberOfLines = 0
            view = label
            
        case .button:
            let button = UIButton(type: .system)
            view = button
            
        case .image:
            let imageView = UIImageView()
            imageView.contentMode = .scaleAspectFit
            view = imageView
            
        case .input:
            let textField = UITextField()
            textField.borderStyle = .roundedRect
            view = textField
            
        case .switch_:
            let switchControl = UISwitch()
            view = switchControl
            
        case .slider:
            let slider = UISlider()
            view = slider
            
        case .scrollView:
            let scrollView = UIScrollView()
            scrollView.isScrollEnabled = true
            scrollView.showsVerticalScrollIndicator = true
            scrollView.showsHorizontalScrollIndicator = false
            scrollView.alwaysBounceVertical = true
            view = scrollView
            
        case .refreshView, .loadMoreView, .template:
            // 返回空视图 (template 不应该走到这里，但作为防御)
            view = UIView()
            
        case .container, .view, .header, .footer, .content:
            view = UIView()
            
        case .custom:
            if let customType = node.customType {
                if let createdView = ComponentRegistry.shared.createView(tagName: customType) {
                    view = createdView
                } else {
                    print("⚠️ [Builder] 未找到自定义组件: \(node.customType ?? "unknown")，退化为 UIView")
                    view = UIView()
                }
            } else {
                print("⚠️ [Builder] 自定义组件类型为空，退化为 UIView")
                view = UIView()
            }
        }
        
        // 调用创建回调
        onViewCreated?(view)
        return view
    }
    
    private func randomColor() -> UIColor {
        let red = CGFloat.random(in: 0.8...1.0)
        let green = CGFloat.random(in: 0.8...1.0)
        let blue = CGFloat.random(in: 0.8...1.0)
        return UIColor(red: red, green: green, blue: blue, alpha: 0.5)
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
            if !(view is UILabel) && !(view is UIImageView) && !(view is PimeierComponent) {
                view.backgroundColor = randomColor()
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
        
        // Switch 样式
        if let switchControl = view as? UISwitch {
            // 确保 Switch 可以交互
            switchControl.isUserInteractionEnabled = true
            if let value = style.switchValue {
                switchControl.isOn = value
            }
            if let onTintColor = style.onTintColor {
                switchControl.onTintColor = onTintColor
            }
            if let thumbTintColor = style.thumbTintColor {
                switchControl.thumbTintColor = thumbTintColor
            }
        }
        
        // Slider 样式
        if let slider = view as? UISlider {
            // 确保 Slider 可以交互
            slider.isUserInteractionEnabled = true
            if let value = style.sliderValue {
                slider.value = value
            }
            if let minimumValue = style.minimumValue {
                slider.minimumValue = minimumValue
            }
            if let maximumValue = style.maximumValue {
                slider.maximumValue = maximumValue
            }
            if let minimumTrackTintColor = style.minimumTrackTintColor {
                slider.minimumTrackTintColor = minimumTrackTintColor
            }
            if let maximumTrackTintColor = style.maximumTrackTintColor {
                slider.maximumTrackTintColor = maximumTrackTintColor
            }
            if let thumbTintColor = style.thumbTintColorSlider {
                slider.thumbTintColor = thumbTintColor
            }
        }
        
        // 图片样式
        if let imageView = view as? UIImageView {
            // 优先处理 imageURL（网络图片）
            if let imageURLString = style.imageURL, !imageURLString.isEmpty, imageURLString != "undefined" {
                // 如果有 imageName 且不为空，作为占位图
                let placeholder = (style.imageName?.isEmpty == false && style.imageName != "undefined") ? style.imageName : nil
                loadImage(from: imageURLString, into: imageView, placeholder: placeholder)
            } else if let imageName = style.imageName, !imageName.isEmpty, imageName != "undefined" {
                // 本地图片
                imageView.image = UIImage(named: imageName)
            }
            if let contentMode = style.contentMode {
                imageView.contentMode = contentMode
            }
        }
        
        // 保存数据 ID
        if let dataId = style.dataId {
            view.accessibilityIdentifier = dataId
        }
    }
    
    // MARK: - Image Loading
    
    /// 加载图片（支持网络和本地）
    /// - Parameters:
    ///   - urlString: 图片 URL 字符串（网络）或图片名称（本地）
    ///   - imageView: 目标 UIImageView
    ///   - placeholder: 占位图名称（可选）
    private func loadImage(from urlString: String, into imageView: UIImageView, placeholder: String?) {
        // 设置占位图
        if let placeholderName = placeholder, !placeholderName.isEmpty {
            imageView.image = UIImage(named: placeholderName)
        }
        
        // 判断是网络 URL 还是本地图片名称
        if urlString.hasPrefix("http://") || urlString.hasPrefix("https://") {
            // 网络图片
            loadNetworkImage(from: urlString, into: imageView)
        } else {
            // 本地图片（如果 imageURL 不是 URL，则作为本地图片名称处理）
            imageView.image = UIImage(named: urlString)
        }
    }
    
    /// 加载网络图片
    /// - Parameters:
    ///   - urlString: 图片 URL
    ///   - imageView: 目标 UIImageView
    private func loadNetworkImage(from urlString: String, into imageView: UIImageView) {
        guard let url = URL(string: urlString) else {
            print("⚠️ [ImageLoader] 无效的图片 URL: \(urlString)")
            return
        }
        
        // 使用 URLSession 加载图片
        let task = URLSession.shared.dataTask(with: url) { [weak imageView] data, response, error in
            DispatchQueue.main.async {
                guard let imageView = imageView else { return }
                
                if let error = error {
                    print("❌ [ImageLoader] 加载图片失败: \(urlString), 错误: \(error.localizedDescription)")
                    // 可以在这里设置错误占位图
                    return
                }
                
                guard let data = data, let image = UIImage(data: data) else {
                    print("⚠️ [ImageLoader] 无法解析图片数据: \(urlString)")
                    return
                }
                
                imageView.image = image
                print("✅ [ImageLoader] 图片加载成功: \(urlString)")
            }
        }
        
        task.resume()
        
        // 保存 task 引用，防止在视图释放前被取消
        // 使用 Associated Object 存储 task
        objc_setAssociatedObject(imageView, &ImageTaskKey, task, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}

// MARK: - Associated Object Keys

private var ImageTaskKey: UInt8 = 0
