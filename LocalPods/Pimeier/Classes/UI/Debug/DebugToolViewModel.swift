//
//  DebugToolViewModel.swift
//  Pimeier
//
//  Created by AI Assistant
//

import UIKit

public enum DebugSectionType {
    case server
    case files
    case templates
    case debug
    case settings
    
    var title: String {
        switch self {
        case .server: return "服务器连接"
        case .files: return "文件操作"
        case .templates: return "Pimeier 模版"
        case .debug: return "调试功能"
        case .settings: return "设置"
        }
    }
}

public struct DebugRowItem {
    let title: String
    var detail: String? = nil
    var detailColor: UIColor? = nil
    var isSwitch: Bool = false
    var isSwitchOn: Bool = false
    var switchAction: ((Bool) -> Void)? = nil
    var action: (() -> Void)? = nil
}

public struct DebugSection {
    let type: DebugSectionType
    var items: [DebugRowItem]
}

public class DebugToolViewModel {
    
    public var sections: [DebugSection] = []
    
    // 状态回调
    public var onHotReloadChanged: ((Bool) -> Void)?
    public var onPollingModeChanged: ((Bool) -> Void)?
    public var onTemplateSelected: ((String) -> Void)?
    public var onOpenTodoDemo: (() -> Void)?
    public var onResetTemplates: (() -> Void)?
    
    // 当前状态
    public var isHotReloadEnabled: Bool = true
    public var usePollingMode: Bool = true
    
    // Actions from Controller
    public var showQRScanner: (() -> Void)?
    public var showManualInput: (() -> Void)?
    public var checkServer: (() -> Void)?
    public var reloadLayout: (() -> Void)?
    public var reloadFromServer: (() -> Void)?
    public var clearCache: (() -> Void)?
    public var showViewHierarchy: (() -> Void)?
    public var showVersionInfo: (() -> Void)?
    
    public init() {}
    
    public func loadData() {
        // 获取当前模版
        let currentTemplateId = TemplateManager.shared.currentTemplateID
        
        sections = [
            DebugSection(type: .server, items: [
                DebugRowItem(
                    title: "📷 扫描二维码",
                    detail: LocalDevServer.shared.isEnabled ? LocalDevServer.shared.baseURL : "未连接",
                    detailColor: LocalDevServer.shared.isEnabled ? .systemGreen : .systemGray,
                    action: { [weak self] in self?.showQRScanner?() }
                ),
                DebugRowItem(
                    title: "🌐 手动输入地址",
                    detail: LocalDevServer.shared.baseURL.isEmpty ? "未设置" : LocalDevServer.shared.baseURL,
                    detailColor: LocalDevServer.shared.baseURL.isEmpty ? .systemGray : .systemBlue,
                    action: { [weak self] in self?.showManualInput?() }
                ),
                DebugRowItem(
                    title: "🔍 检查服务器",
                    action: { [weak self] in self?.checkServer?() }
                )
            ]),
            DebugSection(type: .files, items: [
                DebugRowItem(
                    title: "🔄 重新加载布局",
                    action: { [weak self] in self?.reloadLayout?() }
                ),
                DebugRowItem(
                    title: "📥 从服务器刷新",
                    action: { [weak self] in self?.reloadFromServer?() }
                ),
                DebugRowItem(
                    title: "🗑️ 清除缓存",
                    action: { [weak self] in self?.clearCache?() }
                )
            ]),
            DebugSection(type: .templates, items: [
                DebugRowItem(
                    title: "选择模版",
                    detail: currentTemplateId,
                    action: { [weak self] in self?.showTemplateSelector() }
                ),
                DebugRowItem(
                    title: "📋 打开 TODO Demo",
                    detail: "Native Logic Demo",
                    action: { [weak self] in self?.onOpenTodoDemo?() }
                ),
                DebugRowItem(
                    title: "🛠️ 修复模版",
                    detail: "重置 todo_list",
                    action: { [weak self] in self?.onResetTemplates?() }
                )
            ]),
            DebugSection(type: .debug, items: [
                DebugRowItem(
                    title: "🔍 视图层级",
                    action: { [weak self] in self?.showViewHierarchy?() }
                ),
                DebugRowItem(
                    title: "📊 版本信息",
                    action: { [weak self] in self?.showVersionInfo?() }
                )
            ]),
            DebugSection(type: .settings, items: [
                DebugRowItem(
                    title: "热重载 (远程轮询)",
                    isSwitch: true,
                    isSwitchOn: isHotReloadEnabled,
                    switchAction: { [weak self] isOn in
                        self?.isHotReloadEnabled = isOn
                        self?.onHotReloadChanged?(isOn)
                    }
                ),
                DebugRowItem(
                    title: "本地监听 (Mac模拟器)",
                    isSwitch: true,
                    isSwitchOn: usePollingMode,
                    switchAction: { [weak self] isOn in
                        self?.usePollingMode = isOn
                        self?.onPollingModeChanged?(isOn)
                    }
                )
            ])
        ]
    }
    
    private func showTemplateSelector() {
        // 这里只是个占位，实际逻辑在 Controller 中通过 onTemplateSelected 实现
        // 但为了让 Controller 知道要显示选择器，我们可以在这里不做任何事，
        // 或者更好的方式是：Controller 监听某个闭包来弹出 ActionSheet
        
        // 由于架构原因，Controller 直接处理了 selection，这里我们只负责数据源。
        // 实际上，点击 "选择模版" 会触发 item.action，Controller 会执行它。
        // 为了简单起见，我们在 Controller 中实现 showTemplateSelectorAction，
        // 并在 loadData 时将该 action 绑定给 item。
        
        // 修改：DebugRowItem 的 action 在 Controller 中被调用
        // Controller 需要实现 showTemplateSelector
        
        onTemplateSelected?("")
    }
}
