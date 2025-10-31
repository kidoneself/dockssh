#!/bin/bash
# Roon Server 音乐服务器

DOCKER_DIR=$1
MUSIC_DIR=$2

echo ""
echo "========================================="
echo "🎵 开始安装 Roon Server"
echo "========================================="
echo "📌 Docker目录: $DOCKER_DIR"
echo "📌 音乐目录: $MUSIC_DIR"
echo ""

# 创建目录
echo "➤ [1/4] 创建目录..."
mkdir -p "$DOCKER_DIR/roon" "$DOCKER_DIR/roon/data" "$MUSIC_DIR" && echo "   ✓ 目录创建成功"

# 设置权限
echo "➤ [2/4] 设置权限..."
chmod -R 777 "$DOCKER_DIR/roon" "$MUSIC_DIR" && echo "   ✓ 权限设置完成"

# 拉取镜像
echo "➤ [3/4] 拉取 Roon Server 镜像..."
docker pull steefdebruijn/docker-roonserver:latest

# 停止旧容器
docker stop docker-roonserver 2>/dev/null || true
docker rm docker-roonserver 2>/dev/null || true

# 启动容器
echo "➤ [4/4] 启动容器..."
docker run -d \
    --name docker-roonserver \
    --restart always \
    --network host \
    -v "$DOCKER_DIR/roon:/app" \
    -v "$DOCKER_DIR/roon/data:/backup" \
    -v "$DOCKER_DIR/roon/data:/data" \
    -v "$MUSIC_DIR:/music" \
    steefdebruijn/docker-roonserver:latest

# 检查状态
docker ps | grep docker-roonserver

echo ""
echo "========================================="
echo "✅ Roon Server 安装完成！"
echo "========================================="
echo "💡 请在 Roon 客户端中搜索并连接服务器"
echo "📁 音乐目录: $MUSIC_DIR"
echo ""

