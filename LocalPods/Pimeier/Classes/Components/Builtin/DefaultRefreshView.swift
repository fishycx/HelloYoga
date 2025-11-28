//
//  DefaultRefreshView.swift
//  HelloYoga
//
//  Created by AI Assistant
//

import UIKit

/// 默认下拉刷新视图
class DefaultRefreshView: UIView, RefreshViewProtocol {
    
    private let indicatorView = UIActivityIndicatorView(style: .medium)
    private let titleLabel = UILabel()
    private var progress: CGFloat = 0.0
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        backgroundColor = .clear
        
        // 设置标题标签
        titleLabel.text = "下拉刷新"
        titleLabel.font = .systemFont(ofSize: 14)
        titleLabel.textColor = .gray
        titleLabel.textAlignment = .center
        addSubview(titleLabel)
        
        // 设置指示器
        indicatorView.hidesWhenStopped = true
        indicatorView.color = .gray
        addSubview(indicatorView)
        
        // 布局
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        indicatorView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            indicatorView.centerXAnchor.constraint(equalTo: centerXAnchor, constant: -30),
            indicatorView.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            titleLabel.leadingAnchor.constraint(equalTo: indicatorView.trailingAnchor, constant: 8),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -20)
        ])
    }
    
    // MARK: - RefreshViewProtocol
    
    func refreshStateChanged(to state: RefreshState) {
        switch state {
        case .idle:
            titleLabel.text = "下拉刷新"
            indicatorView.stopAnimating()
            
        case .pulling:
            titleLabel.text = "下拉刷新"
            indicatorView.stopAnimating()
            
        case .willRefresh:
            titleLabel.text = "松开刷新"
            indicatorView.stopAnimating()
            
        case .refreshing:
            titleLabel.text = "正在刷新..."
            indicatorView.startAnimating()
            
        case .completed:
            titleLabel.text = "刷新完成"
            indicatorView.stopAnimating()
        }
    }
    
    func updateProgress(_ progress: CGFloat) {
        self.progress = progress
        // 可以根据进度更新 UI，比如旋转图标
        indicatorView.transform = CGAffineTransform(rotationAngle: CGFloat.pi * 2 * progress)
    }
}

