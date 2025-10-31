#!/bin/bash
# EmbyServer 媒体服务器

DOCKER_DIR=$1
MEDIA_DIR=$2

echo ""
echo "========================================="
echo "🎥 开始安装 EmbyServer"
echo "========================================="
echo "📌 Docker目录: $DOCKER_DIR"
echo "📌 媒体目录: $MEDIA_DIR"
echo ""

# 创建目录
echo "➤ [1/6] 创建目录..."
mkdir -p "$DOCKER_DIR/embyserver" "$MEDIA_DIR" && echo "   ✓ 目录创建成功"

# 下载配置文件
echo "➤ [2/6] 下载 EmbyServer 配置文件..."
DOWNLOAD_URL="https://dockpilot.oss-cn-shanghai.aliyuncs.com/embyserver.tgz"
TEMP_FILE="/tmp/embyserver.tgz"

if curl -sS -L -o "$TEMP_FILE" "$DOWNLOAD_URL" && [ -s "$TEMP_FILE" ]; then
    echo "   ✓ 配置文件下载成功"
    echo "     解压配置文件..."
    cd "$DOCKER_DIR/embyserver"
    tar -zxf "$TEMP_FILE" --strip-components=1 2>/dev/null || tar -zxf "$TEMP_FILE"
    rm -f "$TEMP_FILE"
    echo "   ✓ 配置文件解压完成"
else
    echo "   ⚠️ 配置文件下载失败，跳过（将使用默认配置）"
    rm -f "$TEMP_FILE"
fi

# 设置权限
echo "➤ [3/6] 设置权限..."
chmod 777 "$DOCKER_DIR/embyserver" && echo "   ✓ 权限设置完成"

# 创建Docker网络
echo "➤ [4/6] 检查Docker网络..."
docker network inspect moviepilot-network >/dev/null 2>&1 || docker network create moviepilot-network --driver bridge
echo "   ✓ 网络就绪"

# 拉取镜像
echo "➤ [5/6] 拉取 EmbyServer 镜像..."
if ! docker pull amilys/embyserver:latest; then
    echo "   ⚠️ 镜像拉取失败，请检查网络或配置镜像加速器"
    echo "   💡 配置方法: https://help.aliyun.com/document_detail/60750.html"
    exit 1
fi
echo "   ✓ 镜像拉取成功"

# 停止旧容器
docker stop embyserver 2>/dev/null || true
docker rm embyserver 2>/dev/null || true

# 启动容器
echo "➤ [6/6] 启动容器..."
docker run -d \
    --name embyserver \
    --restart unless-stopped \
    --network moviepilot-network \
    -p 8096:8096 \
    ${DEVICE_DRI:+--device "/dev/dri:/dev/dri"} \
    -v "$MEDIA_DIR:/media" \
    -v "$DOCKER_DIR/embyserver:/config" \
    -e "UID=0" \
    -e "GID=0" \
    -e "GIDLIST=0" \
    -e "TZ=Asia/Shanghai" \
    amilys/embyserver:latest

# 检查状态
docker ps | grep embyserver

echo ""
echo "========================================="
echo "✅ EmbyServer 安装完成！"
echo "========================================="
echo "🌐 访问地址: http://你的IP:8096"
echo "💡 首次访问需要配置管理员账户"
echo ""

