//
//  PimeierRenderer.swift
//  Pimeier
//
//  Created by AI Assistant
//

import Foundation
import UIKit
import JavaScriptCore
import YogaKit

/// Pimeier 渲染引擎 (Level 2)
/// 负责执行数据驱动的渲染，解析模版指令 (if/for) 和表达式 ({{ }})
public class PimeierRenderer {
    
    // MARK: - Properties
    
    private let jsEngine: PimeierJSEngine
    private var yogaBuilder: YogaNodeBuilder?
    
    // MARK: - Initialization
    
    public init(jsEngine: PimeierJSEngine) {
        self.jsEngine = jsEngine
    }
    
    // MARK: - Rendering
    
    /// 渲染根节点
    /// - Parameters:
    ///   - layoutNode: 模版根节点
    ///   - container: 容器视图 (如果提供了，将直接挂载到容器；否则只返回根视图)
    ///   - parentContext: 父级数据上下文 (可选)
    /// - Returns: 生成的根视图
    public func render(node layoutNode: LayoutNode, in container: UIView? = nil, with context: JSValue? = nil) -> UIView? {
        // 1. 如果提供了容器，说明是全量重绘，我们需要先清理旧的 Yoga 上下文
        if let container = container {
            // 清理容器中的旧视图
            container.subviews.forEach { $0.removeFromSuperview() }
            
            // 清理旧的 Yoga 节点
            // 注意：必须在 buildNode 之前清理，否则会把新构建的节点也清理掉
            yogaBuilder?.cleanup()
            yogaBuilder = nil // 彻底重置
        }
        
        // 2. 初始化 Yoga 构建器
        if yogaBuilder == nil {
            yogaBuilder = YogaNodeBuilder()
        }
        
        // 3. 递归构建
        // 根节点的 context 默认为全局 ViewModel
        let effectiveContext = context ?? jsEngine.getViewModel()
        
        // 注意：buildNode 返回的是节点列表
        let views = buildNode(layoutNode, context: effectiveContext)
        
        guard let rootView = views.first else { return nil }
        
        // 4. 如果提供了容器，添加到容器
        if let container = container {
            // 重新添加
            container.addSubview(rootView)
            
            // 计算布局
            yogaBuilder?.calculateLayout(
                for: rootView,
                width: container.bounds.width,
                height: container.bounds.height
            )
        }
        
        return rootView
    }
    
    /// 清理资源
    public func cleanup() {
        yogaBuilder?.cleanup()
        yogaBuilder = nil
    }
    
    /// 获取内部构建器 (用于布局计算)
    public func getBuilder() -> YogaNodeBuilder? {
        return yogaBuilder
    }
    
    // MARK: - Recursive Build
    
    /// 递归构建节点
    /// - Parameters:
    ///   - node: 布局节点模版
    ///   - context: 当前数据上下文
    /// - Returns: 生成的视图列表 (因为 for 循环可能生成多个)
    private func buildNode(_ node: LayoutNode, context: JSValue?) -> [UIView] {
        
        // 1. 处理 if 指令
        if let condition = node.ifCondition {
            let result = evaluateExpression(condition, context: context)
            // 如果结果为 false/undefined/null/0，则不渲染
            if result?.toBool() == false {
                return []
            }
        }
        
        // 2. 处理 for 指令 (格式: item in list)
        if let forLoop = node.forLoop {
            return buildForLoop(node, loopExpression: forLoop, context: context)
        }
        
        // 3. 普通节点渲染
        
        // 3.1 解析属性中的表达式 {{ ... }}
        var resolvedAttributes = node.attributes
        for (key, value) in node.attributes {
            resolvedAttributes[key] = resolveString(value, context: context)
        }
        
        // 3.2 创建视图
        // 我们需要临时创建一个 Resolve 后的 LayoutNode
        // 注意：这里只是为了传递给 YogaNodeBuilder，children 此时是空的，稍后递归填充
        let resolvedNode = LayoutNode(
            type: node.type,
            attributes: resolvedAttributes,
            children: [], // 暂时为空
            ifCondition: nil,
            forLoop: nil,
            customType: node.customType
        )
        
        // 使用 YogaNodeBuilder 创建视图和 Yoga 节点
        // 注意：我们需要稍微修改 YogaNodeBuilder 的 buildViewTree 逻辑
        // 或者我们分步调用：createView -> createYogaNode -> processChildren
        // 目前 buildViewTree 是递归的，这不符合我们的需求（因为我们需要介入子节点的创建过程）
        
        // 临时解决方案：我们扩展 YogaNodeBuilder，提供 createSingleView 接口
        // 或者我们在这里手动调用 builder 的内部方法（如果可见）
        
        // 为了不破坏 YogaNodeBuilder 的封装，我们让它构建一个"只有一层"的树
        // 然后我们自己处理 children 的添加
        
        guard let view = yogaBuilder?.buildViewTree(from: resolvedNode) else { return [] }
        
        // 3.3 绑定事件
        // 注意：我们传递原始 attributes (node.attributes) 用于检查是否是表达式绑定
        // 而传递 resolvedAttributes 用于普通的属性读取
        bindEvents(for: view, attributes: resolvedAttributes, originalAttributes: node.attributes, context: context)
        
        // 3.4 递归处理子节点
        for childNode in node.children {
            let childViews = buildNode(childNode, context: context)
            
            for childView in childViews {
                // 使用 YogaNodeBuilder 的 attachChild 挂载子节点
                yogaBuilder?.attachChild(childView, to: view)
            }
        }
        
        return [view]
    }
    
    /// 处理 for 循环
    private func buildForLoop(_ node: LayoutNode, loopExpression: String, context: JSValue?) -> [UIView] {
        // 解析 "item in list"
        let components = loopExpression.components(separatedBy: " in ")
        guard components.count == 2 else {
            print("❌ [Renderer] 无效的 for 格式: \(loopExpression)")
            return []
        }
        
        let itemName = components[0].trimmingCharacters(in: .whitespaces)
        let listPath = components[1].trimmingCharacters(in: .whitespaces)
        
        // 获取列表数据
        guard let list = evaluateExpression(listPath, context: context),
              list.isArray else {
            print("⚠️ [Renderer] for 循环数据无效或为空: \(listPath)")
            return []
        }
        
        var views: [UIView] = []
        let count = Int(list.objectForKeyedSubscript("length").toInt32())
        
        for i in 0..<count {
            let itemData = list.atIndex(i)
            
            // 创建新的 Context
            // JSValue 并没有直接的 "创建子作用域" 的概念
            // 我们需要构建一个新的对象，包含 itemData 和父级 context
            // 但 JSContext 很难高效实现原型链继承的临时对象
            
            // 简单方案：我们将 itemData 注入到全局或者传递给 evaluate
            // 但为了支持嵌套，我们需要一个能够解析 "item" 的机制
            
            // 改进方案：我们的 evaluateExpression 函数应该支持查找变量
            // 我们可以构造一个临时的 JS 对象作为 Scope
            
            // 创建 Scope 对象: { [itemName]: itemData, ...parentContext }
            // 但这样性能较差。
            
            // 替代方案：我们直接在 context 对象上挂载数据？不行，会污染。
            
            // 正确做法：创建一个新的 JS 对象，原型指向 context (如果是对象)，或者合并
            // 这里简化处理：我们假设 context 就是当前的数据对象
            // 我们创建一个新的 Wrapper 对象
            let scope = JSValue(newObjectIn: context?.context)
            scope?.setValue(itemData, forProperty: itemName)
            scope?.setValue(NSNumber(value: i), forProperty: "index")
            
            // 将父级属性也拷贝进去 (浅拷贝，支持简单层级)
            // 在真实 JS 引擎中，应该使用 Object.create(parent)
            // scope = context.evaluateScript("Object.create(parent)")
            // scope.item = itemData
            
            if let parent = context, !parent.isUndefined {
                 // 这种 JS 注入比较 hacky 但有效
                 // let createScope = context?.context.evaluateScript("(function(parent) { return Object.create(parent); })")
                 // let newScope = createScope?.call(withArguments: [parent])
                 // newScope?.setValue(itemData, forProperty: itemName)
                 // ...
                 
                 // 简单起见，我们只把 itemData 传下去，
                 // 如果表达式里用了 parent 的变量，目前只支持通过全局 ViewModel 访问
                 // 或者我们的 evaluateExpression 支持多级查找
            }
            
            // 暂时使用 scope 作为新 context
            // 递归调用 buildNode (注意要去掉 forLoop 属性，防止死循环)
            var nodeWithoutFor = node
            nodeWithoutFor.forLoop = nil
            
            let childViews = buildNode(nodeWithoutFor, context: scope)
            views.append(contentsOf: childViews)
        }
        
        return views
    }
    
    // MARK: - Expression Evaluation
    
    /// 解析字符串中的表达式 {{ ... }}
    private func resolveString(_ raw: String, context: JSValue?) -> String {
        var result = raw
        let pattern = "\\{\\{(.+?)\\}\\}" // 匹配 {{ ... }}
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return raw }
        
        let matches = regex.matches(in: raw, options: [], range: NSRange(location: 0, length: raw.utf16.count))
        
        // 倒序替换，保持 range 有效
        for match in matches.reversed() {
            if let range = Range(match.range(at: 1), in: raw) {
                let expression = String(raw[range]).trimmingCharacters(in: .whitespaces)
                let value = evaluateExpression(expression, context: context)
                
                let replacement = value?.toString() ?? ""
                
                if let fullRange = Range(match.range, in: raw) {
                    result.replaceSubrange(fullRange, with: replacement)
                }
            }
        }
        
        return result
    }
    
    /// 执行 JS 表达式
    private func evaluateExpression(_ expression: String, context: JSValue?) -> JSValue? {
        // 增加日志追踪
        // print("📝 [Renderer] Try evaluate: \(expression)")
        
        // 1. 尝试在局部 Context 执行 (如果存在)
        if let context = context, !context.isUndefined {
            // 使用 Function + with 语法在指定 scope 下执行
            let script = "(function(scope) { with(scope) { return (\(expression)); } })"
            if let function = context.context.evaluateScript(script) {
                let result = function.call(withArguments: [context])
                
                // 检查是否有异常发生
                if let exception = context.context.exception, !exception.isUndefined {
                    // 发生了异常（例如 ReferenceError），清除异常并尝试全局执行
                    // print("⚠️ 局部执行异常: \(exception), 尝试全局执行")
                    context.context.exception = nil // 清除异常
                } else {
                    // 执行成功（包括返回 undefined），直接返回
                    return result
                }
            }
        }
        
        // 2. 如果没有 context 或 局部执行失败(虽然 with 应该涵盖了 global)，
        // 显式回退到 Global 执行（作为兜底）
        // 注意：如果上面的 call 返回了 undefined，并不代表出错，可能表达式结果就是 undefined。
        // 但如果上面的逻辑没有覆盖到，我们这里直接在 global 执行。
        
        return jsEngine.evaluate(expression)
    }
    
    // MARK: - Event Binding
    
    private func bindEvents(for view: UIView, attributes: [String: String], originalAttributes: [String: String], context: JSValue?) {
        // 打印所有属性，确认 onClick 是否存在
        // print("🔍 [Renderer] Attributes for \(view): \(attributes.keys)")
        
        // 1. 处理 onClick
        // 注意：XML 解析器会将属性名转为小写，所以我们要检查 onclick
        // 但我们在 LayoutModels 中可能没有规范化 key，所以这里做双重检查
        // 实际上 XMLLayoutParser.parser didStartElement 会原样保留 attributes 的 key 大小写吗？
        // XMLParser 的 attributeDict 通常保留原样。
        // 让我们宽容一点，检查 keys
        
        var onClickScript: String?
        for (key, value) in attributes {
            if key.lowercased() == "onclick" {
                onClickScript = value
                break
            }
        }
        
        if let onClick = onClickScript {
            // 开启交互
            view.isUserInteractionEnabled = true
            
            // 使用闭包捕获上下文
            let action = { [weak self] in
                // print("⚡️ [Renderer] 触发事件: \(onClick)")
                
                // 执行 JS 表达式
                _ = self?.evaluateExpression(onClick, context: context)
            }
            
            let wrapper = ActionWrapper(action: action)
            objc_setAssociatedObject(view, &ActionWrapper.associatedKey, wrapper, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            
            if let button = view as? UIButton {
                // 移除所有旧的 target（对于 touchUpInside）以防重复
                // 恢复 removeTarget，防止多次绑定导致事件触发两次
                button.removeTarget(nil, action: nil, for: .touchUpInside)
                
                button.addTarget(wrapper, action: #selector(ActionWrapper.invoke), for: .touchUpInside)
                // print("✅ [Renderer] Button bound: \(onClick)")
            } else {
                // TapGesture
                let tap = UITapGestureRecognizer(target: wrapper, action: #selector(ActionWrapper.invoke))
                view.addGestureRecognizer(tap)
                // print("✅ [Renderer] View bound tap: \(onClick)")
            }
        }
        
        // 2. 处理 UITextField 输入绑定 (双向绑定 Lite)
        // 如果 text 属性是表达式 {{ viewModel.inputText }}，我们需要把输入同步回去
        // 注意：必须检查 originalAttributes，因为 attributes 里的值已经被替换了
        if let textField = view as? UITextField, let textAttr = originalAttributes["text"] {
            // 检查是否是表达式: {{ variable }}
            let pattern = "^\\{\\{(.+?)\\}\\}$"
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: textAttr, options: [], range: NSRange(location: 0, length: textAttr.utf16.count)),
               let range = Range(match.range(at: 1), in: textAttr) {
                
                let expression = String(textAttr[range]).trimmingCharacters(in: .whitespaces)
                // print("🔗 [Renderer] Detected binding: \(expression)")
                
                // 创建 TextChangeWrapper
                let wrapper = TextChangeWrapper { [weak self] newText in
                    // print("🔤 [Renderer] Input changed: \(newText)")
                    // 构造 JS: variable = "newText"
                    // 注意：这里假设 expression 是一个可赋值的路径，如 viewModel.inputText
                    // 我们需要转义 newText
                    let escapedText = newText.replacingOccurrences(of: "\"", with: "\\\"")
                    let script = "\(expression) = \"\(escapedText)\""
                    // print("📝 [Renderer] Sync to JS: \(script)")
                    _ = self?.evaluateExpression(script, context: context)
                }
                
                objc_setAssociatedObject(textField, &TextChangeWrapper.associatedKey, wrapper, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                textField.addTarget(wrapper, action: #selector(TextChangeWrapper.textChanged(_:)), for: .editingChanged)
            }
        }
        
        // 3. 处理 ScrollView 的刷新回调
        if let scrollView = view as? UIScrollView {
            // 下拉刷新 onRefresh
            var onRefreshScript: String?
            for (key, value) in attributes {
                if key.lowercased() == "onrefresh" {
                    onRefreshScript = value
                    break
                }
            }
            
            if let onRefresh = onRefreshScript,
               let refreshControl = yogaBuilder?.getRefreshControl(for: scrollView) {
                
                refreshControl.onRefresh = { [weak self] in
                    // print("🔄 [Renderer] 触发下拉刷新: \(onRefresh)")
                    _ = self?.evaluateExpression(onRefresh, context: context)
                    
                    // 模拟网络延迟后结束刷新 (后续应通过 Bridge 由 JS 控制)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        refreshControl.endRefreshing()
                    }
                }
            }
            
            // 上拉加载 onLoadMore
            var onLoadMoreScript: String?
            for (key, value) in attributes {
                if key.lowercased() == "onloadmore" {
                    onLoadMoreScript = value
                    break
                }
            }
            
            if let onLoadMore = onLoadMoreScript,
               let loadMoreControl = yogaBuilder?.getLoadMoreControl(for: scrollView) {
                
                loadMoreControl.onLoadMore = { [weak self] in
                    // print("📥 [Renderer] 触发加载更多: \(onLoadMore)")
                    _ = self?.evaluateExpression(onLoadMore, context: context)
                    
                    // 模拟网络延迟后结束加载 (后续应通过 Bridge 由 JS 控制)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        loadMoreControl.endLoading(hasMore: true)
                    }
                }
            }
        }
    }
}

// 简单的 Action 包装器
class ActionWrapper: NSObject {
    static var associatedKey = "ActionWrapperKey"
    let action: () -> Void
    
    init(action: @escaping () -> Void) {
        self.action = action
        super.init()
        // print("➕ ActionWrapper created")
    }
    
    deinit {
        // print("➖ ActionWrapper deallocated")
    }
    
    @objc func invoke() {
        action()
    }
}

// 文本变更包装器
class TextChangeWrapper: NSObject {
    static var associatedKey = "TextChangeWrapperKey"
    let callback: (String) -> Void
    
    init(callback: @escaping (String) -> Void) {
        self.callback = callback
    }
    
    @objc func textChanged(_ sender: UITextField) {
        callback(sender.text ?? "")
    }
}
