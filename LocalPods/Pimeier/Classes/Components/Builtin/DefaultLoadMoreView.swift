//
//  DefaultLoadMoreView.swift
//  HelloYoga
//
//  Created by AI Assistant
//

import UIKit

/// 默认上拉加载更多视图
class DefaultLoadMoreView: UIView, LoadMoreViewProtocol {
    
    private let indicatorView = UIActivityIndicatorView(style: .medium)
    private let titleLabel = UILabel()
    
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
        titleLabel.text = "加载更多"
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
    
    // MARK: - LoadMoreViewProtocol
    
    func loadMoreStateChanged(to state: LoadMoreState) {
        switch state {
        case .idle:
            titleLabel.text = "加载更多"
            indicatorView.stopAnimating()
            
        case .loading:
            titleLabel.text = "正在加载..."
            indicatorView.startAnimating()
            
        case .noMore:
            titleLabel.text = "没有更多了"
            indicatorView.stopAnimating()
            
        case .error:
            titleLabel.text = "加载失败，点击重试"
            indicatorView.stopAnimating()
        }
    }
}

