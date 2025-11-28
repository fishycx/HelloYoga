#!/bin/bash

# 本地开发服务器启动脚本
# 用于实时调试 XML 和 JSON 文件

echo "🚀 启动本地开发服务器..."
echo ""

# 获取脚本所在目录
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$SCRIPT_DIR/HelloYoga"

# 检查目录是否存在
if [ ! -d "$PROJECT_DIR" ]; then
    echo "❌ 错误: 找不到项目目录: $PROJECT_DIR"
    exit 1
fi

# 切换到项目目录
cd "$PROJECT_DIR"

# 检查端口是否被占用
PORT=8080
if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null ; then
    echo "⚠️  端口 $PORT 已被占用"
    echo "   正在尝试使用其他端口..."
    PORT=8081
fi

# 显示所有可用的网络接口
show_network_interfaces() {
    echo "📡 可用的网络接口:"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        ifconfig | grep -E "^[a-z]|inet " | while read line; do
            if [[ $line =~ ^[a-z] ]]; then
                interface=$(echo $line | awk '{print $1}' | sed 's/:$//')
            elif [[ $line =~ inet ]]; then
                ip=$(echo $line | awk '{print $2}')
                if [ -n "$ip" ] && [ "$ip" != "127.0.0.1" ]; then
                    echo "   - $interface: $ip"
                fi
            fi
        done
    else
        # Linux
        ip addr show | grep -E "^[0-9]+:|inet " | while read line; do
            if [[ $line =~ ^[0-9]+: ]]; then
                interface=$(echo $line | awk '{print $2}' | sed 's/:$//')
            elif [[ $line =~ inet ]]; then
                ip=$(echo $line | awk '{print $2}' | cut -d'/' -f1)
                if [ -n "$ip" ] && [ "$ip" != "127.0.0.1" ]; then
                    echo "   - $interface: $ip"
                fi
            fi
        done
    fi
    echo ""
}

# 获取本机 IP 地址（排除 localhost）
get_local_ip() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS - 获取所有网络接口的 IP
        # 优先使用 en0 (WiFi), 然后是 en1 (以太网), 最后是其他接口
        for interface in en0 en1 bridge0; do
            ip=$(ipconfig getifaddr $interface 2>/dev/null)
            if [ -n "$ip" ] && [ "$ip" != "127.0.0.1" ]; then
                echo "$ip"
                return 0
            fi
        done
        
        # 如果上面都没找到，尝试从路由表获取默认接口的 IP
        default_interface=$(route get default 2>/dev/null | grep interface | awk '{print $2}')
        if [ -n "$default_interface" ]; then
            ip=$(ipconfig getifaddr $default_interface 2>/dev/null)
            if [ -n "$ip" ] && [ "$ip" != "127.0.0.1" ]; then
                echo "$ip"
                return 0
            fi
        fi
        
        # 最后尝试从 ifconfig 获取（排除 127.0.0.1）
        ip=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -n 1)
        if [ -n "$ip" ]; then
            echo "$ip"
            return 0
        fi
    else
        # Linux - 排除 127.x.x.x
        hostname -I 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i !~ /^127\./) {print $i; exit}}'
    fi
}

# 显示网络接口信息
show_network_interfaces

# 优先使用环境变量中的 IP
if [ -n "$LOCAL_IP" ]; then
    echo "✅ 使用环境变量中的 IP: $LOCAL_IP"
    echo ""
else
    LOCAL_IP=$(get_local_ip)
    
    # 检查 IP 是否有效
    if [ -z "$LOCAL_IP" ] || [ "$LOCAL_IP" = "127.0.0.1" ]; then
        echo "⚠️  警告: 无法自动获取有效的本地 IP 地址"
        echo ""
        echo "   请手动设置 IP 地址："
        echo "   1. 查看上面的网络接口列表"
        echo "   2. 找到你的 WiFi 接口（通常是 en0）对应的 IP"
        echo "   3. 使用环境变量设置："
        echo "      export LOCAL_IP=你的IP地址"
        echo "      ./start_dev_server.sh"
        echo ""
        LOCAL_IP="192.168.1.100"  # 默认值，用户需要修改
        echo "   当前使用默认 IP: $LOCAL_IP"
        echo "   ⚠️  如果这个 IP 不正确，请设置环境变量 LOCAL_IP"
        echo ""
    fi
fi

SERVER_URL="http://$LOCAL_IP:$PORT"

echo "📂 服务目录: $PROJECT_DIR"
echo "🌐 服务地址: $SERVER_URL"
echo "📄 访问文件: $SERVER_URL/page_layout.xml"
echo ""
echo "📋 网络信息:"
echo "   - 本机 IP: $LOCAL_IP"
echo "   - 端口: $PORT"
echo ""
echo "⚠️  重要提示:"
echo "   1. 确保手机和电脑连接到同一个 WiFi 网络"
echo "   2. 如果无法访问，请检查："
echo "      - 防火墙是否允许端口 $PORT"
echo "      - IP 地址是否正确（可在系统设置中查看）"
echo "      - 手机和电脑是否在同一网络"
echo ""

# 生成二维码
generate_qrcode() {
    if command -v qrencode &> /dev/null; then
        echo "📱 二维码（使用 qrencode）:"
        echo ""
        qrencode -t ANSI "$SERVER_URL" 2>/dev/null || qrencode -t UTF8 "$SERVER_URL"
        echo ""
    elif command -v python3 &> /dev/null; then
        echo "📱 生成二维码..."
        python3 << EOF
import sys
try:
    import qrcode
    qr = qrcode.QRCode(version=1, box_size=2, border=1)
    qr.add_data("$SERVER_URL")
    qr.make(fit=True)
    print("\n📱 二维码:")
    print("")
    qr.print_ascii(invert=True)
    print("")
    print("   或扫描上面的二维码连接到服务器")
except ImportError:
    print("💡 提示: 安装 qrcode 库可以显示二维码")
    print("   安装方法: pip3 install qrcode[pil]")
    print("   服务器地址: $SERVER_URL")
except Exception as e:
    print(f"⚠️  生成二维码失败: {e}")
    print("   服务器地址: $SERVER_URL")
EOF
    else
        echo "💡 服务器地址: $SERVER_URL"
        echo "   提示: 安装 qrencode 或 Python qrcode 库可以显示二维码"
    fi
}

generate_qrcode

echo "💡 使用说明:"
echo "   1. 在应用中点击 '扫描二维码' 按钮"
echo "   2. 扫描上面的二维码连接到服务器"
echo "   3. 修改 XML/JSON 文件后，在应用中点击 '🔄 刷新' 按钮即可看到效果"
echo "   4. 按 Ctrl+C 停止服务器"
echo ""

# 启动 Python HTTP 服务器
if command -v python3 &> /dev/null; then
    python3 -m http.server $PORT
elif command -v python &> /dev/null; then
    python -m SimpleHTTPServer $PORT
else
    echo "❌ 错误: 未找到 Python，请安装 Python 3"
    exit 1
fi

