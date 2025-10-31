#!/bin/bash
# BiliLive-Go 哔哩哔哩直播录制

RECORD_DIR=$1
PORT=${2:-8090}

echo ""
echo "========================================="
echo "📺 开始安装 BiliLive-Go"
echo "========================================="
echo "📌 录制目录: $RECORD_DIR"
echo "📌 Web端口: $PORT"
echo ""

# 创建目录
echo "➤ [1/3] 创建目录..."
mkdir -p "$RECORD_DIR" && echo "   ✓ 目录创建成功"

# 设置权限
echo "➤ [2/3] 设置权限..."
chmod 777 "$RECORD_DIR" && echo "   ✓ 权限设置完成"

# 拉取镜像并启动
echo "➤ [3/3] 拉取镜像并启动容器..."
docker pull chigusa/bililive-go:latest

# 停止旧容器
docker stop bililive-go 2>/dev/null || true
docker rm bililive-go 2>/dev/null || true

docker run -d \
    --name bililive-go \
    --restart always \
    --network bridge \
    -p "$PORT:8080" \
    -v "$RECORD_DIR:/srv/bililive" \
    chigusa/bililive-go:latest

# 检查状态
docker ps | grep bililive-go

echo ""
echo "========================================="
echo "✅ BiliLive-Go 安装完成！"
echo "========================================="
echo "🌐 访问地址: http://你的IP:$PORT"
echo "📁 录制文件目录: $RECORD_DIR"
echo ""

