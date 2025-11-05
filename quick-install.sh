#!/bin/bash
# DockSSH 一键安装脚本 v2.0
# 适用于各种Linux发行版和NAS系统

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo "========================================="
echo "🚀 DockSSH 一键安装脚本"
echo "========================================="
echo ""

# 检测安装目录
INSTALL_DIR="${INSTALL_DIR:-/opt/dockssh}"
log_info "安装目录: $INSTALL_DIR"

# 检查Python
log_info "检查 Python 环境..."
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version | awk '{print $2}')
    log_success "Python 版本: $PYTHON_VERSION"
else
    log_error "未找到 Python 3"
    log_info "请先安装 Python 3.8+"
    exit 1
fi

# 检查pip
if ! command -v pip3 &> /dev/null; then
    log_warning "pip 未安装，正在安装..."
    python3 -m ensurepip --default-pip || {
        log_error "pip 安装失败"
        exit 1
    }
fi

# 下载代码
log_info "下载 DockSSH 代码..."
if [ -d "$INSTALL_DIR" ]; then
    log_warning "目录已存在，更新代码..."
    cd "$INSTALL_DIR"
    git pull || {
        log_error "更新失败，请手动删除目录后重试"
        exit 1
    }
else
    git clone https://github.com/kidoneself/dockssh.git "$INSTALL_DIR" || {
        log_error "下载失败，请检查网络"
        exit 1
    }
    cd "$INSTALL_DIR"
fi

# 安装依赖
log_info "安装 Python 依赖..."
log_info "使用清华镜像源加速..."
pip3 install --user \
    --trusted-host pypi.tuna.tsinghua.edu.cn \
    -i http://pypi.tuna.tsinghua.edu.cn/simple \
    -r requirements.txt || {
    log_warning "清华源失败，使用官方源..."
    pip3 install --user -r requirements.txt
}

# 创建数据目录
mkdir -p data
log_success "依赖安装完成"

# 检测系统服务管理器
log_info "配置开机自启..."
if command -v systemctl &> /dev/null; then
    # systemd 系统
    cat > /etc/systemd/system/dockssh.service <<EOF
[Unit]
Description=DockSSH - SSH Management & Docker Deployment
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=$(which python3) $INSTALL_DIR/main.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable dockssh
    systemctl start dockssh
    log_success "已配置 systemd 服务"
    
elif command -v supervisorctl &> /dev/null; then
    # supervisor 系统
    cat > /etc/supervisor/conf.d/dockssh.conf <<EOF
[program:dockssh]
command=$(which python3) $INSTALL_DIR/main.py
directory=$INSTALL_DIR
autostart=true
autorestart=true
user=root
EOF
    
    supervisorctl reread
    supervisorctl update
    supervisorctl start dockssh
    log_success "已配置 supervisor 服务"
    
else
    # 无服务管理器，后台运行
    log_warning "未检测到 systemd/supervisor"
    log_info "使用 nohup 后台运行..."
    nohup python3 main.py > /tmp/dockssh.log 2>&1 &
    log_success "服务已启动（后台运行）"
fi

# 获取本机IP
SERVER_IP=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "localhost")

echo ""
echo "========================================="
log_success "DockSSH 安装完成！"
echo "========================================="
echo ""
log_info "访问地址："
echo "  http://localhost:8000"
echo "  http://${SERVER_IP}:8000"
echo ""
log_info "服务管理："
if command -v systemctl &> /dev/null; then
    echo "  启动: systemctl start dockssh"
    echo "  停止: systemctl stop dockssh"
    echo "  重启: systemctl restart dockssh"
    echo "  日志: journalctl -u dockssh -f"
elif command -v supervisorctl &> /dev/null; then
    echo "  启动: supervisorctl start dockssh"
    echo "  停止: supervisorctl stop dockssh"
    echo "  日志: tail -f /var/log/supervisor/dockssh*.log"
else
    echo "  查看进程: ps aux | grep main.py"
    echo "  停止: pkill -f main.py"
    echo "  日志: tail -f /tmp/dockssh.log"
fi
echo ""
log_info "更新版本："
echo "  cd $INSTALL_DIR && git pull && systemctl restart dockssh"
echo ""
log_info "卸载："
echo "  systemctl stop dockssh && systemctl disable dockssh"
echo "  rm -rf $INSTALL_DIR"
echo "========================================="

# DockSSH 极速一键安装脚本
# 使用方法: bash <(curl -fsSL 你的URL/quick-install.sh)
# 或者: bash <(wget -qO- 你的URL/quick-install.sh)

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }
print_info() { echo -e "${BLUE}ℹ${NC} $1"; }
print_warn() { echo -e "${YELLOW}⚠${NC} $1"; }

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 DockSSH 极速安装"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 项目信息
REPO_URL="https://github.com/你的用户名/DockSSH.git"  # 替换为实际仓库地址
PROJECT_DIR="DockSSH"

# 检查 Python
print_info "检查 Python 环境..."
if ! command -v python3 &> /dev/null; then
    print_error "未找到 Python 3"
    echo "请先安装 Python 3.8+："
    echo "  macOS:   brew install python3"
    echo "  Ubuntu:  sudo apt install python3 python3-pip"
    echo "  CentOS:  sudo yum install python3 python3-pip"
    exit 1
fi

PYTHON_VERSION=$(python3 --version | awk '{print $2}')
print_success "Python $PYTHON_VERSION"

# 检查 Git
print_info "检查 Git..."
if ! command -v git &> /dev/null; then
    print_error "未找到 Git"
    echo "请先安装 Git："
    echo "  macOS:   brew install git"
    echo "  Ubuntu:  sudo apt install git"
    echo "  CentOS:  sudo yum install git"
    exit 1
fi
print_success "Git 已安装"

# 克隆或更新项目
if [ -d "$PROJECT_DIR" ]; then
    print_warn "目录已存在，尝试更新..."
    cd "$PROJECT_DIR"
    git pull origin main || print_warn "无法更新，使用现有版本"
else
    print_info "克隆项目..."
    if git clone "$REPO_URL" "$PROJECT_DIR"; then
        print_success "项目克隆成功"
        cd "$PROJECT_DIR"
    else
        print_error "克隆失败，请检查网络或仓库地址"
        exit 1
    fi
fi

# 安装依赖
print_info "安装 Python 依赖..."
if pip3 install --trusted-host pypi.tuna.tsinghua.edu.cn \
    -i http://pypi.tuna.tsinghua.edu.cn/simple \
    -r requirements.txt -q; then
    print_success "依赖安装成功（清华源）"
else
    print_warn "清华源失败，尝试官方源..."
    if pip3 install -r requirements.txt -q; then
        print_success "依赖安装成功（官方源）"
    else
        print_error "依赖安装失败"
        exit 1
    fi
fi

# 创建数据目录
mkdir -p data
print_success "数据目录创建完成"

# 检查端口
PORT=8000
if lsof -i:$PORT &> /dev/null; then
    print_warn "端口 $PORT 已被占用"
    echo ""
    read -p "是否停止占用进程？(y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        lsof -ti:$PORT | xargs kill -9 2>/dev/null || true
        print_success "进程已停止"
    fi
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ 安装完成！"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🚀 快速启动："
echo "   cd $PROJECT_DIR"
echo "   python3 main.py"
echo ""
echo "或使用后台启动："
echo "   cd $PROJECT_DIR && nohup python3 main.py > dockssh.log 2>&1 &"
echo ""
echo "🌐 访问地址："
echo "   本地: ${GREEN}http://localhost:8000${NC}"
if command -v ifconfig &> /dev/null; then
    LOCAL_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -n 1)
    if [ ! -z "$LOCAL_IP" ]; then
        echo "   局域网: ${GREEN}http://$LOCAL_IP:8000${NC}"
    fi
fi
echo ""
echo "📖 使用文档："
echo "   cat $PROJECT_DIR/README.md"
echo "   cat $PROJECT_DIR/USAGE.md"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
