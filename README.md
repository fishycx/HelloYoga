# HelloYoga - XML 驱动的动态布局引擎

## 🎯 项目概述

HelloYoga 是一个基于 Facebook Yoga 布局引擎的 iOS 动态页面框架。通过 XML 描述页面结构，JSON 提供动态数据，实现类似 Android 的声明式布局体验。

## 🏗️ 架构设计

```
┌──────────────────────────────────────────┐
│         XML 布局文件 (page_layout.xml)    │
│         定义页面结构和样式属性            │
└──────────────────────────────────────────┘
                    ↓
┌──────────────────────────────────────────┐
│         XMLLayoutParser (词法解析层)      │
│         解析 XML → LayoutNode 树          │
└──────────────────────────────────────────┘
                    ↓
┌──────────────────────────────────────────┐
│         YogaNodeBuilder (构建层)          │
│    LayoutNode → UIView + YGNode 树        │
└──────────────────────────────────────────┘
                    ↓
┌──────────────────────────────────────────┐
│         Yoga 布局引擎 (计算层)            │
│         Flexbox 布局计算                  │
└──────────────────────────────────────────┘
                    ↓
┌──────────────────────────────────────────┐
│         UIKit 渲染层                      │
│         渲染到屏幕                        │
└──────────────────────────────────────────┘
                    ↑
┌──────────────────────────────────────────┐
│    JSON 数据文件 (page_data.json)        │
│    LayoutDataBinder 绑定动态数据          │
└──────────────────────────────────────────┘
```

## 📁 核心文件

### 1. LayoutModels.swift
定义数据模型：
- `LayoutNode`: XML 布局节点
- `YogaStyle`: Yoga 布局属性（flexDirection, justifyContent 等）
- `ViewStyle`: UI 视图属性（backgroundColor, fontSize 等）

### 2. XMLLayoutParser.swift
XML 解析器，负责：
- 读取 XML 布局文件
- 使用 XMLParser 解析 XML
- 构建 LayoutNode 树结构

### 3. YogaNodeBuilder.swift
Yoga 节点构建器，负责：
- 从 LayoutNode 创建 UIView
- 创建对应的 YGNode（Yoga 节点）
- 应用样式属性
- 管理视图和节点的映射关系
- 计算和应用布局

### 4. LayoutDataBinder.swift
数据绑定器，负责：
- 加载 JSON 数据
- 根据视图的 ID 绑定数据
- 支持文本、按钮、图片等组件的数据更新

### 5. ViewController.swift
页面控制器，负责：
- 协调各个组件
- 加载 XML 布局
- 绑定 JSON 数据
- 处理用户交互

## 📝 XML 布局语法

### 支持的节点类型
- `container`: 容器
- `view`: 普通视图
- `text`: 文本标签
- `button`: 按钮
- `image`: 图片
- `header`: 头部区域
- `content`: 内容区域
- `footer`: 底部区域
- `scrollView`: 滚动视图

### Yoga 布局属性
```xml
<view 
    flexDirection="column|row|columnReverse|rowReverse"
    justifyContent="flexStart|center|flexEnd|spaceBetween|spaceAround|spaceEvenly"
    alignItems="flexStart|center|flexEnd|stretch|baseline"
    alignSelf="auto|flexStart|center|flexEnd|stretch"
    flexWrap="noWrap|wrap|wrapReverse"
    flex="1"
    flexGrow="1"
    flexShrink="1"
    
    width="100|50%|auto"
    height="200|80%|auto"
    minWidth="100"
    maxWidth="500"
    
    padding="20"
    paddingTop="10"
    paddingRight="10"
    paddingBottom="10"
    paddingLeft="10"
    
    margin="20"
    marginTop="10"
    marginRight="10"
    marginBottom="10"
    marginLeft="10"
    
    position="relative|absolute"
    top="0"
    left="0"
    right="0"
    bottom="0"
    
    aspectRatio="1.5">
</view>
```

### UI 样式属性
```xml
<text 
    id="myText"
    text="Hello World"
    textColor="white|#FF0000"
    fontSize="16"
    fontWeight="regular|bold|semibold|light"
    textAlignment="left|center|right"
    numberOfLines="0"
    
    backgroundColor="systemBlue|white|#00FF00"
    cornerRadius="12"
    borderWidth="1"
    borderColor="gray"
    opacity="0.8"
    hidden="false">
</text>
```

### 按钮属性
```xml
<button 
    id="myButton"
    title="点击我"
    titleColor="white"
    backgroundColor="systemBlue"
    fontSize="18"
    fontWeight="bold"
    cornerRadius="12">
</button>
```

## 📊 JSON 数据格式

### 简单绑定
```json
{
  "myText": "这是动态文本",
  "myButton": "按钮标题"
}
```

### 复杂绑定
```json
{
  "myText": {
    "text": "Hello World",
    "color": "red",
    "fontSize": 20
  },
  "myButton": {
    "title": "点击我",
    "titleColor": "white",
    "backgroundColor": "systemBlue"
  },
  "myImage": {
    "imageName": "icon",
    "imageURL": "https://example.com/image.png"
  }
}
```

## 🚀 使用方法

### 1. 创建 XML 布局文件
在项目中创建 `page_layout.xml`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<container flexDirection="column">
    <text id="title" fontSize="24" fontWeight="bold"/>
    <button id="submitButton" height="50"/>
</container>
```

### 2. 创建 JSON 数据文件
创建 `page_data.json`:
```json
{
  "title": "欢迎使用 HelloYoga",
  "submitButton": "提交"
}
```

### 3. 在 ViewController 中加载
```swift
class ViewController: UIViewController {
    private let xmlParser = XMLLayoutParser()
    private var yogaBuilder: YogaNodeBuilder?
    private let dataBinder = LayoutDataBinder()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 1. 解析 XML
        guard let layoutNode = xmlParser.parse(file: "page_layout") else { return }
        
        // 2. 构建视图树
        yogaBuilder = YogaNodeBuilder()
        guard let rootView = yogaBuilder?.buildViewTree(from: layoutNode) else { return }
        view.addSubview(rootView)
        
        // 3. 绑定数据
        if let data = LayoutDataBinder.loadData(from: "page_data") {
            dataBinder.bindData(data, to: rootView)
        }
        
        // 4. 计算布局
        yogaBuilder?.calculateLayout(for: rootView, width: view.bounds.width, height: view.bounds.height)
    }
}
```

## ✨ 特性

- ✅ **声明式布局**: 使用 XML 描述页面结构，无需写代码
- ✅ **数据绑定**: JSON 数据自动绑定到 UI 组件
- ✅ **Flexbox 布局**: 强大的 Yoga 布局引擎
- ✅ **动态更新**: 可以动态加载不同的 XML 布局
- ✅ **类型安全**: Swift 类型系统保证安全性
- ✅ **易于扩展**: 可以轻松添加新的节点类型和属性

## 🎨 示例

查看 `page_layout.xml` 和 `page_data.json` 了解完整示例。

运行项目后，你会看到：
- 蓝色的 Header 区域
- 动态加载的文本和按钮
- 灰色的 Footer 区域
- 所有布局使用 Flexbox 自动计算

## 🔧 技术栈

- **语言**: Swift 5
- **布局引擎**: Facebook Yoga
- **解析**: XMLParser (Foundation)
- **数据格式**: XML + JSON
- **依赖管理**: CocoaPods

## 📚 相关资源

- [Yoga 官方文档](https://yogalayout.com/)
- [Flexbox 指南](https://css-tricks.com/snippets/css/a-guide-to-flexbox/)
- [Facebook Yoga GitHub](https://github.com/facebook/yoga)

## 🛠️ 下一步改进

- [ ] 支持更多 UI 组件（Switch, Slider, TextField 等）
- [ ] 支持动画和过渡效果
- [ ] 支持条件渲染和循环
- [ ] 支持样式继承和主题系统
- [ ] 添加热重载功能
- [ ] 支持远程 XML 和 JSON 加载
- [ ] 添加布局预览工具

---

**享受 XML 驱动的动态布局吧！** 🎉

