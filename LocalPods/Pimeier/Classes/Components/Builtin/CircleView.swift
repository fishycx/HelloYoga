//
//  CircleView.swift
//  HelloYoga
//
//  Created by AI Assistant
//

import UIKit

/// 演示用自定义组件：圆形视图
/// 可以在 XML 中使用 <circle color="red" />
/// 实现方式：使用 Core Graphics 绘制
public class CircleView: UIView, PimeierComponent {
    
    private var circleColor: UIColor = .red
    
    public required init() {
        // 初始化时 Frame 为 0 是正常的，Yoga 布局引擎稍后会计算并设置正确的 Frame
        super.init(frame: .zero)
        print("🎨 [CircleView] init")
        
        // 背景透明，由 draw 方法绘制圆形
        self.backgroundColor = .clear
        self.isOpaque = false
        
        // 关键：设置为 .redraw，确保当 Frame 发生变化（Yoga 布局更新）时，系统自动调用 draw(_:) 重绘
        self.contentMode = .redraw
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func applyAttributes(_ attributes: [String : String]) {
        // 解析自定义属性 color
        if let colorStr = attributes["color"] {
            self.circleColor = parseColor(colorStr)
            self.setNeedsDisplay()
        }
    }
    
    public override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        // 填充颜色
        context.setFillColor(circleColor.cgColor)
        
        // 绘制椭圆
        // 使用 self.bounds 确保在整个视图区域内绘制
        // rect 参数可能是局部重绘区域，不一定是完整的 bounds
        context.fillEllipse(in: self.bounds)
        
        // print("🎨 [CircleView] Drawing in bounds: \(self.bounds)")
    }
    
    // 辅助方法：解析颜色 (简单实现)
    private func parseColor(_ value: String) -> UIColor {
        switch value.lowercased() {
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "yellow": return .yellow
        case "orange": return .orange
        case "purple": return .purple
        case "black": return .black
        case "white": return .white
        case "gray": return .gray
        case "clear": return .clear
        default: return .red
        }
    }
}
