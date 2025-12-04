# Pimeier UI 开发指南

本文档是 Pimeier 框架的完整 UI 开发指南，涵盖从基础布局到高级功能的全部内容。

## 目录

1. [快速开始](#快速开始)
2. [页面结构](#页面结构)
3. [XML 布局语法](#xml-布局语法)
4. [组件使用](#组件使用)
5. [数据绑定](#数据绑定)
6. [事件处理](#事件处理)
7. [样式系统](#样式系统)
8. [高级功能](#高级功能)
9. [最佳实践](#最佳实践)
10. [示例代码](#示例代码)

---

## 快速开始

### 1. 创建页面模板

在 `HelloYoga/pimeierPages/` 目录下创建模板文件夹：

```
my_page/
├── my_page_layout.xml    # 布局文件（必需）
├── my_page_data.json     # 数据文件（必需）
└── my_page_logic.js      # 逻辑文件（可选）
```

### 2. 编写 XML 布局

`my_page_layout.xml`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<container flexDirection="column" width="100%" height="100%">
    <view height="100" backgroundColor="#007AFF" justifyContent="center" paddingLeft="20">
        <text text="{{ viewModel.title }}" fontSize="20" fontWeight="bold" color="white"/>
    </view>
    
    <view flexGrow="1" padding="20">
        <text text="Hello Pimeier!" fontSize="18" color="#333333"/>
    </view>
</container>
```

### 3. 编写 JSON 数据

`my_page_data.json`:
```json
{
  "title": "我的页面"
}
```

### 4. 在 ViewController 中使用

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

---

## 页面结构

### 文件命名规范

- **布局文件**: `{templateID}_layout.xml`
- **数据文件**: `{templateID}_data.json`
- **逻辑文件**: `{templateID}_logic.js`

### 页面生命周期

1. **加载阶段**: 解析 XML、加载 JSON、执行 JS
2. **渲染阶段**: 构建视图树、应用样式、绑定数据
3. **交互阶段**: 处理用户事件、更新数据、刷新 UI

---

## XML 布局语法

### 基础结构

```xml
<?xml version="1.0" encoding="UTF-8"?>
<container flexDirection="column" width="100%" height="100%">
    <!-- 子组件 -->
</container>
```

### 支持的节点类型

#### 容器组件
- `container` - 根容器
- `view` - 普通视图容器
- `scrollView` - 滚动视图

#### 基础组件
- `text` - 文本标签
- `button` - 按钮
- `image` - 图片
- `input` - 输入框

#### 交互组件
- `switch` - 开关
- `slider` - 滑块

#### 自定义组件
- `list-view` - 列表视图（支持多模板）
- `circle` - 圆形视图（示例）

---

## 组件使用

### Text 文本组件

```xml
<text 
    text="Hello World"
    fontSize="16"
    fontWeight="bold"
    color="#333333"
    textAlign="center"
    numberOfLines="0"/>
```

**属性说明**:
- `text` - 文本内容（支持表达式 `{{ }}`）
- `fontSize` - 字体大小（数字）
- `fontWeight` - 字体粗细（regular/bold/semibold/light）
- `color` - 文字颜色（颜色名或十六进制）
- `textAlign` - 对齐方式（left/center/right）
- `numberOfLines` - 最大行数（0 表示不限制）

### Button 按钮组件

```xml
<button 
    title="点击我"
    titleColor="white"
    backgroundColor="#007AFF"
    fontSize="18"
    fontWeight="bold"
    cornerRadius="12"
    onClick="handleClick()"/>
```

**属性说明**:
- `title` - 按钮标题（支持表达式）
- `titleColor` - 标题颜色
- `backgroundColor` - 背景颜色
- `onClick` - 点击事件处理函数

### Image 图片组件

```xml
<!-- 网络图片 -->
<image 
    imageURL="{{ item.imageURL }}"
    imageName="placeholder"
    width="100%"
    height="200"
    contentMode="scaleAspectFit"
    cornerRadius="8"/>

<!-- 本地图片 -->
<image 
    imageName="AppIcon"
    width="100"
    height="100"/>
```

**属性说明**:
- `imageURL` - 网络图片地址（支持表达式）
- `imageName` - 本地图片名称或占位图
- `contentMode` - 图片显示模式（scaleAspectFit/scaleAspectFill/scaleToFill）
- 优先使用 `imageURL`，如果为空则使用 `imageName`

### Input 输入框组件

```xml
<input 
    text="{{ viewModel.inputText }}"
    placeholder="请输入内容"
    fontSize="16"
    textColor="#333333"
    backgroundColor="white"
    cornerRadius="8"
    paddingLeft="10"
    paddingRight="10"/>
```

**属性说明**:
- `text` - 输入框文本（支持双向绑定）
- `placeholder` - 占位符文本
- 支持双向数据绑定，输入会自动同步到 `viewModel`

### Switch 开关组件

```xml
<switch 
    value="{{ item.switchValue }}"
    onTintColor="#34C759"
    thumbTintColor="#FFFFFF"
    onChange="onSwitchChange(item.id, value)"
    width="51"
    height="31"/>
```

**属性说明**:
- `value` - 开关状态（支持双向绑定）
- `onTintColor` - 开启时的背景色
- `thumbTintColor` - 滑块颜色
- `onChange` - 状态改变事件（参数：id, value）

### Slider 滑块组件

```xml
<slider 
    value="{{ item.sliderValue }}"
    minimumValue="0"
    maximumValue="100"
    minimumTrackTintColor="#007AFF"
    maximumTrackTintColor="#E0E0E0"
    thumbTintColor="#007AFF"
    onChange="onSliderChange(item.id, value)"
    width="100%"
    height="31"/>
```

**属性说明**:
- `value` - 当前值（支持双向绑定）
- `minimumValue` - 最小值
- `maximumValue` - 最大值
- `minimumTrackTintColor` - 已填充轨道颜色
- `maximumTrackTintColor` - 未填充轨道颜色
- `thumbTintColor` - 滑块颜色
- `onChange` - 值改变事件（参数：id, value）

### ListView 列表组件

```xml
<list-view 
    dataSource="{{ viewModel.todoList }}"
    flexGrow="1"
    width="100%"
    backgroundColor="#F2F2F7"
    padding="10">
    
    <!-- 定义 item 模板 -->
    <template type="item">
        <view width="100%" height="70" backgroundColor="white" cornerRadius="12" padding="15">
            <text text="{{ item.title }}" fontSize="16" fontWeight="bold"/>
            <text text="{{ item.subtitle }}" fontSize="12" color="#8E8E93" marginTop="4"/>
        </view>
    </template>
    
    <!-- 可以定义多个模板 -->
    <template type="header">
        <view width="100%" height="50" backgroundColor="#F5F5F5">
            <text text="{{ item.title }}" fontSize="18" fontWeight="bold"/>
        </view>
    </template>
</list-view>
```

**属性说明**:
- `dataSource` - 数据源（数组表达式，如 `{{ viewModel.todoList }}`）
- 每个数据项需要 `templateType` 字段指定使用的模板
- 支持多个模板类型，通过 `type` 属性区分

**数据格式**:
```json
{
  "todoList": [
    {
      "templateType": "item",
      "title": "任务 1",
      "subtitle": "描述信息"
    },
    {
      "templateType": "header",
      "title": "分组标题"
    }
  ]
}
```

---

## 数据绑定

### 表达式语法

使用 `{{ }}` 包裹 JavaScript 表达式：

```xml
<text text="{{ viewModel.title }}"/>
<text text="{{ viewModel.count + 1 }}"/>
<text text="{{ item.name || '默认名称' }}"/>
```

### 双向绑定

某些组件支持双向数据绑定，修改会自动同步到 `viewModel`：

```xml
<!-- Input 双向绑定 -->
<input text="{{ viewModel.inputText }}"/>

<!-- Switch 双向绑定 -->
<switch value="{{ item.switchValue }}"/>

<!-- Slider 双向绑定 -->
<slider value="{{ item.sliderValue }}"/>
```

### 条件渲染

使用 `if` 属性控制组件显示/隐藏：

```xml
<view if="{{ viewModel.isVisible }}">
    <text text="可见内容"/>
</view>

<view if="{{ viewModel.count > 0 }}">
    <text text="有数据"/>
</view>
```

### 循环渲染

使用 `for` 属性渲染列表：

```xml
<view for="{{ item in viewModel.items }}">
    <text text="{{ item.name }}"/>
</view>
```

---

## 事件处理

### onClick 点击事件

```xml
<button title="点击我" onClick="handleClick()"/>
<view onClick="handleViewClick()">
    <text text="可点击的视图"/>
</view>
```

**JavaScript 处理函数**:
```javascript
function handleClick() {
    Pimeier.Toast.show("按钮被点击了！");
    // 更新数据
    viewModel.count = (viewModel.count || 0) + 1;
    render(); // 刷新 UI
}
```

### onChange 值改变事件

```xml
<switch onChange="onSwitchChange(item.id, value)"/>
<slider onChange="onSliderChange(item.id, value)"/>
```

**JavaScript 处理函数**:
```javascript
function onSwitchChange(id, value) {
    log("Switch changed: " + id + " = " + value);
    // 注意：双向绑定已经更新了 item.switchValue
    // 这里只需要处理业务逻辑
    Pimeier.Toast.show("开关已" + (value ? "开启" : "关闭"));
}
```

### 事件参数

- **onClick**: 无参数
- **onChange**: 
  - Switch: `(id, value)` - id 和布尔值
  - Slider: `(id, value)` - id 和数值
  - 在 ListView 中，`item` 和 `index` 会自动注入到上下文

---

## 样式系统

### Flexbox 布局属性

```xml
<view 
    flexDirection="column|row"
    justifyContent="flexStart|center|flexEnd|spaceBetween|spaceAround|spaceEvenly"
    alignItems="flexStart|center|flexEnd|stretch|baseline"
    flexWrap="noWrap|wrap"
    flex="1"
    flexGrow="1"
    flexShrink="1"/>
```

### 尺寸属性

```xml
<view 
    width="100|50%|auto"
    height="200|80%|auto"
    minWidth="100"
    maxWidth="500"
    minHeight="50"
    maxHeight="300"/>
```

### 间距属性

```xml
<view 
    padding="20"
    paddingTop="10"
    paddingRight="10"
    paddingBottom="10"
    paddingLeft="10"
    margin="20"
    marginTop="10"
    marginRight="10"
    marginBottom="10"
    marginLeft="10"/>
```

### 视觉样式

```xml
<view 
    backgroundColor="white|#FF0000|systemBlue"
    cornerRadius="12"
    borderWidth="1"
    borderColor="#E0E0E0"
    opacity="0.8"
    hidden="false"/>
```

### 颜色值格式

- **系统颜色**: `white`, `black`, `systemBlue`, `systemRed` 等
- **十六进制**: `#FF0000`, `#00FF00`, `#0000FF`
- **RGB**: 暂不支持，使用十六进制

---

## 高级功能

### Native Bridge 调用

在 JavaScript 中调用原生功能：

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

Pimeier.System.setBrightness({ value: 0.8 });

// 网络请求
Pimeier.Network.get({
    url: "https://api.example.com/data",
    headers: {"Authorization": "Bearer token"},
    timeout: 10
}).then(function(response) {
    log("数据: " + JSON.stringify(response.data));
}).catch(function(error) {
    log("错误: " + error);
});
```

### 网络请求

#### GET 请求
```javascript
Pimeier.Network.get({
    url: "https://api.example.com/posts/1",
    timeout: 10
}).then(function(response) {
    viewModel.data = response.data;
    render();
});
```

#### POST 请求
```javascript
Pimeier.Network.post({
    url: "https://api.example.com/posts",
    headers: {
        "Content-Type": "application/json"
    },
    body: {
        title: "标题",
        content: "内容"
    }
}).then(function(response) {
    Pimeier.Toast.show("提交成功！");
});
```

#### 文件下载
```javascript
Pimeier.Network.download({
    url: "https://example.com/file.pdf",
    savePath: "downloads/file.pdf"
}).then(function(response) {
    log("文件保存路径: " + response.filePath);
});
```

### 数据更新和 UI 刷新

```javascript
// 更新数据
viewModel.title = "新标题";
viewModel.count = 100;

// 刷新 UI（重新渲染整个页面）
render();

// 注意：对于双向绑定的组件（Switch、Slider），
// 值改变时不需要手动调用 render()
```

---

## 最佳实践

### 1. 布局设计

- **使用 Flexbox**: 充分利用 Flexbox 布局，避免固定尺寸
- **响应式设计**: 使用百分比和 `flexGrow` 实现响应式布局
- **组件复用**: 将常用布局封装为模板

### 2. 数据管理

- **单一数据源**: 所有数据存储在 `viewModel` 中
- **数据驱动**: 通过修改 `viewModel` 驱动 UI 更新
- **避免直接操作 DOM**: 使用 `render()` 统一刷新

### 3. 性能优化

- **避免频繁刷新**: 不要在每个事件处理中都调用 `render()`
- **使用条件渲染**: 用 `if` 属性控制组件显示，而不是频繁创建/销毁
- **ListView 优化**: ListView 自动使用 cell 重用机制

### 4. 代码组织

- **逻辑分离**: 将业务逻辑放在 `logic.js` 中
- **函数命名**: 使用有意义的函数名，如 `handleSubmit()`, `onItemClick()`
- **注释说明**: 为复杂逻辑添加注释

### 5. 错误处理

```javascript
Pimeier.Network.get({ url: "..." })
    .then(function(response) {
        // 处理成功
    })
    .catch(function(error) {
        // 处理错误
        Pimeier.Toast.show("请求失败: " + error);
        log("错误详情: " + error);
    });
```

### 6. 调试技巧

- **使用 log()**: 在 JavaScript 中使用 `log()` 输出调试信息
- **检查数据**: 使用 `log(JSON.stringify(viewModel))` 查看数据状态
- **热重载**: 开发时使用热重载功能，实时查看修改效果

---

## 示例代码

### 完整示例：TODO 列表

**布局文件** (`todo_layout.xml`):
```xml
<?xml version="1.0" encoding="UTF-8"?>
<container flexDirection="column" width="100%" height="100%">
    <!-- 头部 -->
    <view height="100" backgroundColor="#007AFF" justifyContent="center" paddingLeft="20">
        <text text="{{ viewModel.navTitle }}" fontSize="20" fontWeight="bold" color="white"/>
    </view>
    
    <!-- 输入区域 -->
    <view flexDirection="row" padding="15" backgroundColor="white">
        <input 
            text="{{ viewModel.inputText }}"
            placeholder="输入新任务"
            flexGrow="1"
            fontSize="16"
            backgroundColor="#F5F5F5"
            cornerRadius="8"
            paddingLeft="10"
            paddingRight="10"/>
        <button 
            title="添加"
            onClick="addTask()"
            marginLeft="10"
            backgroundColor="#007AFF"
            titleColor="white"
            cornerRadius="8"
            paddingLeft="20"
            paddingRight="20"/>
    </view>
    
    <!-- 列表 -->
    <list-view 
        dataSource="{{ viewModel.todoList }}"
        flexGrow="1"
        width="100%"
        backgroundColor="#F2F2F7"
        padding="10">
        
        <template type="item">
            <view 
                width="100%" 
                height="60" 
                backgroundColor="white" 
                cornerRadius="12"
                flexDirection="row"
                justifyContent="spaceBetween"
                alignItems="center"
                paddingLeft="15"
                paddingRight="15">
                <text text="{{ item.title }}" fontSize="16" color="#333333"/>
                <button 
                    title="删除"
                    onClick="deleteTask(item.id)"
                    backgroundColor="#FF3B30"
                    titleColor="white"
                    fontSize="14"
                    cornerRadius="6"
                    paddingLeft="15"
                    paddingRight="15"/>
            </view>
        </template>
    </list-view>
</container>
```

**数据文件** (`todo_data.json`):
```json
{
  "navTitle": "TODO 列表",
  "inputText": "",
  "todoList": [
    {
      "id": "1",
      "templateType": "item",
      "title": "学习 Pimeier"
    },
    {
      "id": "2",
      "templateType": "item",
      "title": "完成项目"
    }
  ]
}
```

**逻辑文件** (`todo_logic.js`):
```javascript
var nextId = 3;

function addTask() {
    var title = viewModel.inputText;
    if (!title || title.trim() === "") {
        Pimeier.Toast.show("请输入任务内容");
        return;
    }
    
    var newTask = {
        id: String(nextId++),
        templateType: "item",
        title: title.trim()
    };
    
    viewModel.todoList.push(newTask);
    viewModel.inputText = "";
    render();
    
    Pimeier.Toast.show("任务已添加");
}

function deleteTask(id) {
    var index = viewModel.todoList.findIndex(function(item) {
        return item.id === id;
    });
    
    if (index >= 0) {
        viewModel.todoList.splice(index, 1);
        render();
        Pimeier.Toast.show("任务已删除");
    }
}
```

---

## 常见问题

### Q: 如何实现下拉刷新？

A: ListView 组件内置下拉刷新功能，通过 `onRefresh` 属性绑定处理函数。

### Q: 如何实现上拉加载更多？

A: ListView 组件支持上拉加载，通过 `onLoadMore` 属性绑定处理函数。

### Q: 图片加载失败怎么办？

A: 网络图片加载失败会在控制台输出错误日志，可以设置 `imageName` 作为占位图。

### Q: 如何实现页面跳转？

A: 使用 Native 导航控制器，在 JavaScript 中调用原生导航方法（需要扩展 Bridge）。

### Q: 如何实现动画？

A: 当前版本暂不支持动画，可以通过数据驱动实现简单的过渡效果。

### Q: 如何自定义组件？

A: 参考 `组件封装指南.md`，实现 `PimeierComponent` 协议。

---

## 参考资源

- [组件封装指南](./组件封装指南.md) - 如何封装自定义 UI 组件
- [Bridge 开发指南](./Bridge开发指南.md) - 如何开发 Native Bridge 模块
- [README.md](../README.md) - 项目总体说明
- [测试指南](./测试指南.md) - 开发调试指南

---

**享受 Pimeier 框架带来的声明式开发体验！** 🎉

