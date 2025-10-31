#!/bin/bash
# Clash 代理服务

DOCKER_DIR=$1
WEB_PORT=${2:-7888}
PROXY_PORT=${3:-7890}

echo ""
echo "========================================="
echo "🌐 开始安装 Clash"
echo "========================================="
echo "📌 Docker目录: $DOCKER_DIR"
echo "📌 Web端口: $WEB_PORT"
echo "📌 代理端口: $PROXY_PORT"
echo ""

# 创建目录
echo "➤ [1/3] 创建目录..."
mkdir -p "$DOCKER_DIR/clash" && echo "   ✓ 目录创建成功"

# 设置权限
echo "➤ [2/3] 设置权限..."
chmod 777 "$DOCKER_DIR/clash" && echo "   ✓ 权限设置完成"

# 拉取镜像并启动
echo "➤ [3/3] 拉取镜像并启动容器..."
docker pull laoyutang/clash-and-dashboard:latest

# 停止旧容器
docker stop clash 2>/dev/null || true
docker rm clash 2>/dev/null || true

docker run -d \
    --name clash \
    --restart always \
    --log-opt max-size=1m \
    -v "$DOCKER_DIR/clash:/root/.config/clash" \
    -p "$WEB_PORT:8080" \
    -p "$PROXY_PORT:7890" \
    laoyutang/clash-and-dashboard:latest

# 检查状态
docker ps | grep clash

echo ""
echo "========================================="
echo "✅ Clash 安装完成！"
echo "========================================="
echo "🌐 Web管理: http://你的IP:$WEB_PORT"
echo "🔧 HTTP代理: http://你的IP:$PROXY_PORT"
echo "📁 配置目录: $DOCKER_DIR/clash"
echo ""

