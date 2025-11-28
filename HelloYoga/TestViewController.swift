//
//  TestViewController.swift
//  HelloYoga
//
//  Created by AI Assistant
//

import UIKit
import Pimeier

/// 模版列表示例页
class TestViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    private let tableView = UITableView()
    private var templates: [String] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Pimeier Demos"
        view.backgroundColor = .systemBackground
        
        setupTableView()
        loadTemplates()
        
        // 监听模版变化（如果 TemplateManager 支持）
        // NotificationCenter.default.addObserver(...)
    }
    
    private func setupTableView() {
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
    }
    
    private func loadTemplates() {
        // 使用 TemplateManager 获取模版列表
        templates = TemplateManager.shared.listTemplates()
        tableView.reloadData()
    }
    
    // MARK: - UITableViewDataSource
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return templates.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let templateId = templates[indexPath.row]
        
        cell.textLabel?.text = templateId
        cell.accessoryType = .disclosureIndicator
        
        // 简单的图标区分
        if templateId.contains("todo") {
            cell.imageView?.image = UIImage(systemName: "checklist")
        } else if templateId.contains("test") {
            cell.imageView?.image = UIImage(systemName: "testtube.2")
        } else {
            cell.imageView?.image = UIImage(systemName: "doc.text")
        }
        
        return cell
    }
    
    // MARK: - UITableViewDelegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let templateId = templates[indexPath.row]
        openTemplate(templateId)
    }
    
    private func openTemplate(_ id: String) {
        let pimeierVC = PimeierViewController(templateID: id)
        pimeierVC.title = id
        navigationController?.pushViewController(pimeierVC, animated: true)
    }
}
