//
//  QRCodeScanner.swift
//  HelloYoga
//
//  Created by AI Assistant
//

import UIKit
import AVFoundation

/// 二维码扫描器
open class QRCodeScanner: NSObject {
    
    // MARK: - Properties
    
    public weak var delegate: QRCodeScannerDelegate?
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var targetView: UIView?
    private var isSetupInProgress = false
    private var setupRetryCount = 0
    private let maxRetryCount = 3

    public override init() {
        super.init()
    }
    
    // MARK: - Public Methods
    
    /// 开始扫描
    public func startScanning(in view: UIView) -> Bool {
        print("📱 [QRCodeScanner] ========== 开始扫描请求 ==========")
        print("📱 [QRCodeScanner] 视图: \(view)")
        print("📱 [QRCodeScanner] 视图 bounds: \(view.bounds)")
        print("📱 [QRCodeScanner] 视图 window: \(view.window != nil ? "存在" : "nil")")
        
        // 检查是否在模拟器上运行
        #if targetEnvironment(simulator)
        print("❌ [QRCodeScanner] 模拟器不支持相机扫描")
        delegate?.scannerDidFail(with: "模拟器不支持相机扫描，请在真机上运行")
        return false
        #else
        
        // 如果已经在设置中，先停止之前的设置
        if isSetupInProgress {
            print("⚠️ [QRCodeScanner] 设置正在进行中，先停止之前的设置")
            stopScanning()
        }
        
        // 保存目标视图
        targetView = view
        
        // 检查相机权限
        let authStatus = AVCaptureDevice.authorizationStatus(for: .video)
        print("📱 [QRCodeScanner] 相机权限状态: \(authStatus.rawValue)")
        
        switch authStatus {
        case .authorized:
            print("✅ [QRCodeScanner] 权限已授权，开始设置会话")
            let result = setupCaptureSession(in: view)
            print("📱 [QRCodeScanner] setupCaptureSession 返回: \(result)")
            if !result {
                print("❌ [QRCodeScanner] 设置会话失败，检查上面的日志了解原因")
            }
            return result
        case .notDetermined:
            print("📱 [QRCodeScanner] 请求相机权限...")
            isSetupInProgress = true
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isSetupInProgress = false
                    if granted {
                        print("✅ [QRCodeScanner] 相机权限已授予")
                        _ = self?.setupCaptureSession(in: view)
                    } else {
                        print("❌ [QRCodeScanner] 相机权限被拒绝")
                        self?.delegate?.scannerDidFail(with: "需要相机权限才能扫描二维码")
                    }
                }
            }
            return true
        case .denied, .restricted:
            print("❌ [QRCodeScanner] 相机权限被拒绝或受限")
            delegate?.scannerDidFail(with: "相机权限被拒绝，请在设置中允许访问相机")
            return false
        @unknown default:
            print("❌ [QRCodeScanner] 未知的权限状态: \(authStatus)")
            return false
        }
        #endif
    }
    
    /// 停止扫描
    public func stopScanning() {
        print("📱 [QRCodeScanner] 停止扫描")
        
        isSetupInProgress = false
        setupRetryCount = 0
        
        // 移除所有通知观察者
        NotificationCenter.default.removeObserver(self)
        
        // 在后台线程停止会话
        if let session = captureSession {
            let sessionToStop = session
            if sessionToStop.isRunning {
                print("📱 [QRCodeScanner] 正在停止会话...")
                sessionToStop.stopRunning()
                print("📱 [QRCodeScanner] 会话已停止")
            }
        }
        
        // 定义清理闭包
        let cleanup = { [weak self] in
            self?.previewLayer?.removeFromSuperlayer()
            self?.previewLayer = nil
            self?.captureSession = nil
            self?.targetView = nil
            print("📱 [QRCodeScanner] 资源已清理")
        }
        
        // 确保在主线程执行清理
        if Thread.isMainThread {
            cleanup()
        } else {
            DispatchQueue.main.sync {
                cleanup()
            }
        }
    }
    
    /// 更新预览层大小
    public func updatePreviewLayer(frame: CGRect) {
        DispatchQueue.main.async { [weak self] in
            self?.previewLayer?.frame = frame
        }
    }
    
    // MARK: - Private Methods
    
    private func setupCaptureSession(in view: UIView) -> Bool {
        print("📱 [QRCodeScanner] ========== 开始设置相机会话 ==========")
        print("📱 [QRCodeScanner] 视图 bounds: \(view.bounds)")
        print("📱 [QRCodeScanner] 视图 window: \(view.window != nil ? "存在" : "nil")")
        
        // 防止重复设置
        if isSetupInProgress {
            print("⚠️ [QRCodeScanner] 设置正在进行中，等待完成...")
            // 等待一小段时间后重试
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                _ = self?.setupCaptureSession(in: view)
            }
            return true
        }
        
        isSetupInProgress = true
        
        // 先停止之前的会话（如果存在）
        print("📱 [QRCodeScanner] 停止之前的会话...")
        stopScanning()
        
        // 确保在主线程执行
        guard Thread.isMainThread else {
            print("⚠️ [QRCodeScanner] 不在主线程，切换到主线程")
            DispatchQueue.main.async { [weak self] in
                self?.isSetupInProgress = false
                _ = self?.setupCaptureSession(in: view)
            }
            return true
        }
        
        // 检查视图是否有效（放宽检查条件）
        print("📱 [QRCodeScanner] 视图 bounds: \(view.bounds)")
        print("📱 [QRCodeScanner] 视图 window: \(view.window != nil ? "存在" : "nil")")
        
        // 强制布局
        view.layoutIfNeeded()
        
        // 如果视图 bounds 无效，延迟重试（但不要阻止启动）
        if view.bounds.width <= 0 || view.bounds.height <= 0 {
            print("⚠️ [QRCodeScanner] 视图 bounds 无效，延迟重试")
            isSetupInProgress = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                _ = self?.setupCaptureSession(in: view)
            }
            return true
        }
        
        // 如果视图还没有添加到窗口，也延迟重试
        if view.window == nil {
            print("⚠️ [QRCodeScanner] 视图还没有添加到窗口，延迟重试")
            isSetupInProgress = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                _ = self?.setupCaptureSession(in: view)
            }
            return true
        }
        
        // 创建会话
        let session = AVCaptureSession()
        
        // 配置会话预设（使用 medium 以提高兼容性）
        if session.canSetSessionPreset(.medium) {
            session.sessionPreset = .medium
            print("📱 [QRCodeScanner] 使用 medium 预设")
        } else if session.canSetSessionPreset(.low) {
            session.sessionPreset = .low
            print("📱 [QRCodeScanner] 使用 low 预设")
        } else {
            print("⚠️ [QRCodeScanner] 使用默认预设")
        }
        
        // 获取相机设备
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            print("❌ [QRCodeScanner] 无法访问相机设备")
            isSetupInProgress = false
            delegate?.scannerDidFail(with: "无法访问相机设备，请检查设备是否支持相机")
            return false
        }
        
        print("✅ [QRCodeScanner] 找到相机设备: \(videoCaptureDevice.localizedName)")
        
        // 创建视频输入
        let videoInput: AVCaptureDeviceInput
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
            print("✅ [QRCodeScanner] 创建视频输入成功")
        } catch {
            print("❌ [QRCodeScanner] 无法创建视频输入: \(error.localizedDescription)")
            isSetupInProgress = false
            delegate?.scannerDidFail(with: "无法初始化相机输入: \(error.localizedDescription)")
            return false
        }
        
        // 配置会话
        session.beginConfiguration()
        
        // 添加视频输入
        if session.canAddInput(videoInput) {
            session.addInput(videoInput)
            print("✅ [QRCodeScanner] 已添加视频输入")
        } else {
            session.commitConfiguration()
            print("❌ [QRCodeScanner] 无法添加视频输入到会话")
            isSetupInProgress = false
            delegate?.scannerDidFail(with: "无法添加相机输入到会话，可能被其他应用占用")
            return false
        }
        
        // 创建并添加元数据输出
        let metadataOutput = AVCaptureMetadataOutput()
        
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            print("✅ [QRCodeScanner] 已添加元数据输出")
            
            // 设置代理（必须在主线程）
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            
            // 检查并设置二维码类型
            if metadataOutput.availableMetadataObjectTypes.contains(.qr) {
                metadataOutput.metadataObjectTypes = [.qr]
                print("✅ [QRCodeScanner] 已设置二维码扫描类型")
            } else {
                session.commitConfiguration()
                print("❌ [QRCodeScanner] 设备不支持二维码扫描")
                print("   支持的类型: \(metadataOutput.availableMetadataObjectTypes)")
                isSetupInProgress = false
                delegate?.scannerDidFail(with: "设备不支持二维码扫描")
                return false
            }
        } else {
            session.commitConfiguration()
            print("❌ [QRCodeScanner] 无法添加元数据输出到会话")
            isSetupInProgress = false
            delegate?.scannerDidFail(with: "无法添加元数据输出到会话")
            return false
        }
        
        // 提交配置
        session.commitConfiguration()
        print("✅ [QRCodeScanner] 会话配置已提交")
        
        // 创建预览层（必须在主线程）
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.insertSublayer(previewLayer, at: 0)
        
        print("✅ [QRCodeScanner] 预览层已创建: \(previewLayer.frame)")
        
        // 保存引用
        self.captureSession = session
        self.previewLayer = previewLayer
        
        // 添加通知观察者
        addNotificationObservers(for: session)
        
        // 启动会话
        startSession(session, metadataOutput: metadataOutput)
        
        isSetupInProgress = false
        return true
    }
    
    private func addNotificationObservers(for session: AVCaptureSession) {
        // 运行时错误
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSessionRuntimeError(_:)),
            name: .AVCaptureSessionRuntimeError,
            object: session
        )
        
        // 会话中断
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSessionInterruption(_:)),
            name: .AVCaptureSessionWasInterrupted,
            object: session
        )
        
        // 会话中断结束
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSessionInterruptionEnded(_:)),
            name: .AVCaptureSessionInterruptionEnded,
            object: session
        )
        
        print("✅ [QRCodeScanner] 已添加通知观察者")
    }
    
    private func startSession(_ session: AVCaptureSession, metadataOutput: AVCaptureMetadataOutput) {
        print("📱 [QRCodeScanner] 准备启动相机会话...")
        
        // 在后台线程启动会话（避免阻塞主线程）
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self, let session = self.captureSession, session === self.captureSession else {
                print("❌ [QRCodeScanner] 会话已失效")
                return
            }
            
            print("📱 [QRCodeScanner] 正在启动会话...")
            session.startRunning()
            
            let isRunning = session.isRunning
            print("📱 [QRCodeScanner] 会话启动完成，运行状态: \(isRunning)")
            
            if !isRunning {
                print("⚠️ [QRCodeScanner] 会话启动失败")
                DispatchQueue.main.async {
                    self.delegate?.scannerDidFail(with: "相机启动失败，请重试")
                    self.stopScanning()
                }
                return
            }
            
            // 会话启动成功后，在主线程设置扫描区域
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.configureScanArea(metadataOutput: metadataOutput)
            }
        }
    }
    
    private func configureScanArea(metadataOutput: AVCaptureMetadataOutput) {
        guard let previewLayer = previewLayer,
              let session = captureSession,
              session.isRunning else {
            print("⚠️ [QRCodeScanner] 无法设置扫描区域：会话未运行")
            return
        }
        
        // 设置扫描区域为整个预览区域
        let rectOfInterest = CGRect(x: 0, y: 0, width: 1, height: 1)
        metadataOutput.rectOfInterest = rectOfInterest
        
        print("✅ [QRCodeScanner] 扫描区域已设置: \(rectOfInterest)")
        print("📱 [QRCodeScanner] 预览层尺寸: \(previewLayer.bounds)")
        print("📱 [QRCodeScanner] 预览层 frame: \(previewLayer.frame)")
        print("📱 [QRCodeScanner] 支持的元数据类型: \(metadataOutput.availableMetadataObjectTypes)")
        print("📱 [QRCodeScanner] 当前元数据类型: \(metadataOutput.metadataObjectTypes)")
        print("📱 [QRCodeScanner] 会话运行状态: \(session.isRunning)")
        print("✅ [QRCodeScanner] 相机扫描已就绪")
    }
    
    // MARK: - Notification Handlers
    
    @objc private func handleSessionInterruption(_ notification: Notification) {
        print("⚠️ [QRCodeScanner] 相机会话被中断")
    }
    
    @objc private func handleSessionInterruptionEnded(_ notification: Notification) {
        print("✅ [QRCodeScanner] 相机会话中断已结束")
        // 尝试重新启动
        if let session = captureSession, !session.isRunning {
            print("📱 [QRCodeScanner] 尝试重新启动会话...")
            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
            }
        }
    }
    
    @objc private func handleSessionRuntimeError(_ notification: Notification) {
        guard let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError else {
            return
        }
        
        print("⚠️ [QRCodeScanner] 相机会话运行时错误: \(error.localizedDescription)")
        print("   错误代码: \(error.code.rawValue)")
        
        // 处理运行时错误
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // 尝试恢复会话
            if let session = self.captureSession, session.isRunning == false {
                print("📱 [QRCodeScanner] 尝试恢复会话...")
                DispatchQueue.global(qos: .userInitiated).async {
                    session.startRunning()
                }
            } else {
                // 如果无法恢复，通知代理
                self.delegate?.scannerDidFail(with: "相机设备错误: \(error.localizedDescription)")
                self.stopScanning()
            }
        }
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate

extension QRCodeScanner: AVCaptureMetadataOutputObjectsDelegate {
    
    public func metadataOutput(_ output: AVCaptureMetadataOutput,
                       didOutput metadataObjects: [AVMetadataObject],
                       from connection: AVCaptureConnection) {
        
        guard !metadataObjects.isEmpty else { return }
        
        print("📱 [QRCodeScanner] 检测到 \(metadataObjects.count) 个元数据对象")
        
        // 查找二维码
        for obj in metadataObjects {
            if let qrCode = obj as? AVMetadataMachineReadableCodeObject,
               let stringValue = qrCode.stringValue {
                print("✅ [QRCodeScanner] 识别到二维码: \(stringValue)")
                delegate?.scannerDidFindCode(stringValue)
                stopScanning()
                return
            }
        }
        
        print("⚠️ [QRCodeScanner] 检测到元数据但无法解析为二维码")
    }
}

// MARK: - QRCodeScannerDelegate

public protocol QRCodeScannerDelegate: AnyObject {
    func scannerDidFindCode(_ code: String)
    func scannerDidFail(with error: String)
}
