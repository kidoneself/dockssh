#!/bin/bash
# Transmission BT下载工具

DOCKER_DIR=$1
MEDIA_DIR=$2

echo ""
echo "========================================="
echo "📥 开始安装 Transmission"
echo "========================================="
echo "📌 Docker目录: $DOCKER_DIR"
echo "📌 媒体目录: $MEDIA_DIR"
echo ""

# 创建目录
echo "➤ [1/6] 创建目录..."
mkdir -p "$DOCKER_DIR/transmission" "$MEDIA_DIR" && echo "   ✓ 目录创建成功"

# 下载配置文件
echo "➤ [2/6] 下载 Transmission 配置文件..."
DOWNLOAD_URL="https://dockpilot.oss-cn-shanghai.aliyuncs.com/transmission.tgz"
TEMP_FILE="/tmp/transmission.tgz"

if curl -sS -L -o "$TEMP_FILE" "$DOWNLOAD_URL" && [ -s "$TEMP_FILE" ]; then
    echo "   ✓ 配置文件下载成功"
    echo "     解压配置文件..."
    cd "$DOCKER_DIR/transmission"
    tar -zxf "$TEMP_FILE" --strip-components=1 2>/dev/null || tar -zxf "$TEMP_FILE"
    rm -f "$TEMP_FILE"
    echo "   ✓ 配置文件解压完成"
else
    echo "   ⚠️ 配置文件下载失败，跳过（将使用默认配置）"
    rm -f "$TEMP_FILE"
fi

# 设置权限
echo "➤ [3/6] 设置权限..."
chmod 777 "$DOCKER_DIR/transmission" && echo "   ✓ 权限设置完成"

# 创建Docker网络
echo "➤ [4/6] 检查Docker网络..."
docker network inspect moviepilot-network >/dev/null 2>&1 || docker network create moviepilot-network --driver bridge
echo "   ✓ 网络就绪"

# 拉取镜像
echo "➤ [5/6] 拉取 Transmission 镜像..."
docker pull linuxserver/transmission:4.0.5

# 停止旧容器
docker stop transmission 2>/dev/null || true
docker rm transmission 2>/dev/null || true

# 启动容器
echo "➤ [6/6] 启动容器..."
docker run -d \
    --name transmission \
    --restart unless-stopped \
    --network moviepilot-network \
    -p 9091:9091 \
    -e "PUID=0" \
    -e "PGID=0" \
    -e "TZ=Asia/Shanghai" \
    -e "USER=admin" \
    -e "PASS=a123456!@" \
    -v "$MEDIA_DIR:/media" \
    -v "$DOCKER_DIR/transmission:/config" \
    linuxserver/transmission:4.0.5

# 检查状态
docker ps | grep transmission

echo ""
echo "========================================="
echo "✅ Transmission 安装完成！"
echo "========================================="
echo "🌐 访问地址: http://你的IP:9091"
echo "👤 用户名: admin"
echo "🔑 密码: a123456!@"
echo ""

