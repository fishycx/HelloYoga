//
//  LayoutModels.swift
//  Pimeier
//
//  Created by AI Assistant
//

import UIKit
import YogaKit

// MARK: - 布局节点模型

/// XML 布局节点
public struct LayoutNode {
    public let type: NodeType
    public let attributes: [String: String]
    public var children: [LayoutNode]
    
    // 控制流指令
    public var ifCondition: String? = nil
    public var forLoop: String? = nil
    
    // 自定义组件类型 (当 type == .custom 时使用)
    public var customType: String? = nil
    
    public enum NodeType: String {
        case container
        case view
        case text
        case button
        case image
        case input
        case scrollView
        case header
        case footer
        case content
        case template // 模版定义节点
        case custom // 自定义组件
        
        // 新增 UI 组件
        case switch_ // Switch 开关（使用 switch_ 避免与 Swift 关键字冲突）
        case slider // Slider 滑块
        
        // 已废弃的类型，保留枚举 case 但不处理，或者直接移除
        case refreshView
        case loadMoreView
    }
    
    public init(type: NodeType, attributes: [String : String], children: [LayoutNode], ifCondition: String? = nil, forLoop: String? = nil, customType: String? = nil) {
        self.type = type
        self.attributes = attributes
        self.children = children
        self.ifCondition = ifCondition
        self.forLoop = forLoop
        self.customType = customType
    }
}

// MARK: - Yoga 样式属性

/// Yoga 布局属性
public struct YogaStyle {
    // Flex 属性
    public var flexDirection: YGDirection?
    // ... (Rest of Yoga properties mapped to YogaKit types if needed, or standard Yoga C types if using direct Yoga)
    // Using YogaKit types for consistency if possible, or raw YG enums.
    // The original file imported 'yoga', which is the C module.
    // Since we depend on YogaKit, we should check what it exposes.
    // YogaKit exposes YG* enums.
    
    public var flexDirectionVal: YGFlexDirection?
    public var justifyContent: YGJustify?
    public var alignItems: YGAlign?
    public var alignSelf: YGAlign?
    public var flexWrap: YGWrap?
    public var flex: Float?
    public var flexGrow: Float?
    public var flexShrink: Float?
    
    // 尺寸属性
    public var width: YGValue?
    public var height: YGValue?
    public var minWidth: YGValue?
    public var minHeight: YGValue?
    public var maxWidth: YGValue?
    public var maxHeight: YGValue?
    
    // 间距属性
    public var padding: YGValue?
    public var paddingTop: YGValue?
    public var paddingRight: YGValue?
    public var paddingBottom: YGValue?
    public var paddingLeft: YGValue?
    
    public var margin: YGValue?
    public var marginTop: YGValue?
    public var marginRight: YGValue?
    public var marginBottom: YGValue?
    public var marginLeft: YGValue?
    
    // 位置属性
    public var position: YGPositionType?
    public var top: YGValue?
    public var right: YGValue?
    public var bottom: YGValue?
    public var left: YGValue?
    
    // 其他属性
    public var aspectRatio: Float?
    
    // 从属性字典解析 Yoga 样式
    public static func from(attributes: [String: String]) -> YogaStyle {
        var style = YogaStyle()
        
        for (key, value) in attributes {
            switch key.lowercased() {
            // Flex Direction
            case "flexdirection":
                style.flexDirectionVal = parseFlexDirection(value)
            case "justifycontent":
                style.justifyContent = parseJustify(value)
            case "alignitems":
                style.alignItems = parseAlign(value)
            case "alignself":
                style.alignSelf = parseAlign(value)
            case "flexwrap":
                style.flexWrap = parseWrap(value)
            case "flex":
                style.flex = Float(value)
            case "flexgrow":
                style.flexGrow = Float(value)
            case "flexshrink":
                style.flexShrink = Float(value)
                
            // 尺寸
            case "width":
                style.width = parseValue(value)
            case "height":
                style.height = parseValue(value)
            case "minwidth":
                style.minWidth = parseValue(value)
            case "minheight":
                style.minHeight = parseValue(value)
            case "maxwidth":
                style.maxWidth = parseValue(value)
            case "maxheight":
                style.maxHeight = parseValue(value)
                
            // Padding
            case "padding":
                style.padding = parseValue(value)
            case "paddingtop":
                style.paddingTop = parseValue(value)
            case "paddingright":
                style.paddingRight = parseValue(value)
            case "paddingbottom":
                style.paddingBottom = parseValue(value)
            case "paddingleft":
                style.paddingLeft = parseValue(value)
                
            // Margin
            case "margin":
                style.margin = parseValue(value)
            case "margintop":
                style.marginTop = parseValue(value)
            case "marginright":
                style.marginRight = parseValue(value)
            case "marginbottom":
                style.marginBottom = parseValue(value)
            case "marginleft":
                style.marginLeft = parseValue(value)
                
            // Position
            case "position":
                style.position = parsePosition(value)
            case "top":
                style.top = parseValue(value)
            case "right":
                style.right = parseValue(value)
            case "bottom":
                style.bottom = parseValue(value)
            case "left":
                style.left = parseValue(value)
                
            // 其他
            case "aspectratio":
                style.aspectRatio = Float(value)
                
            default:
                break
            }
        }
        
        return style
    }
    
    // MARK: - 解析辅助方法
    
    private static func parseFlexDirection(_ value: String) -> YGFlexDirection {
        switch value.lowercased() {
        case "row": return YGFlexDirection.row
        case "rowreverse": return YGFlexDirection.rowReverse
        case "column": return YGFlexDirection.column
        case "columnreverse": return YGFlexDirection.columnReverse
        default: return YGFlexDirection.column
        }
    }
    
    private static func parseJustify(_ value: String) -> YGJustify {
        switch value.lowercased() {
        case "flexstart", "start": return YGJustify.flexStart
        case "center": return YGJustify.center
        case "flexend", "end": return YGJustify.flexEnd
        case "spacebetween": return YGJustify.spaceBetween
        case "spacearound": return YGJustify.spaceAround
        case "spaceevenly": return YGJustify.spaceEvenly
        default: return YGJustify.flexStart
        }
    }
    
    private static func parseAlign(_ value: String) -> YGAlign {
        switch value.lowercased() {
        case "auto": return YGAlign.auto
        case "flexstart", "start": return YGAlign.flexStart
        case "center": return YGAlign.center
        case "flexend", "end": return YGAlign.flexEnd
        case "stretch": return YGAlign.stretch
        case "baseline": return YGAlign.baseline
        case "spacebetween": return YGAlign.spaceBetween
        case "spacearound": return YGAlign.spaceAround
        default: return YGAlign.flexStart
        }
    }
    
    private static func parseWrap(_ value: String) -> YGWrap {
        switch value.lowercased() {
        case "nowrap": return YGWrap.noWrap
        case "wrap": return YGWrap.wrap
        case "wrapreverse": return YGWrap.wrapReverse
        default: return YGWrap.noWrap
        }
    }
    
    private static func parsePosition(_ value: String) -> YGPositionType {
        switch value.lowercased() {
        case "relative": return YGPositionType.relative
        case "absolute": return YGPositionType.absolute
        default: return YGPositionType.relative
        }
    }
    
    private static func parseValue(_ value: String) -> YGValue {
        var trimmed = value.trimmingCharacters(in: .whitespaces).lowercased()
        
        if trimmed == "auto" {
            return YGValue(value: .nan, unit: YGUnit.auto) // auto 值应该是 NaN
        }
        
        if trimmed.hasSuffix("%") {
            let numStr = trimmed.dropLast()
            if let num = Float(numStr) {
                return YGValue(value: num, unit: YGUnit.percent)
            }
        }
        
        // 移除常见的单位后缀
        if trimmed.hasSuffix("px") { trimmed = String(trimmed.dropLast(2)) }
        else if trimmed.hasSuffix("pt") { trimmed = String(trimmed.dropLast(2)) }
        else if trimmed.hasSuffix("dp") { trimmed = String(trimmed.dropLast(2)) }
        
        if let num = Float(trimmed) {
            return YGValue(value: num, unit: YGUnit.point)
        }
        
        return YGValue(value: .nan, unit: YGUnit.undefined)
    }
}

// MARK: - UI 样式属性

/// UI 视图样式属性（非 Yoga 属性）
public struct ViewStyle {
    public var backgroundColor: UIColor?
    public var cornerRadius: CGFloat?
    public var borderWidth: CGFloat?
    public var borderColor: UIColor?
    public var opacity: CGFloat?
    public var isHidden: Bool?
    
    // 文本属性
    public var text: String?
    public var textColor: UIColor?
    public var fontSize: CGFloat?
    public var fontWeight: UIFont.Weight?
    public var textAlignment: NSTextAlignment?
    public var numberOfLines: Int?
    
    // 按钮属性
    public var title: String?
    public var titleColor: UIColor?
    
    // 图片属性
    public var imageName: String?
    public var imageURL: String?
    public var contentMode: UIView.ContentMode?
    
    // 输入框属性
    public var placeholder: String?
    public var placeholderColor: UIColor?
    public var borderStyle: UITextField.BorderStyle?
    
    // Switch 属性
    public var switchValue: Bool?
    public var onTintColor: UIColor?
    public var thumbTintColor: UIColor?
    
    // Slider 属性
    public var sliderValue: Float?
    public var minimumValue: Float?
    public var maximumValue: Float?
    public var minimumTrackTintColor: UIColor?
    public var maximumTrackTintColor: UIColor?
    public var thumbTintColorSlider: UIColor? // 为 Slider 单独命名，避免与 Switch 冲突
    
    // 数据绑定 ID
    public var dataId: String?
    
    public static func from(attributes: [String: String]) -> ViewStyle {
        var style = ViewStyle()
        
        for (key, value) in attributes {
            switch key.lowercased() {
            case "backgroundcolor", "bgcolor":
                style.backgroundColor = parseColor(value)
            case "cornerradius":
                style.cornerRadius = CGFloat(Float(value) ?? 0)
            case "borderwidth":
                style.borderWidth = CGFloat(Float(value) ?? 0)
            case "bordercolor":
                style.borderColor = parseColor(value)
            case "opacity", "alpha":
                style.opacity = CGFloat(Float(value) ?? 1.0)
            case "hidden":
                style.isHidden = (value.lowercased() == "true")
                
            // 文本
            case "text":
                style.text = value
            case "textcolor", "color":
                style.textColor = parseColor(value)
            case "fontsize":
                style.fontSize = CGFloat(Float(value) ?? 16)
            case "fontweight":
                style.fontWeight = parseFontWeight(value)
            case "textalignment", "textalign":
                style.textAlignment = parseTextAlignment(value)
            case "numberoflines":
                style.numberOfLines = Int(value) ?? 0
                
            // 按钮
            case "title":
                style.title = value
            case "titlecolor":
                style.titleColor = parseColor(value)
                
            // 图片
            case "imagename", "image":
                style.imageName = value
            case "imageurl":
                style.imageURL = value
            case "contentmode":
                style.contentMode = parseContentMode(value)
                
            // 输入框
            case "placeholder":
                style.placeholder = value
            case "placeholdercolor":
                style.placeholderColor = parseColor(value)
            case "borderstyle":
                style.borderStyle = parseBorderStyle(value)
                
            // Switch 属性
            case "value":
                // value 可以是布尔值（Switch）或浮点数（Slider）
                if let boolValue = parseBool(value) {
                    style.switchValue = boolValue
                } else if let floatValue = Float(value) {
                    style.sliderValue = floatValue
                }
            case "ontintcolor":
                style.onTintColor = parseColor(value)
            case "thumbtintcolor":
                style.thumbTintColor = parseColor(value)
                
            // Slider 属性
            case "minimumvalue", "minvalue":
                style.minimumValue = Float(value)
            case "maximumvalue", "maxvalue":
                style.maximumValue = Float(value)
            case "minimumtracktintcolor":
                style.minimumTrackTintColor = parseColor(value)
            case "maximumtracktintcolor":
                style.maximumTrackTintColor = parseColor(value)
            case "thumbtintcolorslider":
                style.thumbTintColorSlider = parseColor(value)
                
            // 数据绑定
            case "id", "dataid":
                style.dataId = value
                
            default:
                break
            }
        }
        
        return style
    }
    
    // MARK: - 解析辅助方法
    
    private static func parseColor(_ value: String) -> UIColor {
        let trimmed = value.trimmingCharacters(in: .whitespaces).lowercased()
        
        // 预定义颜色
        switch trimmed {
        case "clear": return .clear
        case "black": return .black
        case "white": return .white
        case "red": return .red
        case "green": return .green
        case "blue": return .blue
        case "yellow": return .yellow
        case "orange": return .orange
        case "purple": return .purple
        case "gray": return .gray
        case "lightgray": return .lightGray
        case "darkgray": return .darkGray
        case "systemblue": return .systemBlue
        case "systemgreen": return .systemGreen
        case "systemred": return .systemRed
        case "systemorange": return .systemOrange
        case "systempurple": return .systemPurple
        case "systemgray": return .systemGray
        case "systemgray6": return .systemGray6
        case "systembackground": return .systemBackground
        case "label": return .label
        default:
            break
        }
        
        // 十六进制颜色 (#RRGGBB 或 #RRGGBBAA)
        if trimmed.hasPrefix("#") {
            let hex = String(trimmed.dropFirst())
            var rgb: UInt64 = 0
            Scanner(string: hex).scanHexInt64(&rgb)
            
            let length = hex.count
            let r, g, b, a: CGFloat
            
            if length == 6 {
                r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
                g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
                b = CGFloat(rgb & 0x0000FF) / 255.0
                a = 1.0
            } else if length == 8 {
                r = CGFloat((rgb & 0xFF000000) >> 24) / 255.0
                g = CGFloat((rgb & 0x00FF0000) >> 16) / 255.0
                b = CGFloat((rgb & 0x0000FF00) >> 8) / 255.0
                a = CGFloat(rgb & 0x000000FF) / 255.0
            } else {
                return .black
            }
            
            return UIColor(red: r, green: g, blue: b, alpha: a)
        }
        
        return .black
    }
    
    private static func parseFontWeight(_ value: String) -> UIFont.Weight {
        switch value.lowercased() {
        case "ultralight": return .ultraLight
        case "thin": return .thin
        case "light": return .light
        case "regular": return .regular
        case "medium": return .medium
        case "semibold": return .semibold
        case "bold": return .bold
        case "heavy": return .heavy
        case "black": return .black
        default: return .regular
        }
    }
    
    private static func parseTextAlignment(_ value: String) -> NSTextAlignment {
        switch value.lowercased() {
        case "left": return .left
        case "center": return .center
        case "right": return .right
        case "justified": return .justified
        case "natural": return .natural
        default: return .left
        }
    }
    
    private static func parseContentMode(_ value: String) -> UIView.ContentMode {
        switch value.lowercased() {
        case "scaletofill": return .scaleToFill
        case "scaleaspectfit": return .scaleAspectFit
        case "scaleaspectfill": return .scaleAspectFill
        case "center": return .center
        case "top": return .top
        case "bottom": return .bottom
        case "left": return .left
        case "right": return .right
        default: return .scaleAspectFit
        }
    }
    
    private static func parseBorderStyle(_ value: String) -> UITextField.BorderStyle {
        switch value.lowercased() {
        case "none": return .none
        case "line": return .line
        case "bezel": return .bezel
        case "roundedrect", "rounded": return .roundedRect
        default: return .roundedRect
        }
    }
    
    private static func parseBool(_ value: String) -> Bool? {
        let lowercased = value.lowercased()
        switch lowercased {
        case "true", "1", "yes", "on": return true
        case "false", "0", "no", "off": return false
        default: return nil
        }
    }
}

// MARK: - ScrollView 刷新配置 (已废弃)
// public struct ScrollViewRefreshConfig { ... }

