#!/bin/bash
# DockSSH 一键安装脚本

echo "========================================="
echo "🚀 DockSSH 一键安装脚本"
echo "========================================="
echo ""

# 检查 Python 版本
echo "📌 检查 Python 版本..."
if ! command -v python3 &> /dev/null; then
    echo "❌ 未找到 Python 3，请先安装 Python 3.8+"
    exit 1
fi

PYTHON_VERSION=$(python3 --version | awk '{print $2}')
echo "✓ Python 版本: $PYTHON_VERSION"
echo ""

# 检查 pip
echo "📌 检查 pip..."
if ! command -v pip3 &> /dev/null; then
    echo "安装 pip..."
    python3 -m ensurepip --default-pip
fi
echo "✓ pip 已就绪"
echo ""

# 安装依赖
echo "📦 安装 Python 依赖..."
echo "   使用国内镜像源加速下载..."

pip3 install --trusted-host pypi.tuna.tsinghua.edu.cn \
    -i http://pypi.tuna.tsinghua.edu.cn/simple \
    -r requirements.txt

if [ $? -eq 0 ]; then
    echo "✓ 依赖安装成功"
else
    echo "⚠️ 国内源失败，尝试官方源..."
    pip3 install -r requirements.txt
fi

echo ""

# 创建数据目录
echo "📁 创建数据目录..."
mkdir -p data
echo "✓ 目录创建完成"
echo ""

# 检查端口
echo "🔍 检查端口 8000..."
if lsof -i:8000 &> /dev/null; then
    echo "⚠️ 端口 8000 已被占用"
    read -p "是否停止占用进程？(y/n): " choice
    if [[ "$choice" =~ ^[Yy]$ ]]; then
        lsof -ti:8000 | xargs kill -9
        echo "✓ 进程已停止"
    fi
fi
echo ""

echo "========================================="
echo "✅ 安装完成！"
echo "========================================="
echo ""
echo "🚀 启动服务："
echo "   python3 main.py"
echo ""
echo "🌐 访问地址："
echo "   http://localhost:8000"
echo "   或"
echo "   http://你的服务器IP:8000"
echo ""
echo "📖 详细文档："
echo "   README.md - 项目说明"
echo "   USAGE.md  - 使用指南"
echo ""
echo "========================================="

