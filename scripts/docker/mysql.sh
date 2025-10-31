#!/bin/bash
# MySQL 安装脚本

PORT=$1
PASSWORD=$2
DATA_PATH=$3

echo ""
echo "========================================="
echo "🚀 开始安装 MySQL"
echo "========================================="
echo "📌 端口: $PORT"
echo "📌 密码: ********"
echo "📌 数据目录: $DATA_PATH"
echo ""

# 创建数据目录
echo "➤ [1/5] 创建数据目录..."
mkdir -p ${DATA_PATH} && echo "   ✓ 目录创建成功" || echo "   ✗ 创建失败"

# 设置权限
echo "➤ [2/5] 设置权限..."
chmod 777 ${DATA_PATH} && echo "   ✓ 权限设置完成" || echo "   ✗ 设置失败"

# 拉取镜像
echo "➤ [3/5] 拉取 MySQL 镜像..."
docker pull mysql:latest

# 启动容器
echo "➤ [4/5] 启动容器..."
docker run -d \
  --name mysql_${PORT} \
  -p ${PORT}:3306 \
  -e MYSQL_ROOT_PASSWORD=${PASSWORD} \
  -v ${DATA_PATH}:/var/lib/mysql \
  mysql:latest

# 等待启动
echo "➤ [5/5] 等待 MySQL 启动..."
sleep 5
docker logs mysql_${PORT} 2>&1 | tail -10

echo ""
echo "========================================="
echo "✅ MySQL 安装完成！"
echo "========================================="
echo "📊 连接信息:"
echo "   主机: 你的IP"
echo "   端口: ${PORT}"
echo "   用户: root"
echo "   密码: ${PASSWORD}"
echo ""

