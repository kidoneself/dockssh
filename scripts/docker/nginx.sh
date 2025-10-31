#!/bin/bash
# Nginx 安装脚本

PORT=$1
DATA_PATH=$2

echo ""
echo "========================================="
echo "🚀 开始安装 Nginx"
echo "========================================="
echo "📌 端口: $PORT"
echo "📌 数据目录: $DATA_PATH"
echo ""

# 创建目录
echo "➤ [1/5] 创建目录..."
mkdir -p ${DATA_PATH}/html ${DATA_PATH}/conf && echo "   ✓ 目录创建成功" || echo "   ✗ 创建失败"

# 设置权限
echo "➤ [2/5] 设置权限..."
chmod -R 755 ${DATA_PATH} && echo "   ✓ 权限设置完成" || echo "   ✗ 设置失败"

# 拉取镜像
echo "➤ [3/5] 拉取 Nginx 镜像..."
docker pull nginx:latest

# 启动容器
echo "➤ [4/5] 启动容器..."
docker run -d \
  --name nginx_${PORT} \
  -p ${PORT}:80 \
  -v ${DATA_PATH}/html:/usr/share/nginx/html \
  nginx:latest

# 检查状态
echo "➤ [5/5] 检查容器状态..."
docker ps | grep nginx_${PORT}

echo ""
echo "========================================="
echo "✅ Nginx 安装完成！"
echo "========================================="
echo "🌐 访问地址: http://你的IP:${PORT}"
echo ""

