# HelloYoga - Pimeier 动态页面框架

## 🎯 项目概述

HelloYoga 是一个基于 Facebook Yoga 布局引擎的 iOS 动态页面框架（Pimeier Framework）。通过 XML 描述页面结构，JSON 提供动态数据，JavaScript 处理业务逻辑，实现类似 React Native 的声明式开发体验。

### 核心特性

- 🎨 **声明式布局**: XML 描述页面结构，无需写代码
- 📊 **数据驱动**: JSON 数据自动绑定，支持表达式 `{{ }}`
- 🧩 **组件化**: 支持自定义组件和内置组件（ListView、Switch、Slider 等）
- 🔌 **Native Bridge**: JavaScript 调用原生功能（Toast、设备信息、系统设置等）
- ⚡ **热重载**: 开发时实时预览 XML/JSON/JS 修改
- 📱 **模板系统**: 独立的页面模板，支持版本管理和迭代开发

## 🏗️ 架构设计

```
┌──────────────────────────────────────────┐
│    Pimeier 页面模板 (template_id/)       │
│    ├── template_id_layout.xml            │
│    ├── template_id_data.json             │
│    └── template_id_logic.js              │
└──────────────────────────────────────────┘
                    ↓
┌──────────────────────────────────────────┐
│         PimeierViewController            │
│    加载模板、协调各组件、处理热重载       │
└──────────────────────────────────────────┘
                    ↓
┌──────────────────────────────────────────┐
│         XMLLayoutParser (解析层)          │
│         解析 XML → LayoutNode 树          │
└──────────────────────────────────────────┘
                    ↓
┌──────────────────────────────────────────┐
│         PimeierRenderer (渲染引擎)        │
│    - 表达式解析 {{ }}                     │
│    - 条件渲染 if/for                     │
│    - 事件绑定 onClick/onChange           │
│    - 数据绑定 value="{{ }}"              │
└──────────────────────────────────────────┘
                    ↓
┌──────────────────────────────────────────┐
│         YogaNodeBuilder (构建层)          │
│    LayoutNode → UIView + YGNode 树        │
│    - 支持自定义组件 (PimeierComponent)   │
│    - 支持 ListView (UICollectionView)    │
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
│    PimeierJSEngine (JavaScript 引擎)     │
│    - 执行 logic.js                       │
│    - 注入 viewModel (JSON 数据)          │
│    - Native Bridge (Pimeier.Toast 等)    │
└──────────────────────────────────────────┘
```

## 📁 核心组件

### 1. PimeierViewController
页面容器，负责：
- 加载页面模板（XML + JSON + JS）
- 协调渲染引擎、JS 引擎、布局构建器
- 处理热重载和文件更新
- 管理页面生命周期

### 2. PimeierRenderer
渲染引擎（Level 2），负责：
- 解析表达式 `{{ viewModel.property }}`
- 条件渲染 `if="{{ condition }}"`
- 循环渲染 `for="{{ item in list }}"`
- 事件绑定 `onClick="functionName()"`
- 双向数据绑定 `value="{{ viewModel.value }}"`

### 3. PimeierJSEngine
JavaScript 引擎（Level 3），负责：
- 执行 `logic.js` 脚本
- 注入 `viewModel` 数据
- 提供 Native Bridge SDK (`Pimeier.Toast`, `Pimeier.System` 等)
- 支持 Promise 风格的 API

### 4. YogaNodeBuilder
布局构建器，负责：
- 从 LayoutNode 创建 UIView
- 创建对应的 YGNode（Yoga 节点）
- 应用样式属性
- 支持自定义组件（PimeierComponent）
- 计算和应用 Flexbox 布局

### 5. XMLLayoutParser
XML 解析器，负责：
- 解析 XML 布局文件
- 构建 LayoutNode 树结构
- 支持自定义标签和属性

### 6. BridgeManager
Native Bridge 管理器，负责：
- 注册和管理 Native 模块
- 路由 JavaScript 调用到 Native 方法
- 提供 Promise 风格的 API

### 7. TemplateManager
模板管理器，负责：
- 发现和加载页面模板
- 支持 Bundle 和 Cache 两种来源
- 处理模板路径解析

## 📝 XML 布局语法

### 支持的节点类型

#### 基础组件
- `container`: 容器
- `view`: 普通视图
- `text`: 文本标签
- `button`: 按钮
- `image`: 图片
- `input`: 输入框（UITextField）
- `scrollView`: 滚动视图

#### 新增 UI 组件
- `switch`: 开关（UISwitch）
- `slider`: 滑块（UISlider）

#### 自定义组件
- `list-view`: 列表视图（基于 UICollectionView，支持多模板）
- `circle`: 圆形视图（示例自定义组件）

#### 特殊节点
- `template`: 模板定义（用于 ListView 的 item 模板）

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
    cornerRadius="12"
    onClick="handleClick()">
</button>
```

### Switch 属性
```xml
<switch 
    value="{{ viewModel.switchValue }}"
    onTintColor="#34C759"
    thumbTintColor="#FFFFFF"
    onChange="onSwitchChange(item.id, value)"
    width="51"
    height="31"/>
```

### Slider 属性
```xml
<slider 
    value="{{ viewModel.sliderValue }}"
    minimumValue="0"
    maximumValue="100"
    minimumTrackTintColor="#007AFF"
    maximumTrackTintColor="#E0E0E0"
    thumbTintColor="#007AFF"
    onChange="onSliderChange(item.id, value)"
    width="100%"
    height="31"/>
```

### ListView 属性
```xml
<list-view 
    dataSource="{{ viewModel.todoList }}"
    flexGrow="1"
    width="100%"
    backgroundColor="#F2F2F7"
    padding="10">
    
    <!-- 定义 item 模板 -->
    <template type="item">
        <view width="100%" height="70" backgroundColor="white" cornerRadius="12">
            <text text="{{ item.title }}" fontSize="16" fontWeight="bold"/>
            <text text="{{ item.subtitle }}" fontSize="12" color="#8E8E93"/>
        </view>
    </template>
</list-view>
```

### 表达式支持
```xml
<!-- 文本表达式 -->
<text text="{{ viewModel.title }}"/>

<!-- 条件渲染 -->
<view if="{{ viewModel.isVisible }}">
    <text text="可见内容"/>
</view>

<!-- 循环渲染 -->
<view for="{{ item in viewModel.items }}">
    <text text="{{ item.name }}"/>
</view>
```

## 📊 JSON 数据格式

### 基本格式
```json
{
  "navTitle": "页面标题",
  "inputText": "",
  "isRefreshing": false,
  "todoList": [
    {
      "id": "1",
      "templateType": "item",
      "title": "任务 1",
      "subtitle": "描述信息"
    }
  ]
}
```

### 数据绑定到表达式
XML 中的 `{{ viewModel.property }}` 会自动从 JSON 中读取对应的值。

## 💻 JavaScript 逻辑

### logic.js 文件结构
```javascript
// 页面加载时初始化
function initSystemSettings() {
    Pimeier.System.getBrightness()
        .then(function(brightness) {
            viewModel.brightness = brightness * 100;
        });
}

// 事件处理函数
function onSwitchChange(id, value) {
    log("Switch changed: " + id + " = " + value);
    Pimeier.Toast.show("开关已" + (value ? "开启" : "关闭"));
}

function onSliderChange(id, value) {
    if (id === "slider_brightness") {
        var brightness = value / 100.0;
        Pimeier.System.setBrightness({ value: brightness });
    }
}

// 按钮点击事件
function handleClick() {
    Pimeier.Toast.show("按钮被点击了！");
    Pimeier.Device.vibrate();
}
```

### Native Bridge API
```javascript
// Toast 提示
Pimeier.Toast.show("消息内容");

// 设备信息
Pimeier.Device.getInfo()
    .then(function(info) {
        log("设备型号: " + info.model);
    });

// 设备震动
Pimeier.Device.vibrate();

// 系统功能
Pimeier.System.getBrightness()
    .then(function(brightness) {
        log("当前亮度: " + brightness);
    });

Pimeier.System.setBrightness({ value: 0.8 })
    .then(function(result) {
        log("亮度设置成功");
    });
```

## 🚀 使用方法

### 1. 创建页面模板

在 `HelloYoga/pimeierPages/` 目录下创建模板文件夹，例如 `my_page/`:

```
my_page/
├── my_page_layout.xml    # 布局文件
├── my_page_data.json     # 数据文件
└── my_page_logic.js      # 逻辑文件（可选）
```

### 2. 编写 XML 布局

`my_page_layout.xml`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<container flexDirection="column" width="100%" height="100%">
    <view height="100" backgroundColor="#007AFF" justifyContent="center" paddingLeft="20">
        <text text="{{ viewModel.navTitle }}" fontSize="20" fontWeight="bold" color="white"/>
    </view>
    
    <list-view dataSource="{{ viewModel.todoList }}" flexGrow="1" width="100%">
        <template type="item">
            <view width="100%" height="70" backgroundColor="white" cornerRadius="12" padding="15">
                <text text="{{ item.title }}" fontSize="16" fontWeight="bold"/>
                <text text="{{ item.subtitle }}" fontSize="12" color="#8E8E93" marginTop="4"/>
            </view>
        </template>
    </list-view>
</container>
```

### 3. 编写 JSON 数据

`my_page_data.json`:
```json
{
  "navTitle": "我的页面",
  "todoList": [
    {
      "id": "1",
      "templateType": "item",
      "title": "任务 1",
      "subtitle": "这是第一个任务"
    }
  ]
}
```

### 4. 编写 JavaScript 逻辑（可选）

`my_page_logic.js`:
```javascript
function onItemClick(item) {
    Pimeier.Toast.show("点击了: " + item.title);
}

function addTask() {
    var newTask = {
        id: Date.now().toString(),
        templateType: "item",
        title: "新任务",
        subtitle: "刚刚添加的"
    };
    viewModel.todoList.push(newTask);
    render();
}
```

### 5. 在 ViewController 中使用

```swift
import Pimeier

class MyViewController: PimeierViewController {
    init() {
        super.init(templateID: "my_page")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
```

### 6. 热重载开发

启动本地开发服务器：
```bash
cd HelloYoga
./start_dev_server.sh
```

修改 XML/JSON/JS 文件后，应用会自动检测变化并刷新页面。

## ✨ 核心特性

### Level 1: 基础布局
- ✅ **声明式布局**: 使用 XML 描述页面结构，无需写代码
- ✅ **Flexbox 布局**: 强大的 Yoga 布局引擎
- ✅ **数据绑定**: JSON 数据自动绑定到 UI 组件
- ✅ **样式系统**: 支持颜色、字体、边距等完整样式属性

### Level 2: 模板引擎
- ✅ **表达式支持**: `{{ viewModel.property }}` 动态数据绑定
- ✅ **条件渲染**: `if="{{ condition }}"` 条件显示/隐藏
- ✅ **循环渲染**: `for="{{ item in list }}"` 列表渲染
- ✅ **事件绑定**: `onClick="functionName()"` 交互处理

### Level 3: JavaScript 运行时
- ✅ **JS 逻辑**: 支持 `logic.js` 文件，处理业务逻辑
- ✅ **数据驱动**: `viewModel` 数据模型，支持动态更新
- ✅ **函数调用**: JavaScript 函数可以调用 Native 功能

### Level 4: Native Bridge
- ✅ **Toast 模块**: 显示提示消息
- ✅ **Device 模块**: 获取设备信息、震动反馈
- ✅ **System 模块**: 调节亮度、音量等系统功能
- ✅ **可扩展**: 轻松添加新的 Native 模块

### Level 5: 自定义组件
- ✅ **组件注册**: 支持注册自定义 UI 组件
- ✅ **ListView**: 高性能列表组件（基于 UICollectionView）
- ✅ **多模板支持**: ListView 支持多种 cell 样式
- ✅ **组件协议**: `PimeierComponent` 协议规范

### 开发体验
- ✅ **热重载**: 开发时实时预览 XML/JSON/JS 修改
- ✅ **模板系统**: 独立的页面模板，支持版本管理
- ✅ **类型安全**: Swift 类型系统保证安全性
- ✅ **易于扩展**: 可以轻松添加新的组件和功能

## 🎨 示例

### test_demo 页面
查看 `HelloYoga/pimeierPages/test_demo/` 了解完整示例，包括：
- 多种 ListView cell 样式（item、header、button、switch、slider、large、compact）
- Switch 和 Slider 组件使用
- 实时调节系统亮度和音量
- 下拉刷新功能
- JavaScript 事件处理

### todo_list 页面
查看 `HelloYoga/pimeierPages/todo_list/` 了解 TODO 应用示例。

运行项目后，你会看到：
- 动态加载的页面内容
- 交互式组件（Switch、Slider）
- 实时数据更新
- 所有布局使用 Flexbox 自动计算

## 🔧 技术栈

- **语言**: Swift 5
- **布局引擎**: Facebook Yoga (YogaKit)
- **JavaScript 引擎**: JavaScriptCore
- **解析**: XMLParser (Foundation)
- **数据格式**: XML + JSON + JavaScript
- **依赖管理**: CocoaPods (本地 Pod)
- **UI 框架**: UIKit

## 📚 开发文档

- **[组件封装指南](./HelloYoga/组件封装指南.md)**: 如何封装新的 UI 组件（Switch、Slider 等）
- **[Bridge 开发指南](./HelloYoga/Bridge开发指南.md)**: 如何开发 Native Bridge 模块
- **[测试指南](./测试指南.md)**: 开发调试和测试说明
- **[README_DEV.md](./README_DEV.md)**: 开发环境配置

## 📚 相关资源

- [Yoga 官方文档](https://yogalayout.com/)
- [Flexbox 指南](https://css-tricks.com/snippets/css/a-guide-to-flexbox/)
- [Facebook Yoga GitHub](https://github.com/facebook/yoga)
- [JavaScriptCore 文档](https://developer.apple.com/documentation/javascriptcore)

## 🛠️ 已实现功能

- ✅ 支持更多 UI 组件（Switch, Slider, TextField, ListView 等）
- ✅ 支持条件渲染和循环（`if`、`for` 指令）
- ✅ 支持表达式和数据绑定（`{{ }}` 语法）
- ✅ 支持 JavaScript 逻辑处理
- ✅ 添加热重载功能（开发时实时预览）
- ✅ Native Bridge 系统（Toast、Device、System 模块）
- ✅ 自定义组件系统（PimeierComponent）
- ✅ 高性能 ListView（基于 UICollectionView）

## 🚧 计划中的功能

- [ ] 支持动画和过渡效果
- [ ] 支持样式继承和主题系统
- [ ] 支持远程 XML 和 JSON 加载
- [ ] 添加布局预览工具
- [ ] 支持更多 Native 模块（相机、定位、通知等）

---

## 🎯 快速开始

1. **克隆项目**
   ```bash
   git clone <repository-url>
   cd HelloYoga
   ```

2. **安装依赖**
   ```bash
   pod install
   ```

3. **启动开发服务器**（可选，用于热重载）
   ```bash
   ./start_dev_server.sh
   ```

4. **打开项目**
   ```bash
   open HelloYoga.xcworkspace
   ```

5. **运行项目**
   - 选择目标设备或模拟器
   - 点击运行按钮
   - 查看 `test_demo` 页面示例

---

**享受 Pimeier 框架带来的声明式开发体验！** 🎉

