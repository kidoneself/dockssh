#!/bin/bash
# MoviePilot 影视自动化管理工具

DOCKER_DIR=$1
MEDIA_DIR=$2
PROXY=$3

echo ""
echo "========================================="
echo "🎬 开始安装 MoviePilot"
echo "========================================="
echo "📌 Docker目录: $DOCKER_DIR"
echo "📌 媒体目录: $MEDIA_DIR"
echo "📌 代理地址: ${PROXY:-未配置}"
echo ""

# 创建目录
echo "➤ [1/6] 创建目录..."
mkdir -p "$DOCKER_DIR/moviepilot/config" "$DOCKER_DIR/moviepilot/core" "$MEDIA_DIR" && echo "   ✓ 目录创建成功"

# 下载配置文件
echo "➤ [2/6] 下载 MoviePilot 配置文件..."
DOWNLOAD_URL="https://dockpilot.oss-cn-shanghai.aliyuncs.com/moviepilot.tgz"
TEMP_FILE="/tmp/moviepilot.tgz"

if curl -sS -L -o "$TEMP_FILE" "$DOWNLOAD_URL" && [ -s "$TEMP_FILE" ]; then
    echo "   ✓ 配置文件下载成功"
    echo "     解压配置文件..."
    cd "$DOCKER_DIR/moviepilot"
    tar -zxf "$TEMP_FILE" --strip-components=1 2>/dev/null || tar -zxf "$TEMP_FILE"
    rm -f "$TEMP_FILE"
    echo "   ✓ 配置文件解压完成"
else
    echo "   ⚠️ 配置文件下载失败，跳过（将使用默认配置）"
    rm -f "$TEMP_FILE"
fi

# 设置权限
echo "➤ [3/6] 设置权限..."
chmod -R 777 "$DOCKER_DIR/moviepilot" "$MEDIA_DIR" && echo "   ✓ 权限设置完成"

# 创建Docker网络
echo "➤ [4/6] 创建Docker网络..."
docker network inspect moviepilot-network >/dev/null 2>&1 || docker network create moviepilot-network --driver bridge
echo "   ✓ 网络就绪"

# 拉取镜像
echo "➤ [5/6] 拉取 MoviePilot 镜像..."
docker pull jxxghp/moviepilot-v2:latest

# 停止旧容器
docker stop moviepilot 2>/dev/null || true
docker rm moviepilot 2>/dev/null || true

# 启动容器
echo "➤ [6/6] 启动容器..."
docker run -d \
    --name moviepilot \
    --hostname moviepilot-v2 \
    --restart unless-stopped \
    --network moviepilot-network \
    -p 3000:3000 \
    -p 3001:3001 \
    -v "$MEDIA_DIR:/media" \
    -v "$DOCKER_DIR/moviepilot/config:/config" \
    -v "$DOCKER_DIR/moviepilot/core:/moviepilot/.cache/ms-playwright" \
    -v "/var/run/docker.sock:/var/run/docker.sock:ro" \
    -e "NGINX_PORT=3000" \
    -e "PORT=3001" \
    -e "PUID=0" \
    -e "PGID=0" \
    -e "UMASK=000" \
    -e "TZ=Asia/Shanghai" \
    -e "SUPERUSER=admin" \
    -e "SUPERUSER_PASSWORD=a123456!@" \
    ${PROXY:+-e "PROXY_HOST=$PROXY"} \
    -e "AUTH_SITE=hhclub" \
    -e "HHCLUB_USERNAME=kidoneself" \
    -e "HHCLUB_PASSKEY=0bd1c21acf6d3880e34e3fa5489ccdca" \
    --add-host "host.docker.internal:host-gateway" \
    jxxghp/moviepilot-v2:latest

# 检查状态
docker ps | grep moviepilot

echo ""
echo "========================================="
echo "✅ MoviePilot 安装完成！"
echo "========================================="
echo "🌐 访问地址: http://你的IP:3000"
echo "🔧 管理端口: http://你的IP:3001"
echo "👤 用户名: admin"
echo "🔑 密码: a123456!@"
echo ""

