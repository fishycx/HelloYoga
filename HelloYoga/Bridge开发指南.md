# Pimeier Native Bridge 开发指南

本文档详细说明如何在 Pimeier 框架中开发 Native Bridge 模块，扩展 JavaScript 的能力，使其可以调用原生 iOS 功能。

## 目录

1. [概述](#概述)
2. [Bridge 架构](#bridge-架构)
3. [开发步骤](#开发步骤)
4. [完整示例](#完整示例)
5. [最佳实践](#最佳实践)

---

## 概述

Pimeier Native Bridge (PNB) 是一个桥接机制，允许 JavaScript 代码调用原生 iOS 功能。通过 Bridge，你可以：

- 访问系统功能（如相机、定位、通知等）
- 调用原生 UI 组件（如 Toast、Alert 等）
- 获取设备信息（如设备型号、系统版本等）
- 执行系统级操作（如调节亮度、音量等）

### Bridge 工作流程

```
JavaScript (Pimeier.System.setBrightness)
    ↓
JS SDK Shim (Promise 封装)
    ↓
BridgeManager (路由分发)
    ↓
Native Module (SystemModule.setBrightness)
    ↓
iOS API (UIScreen.main.brightness)
    ↓
Callback (Promise resolve/reject)
```

---

## Bridge 架构

### 核心组件

1. **`PimeierModule` 协议**：定义模块接口
2. **`BridgeManager`**：模块注册和消息分发中心
3. **`PimeierJSEngine`**：JS SDK Shim 注入
4. **具体模块实现**：如 `ToastModule`、`DeviceModule`、`SystemModule`

### 文件结构

```
LocalPods/Pimeier/Classes/
├── Core/
│   └── PimeierModule.swift          # 模块协议定义
├── Bridge/
│   ├── BridgeManager.swift          # Bridge 管理器
│   └── Modules/
│       ├── ToastModule.swift        # Toast 模块示例
│       ├── DeviceModule.swift       # 设备信息模块
│       └── SystemModule.swift       # 系统功能模块（亮度、音量）
└── Engine/
    └── PimeierJSEngine.swift        # JS 引擎和 SDK Shim
```

---

## 开发步骤

### 步骤 1: 创建模块类

**文件位置**: `LocalPods/Pimeier/Classes/Bridge/Modules/YourModule.swift`

创建一个新的 Swift 文件，实现 `PimeierModule` 协议：

```swift
import UIKit

public class YourModule: PimeierModule {
    // 1. 定义模块名称（JS 端访问的对象名）
    public static let moduleName = "YourModule"
    
    // 2. 实现必需的初始化器
    public required init() {}
    
    // 3. 定义模块方法映射表
    public func methods() -> [String: PimeierModuleMethod] {
        return [
            "methodName1": method1,
            "methodName2": method2
        ]
    }
    
    // 4. 实现具体的方法
    private func method1(params: [String: Any], callback: PimeierModuleCallback) {
        // 从 params 中获取参数
        guard let param1 = params["param1"] as? String else {
            callback.failure("Missing parameter: param1")
            return
        }
        
        // 执行原生操作
        // ...
        
        // 返回结果
        callback.success(result)
    }
    
    private func method2(params: [String: Any], callback: PimeierModuleCallback) {
        // 实现逻辑
    }
}
```

### 步骤 2: 注册模块

**文件位置**: `HelloYoga/AppDelegate.swift`

在应用启动时注册模块：

```swift
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    // 注册 Native Bridge 模块
    BridgeManager.shared.register(ToastModule.self)
    BridgeManager.shared.register(DeviceModule.self)
    BridgeManager.shared.register(SystemModule.self)
    BridgeManager.shared.register(YourModule.self)  // 注册你的新模块
    
    return true
}
```

### 步骤 3: 添加 JS SDK 支持（可选）

**文件位置**: `LocalPods/Pimeier/Classes/Engine/PimeierJSEngine.swift`

如果希望提供更友好的 JS API，可以在 JS SDK Shim 中添加：

```swift
let sdkScript = """
var Pimeier = {
    // ... 现有模块 ...
    
    // YourModule 模块
    YourModule: {
        methodName1: function(params) { 
            return Pimeier.invoke('YourModule', 'methodName1', params); 
        },
        methodName2: function(params) { 
            return Pimeier.invoke('YourModule', 'methodName2', params); 
        }
    }
};
"""
```

**注意**：如果不添加 JS SDK，JavaScript 端仍然可以通过 `Pimeier.invoke('YourModule', 'methodName1', params)` 调用。

---

## 完整示例

### 示例：SystemModule（系统功能模块）

#### 1. 模块实现

```swift
// LocalPods/Pimeier/Classes/Bridge/Modules/SystemModule.swift

import UIKit
import MediaPlayer
import AVFoundation

public class SystemModule: PimeierModule {
    public static let moduleName = "System"
    
    public required init() {}
    
    public func methods() -> [String: PimeierModuleMethod] {
        return [
            "getBrightness": getBrightness,
            "setBrightness": setBrightness,
            "getVolume": getVolume,
            "setVolume": setVolume
        ]
    }
    
    /// 获取当前屏幕亮度
    private func getBrightness(params: [String: Any], callback: PimeierModuleCallback) {
        let brightness = UIScreen.main.brightness
        callback.success(brightness)
    }
    
    /// 设置屏幕亮度
    /// 参数: { "value": 0.0-1.0 }
    private func setBrightness(params: [String: Any], callback: PimeierModuleCallback) {
        guard let valueAny = params["value"] else {
            callback.failure("Missing parameter: value (0.0-1.0)")
            return
        }
        
        let value: Double
        switch valueAny {
        case let d as Double:
            value = d
        case let f as Float:
            value = Double(f)
        case let i as Int:
            value = Double(i)
        case let s as String:
            value = Double(s) ?? 0
        default:
            callback.failure("Invalid type for value")
            return
        }
        
        let brightness = max(0.0, min(1.0, Double(value)))
        UIScreen.main.brightness = CGFloat(brightness)
        
        callback.success(brightness)
    }
    
    /// 获取当前系统音量
    private func getVolume(params: [String: Any], callback: PimeierModuleCallback) {
        let audioSession = AVAudioSession.sharedInstance()
        var volume: Float = 0.5
        
        do {
            try audioSession.setActive(true)
            volume = audioSession.outputVolume
        } catch {
            print("⚠️ [System] Failed to get volume: \(error)")
        }
        
        callback.success(volume)
    }
    
    /// 设置系统音量
    /// 注意：iOS 系统限制，应用无法直接设置系统音量
    private func setVolume(params: [String: Any], callback: PimeierModuleCallback) {
        guard let valueAny = params["value"] else {
            callback.failure("Missing parameter: value (0.0-1.0)")
            return
        }
        
        let value: Double
        switch valueAny {
        case let d as Double:
            value = d
        case let f as Float:
            value = Double(f)
        case let i as Int:
            value = Double(i)
        case let s as String:
            value = Double(s) ?? 0
        default:
            callback.failure("Invalid type for value")
            return
        }
        
        let volume = max(0.0, min(1.0, Float(value)))
        
        // 使用 MPVolumeView 的私有 API（仅用于演示，生产环境需谨慎）
        let volumeView = MPVolumeView(frame: .zero)
        volumeView.isHidden = true
        
        if let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider {
            slider.value = volume
            slider.sendActions(for: .valueChanged)
            callback.success(volume)
        } else {
            callback.failure("iOS system restriction: Cannot directly set system volume")
        }
    }
}
```

#### 2. 注册模块

```swift
// HelloYoga/AppDelegate.swift

BridgeManager.shared.register(SystemModule.self)
```

#### 3. 添加 JS SDK 支持

```swift
// LocalPods/Pimeier/Classes/Engine/PimeierJSEngine.swift

System: {
    getBrightness: function() { return Pimeier.invoke('System', 'getBrightness'); },
    setBrightness: function(params) { return Pimeier.invoke('System', 'setBrightness', params); },
    getVolume: function() { return Pimeier.invoke('System', 'getVolume'); },
    setVolume: function(params) { return Pimeier.invoke('System', 'setVolume', params); }
}
```

#### 4. JavaScript 使用示例

```javascript
// 获取当前亮度
Pimeier.System.getBrightness()
    .then(function(brightness) {
        log("当前亮度: " + brightness);
    })
    .catch(function(error) {
        log("获取亮度失败: " + error);
    });

// 设置亮度
Pimeier.System.setBrightness({ value: 0.8 })
    .then(function(result) {
        log("亮度设置成功: " + result);
    })
    .catch(function(error) {
        log("亮度设置失败: " + error);
    });

// 在 Slider 的 onChange 事件中使用
function onSliderChange(id, value) {
    if (id === "slider_brightness") {
        // 将 0-100 转换为 0-1
        var brightness = value / 100.0;
        Pimeier.System.setBrightness({ value: brightness })
            .then(function(result) {
                log("亮度设置成功: " + result);
            })
            .catch(function(error) {
                log("亮度设置失败: " + error);
            });
    }
}
```

---

## 最佳实践

### 1. 参数类型处理

由于 JavaScript 和 Swift 之间的类型转换，建议支持多种类型：

```swift
private func setBrightness(params: [String: Any], callback: PimeierModuleCallback) {
    guard let valueAny = params["value"] else {
        callback.failure("Missing parameter: value")
        return
    }
    
    let value: Double
    switch valueAny {
    case let d as Double:
        value = d
    case let f as Float:
        value = Double(f)
    case let i as Int:
        value = Double(i)
    case let s as String:
        value = Double(s) ?? 0
    default:
        callback.failure("Invalid type for value")
        return
    }
    
    // 使用 value...
}
```

### 2. 错误处理

始终提供清晰的错误信息：

```swift
guard let message = params["message"] as? String else {
    callback.failure("Missing parameter: message")
    return
}
```

### 3. 主线程执行

所有涉及 UI 的操作都应该在主线程执行。`BridgeManager` 已经自动将所有调用派发到主线程，但如果你需要异步操作，记得切换回主线程：

```swift
private func someAsyncOperation(params: [String: Any], callback: PimeierModuleCallback) {
    // 异步操作
    DispatchQueue.global().async {
        // 执行耗时操作
        let result = performHeavyOperation()
        
        // 回到主线程返回结果
        DispatchQueue.main.async {
            callback.success(result)
        }
    }
}
```

### 4. Promise 风格 API

JavaScript 端使用 Promise 风格，确保方法返回 Promise：

```javascript
// ✅ 正确：返回 Promise
Pimeier.System.setBrightness({ value: 0.8 })
    .then(function(result) {
        // 处理成功
    })
    .catch(function(error) {
        // 处理错误
    });

// ❌ 错误：不要期望同步返回
var result = Pimeier.System.setBrightness({ value: 0.8 }); // 这会返回 Promise，不是结果
```

### 5. 模块命名规范

- 模块名使用 PascalCase：`SystemModule`、`DeviceModule`
- JS 端访问名使用相同的名称：`Pimeier.System`、`Pimeier.Device`
- 方法名使用 camelCase：`getBrightness`、`setVolume`

### 6. 参数验证

始终验证参数的有效性：

```swift
private func setBrightness(params: [String: Any], callback: PimeierModuleCallback) {
    guard let valueAny = params["value"] else {
        callback.failure("Missing parameter: value (0.0-1.0)")
        return
    }
    
    // 类型转换和范围检查
    let value = max(0.0, min(1.0, Double(value)))
    
    // 执行操作
    UIScreen.main.brightness = CGFloat(value)
    callback.success(value)
}
```

### 7. 日志记录

添加适当的日志，便于调试：

```swift
private func setBrightness(params: [String: Any], callback: PimeierModuleCallback) {
    print("🔆 [System] Setting brightness: \(params)")
    // ...
    print("✅ [System] Brightness set successfully")
}
```

### 8. 系统限制处理

某些功能可能受到 iOS 系统限制，需要提供替代方案或清晰的错误信息：

```swift
private func setVolume(params: [String: Any], callback: PimeierModuleCallback) {
    // iOS 系统限制：应用无法直接设置系统音量
    // 使用 MPVolumeView 的私有 API（可能被拒审）
    // 或者返回错误信息，建议用户使用系统音量控制
    
    let volumeView = MPVolumeView(frame: .zero)
    volumeView.isHidden = true
    
    if let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider {
        slider.value = volume
        slider.sendActions(for: .valueChanged)
        callback.success(volume)
    } else {
        callback.failure("iOS system restriction: Cannot directly set system volume. Please use system volume controls.")
    }
}
```

---

## 常见问题

### Q1: 如何传递复杂对象？

A: 使用字典传递，JavaScript 端会自动序列化：

```javascript
// JavaScript
Pimeier.YourModule.method({
    name: "John",
    age: 30,
    tags: ["developer", "iOS"]
});
```

```swift
// Swift
private func method(params: [String: Any], callback: PimeierModuleCallback) {
    let name = params["name"] as? String
    let age = params["age"] as? Int
    let tags = params["tags"] as? [String]
}
```

### Q2: 如何返回复杂对象？

A: 返回字典，会自动序列化为 JavaScript 对象：

```swift
private func getInfo(params: [String: Any], callback: PimeierModuleCallback) {
    let info: [String: Any] = [
        "name": "John",
        "age": 30,
        "tags": ["developer", "iOS"]
    ]
    callback.success(info)
}
```

```javascript
// JavaScript
Pimeier.YourModule.getInfo()
    .then(function(info) {
        log(info.name);  // "John"
        log(info.age);   // 30
        log(info.tags);  // ["developer", "iOS"]
    });
```

### Q3: 如何处理异步操作？

A: 在异步操作完成后调用 callback：

```swift
private func asyncOperation(params: [String: Any], callback: PimeierModuleCallback) {
    DispatchQueue.global().async {
        // 执行异步操作
        let result = performAsyncWork()
        
        DispatchQueue.main.async {
            callback.success(result)
        }
    }
}
```

### Q4: 模块方法会在哪个线程执行？

A: `BridgeManager` 会自动将所有调用派发到主线程，所以你的方法实现会在主线程执行。如果需要进行耗时操作，应该切换到后台线程，然后在完成后回到主线程调用 callback。

---

## 参考

- **SystemModule 实现**: `LocalPods/Pimeier/Classes/Bridge/Modules/SystemModule.swift`
- **DeviceModule 实现**: `LocalPods/Pimeier/Classes/Bridge/Modules/DeviceModule.swift`
- **ToastModule 实现**: `LocalPods/Pimeier/Classes/Bridge/Modules/ToastModule.swift`
- **BridgeManager**: `LocalPods/Pimeier/Classes/Bridge/BridgeManager.swift`
- **PimeierModule 协议**: `LocalPods/Pimeier/Classes/Core/PimeierModule.swift`

---

## 总结

开发一个 Bridge 模块的完整流程：

1. ✅ 创建模块类，实现 `PimeierModule` 协议
2. ✅ 在 `AppDelegate` 中注册模块
3. ✅ （可选）在 `PimeierJSEngine` 中添加 JS SDK 支持
4. ✅ 在 JavaScript 中使用 `Pimeier.YourModule.methodName(params)` 调用

完成以上步骤后，就可以在 Pimeier 页面中使用原生功能了！

