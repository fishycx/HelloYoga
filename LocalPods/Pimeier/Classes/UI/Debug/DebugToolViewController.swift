//
//  DebugToolViewController.swift
//  Pimeier
//
//  Created by AI Assistant
//

import UIKit
import AVFoundation

/// 调试工具页面
public class DebugToolViewController: UIViewController {
    
    // MARK: - Properties
    
    private let viewModel = DebugToolViewModel()
    private var qrScanner: QRCodeScanner?
    private let fileWatcher = FileWatcher()
    
    // 当前布局信息 (这里 xmlFile 和 jsonFile 实际上存的是 templateID)
    public var currentLayoutInfo: (xmlFile: String, jsonFile: String, name: String)?
    public var onReloadLayout: (() -> Void)?
    public var onScanQRCode: ((String) -> Void)?
    
    // MARK: - UI Components
    
    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.delegate = self
        tv.dataSource = self
        tv.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        return tv
    }()
    
    // MARK: - Lifecycle
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "调试工具"
        view.backgroundColor = .systemGroupedBackground
        
        setupNavigationBar()
        setupTableView()
        setupViewModel()
        
        // 启动文件监听
        print("🔍 [DebugTool] 尝试启动监听...")
        print("   - LayoutInfo: \(currentLayoutInfo != nil ? "YES" : "NO")")
        print("   - HotReload: \(viewModel.isHotReloadEnabled)")
        print("   - ServerEnabled: \(LocalDevServer.shared.isEnabled)")
        print("   - ServerURL: \(LocalDevServer.shared.baseURL)")
        
        if viewModel.isHotReloadEnabled, let layoutInfo = currentLayoutInfo {
            startFileWatching(templateID: layoutInfo.xmlFile)
        }
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // 注意：这里不要停止监听，因为我们需要在调试页面关闭后继续监听文件变化以刷新页面
        // fileWatcher.stopWatching()
    }
    
    // MARK: - Setup
    
    private func setupNavigationBar() {
        // 使用自定义按钮避免约束冲突
        let doneButton = UIButton(type: .system)
        doneButton.setTitle("完成", for: .normal)
        doneButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .medium)
        doneButton.addTarget(self, action: #selector(dismissSelf), for: .touchUpInside)
        doneButton.sizeToFit()
        
        // 确保按钮有最小宽度，避免约束冲突
        let buttonWidth = max(doneButton.bounds.width, 60)
        doneButton.frame = CGRect(x: 0, y: 0, width: buttonWidth, height: 44)
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: doneButton)
    }
    
    private func setupTableView() {
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupViewModel() {
        // 绑定 Actions
        viewModel.showQRScanner = { [weak self] in self?.showQRScannerAction() }
        viewModel.showManualInput = { [weak self] in self?.showManualInputAction() }
        viewModel.checkServer = { [weak self] in self?.checkServerAction() }
        viewModel.reloadLayout = { [weak self] in self?.reloadLayoutAction() }
        viewModel.reloadFromServer = { [weak self] in self?.reloadFromServerAction() }
        viewModel.clearCache = { [weak self] in self?.clearCacheAction() }
        viewModel.showViewHierarchy = { [weak self] in self?.showViewHierarchyAction() }
        viewModel.showVersionInfo = { [weak self] in self?.showVersionInfoAction() }
        
        // 绑定模版相关 Actions
        viewModel.onTemplateSelected = { [weak self] templateId in
            self?.showTemplateSelectorAction()
        }
        
        viewModel.onOpenTodoDemo = { [weak self] in
            self?.openTodoDemoAction()
        }
        
        viewModel.onResetTemplates = { [weak self] in
            self?.resetTemplatesAction()
        }
        
        // 绑定状态变更
        viewModel.onHotReloadChanged = { [weak self] isEnabled in
            guard let self = self else { return }
            if isEnabled, let layoutInfo = self.currentLayoutInfo {
                self.startFileWatching(templateID: layoutInfo.xmlFile)
            } else {
                self.fileWatcher.stopWatching()
            }
        }
        
        viewModel.onPollingModeChanged = { [weak self] isEnabled in
            guard let self = self else { return }
            if self.viewModel.isHotReloadEnabled, let layoutInfo = self.currentLayoutInfo {
                self.startFileWatching(templateID: layoutInfo.xmlFile)
            }
        }
        
        // 加载数据
        viewModel.loadData()
        tableView.reloadData()
    }
    
    @objc private func dismissSelf() {
        dismiss(animated: true)
    }
    
    // MARK: - File Watching
    
    private func startFileWatching(templateID: String) {
        // 构造文件路径 (相对于 Server Root 或 Cache Root)
        // 路径格式: pimeierPages/{id}/{id}_{type}.{ext}
        let layoutName = "\(templateID)_layout.xml"
        let dataName = "\(templateID)_data.json"
        let logicName = "\(templateID)_logic.js"
        
        let filesToWatch = [
            "pimeierPages/\(templateID)/\(layoutName)",
            "pimeierPages/\(templateID)/\(dataName)",
            "pimeierPages/\(templateID)/\(logicName)"
        ]
        
        // 如果启用本地服务器，使用远程轮询
        if LocalDevServer.shared.isEnabled && viewModel.isHotReloadEnabled {
            print("📡 启用远程热重载: \(filesToWatch)")
            LocalDevServer.shared.startPolling(files: filesToWatch)
            fileWatcher.stopWatching() // 停止本地监听以避免冲突
        } else {
            // 否则使用本地文件监听 (模拟器/Mac调试用)
            print("👀 本地文件监听 (仅支持部分环境): \(filesToWatch)")
            LocalDevServer.shared.stopPolling()
        }
        
        // 监听通知 (无论是本地还是远程，都发这个通知)
        NotificationCenter.default.removeObserver(self, name: FileWatcher.fileChangedNotification, object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFileChanged(_:)),
            name: FileWatcher.fileChangedNotification,
            object: nil
        )
    }
    
    @objc private func handleFileChanged(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let fileName = userInfo["fileName"] as? String else { return }
        
        let source = userInfo["source"] as? String ?? "local"
        print("🔄 文件已修改 (\(source)): \(fileName)")
        
        DispatchQueue.main.async {
            // 避免频繁弹窗导致 UI 冲突/崩溃
            // self.showTemporaryMessage("热重载: \(fileName)")
            print("⚡️ [DebugTool] 触发界面刷新: \(fileName)")
            self.onReloadLayout?()
        }
    }
    
    private func showTemporaryMessage(_ message: String) {
        let alert = UIAlertController(title: "提示", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
        // 自动消失
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            alert.dismiss(animated: true)
        }
    }
    
    // MARK: - Actions Implementation
    
    private func showQRScannerAction() {
        // 确保 qrScanner 存在
        if qrScanner == nil {
            qrScanner = QRCodeScanner()
        }
        
        guard let qrScanner = self.qrScanner else {
            showAlert(title: "错误", message: "无法初始化相机扫描器")
            return
        }
        
        // 创建扫描控制器
        let scannerVC = DebugScannerViewController()
        scannerVC.qrScanner = qrScanner
        scannerVC.modalPresentationStyle = .fullScreen
        
        // 设置回调
        scannerVC.onScanResult = { [weak self] code in
            guard let self = self, let code = code else { return }
            
            // 设置服务器地址
            LocalDevServer.shared.baseURL = code
            LocalDevServer.shared.isEnabled = true
            
            // 重新启动监听 (如果当前有布局信息)
            if let layoutInfo = self.currentLayoutInfo {
                print("🔄 [DebugTool] 扫码成功，重启监听...")
                self.startFileWatching(templateID: layoutInfo.xmlFile)
            }
            
            // 通知外部监听者
            self.onScanQRCode?(code)
            
            // 刷新 UI
            self.viewModel.loadData()
            self.tableView.reloadData()
            
            // 关闭扫描页面并显示成功提示
            scannerVC.dismiss(animated: true) {
                self.showAlert(title: "✅ 连接成功", message: "已连接到服务器:\n\(code)")
            }
        }
        
        // 直接 present，不要先 dismiss 调试页面
        present(scannerVC, animated: true)
    }
    
    private func showManualInputAction() {
        let alert = UIAlertController(title: "输入服务器地址", message: nil, preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = "http://10.21.81.150:8080"
            textField.text = LocalDevServer.shared.baseURL
            textField.keyboardType = .URL
            textField.autocapitalizationType = .none
        }
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "确定", style: .default) { [weak self] _ in
            guard let textField = alert.textFields?.first,
                  let url = textField.text, !url.isEmpty else { return }
            
            LocalDevServer.shared.baseURL = url
            LocalDevServer.shared.isEnabled = true
            self?.viewModel.loadData()
            self?.tableView.reloadData()
            self?.showAlert(title: "成功", message: "已设置服务器地址: \(url)")
        })
        
        present(alert, animated: true)
    }
    
    private func checkServerAction() {
        let alert = UIAlertController(title: "检查服务器", message: "正在检查...", preferredStyle: .alert)
        present(alert, animated: true)
        
        LocalDevServer.shared.checkServerAvailable { [weak self] available in
            DispatchQueue.main.async {
                alert.dismiss(animated: true) {
                    if available {
                        self?.showAlert(title: "成功", message: "服务器可用: \(LocalDevServer.shared.baseURL)")
                    } else {
                        self?.showAlert(title: "失败", message: "无法连接到服务器: \(LocalDevServer.shared.baseURL)")
                    }
                }
            }
        }
    }
    
    private func reloadLayoutAction() {
        onReloadLayout?()
        showAlert(title: "提示", message: "已重新加载布局")
    }
    
    private func reloadFromServerAction() {
        guard LocalDevServer.shared.isEnabled else {
            showAlert(title: "错误", message: "请先连接服务器")
            return
        }
        
        guard let layoutInfo = currentLayoutInfo else {
            showAlert(title: "错误", message: "未找到布局信息")
            return
        }
        
        let alert = UIAlertController(title: "从服务器刷新", message: "正在下载...", preferredStyle: .alert)
        present(alert, animated: true)
        
        let templateId = layoutInfo.xmlFile
        let layoutName = "\(templateId)_layout.xml"
        let dataName = "\(templateId)_data.json"
        let logicName = "\(templateId)_logic.js"
        
        let layoutPath = "pimeierPages/\(templateId)/\(layoutName)"
        let dataPath = "pimeierPages/\(templateId)/\(dataName)"
        let logicPath = "pimeierPages/\(templateId)/\(logicName)"
        
        let group = DispatchGroup()
        var hasError = false
        
        // 下载 Layout
        group.enter()
        downloadAndCacheFile(path: layoutPath) { success in
            if !success { hasError = true }
            group.leave()
        }
        
        // 下载 Data
        group.enter()
        downloadAndCacheFile(path: dataPath) { success in
            if !success { hasError = true }
            group.leave()
        }
        
        // 下载 Logic
        group.enter()
        downloadAndCacheFile(path: logicPath) { success in
            // logic.js 是可选的
            if !success { 
                print("⚠️ Logic JS 下载失败 (可能是文件不存在)")
            }
            group.leave()
        }
        
        group.notify(queue: .main) { [weak self] in
            alert.dismiss(animated: true) {
                self?.onReloadLayout?()
                
                if hasError {
                    self?.showAlert(title: "部分成功", message: "部分文件加载失败，使用缓存或默认值")
                } else {
                    self?.showTemporaryMessage("✅ 已从服务器更新")
                }
            }
        }
    }
    
    private func downloadAndCacheFile(path: String, completion: @escaping (Bool) -> Void) {
        let urlString = LocalDevServer.shared.getFileURL(path)
        guard let url = URL(string: urlString) else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 5.0
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Download Error (\(path)): \(error.localizedDescription)")
                completion(false)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let data = data else {
                print("❌ Download Failed (\(path)): Status \((response as? HTTPURLResponse)?.statusCode ?? 0)")
                completion(false)
                return
            }
            
            // 保存到缓存
            let success = FileCacheManager.saveToCache(data, fileName: path)
            completion(success)
        }.resume()
    }
    
    private func clearCacheAction() {
        let alert = UIAlertController(title: "清除缓存", message: "确定要清除所有缓存文件吗？", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "确定", style: .destructive) { [weak self] _ in
            FileCacheManager.clearCache()
            self?.showAlert(title: "成功", message: "已清除所有缓存")
        })
        present(alert, animated: true)
    }
    
    private func showViewHierarchyAction() {
        guard let rootView = getRootView() else {
            showAlert(title: "视图层级", message: "无法获取根视图")
            return
        }
        
        print("🔍 开始调试视图层级...")
        YogaInspector.printHierarchy(rootView: rootView)
        YogaInspector.toggleVisualDebugger(rootView: rootView)
        
        showAlert(title: "视图层级", message: "已打印到控制台，并显示可视化调试层")
    }
    
    private func showVersionInfoAction() {
        let message = """
        服务器地址: \(LocalDevServer.shared.isEnabled ? LocalDevServer.shared.baseURL : "未设置")
        缓存大小: \(formatBytes(FileCacheManager.getCacheSize()))
        """
        
        showAlert(title: "版本信息", message: message)
    }
    
    private func showTemplateSelectorAction() {
        let templates = TemplateManager.shared.listTemplates()
        let alert = UIAlertController(title: "选择模版", message: nil, preferredStyle: .actionSheet)
        
        for templateId in templates {
            let action = UIAlertAction(title: templateId, style: .default) { [weak self] _ in
                TemplateManager.shared.currentTemplateID = templateId
                self?.onReloadLayout?()
                self?.viewModel.loadData()
                self?.tableView.reloadData()
                
                if let self = self, self.viewModel.isHotReloadEnabled {
                    self.startFileWatching(templateID: templateId)
                }
            }
            alert.addAction(action)
        }
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = tableView
            popover.sourceRect = tableView.bounds
        }
        
        present(alert, animated: true)
    }
    
    private func openTodoDemoAction() {
        let todoVC = PimeierViewController(templateID: "todo_list")
        
        if let nav = navigationController {
            nav.pushViewController(todoVC, animated: true)
        } else {
            present(todoVC, animated: true)
        }
    }
    
    private func resetTemplatesAction() {
        let alert = UIAlertController(title: "修复模版", message: "将重置 todo_list 模版缓存，下次打开时会重新安装。", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "确定", style: .destructive) { _ in
            TemplateManager.shared.resetTodoTemplate()
        })
        present(alert, animated: true)
    }
    
    // MARK: - Helpers
    
    private func getRootView() -> UIView? {
        for window in UIApplication.shared.windows {
            if let root = window.rootViewController {
                if let pimeierVC = root as? PimeierViewController {
                    return pimeierVC.rootContentView
                }
            }
        }
        return nil
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource & Delegate

extension DebugToolViewController: UITableViewDataSource, UITableViewDelegate {
    
    public func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel.sections.count
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.sections[section].items.count
    }
    
    public func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return viewModel.sections[section].type.title
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let item = viewModel.sections[indexPath.section].items[indexPath.row]
        
        cell.textLabel?.text = item.title
        cell.detailTextLabel?.text = item.detail
        if let color = item.detailColor {
            cell.detailTextLabel?.textColor = color
        }
        
        if item.isSwitch {
            let switchView = UISwitch()
            switchView.isOn = item.isSwitchOn
            switchView.addTarget(self, action: #selector(handleSwitchChange(_:)), for: .valueChanged)
            // Store closure wrapper or tag? Using closure in cell is safer if not reusing heavily, but addTarget is better for selector
            // But we need to pass the item's action.
            // Let's use the closure approach from before but make sure it's clean
            switchView.addAction(UIAction(handler: { _ in
                item.switchAction?(switchView.isOn)
            }), for: .valueChanged)
            
            cell.accessoryView = switchView
            cell.accessoryType = .none
            cell.selectionStyle = .none
        } else {
            cell.accessoryView = nil
            cell.accessoryType = .disclosureIndicator
            cell.selectionStyle = .default
        }
        
        return cell
    }
    
    @objc private func handleSwitchChange(_ sender: UISwitch) {
        // Fallback if UIAction not available (iOS < 14), but we target 14.0
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = viewModel.sections[indexPath.section].items[indexPath.row]
        if !item.isSwitch {
            item.action?()
        }
    }
}
