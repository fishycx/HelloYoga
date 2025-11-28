//
//  YogaInspector.swift
//  Pimeier
//
//  Created by AI Assistant
//

import UIKit
import YogaKit

/// Yoga 布局调试检查器
public class YogaInspector {
    
    /// 打印视图层级结构
    public static func printHierarchy(rootView: UIView) {
        print("\n🔍 ==================== Yoga 视图层级检查 ====================")
        printHierarchyRecursive(view: rootView, level: 0, prefix: "")
        print("==========================================================\n")
    }
    
    private static func printHierarchyRecursive(view: UIView, level: Int, prefix: String) {
        // 构建缩进
        let indent = String(repeating: "  ", count: level)
        let branch = level == 0 ? "" : "├─ "
        
        // 获取基本信息
        let className = String(describing: type(of: view))
        let frameStr = String(format: "(%.1f, %.1f, %.1f, %.1f)", 
                            view.frame.origin.x, 
                            view.frame.origin.y, 
                            view.frame.size.width, 
                            view.frame.size.height)
        
        // 获取 ID 和 Tag
        let idStr = view.accessibilityIdentifier.map { "id='\($0)'" } ?? ""
        let tagStr = view.tag != 0 ? "tag=\(view.tag)" : ""
        
        // 组合信息
        var info = "\(prefix)\(branch)📦 \(className) \(frameStr)"
        if !idStr.isEmpty { info += " \(idStr)" }
        if !tagStr.isEmpty { info += " \(tagStr)" }
        
        // 检查可见性
        if view.isHidden { info += " 🚫 [HIDDEN]" }
        if view.alpha < 0.01 { info += " 👻 [TRANSPARENT]" }
        if view.frame.size.width == 0 || view.frame.size.height == 0 { info += " ⚠️ [ZERO SIZE]" }
        
        print(info)
        
        // 递归打印子视图
        for (index, subview) in view.subviews.enumerated() {
            let isLast = index == view.subviews.count - 1
            let nextPrefix = prefix + (level == 0 ? "" : "│ ")
            printHierarchyRecursive(view: subview, level: level + 1, prefix: nextPrefix)
        }
    }
    
    /// 检查特定的 Yoga 节点信息（如果有对应的 YogaNodeBuilder）
    public static func inspectYogaNode(view: UIView, builder: YogaNodeBuilder?) {
        guard let builder = builder, let node = builder.viewNodeMap[view] else {
            print("⚠️ 该视图没有关联的 Yoga 节点")
            return
        }
        
        print("\n🧘 Yoga 节点信息 [\(view.accessibilityIdentifier ?? "无ID")]")
        print("----------------------------------------")
        
        // 布局结果
        print("Layout: x=\(YGNodeLayoutGetLeft(node)), y=\(YGNodeLayoutGetTop(node)), w=\(YGNodeLayoutGetWidth(node)), h=\(YGNodeLayoutGetHeight(node))")
        
        // Flex 属性
        let flexDirection = YGNodeStyleGetFlexDirection(node)
        print("FlexDirection: \(flexDirectionString(flexDirection))")
        
        let justify = YGNodeStyleGetJustifyContent(node)
        print("JustifyContent: \(justifyString(justify))")
        
        let align = YGNodeStyleGetAlignItems(node)
        print("AlignItems: \(alignString(align))")
        
        // 尺寸属性
        let width = YGNodeStyleGetWidth(node)
        print("Width: \(valueString(width))")
        
        let height = YGNodeStyleGetHeight(node)
        print("Height: \(valueString(height))")
        
        print("----------------------------------------\n")
    }
    
    /// 切换可视化调试层（显示边框和尺寸）
    public static func toggleVisualDebugger(rootView: UIView) {
        func toggleDebugOverlay(for view: UIView) {
            let debugTag = 9999
            
            if let existingOverlay = view.viewWithTag(debugTag) {
                existingOverlay.removeFromSuperview()
                view.layer.borderWidth = 0
            } else {
                view.layer.borderColor = UIColor.red.withAlphaComponent(0.5).cgColor
                view.layer.borderWidth = 1
                
                if view.bounds.width > 40 && view.bounds.height > 20 {
                    let label = UILabel()
                    label.tag = debugTag
                    label.text = "\(Int(view.bounds.width))x\(Int(view.bounds.height))"
                    label.font = .systemFont(ofSize: 8)
                    label.textColor = .red
                    label.backgroundColor = UIColor.white.withAlphaComponent(0.7)
                    label.frame = CGRect(x: 2, y: 2, width: 50, height: 10)
                    label.sizeToFit()
                    view.addSubview(label)
                }
            }
            
            for subview in view.subviews {
                toggleDebugOverlay(for: subview)
            }
        }
        
        toggleDebugOverlay(for: rootView)
    }
    
    // MARK: - Helper Methods
    
    private static func flexDirectionString(_ direction: YGFlexDirection) -> String {
        switch direction {
        case .column: return "Column"
        case .columnReverse: return "ColumnReverse"
        case .row: return "Row"
        case .rowReverse: return "RowReverse"
        @unknown default: return "Unknown"
        }
    }
    
    private static func justifyString(_ justify: YGJustify) -> String {
        switch justify {
        case .flexStart: return "FlexStart"
        case .center: return "Center"
        case .flexEnd: return "FlexEnd"
        case .spaceBetween: return "SpaceBetween"
        case .spaceAround: return "SpaceAround"
        case .spaceEvenly: return "SpaceEvenly"
        @unknown default: return "Unknown"
        }
    }
    
    private static func alignString(_ align: YGAlign) -> String {
        switch align {
        case .auto: return "Auto"
        case .flexStart: return "FlexStart"
        case .center: return "Center"
        case .flexEnd: return "FlexEnd"
        case .stretch: return "Stretch"
        case .baseline: return "Baseline"
        case .spaceBetween: return "SpaceBetween"
        case .spaceAround: return "SpaceAround"
        @unknown default: return "Unknown"
        }
    }
    
    private static func valueString(_ value: YGValue) -> String {
        switch value.unit {
        case .point: return "\(value.value)pt"
        case .percent: return "\(value.value)%"
        case .auto: return "Auto"
        case .undefined: return "Undefined"
        @unknown default: return "Unknown"
        }
    }
}
