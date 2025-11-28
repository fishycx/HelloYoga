//
//  TodoPimeierViewController.swift
//  HelloYoga
//
//  Created by AI Assistant
//

import UIKit
import yoga
import YogaKit
import Pimeier

class TodoPimeierViewController: PimeierViewController {
    
    init() {
        super.init(templateID: "todo_list")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadTemplate() {
        super.loadTemplate()
        // 逻辑已经全部移到 logic.js 和 layout.xml 中
        // 这里不需要写任何代码了！
        // Pimeier 框架已经接管了一切！
    }
}
