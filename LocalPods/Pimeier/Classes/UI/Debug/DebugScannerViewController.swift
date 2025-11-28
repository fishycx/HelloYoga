//
//  DebugScannerViewController.swift
//  Pimeier
//
//  Created by AI Assistant
//

import UIKit
import AVFoundation

/// 二维码扫描视图控制器
public class DebugScannerViewController: UIViewController {
    
    // MARK: - Properties
    
    public var qrScanner: QRCodeScanner?
    public var onDismiss: (() -> Void)?
    public var onScanResult: ((String?) -> Void)?
    
    // MARK: - UI Components
    
    private lazy var scanView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()
    
    private lazy var hintLabel: UILabel = {
        let label = UILabel()
        label.text = "将二维码对准扫描框"
        label.textColor = .white
        label.font = .systemFont(ofSize: 18, weight: .medium)
        label.textAlignment = .center
        label.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        label.layer.cornerRadius = 8
        label.layer.masksToBounds = true
        return label
    }()
    
    private lazy var cancelButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("取消", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor.systemRed.withAlphaComponent(0.8)
        button.layer.cornerRadius = 25
        button.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var scanFrameView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.layer.borderColor = UIColor.systemGreen.cgColor
        view.layer.borderWidth = 2
        view.layer.cornerRadius = 10
        return view
    }()
    
    // MARK: - Lifecycle
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupUI()
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startCamera()
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        qrScanner?.stopScanning()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        // 添加扫描视图
        view.addSubview(scanView)
        scanView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scanView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scanView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scanView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scanView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // 提示标签
        view.addSubview(hintLabel)
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hintLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            hintLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hintLabel.widthAnchor.constraint(equalToConstant: 250),
            hintLabel.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        // 取消按钮
        view.addSubview(cancelButton)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            cancelButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            cancelButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cancelButton.widthAnchor.constraint(equalToConstant: 200),
            cancelButton.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        // 扫描框
        view.addSubview(scanFrameView)
        scanFrameView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scanFrameView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            scanFrameView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            scanFrameView.widthAnchor.constraint(equalToConstant: 250),
            scanFrameView.heightAnchor.constraint(equalToConstant: 250)
        ])
    }
    
    // MARK: - Camera Logic
    
    private func startCamera() {
        // 确保视图已布局完成
        view.layoutIfNeeded()
        
        // 等待视图完全准备好
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            
            // 再次确保布局完成
            self.view.layoutIfNeeded()
            
            print("📱 [DebugTool] ========== 准备启动相机 ==========")
            
            guard let scanner = self.qrScanner else {
                print("❌ [DebugTool] qrScanner 为 nil")
                self.onDismiss?()
                return
            }
            
            // 接管代理
            scanner.delegate = self
            
            let result = scanner.startScanning(in: self.scanView)
            
            if !result {
                print("❌ [DebugTool] 相机启动失败，3秒后重试...")
                // 延迟重试
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                    guard let self = self, let scanner = self.qrScanner else { return }
                    let retryResult = scanner.startScanning(in: self.scanView)
                    if !retryResult {
                        print("❌ [DebugTool] 相机启动再次失败")
                        self.onDismiss?()
                    }
                }
            } else {
                print("✅ [DebugTool] 相机启动成功")
            }
        }
    }
    
    // MARK: - Actions
    
    @objc private func cancelTapped() {
        qrScanner?.stopScanning()
        dismiss(animated: true) { [weak self] in
            self?.onDismiss?()
        }
    }
}

// MARK: - QRCodeScannerDelegate

extension DebugScannerViewController: QRCodeScannerDelegate {
    public func scannerDidFindCode(_ code: String) {
        print("📱 [DebugScanner] 扫描到二维码: \(code)")
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        qrScanner?.stopScanning()
        
        // 验证格式
        guard code.hasPrefix("http://") || code.hasPrefix("https://") else {
            let alert = UIAlertController(title: "无效的二维码", message: "请扫描包含 http:// 或 https:// 的服务器地址", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "重试", style: .default) { [weak self] _ in
                self?.qrScanner?.startScanning(in: self?.scanView ?? UIView())
            })
            alert.addAction(UIAlertAction(title: "取消", style: .cancel) { [weak self] _ in
                self?.dismiss(animated: true)
            })
            present(alert, animated: true)
            return
        }
        
        onScanResult?(code)
    }
    
    public func scannerDidFail(with error: String) {
        print("❌ [DebugScanner] 扫描失败: \(error)")
        let alert = UIAlertController(title: "扫描失败", message: error, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default) { [weak self] _ in
            self?.dismiss(animated: true)
        })
        present(alert, animated: true)
    }
}
