#!/bin/bash

# Docker镜像下载客户端脚本
# 使用方法: ./client-pull.sh <镜像名> [标签] [服务器地址]
# 示例: ./client-pull.sh nginx latest http://your-server:8080

set -e

# 默认配置
DEFAULT_TAG="latest"
DEFAULT_SERVER="http://148.135.15.210:8080"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 显示帮助信息
show_help() {
    cat << EOF
Docker镜像下载客户端脚本

使用方法:
    $0 <镜像名> [标签] [服务器地址]

参数说明:
    镜像名        - 必需，Docker镜像名称，如: nginx, redis, mysql
    标签          - 可选，镜像标签，默认: latest
    服务器地址    - 可选，did-tool服务器地址，默认: http://localhost:8080

示例:
    $0 nginx
    $0 nginx latest
    $0 nginx latest http://192.168.1.100:8080
    $0 redis 7-alpine http://your-server.com:8080

环境变量:
    DID_SERVER    - 默认服务器地址
    FORCE_DOWNLOAD - 设置为true强制重新下载 (默认: false)

EOF
}

# 检查依赖
check_dependencies() {
    if ! command -v curl &> /dev/null; then
        log_error "curl 未安装，请先安装curl"
        exit 1
    fi
    
    if ! command -v docker &> /dev/null; then
        log_error "docker 未安装，请先安装Docker"
        exit 1
    fi
}

# 获取系统架构信息
detect_architecture() {
    local arch=$(uname -m)
    local os=$(uname -s | tr '[:upper:]' '[:lower:]')
    
    case $arch in
        x86_64)
            DOCKER_ARCH="amd64"
            ;;
        aarch64|arm64)
            DOCKER_ARCH="arm64"
            ;;
        armv7l)
            DOCKER_ARCH="arm"
            ;;
        *)
            log_warning "未知架构: $arch, 使用默认值 amd64"
            DOCKER_ARCH="amd64"
            ;;
    esac
    
    case $os in
        linux)
            DOCKER_OS="linux"
            ;;
        darwin)
            DOCKER_OS="linux"  # Docker Desktop for Mac 仍使用linux镜像
            ;;
        *)
            log_warning "未知操作系统: $os, 使用默认值 linux"
            DOCKER_OS="linux"
            ;;
    esac
    
    log_info "检测到架构: ${DOCKER_OS}/${DOCKER_ARCH}"
}

# 构建下载URL
build_download_url() {
    local server="$1"
    local image_name="$2"
    local tag="$3"
    local force_download="${FORCE_DOWNLOAD:-false}"
    
    echo "${server}/api/pull?imageName=${image_name}&tag=${tag}&os=${DOCKER_OS}&arch=${DOCKER_ARCH}&forceDownload=${force_download}"
}

# 下载镜像
download_image() {
    local url="$1"
    local image_name="$2"
    local tag="$3"
    local output_file="${image_name//\//_}_${tag}.tar"
    
    log_info "开始下载镜像: ${image_name}:${tag}"
    log_info "目标架构: ${DOCKER_OS}/${DOCKER_ARCH}"
    log_info "下载地址: ${url}"
    
    # 显示进度条的curl下载
    if curl -L --fail --progress-bar \
        -H "User-Agent: did-tool-client/1.0" \
        -o "${output_file}" \
        "${url}"; then
        
        log_success "镜像下载完成: ${output_file}"
        
        # 获取文件大小
        local file_size=$(ls -lh "${output_file}" | awk '{print $5}')
        log_info "文件大小: ${file_size}"
        
        return 0
    else
        log_error "下载失败"
        # 清理失败的下载文件
        [ -f "${output_file}" ] && rm -f "${output_file}"
        return 1
    fi
}

# 加载镜像到Docker
load_image() {
    local tar_file="$1"
    local image_name="$2"
    local tag="$3"
    
    log_info "加载镜像到Docker: ${tar_file}"
    
    if docker load < "${tar_file}"; then
        log_success "镜像加载成功: ${image_name}:${tag}"
        
        # 显示镜像信息
        log_info "镜像信息:"
        docker images "${image_name}:${tag}"
        
        return 0
    else
        log_error "镜像加载失败"
        return 1
    fi
}

# 清理临时文件
cleanup() {
    if [ -n "$TAR_FILE" ] && [ -f "$TAR_FILE" ]; then
        log_info "清理临时文件: ${TAR_FILE}"
        rm -f "$TAR_FILE"
    fi
}

# 主函数
main() {
    # 参数解析
    if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        show_help
        exit 0
    fi
    
    local image_name="$1"
    local tag="${2:-$DEFAULT_TAG}"
    local server="${3:-${DID_SERVER:-$DEFAULT_SERVER}}"
    
    # 验证参数
    if [ -z "$image_name" ]; then
        log_error "镜像名不能为空"
        exit 1
    fi
    
    # 检查依赖
    check_dependencies
    
    # 检测架构
    detect_architecture
    
    # 构建下载URL
    local download_url=$(build_download_url "$server" "$image_name" "$tag")
    
    # 设置清理trap
    TAR_FILE="${image_name//\//_}_${tag}.tar"
    trap cleanup EXIT
    
    # 下载镜像
    if download_image "$download_url" "$image_name" "$tag"; then
        # 加载镜像
        if load_image "$TAR_FILE" "$image_name" "$tag"; then
            log_success "完成! 镜像 ${image_name}:${tag} 已成功加载到Docker"
        else
            exit 1
        fi
    else
        exit 1
    fi
}

# 执行主函数
main "$@"
