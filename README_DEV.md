# 实时调试指南

## 本地开发服务器设置

### 1. 启动本地服务器

在项目根目录运行：

```bash
./start_dev_server.sh
```

或者手动启动：

```bash
cd HelloYoga/HelloYoga
python3 -m http.server 8080
```

服务器启动后，可以通过以下地址访问文件：
- http://localhost:8080/page_layout.xml
- http://localhost:8080/page_data.json
- http://localhost:8080/test_layout.xml
- http://localhost:8080/test_data.json

### 2. 配置应用

应用默认在 Debug 模式下启用本地开发服务器，服务器地址为 `http://localhost:8080`。

如果需要修改服务器地址，可以在代码中设置：

```swift
LocalDevServer.shared.baseURL = "http://localhost:8080"
```

### 3. 使用实时调试

1. **启动本地服务器**（如上所述）

2. **运行应用**，应用会自动连接到本地服务器

3. **修改 XML 或 JSON 文件**（在 `HelloYoga/HelloYoga/` 目录下）

4. **点击应用中的 "🔄 刷新" 按钮**，应用会：
   - 从本地服务器下载最新文件
   - 保存到缓存目录
   - 自动重新加载布局

5. **或者等待自动检测**（如果启用了文件监听）

## 文件监听模式

应用支持两种文件监听模式：

### 轮询模式（默认）
- 每秒检查一次文件变化
- 更可靠，但消耗少量资源
- 适用于监听缓存目录中的文件

### 文件系统事件模式
- 使用系统事件监听文件变化
- 更高效，但可能在某些情况下不可靠
- 需要文件在可写目录中

## 注意事项

1. **Bundle 文件是只读的**：直接修改 Bundle 中的文件不会生效，需要通过本地服务器提供文件

2. **网络连接**：确保 iOS 模拟器或真机能够访问 `localhost:8080`
   - 模拟器：直接使用 `localhost` 或 `127.0.0.1`
   - 真机：需要使用电脑的 IP 地址，例如 `http://192.168.1.100:8080`

3. **防火墙**：确保防火墙允许 8080 端口的连接

4. **文件路径**：确保 XML 和 JSON 文件在 `HelloYoga/HelloYoga/` 目录下

## 真机调试

如果要在真机上调试，需要：

1. 找到电脑的 IP 地址：
   ```bash
   # macOS/Linux
   ifconfig | grep "inet "
   
   # 或
   ipconfig getifaddr en0
   ```

2. 修改服务器地址：
   ```swift
   LocalDevServer.shared.baseURL = "http://192.168.1.100:8080"  // 替换为你的 IP
   ```

3. 确保手机和电脑在同一 WiFi 网络下

## 故障排除

### 服务器无法连接
- 检查服务器是否正在运行
- 检查端口是否正确
- 检查防火墙设置

### 文件没有更新
- 确保文件已保存
- 点击"🔄 刷新"按钮手动刷新
- 检查控制台日志查看错误信息

### 真机无法连接
- 确保手机和电脑在同一网络
- 使用电脑的 IP 地址而不是 localhost
- 检查路由器是否允许设备间通信

