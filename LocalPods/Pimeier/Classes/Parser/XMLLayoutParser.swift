//
//  XMLLayoutParser.swift
//  Pimeier
//
//  Created by AI Assistant
//

import Foundation

/// XML 布局解析器
public class XMLLayoutParser: NSObject {
    
    // 使用数组来存储节点，通过索引来管理父子关系
    // 这样可以避免值类型的问题
    private var nodes: [LayoutNode] = []
    private var nodeStack: [Int] = []  // 存储节点索引而不是节点本身
    private var currentNodeIndex: Int?
    private var rootNode: LayoutNode?
    private var rawXMLString: String? // 存储原始 XML 字符串，用于手动提取丢失的属性
    
    public override init() {
        super.init()
    }
    
    /// 解析 XML 字符串
    public func parse(xml: String) -> LayoutNode? {
        guard let data = xml.data(using: .utf8) else { return nil }
        return parse(data: data)
    }
    
    /// 解析 XML 数据
    public func parse(data: Data) -> LayoutNode? {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.shouldProcessNamespaces = false
        parser.shouldReportNamespacePrefixes = false
        parser.shouldResolveExternalEntities = false
        
        rootNode = nil
        nodeStack = []
        currentNodeIndex = nil
        nodes = []
        
        // 保存原始 XML 字符串，用于手动提取丢失的属性
        rawXMLString = String(data: data, encoding: .utf8)
        
        if parser.parse() {
            // 验证节点树构建
            if let root = rootNode {
                print("✅ XML 解析成功，根节点: \(root.type.rawValue)")
                printNodeTree(root, level: 0)
                return root
            } else {
                print("❌ XML 解析完成但根节点为空")
                return nil
            }
        }
        
        return nil
    }
    
    /// 递归打印节点树（用于调试）
    private func printNodeTree(_ node: LayoutNode, level: Int) {
        let indent = String(repeating: "  ", count: level)
        let childrenCount = node.children.count
        print("\(indent)📦 \(node.type.rawValue) [\(childrenCount) 个子节点]")
        
        for child in node.children {
            printNodeTree(child, level: level + 1)
        }
    }
    
    /// 规范化元素名称，支持多种命名格式
    private func normalizeElementName(_ name: String) -> String {
        let lowercased = name.lowercased()
        
        // 特殊处理：驼峰命名的节点类型
        if lowercased == "scrollview" {
            return "scrollView"
        } else if lowercased == "refreshview" {
            return "refreshView"
        } else if lowercased == "loadmoreview" {
            return "loadMoreView"
        } else if lowercased == "textfield" || lowercased == "edittext" {
            return "input"
        } else if lowercased == "switch" {
            // switch 是 Swift 关键字，在 NodeType 中使用 switch_，但 XML 中可以使用 switch
            return "switch_"
        } else if lowercased == "slider" {
            return "slider"
        } else if lowercased == "webview" || lowercased == "web-view" {
            return "webview"
        }
        
        // 其他情况使用全小写
        return lowercased
    }
    
    /// 从文件解析 XML
    /// 优先从缓存目录加载，如果不存在则从 Bundle 加载
    public func parse(file: String) -> LayoutNode? {
        print("🔍 正在查找 XML 文件: \(file)")
        
        // 此方法现在需要依赖外部的文件查找逻辑，或者我们需要在这里注入查找器
        // 为了解耦，Parser 应该只负责 Parse，不负责 Find File。
        // 但为了保持现有逻辑，我们暂时注释掉 FileCacheManager 依赖，
        // 或者假设调用者会传入 Data。
        // 实际上，PimeierViewController 会调用 TemplateManager 获取 URL，然后读取 Data，再传给 Parser。
        // 所以这个 parse(file:) 方法可能已经过时了，或者应该重构。
        
        // 考虑到这是一个 SDK，我们最好提供 parse(data:) 接口，让宿主决定文件来源。
        // 保留 parse(file:) 可能会引入对 FileCacheManager 的循环依赖（如果 CacheManager 在 Services）
        // XMLLayoutParser 在 Parser 层，不应依赖 Services。
        
        // 暂时保留逻辑，但假定 FileCacheManager 不再直接可用，需要外部传入路径？
        // 我们修改为：只通过 parse(data:) 工作。
        // 调用者（PimeierViewController）负责加载数据。
        print("⚠️ XMLLayoutParser.parse(file:) is deprecated. Please use parse(data:).")
        return nil
    }
}

// MARK: - XMLParserDelegate

extension XMLLayoutParser: XMLParserDelegate {
    
    public func parser(_ parser: XMLParser,
                didStartElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        
        // 确定节点类型
        // 智能匹配：先尝试原始大小写，再尝试全小写，最后尝试驼峰转小写
        let normalizedName = normalizeElementName(elementName)
        var nodeType = LayoutNode.NodeType(rawValue: normalizedName)
        var customType: String? = nil
        
        // 如果未匹配到内置类型，尝试查找自定义组件
        if nodeType == nil {
            // 检查是否是注册的自定义组件
            // 注意：Parser 不应该依赖 ComponentRegistry (UI 层)。
            // 但为了能够正确标记 .custom 类型，我们需要一种机制。
            // 简单的做法是：只要不是内置类型，都认为是 custom。
            // 构建阶段再校验是否存在。
            nodeType = .custom
            customType = elementName
        }
        
        guard let finalNodeType = nodeType else {
            print("⚠️ 无法识别的节点: \(elementName)")
            return
        }
        
        // 调试属性解析
        if elementName == "list-view" {
            print("📦 [Parser] <\(elementName)> attributes count: \(attributeDict.count)")
            print("📦 [Parser] <\(elementName)> attributes: \(attributeDict.keys.sorted())")
            print("📦 [Parser] Full attributeDict: \(attributeDict)")
            
            // 检查是否有 data 属性
            if let dataValue = attributeDict["data"] {
                print("✅ [Parser] Found data attribute: \(dataValue)")
            } else {
                print("❌ [Parser] data attribute NOT FOUND in attributeDict!")
            }
        }
        
        // 解析指令属性
        var attributes = attributeDict
        
        // 临时修复：如果 elementName 是 list-view 且缺少 data 属性，手动从原始 XML 中提取
        if elementName == "list-view" && attributes["data"] == nil {
            print("🔧 [Parser] Attempting manual extraction for list-view...")
            if let xmlString = rawXMLString {
                print("🔧 [Parser] rawXMLString exists, length: \(xmlString.count)")
                if let extracted = extractAttributesFromXML(xmlString, forTag: "list-view") {
                    print("🔧 [Parser] Successfully extracted \(extracted.count) attributes")
                    attributes.merge(extracted) { (_, new) in new } // 合并提取的属性，新值优先
                    print("🔧 [Parser] Manually extracted attributes for list-view: \(extracted.keys.sorted())")
                } else {
                    print("❌ [Parser] Manual extraction returned nil")
                }
            } else {
                print("❌ [Parser] rawXMLString is nil!")
            }
        }
        
        let ifCondition = attributes.removeValue(forKey: "if")
        let forLoop = attributes.removeValue(forKey: "for")
        
        // 创建新节点
        let newNode = LayoutNode(
            type: finalNodeType,
            attributes: attributes,
            children: [],
            ifCondition: ifCondition,
            forLoop: forLoop,
            customType: customType // 确保这里传递了 customType
        )
        
        // 将新节点添加到 nodes 数组
        let newNodeIndex = nodes.count
        nodes.append(newNode)
        
        // 如果有当前节点（父节点），将其索引 push 到 stack
        if let currentIndex = currentNodeIndex {
            nodeStack.append(currentIndex)
        }
        
        // 设置新节点为当前节点
        currentNodeIndex = newNodeIndex
        
        // 如果是第一个节点（根节点），同时设置 rootNode
        if rootNode == nil {
            rootNode = newNode
        }
    }
    
    public func parser(_ parser: XMLParser,
                didEndElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?) {
        
        // 当前节点已经完成（包含所有子节点），需要将其添加到父节点
        guard let currentIndex = currentNodeIndex else { return }
        let completedNode = nodes[currentIndex]
        
        if !nodeStack.isEmpty {
            // 从 stack 中取出父节点的索引
            let parentIndex = nodeStack.removeLast()
            
            // 将完成的节点添加到父节点的 children 中
            // 由于 nodes 是数组，我们需要更新数组中的节点
            nodes[parentIndex].children.append(completedNode)
            
            // 将父节点设置为当前节点
            currentNodeIndex = parentIndex
            
            // 如果 stack 为空，说明父节点是根节点，更新 rootNode
            if nodeStack.isEmpty {
                rootNode = nodes[parentIndex]
            }
        } else {
            // Stack 为空，说明当前节点就是根节点
            rootNode = completedNode
        }
    }
    
    public func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        print("❌ XML 解析错误: \(parseError.localizedDescription)")
    }
    
    // MARK: - Helper Methods
    
    /// 从原始 XML 字符串中手动提取指定标签的属性（用于修复 XMLParser 丢失属性的 bug）
    private func extractAttributesFromXML(_ xmlString: String, forTag tagName: String) -> [String: String]? {
        // 使用正则表达式匹配完整的开始标签（包括所有属性，支持跨行）
        // 模式：<tagName 后面跟着任意字符（包括换行），直到遇到 >
        let pattern = "<\(tagName)\\s+([\\s\\S]*?)>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            print("❌ [Parser] Failed to create regex for tag: \(tagName)")
            return nil
        }
        
        let range = NSRange(location: 0, length: xmlString.utf16.count)
        guard let match = regex.firstMatch(in: xmlString, options: [], range: range),
              let attributesRange = Range(match.range(at: 1), in: xmlString) else {
            print("❌ [Parser] No match found for tag: \(tagName)")
            return nil
        }
        
        let attributesString = String(xmlString[attributesRange])
        print("🔍 [Parser] Extracted attributes string (full): \(attributesString)")
        
        var result: [String: String] = [:]
        
        // 解析属性字符串，格式：key="value" key2="value2"
        // 注意：需要处理属性值中包含引号的情况，以及属性可能跨行的情况
        // 改进：使用更健壮的正则表达式，支持属性名中的连字符（如 data-source）
        let attrPattern = "([a-zA-Z][a-zA-Z0-9_-]*)\\s*=\\s*\"([^\"]*)\""
        guard let attrRegex = try? NSRegularExpression(pattern: attrPattern, options: []) else {
            print("❌ [Parser] Failed to create attribute regex")
            return nil
        }
        
        // 清理属性字符串：移除换行符和多余空格
        let cleanedAttributes = attributesString.replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        
        print("🔍 [Parser] Cleaned attributes string: \(cleanedAttributes)")
        
        let attrMatches = attrRegex.matches(in: cleanedAttributes, options: [], range: NSRange(location: 0, length: cleanedAttributes.utf16.count))
        print("🔍 [Parser] Found \(attrMatches.count) attribute matches")
        
        for match in attrMatches {
            if let keyRange = Range(match.range(at: 1), in: cleanedAttributes),
               let valueRange = Range(match.range(at: 2), in: cleanedAttributes) {
                let key = String(cleanedAttributes[keyRange])
                let value = String(cleanedAttributes[valueRange])
                result[key] = value
                print("🔍 [Parser] Extracted: \(key) = \(value)")
            }
        }
        
        return result.isEmpty ? nil : result
    }
}
