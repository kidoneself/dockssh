#!/bin/bash
# Redis 安装脚本

PORT=$1
DATA_PATH=$2

echo ""
echo "========================================="
echo "🚀 开始安装 Redis"
echo "========================================="
echo "📌 端口: $PORT"
echo "📌 数据目录: $DATA_PATH"
echo ""

# 创建数据目录
echo "➤ [1/4] 创建数据目录..."
mkdir -p ${DATA_PATH} && echo "   ✓ 目录创建成功" || echo "   ✗ 创建失败"

# 拉取镜像
echo "➤ [2/4] 拉取 Redis 镜像..."
docker pull redis:latest

# 启动容器
echo "➤ [3/4] 启动容器..."
docker run -d \
  --name redis_${PORT} \
  -p ${PORT}:6379 \
  -v ${DATA_PATH}:/data \
  redis:latest \
  redis-server --appendonly yes

# 检查状态
echo "➤ [4/4] 检查容器状态..."
docker ps | grep redis_${PORT}

echo ""
echo "========================================="
echo "✅ Redis 安装完成！"
echo "========================================="
echo "🌐 连接地址: redis://你的IP:${PORT}"
echo ""

