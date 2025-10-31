#!/bin/bash


set -e  # 遇到错误立即退出

# 颜色定义
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

# 检查是否为root用户
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "请使用root权限运行此脚本"
        echo "使用方法: sudo bash $0"
        exit 1
    fi
}

# 检查Docker是否运行
check_docker_running() {
    if ! command -v docker >/dev/null 2>&1; then
        log_error "Docker未安装，请先安装Docker"
        exit 1
    fi
    
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker未运行，请先启动Docker服务"
        log_info "启动命令: systemctl start docker"
        exit 1
    fi
    
    log_info "Docker运行正常: $(docker --version)"
}

# 主服务选择菜单
show_main_menu() {
    echo
    log_info "请选择要部署的服务："
    echo "1) MoviePilot (影视自动化管理)"
    echo "2) qBittorrent (BT下载工具)"
    echo "3) Transmission (BT下载工具)"
    echo "4) EmbyServer (媒体服务器)"
    echo "5) Roon Server (音乐服务器)"
    echo "6) BiliLive-Go (哔哩哔哩直播录制)"
    echo "7) Clash (代理服务)"
    echo "8) FRP Client (内网穿透客户端)"
    echo
    read -p "请输入要安装的服务编号: " MAIN_CHOICE
    
    # 初始化所有服务为false
    DEPLOY_MOVIEPILOT=false
    DEPLOY_QBITTORRENT=false
    DEPLOY_TRANSMISSION=false
    DEPLOY_EMBYSERVER=false
    DEPLOY_ROON=false
    DEPLOY_BILILIVE=false
    DEPLOY_CLASH=false
    DEPLOY_FRPC=false
    DEPLOY_MEDIA_SUITE=false
    
    # 解析用户输入的数字组合
    if [[ "$MAIN_CHOICE" =~ ^[1-8]+$ ]]; then
        local selected_services=""
        
        # 检查每个数字
        for (( i=0; i<${#MAIN_CHOICE}; i++ )); do
            case "${MAIN_CHOICE:$i:1}" in
                "1")
                    DEPLOY_MOVIEPILOT=true
                    DEPLOY_MEDIA_SUITE=true
                    selected_services="$selected_services MoviePilot"
                    ;;
                "2")
                    DEPLOY_QBITTORRENT=true
                    DEPLOY_MEDIA_SUITE=true
                    selected_services="$selected_services qBittorrent"
                    ;;
                "3")
                    DEPLOY_TRANSMISSION=true
                    DEPLOY_MEDIA_SUITE=true
                    selected_services="$selected_services Transmission"
                    ;;
                "4")
                    DEPLOY_EMBYSERVER=true
                    DEPLOY_MEDIA_SUITE=true
                    selected_services="$selected_services EmbyServer"
                    ;;
                "5")
                    DEPLOY_ROON=true
                    selected_services="$selected_services Roon-Server"
                    ;;
                "6")
                    DEPLOY_BILILIVE=true
                    selected_services="$selected_services BiliLive-Go"
                    ;;
                "7")
                    DEPLOY_CLASH=true
                    selected_services="$selected_services Clash"
                    ;;
                "8")
                    DEPLOY_FRPC=true
                    selected_services="$selected_services FRP-Client"
                    ;;
            esac
        done
        
        echo
        log_info "您选择安装的服务:$selected_services"
    else
        log_error "无效输入，请输入1-8之间的数字组合"
        exit 1
    fi
}

# 获取用户输入配置
get_user_input() {
    echo
    log_info "请配置服务安装参数"
    
    # 只有在部署需要Docker配置目录的服务时才询问Docker根目录
    if [ "$DEPLOY_MEDIA_SUITE" = true ] || [ "$DEPLOY_ROON" = true ] || [ "$DEPLOY_CLASH" = true ] || [ "$DEPLOY_FRPC" = true ]; then
        read -p "请输入Docker数据根目录 (默认: /volume1/docker): " DOCKER_ROOT_DIR
        DOCKER_ROOT_DIR=${DOCKER_ROOT_DIR:-/volume1/docker}
    fi
    
    # 如果部署媒体服务器，获取媒体目录
    if [ "$DEPLOY_MEDIA_SUITE" = true ]; then
        read -p "请输入媒体库目录 (默认: /volume1/media): " MEDIA_DIR
        MEDIA_DIR=${MEDIA_DIR:-/volume1/media}
        
        # 设置媒体服务路径
        MOVIEPILOT_DIR="$DOCKER_ROOT_DIR/moviepilot"
        QBITTORRENT_DIR="$DOCKER_ROOT_DIR/qbittorrent"
        TRANSMISSION_DIR="$DOCKER_ROOT_DIR/transmission"
        EMBYSERVER_DIR="$DOCKER_ROOT_DIR/embyserver"
        
        # 固定用户凭证配置
        MP_SUPERUSER="admin"
        MP_PASSWORD="a123456!@"
        
        # 只在部署MoviePilot时询问代理设置
        if [ "$DEPLOY_MOVIEPILOT" = true ]; then
            read -p "请输入代理地址 (回车跳过): " PROXY_HOST
        fi
        
        HHCLUB_USERNAME="kidoneself"
        HHCLUB_PASSKEY="0bd1c21acf6d3880e34e3fa5489ccdca"
        TRANS_USER="admin"
        TRANS_PASS="a123456!@"
    fi
    
    # 如果部署Roon Server，获取音乐目录
    if [ "$DEPLOY_ROON" = true ]; then
        read -p "请输入音乐库目录 (默认: /volume1/music): " MUSIC_DIR
        MUSIC_DIR=${MUSIC_DIR:-/volume1/music}
        
        # 设置Roon路径
        ROON_DIR="$DOCKER_ROOT_DIR/roon"
        ROON_DATA_DIR="$ROON_DIR/data"
    fi
    
    # 如果部署BiliLive，设置固定配置
    if [ "$DEPLOY_BILILIVE" = true ]; then
        # 固定配置参数
        BILILIVE_CONTAINER_NAME="bililive-go"
        BILILIVE_PORT="8090"
        
        # 获取录制文件存放目录
        read -p "请输入录制文件存放目录 (默认: /volume1/records): " RECORD_DIR
        RECORD_DIR=${RECORD_DIR:-/volume1/records}
        
        # 设置BiliLive录制文件存放目录
        BILILIVE_DIR="$RECORD_DIR"
    fi
    
    # 如果部署Clash，设置固定配置
    if [ "$DEPLOY_CLASH" = true ]; then
        # 固定配置参数
        CLASH_CONTAINER_NAME="clash"
        CLASH_WEB_PORT="7888"
        CLASH_PROXY_PORT="7890"
        
        # 设置Clash配置目录
        CLASH_DIR="$DOCKER_ROOT_DIR/clash"
    fi
    
    # 如果部署FRP Client，设置固定配置
    if [ "$DEPLOY_FRPC" = true ]; then
        # 固定配置参数
        FRPC_CONTAINER_NAME="frpc"
        
        # 设置FRP Client配置目录
        FRPC_DIR="$DOCKER_ROOT_DIR/frpc"
    fi
    
    # 显示配置信息
    echo
    log_info "配置信息:"
    
    # 只在需要时显示Docker根目录
    if [ "$DEPLOY_MEDIA_SUITE" = true ] || [ "$DEPLOY_ROON" = true ] || [ "$DEPLOY_CLASH" = true ] || [ "$DEPLOY_FRPC" = true ]; then
        log_info "Docker根目录: $DOCKER_ROOT_DIR"
    fi
    
    if [ "$DEPLOY_MEDIA_SUITE" = true ]; then
        log_info "媒体目录: $MEDIA_DIR"
        
        # 只显示选择安装的服务的目录
        [ "$DEPLOY_MOVIEPILOT" = true ] && log_info "MoviePilot目录: $MOVIEPILOT_DIR"
        [ "$DEPLOY_QBITTORRENT" = true ] && log_info "qBittorrent目录: $QBITTORRENT_DIR"
        [ "$DEPLOY_TRANSMISSION" = true ] && log_info "Transmission目录: $TRANSMISSION_DIR"
        [ "$DEPLOY_EMBYSERVER" = true ] && log_info "EmbyServer目录: $EMBYSERVER_DIR"
        
        # 只在部署MoviePilot且设置了代理时显示
        if [ "$DEPLOY_MOVIEPILOT" = true ]; then
            if [ -n "$PROXY_HOST" ]; then
                log_info "代理地址: $PROXY_HOST"
            else
                log_info "代理地址: 未配置"
            fi
        fi
    fi
    
    if [ "$DEPLOY_ROON" = true ]; then
        log_info "Roon安装目录: $ROON_DIR"
        log_info "Roon数据目录: $ROON_DATA_DIR"
        log_info "音乐目录: $MUSIC_DIR"
    fi
    
    if [ "$DEPLOY_BILILIVE" = true ]; then
        log_info "BiliLive容器名称: $BILILIVE_CONTAINER_NAME"
        log_info "BiliLive录制文件目录: $BILILIVE_DIR" 
        log_info "BiliLive Web端口: $BILILIVE_PORT"
    fi
    
    if [ "$DEPLOY_CLASH" = true ]; then
        log_info "Clash容器名称: $CLASH_CONTAINER_NAME"
        log_info "Clash配置目录: $CLASH_DIR"
        log_info "Clash Web端口: $CLASH_WEB_PORT"
        log_info "Clash代理端口: $CLASH_PROXY_PORT"
    fi
    
    if [ "$DEPLOY_FRPC" = true ]; then
        log_info "FRP Client容器名称: $FRPC_CONTAINER_NAME"
        log_info "FRP Client配置目录: $FRPC_DIR"
        log_info "FRP Client本机IP: $FRPC_LOCAL_IP"
        log_info "FRP Client随机远程端口: $FRPC_REMOTE_PORT"
    fi
    
    # 只在部署相关服务时显示凭证信息
    if [ "$DEPLOY_MOVIEPILOT" = true ] || [ "$DEPLOY_TRANSMISSION" = true ]; then
        echo
        log_info "固定配置:"
        [ "$DEPLOY_MOVIEPILOT" = true ] && log_info "MoviePilot凭证: $MP_SUPERUSER / $MP_PASSWORD"
        log_info "HHCLUB用户: $HHCLUB_USERNAME"
        [ "$DEPLOY_TRANSMISSION" = true ] && log_info "Transmission凭证: $TRANS_USER / $TRANS_PASS"
    fi
    
    echo
    read -p "确认配置正确吗? (y/n): " CONFIRM
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        log_warning "用户取消安装"
        exit 0
    fi
}

# 创建目录结构
create_directories() {
    log_info "创建目录结构..."
    
    # 只在需要时创建基础Docker目录
    if [ "$DEPLOY_MEDIA_SUITE" = true ] || [ "$DEPLOY_ROON" = true ] || [ "$DEPLOY_CLASH" = true ] || [ "$DEPLOY_FRPC" = true ]; then
        mkdir -p "$DOCKER_ROOT_DIR"
    fi
    
    # 创建媒体服务器目录
    if [ "$DEPLOY_MEDIA_SUITE" = true ]; then
        mkdir -p "$MEDIA_DIR"
        
        # 只创建选择服务的目录
        [ "$DEPLOY_MOVIEPILOT" = true ] && mkdir -p "$MOVIEPILOT_DIR"
        [ "$DEPLOY_QBITTORRENT" = true ] && mkdir -p "$QBITTORRENT_DIR"
        [ "$DEPLOY_TRANSMISSION" = true ] && mkdir -p "$TRANSMISSION_DIR"
        [ "$DEPLOY_EMBYSERVER" = true ] && mkdir -p "$EMBYSERVER_DIR"
        
        # 创建媒体分类目录结构
        log_info "创建媒体分类目录结构..."
        
        # 创建下载目录
        mkdir -p "$MEDIA_DIR/downloads"
        
        # 剧集目录
        mkdir -p \
            "$MEDIA_DIR/links/剧集/国产剧集" \
            "$MEDIA_DIR/links/剧集/日韩剧集" \
            "$MEDIA_DIR/links/剧集/欧美剧集" \
            "$MEDIA_DIR/links/剧集/综艺节目" \
            "$MEDIA_DIR/links/剧集/纪录片" \
            "$MEDIA_DIR/links/剧集/儿童剧集" \
            "$MEDIA_DIR/links/剧集/纪录影片" \
            "$MEDIA_DIR/links/剧集/港台剧集" \
            "$MEDIA_DIR/links/剧集/南亚剧集"
        
        # 动漫目录
        mkdir -p \
            "$MEDIA_DIR/links/动漫/国产动漫" \
            "$MEDIA_DIR/links/动漫/欧美动漫" \
            "$MEDIA_DIR/links/动漫/日本番剧"
        
        # 电影目录
        mkdir -p \
            "$MEDIA_DIR/links/电影/儿童电影" \
            "$MEDIA_DIR/links/电影/动画电影" \
            "$MEDIA_DIR/links/电影/国产电影" \
            "$MEDIA_DIR/links/电影/日韩电影" \
            "$MEDIA_DIR/links/电影/欧美电影" \
            "$MEDIA_DIR/links/电影/歌舞电影" \
            "$MEDIA_DIR/links/电影/港台电影" \
            "$MEDIA_DIR/links/电影/南亚电影"
    fi
    
    # 创建Roon Server目录
    if [ "$DEPLOY_ROON" = true ]; then
        mkdir -p "$ROON_DIR"
        mkdir -p "$ROON_DATA_DIR"
        mkdir -p "$MUSIC_DIR"
    fi
    
    # 创建BiliLive录制目录
    if [ "$DEPLOY_BILILIVE" = true ]; then
        mkdir -p "$BILILIVE_DIR"
    fi
    
    # 创建Clash配置目录
    if [ "$DEPLOY_CLASH" = true ]; then
        mkdir -p "$CLASH_DIR"
    fi
    
    # 创建FRP Client配置目录
    if [ "$DEPLOY_FRPC" = true ]; then
        mkdir -p "$FRPC_DIR"
    fi
    
    # 设置目录权限
    if [ "$DEPLOY_MEDIA_SUITE" = true ] || [ "$DEPLOY_ROON" = true ] || [ "$DEPLOY_CLASH" = true ] || [ "$DEPLOY_FRPC" = true ]; then
        chmod 777 "$DOCKER_ROOT_DIR"
    fi
    
    if [ "$DEPLOY_MEDIA_SUITE" = true ]; then
        chmod -R 777 "$MEDIA_DIR"
        
        # 只设置选择服务的目录权限
        [ "$DEPLOY_MOVIEPILOT" = true ] && chmod -R 777 "$MOVIEPILOT_DIR"
        [ "$DEPLOY_QBITTORRENT" = true ] && chmod 777 "$QBITTORRENT_DIR"
        [ "$DEPLOY_TRANSMISSION" = true ] && chmod 777 "$TRANSMISSION_DIR"  
        [ "$DEPLOY_EMBYSERVER" = true ] && chmod 777 "$EMBYSERVER_DIR"
    fi
    
    if [ "$DEPLOY_ROON" = true ]; then
        chmod 777 "$ROON_DIR"
        chmod 777 "$ROON_DATA_DIR"
        chmod 777 "$MUSIC_DIR"
    fi
    
    if [ "$DEPLOY_BILILIVE" = true ]; then
        chmod 777 "$BILILIVE_DIR"
    fi
    
    if [ "$DEPLOY_CLASH" = true ]; then
        chmod 777 "$CLASH_DIR"
    fi
    
    if [ "$DEPLOY_FRPC" = true ]; then
        chmod 777 "$FRPC_DIR"
    fi
    
    log_success "目录创建完成"
}

# 创建Docker网络
create_network() {
    if [ "$DEPLOY_MEDIA_SUITE" = true ]; then
        log_info "创建Docker网络..."
        
        # 删除已存在的网络（如果存在）
        docker network rm moviepilot-network 2>/dev/null || true
        
        # 创建新网络
        docker network create moviepilot-network --driver bridge
        
        log_success "Docker网络创建完成"
    fi
}

# 下载并解压媒体服务器配置文件
download_media_configs() {
    if [ "$DEPLOY_MEDIA_SUITE" = true ]; then
        log_info "下载媒体服务配置文件..."
        
        # 根据选择的服务构建下载列表
        local services=""
        [ "$DEPLOY_MOVIEPILOT" = true ] && services="$services moviepilot"
        [ "$DEPLOY_QBITTORRENT" = true ] && services="$services qbittorrent"
        [ "$DEPLOY_TRANSMISSION" = true ] && services="$services transmission"
        [ "$DEPLOY_EMBYSERVER" = true ] && services="$services embyserver"
        
        for service in $services; do
            log_info "正在下载 $service 配置文件..."
            
            case $service in
                "moviepilot")
                    DOWNLOAD_URL="https://dockpilot.oss-cn-shanghai.aliyuncs.com/moviepilot.tgz"
                    TARGET_DIR="$MOVIEPILOT_DIR"
                    ;;
                "qbittorrent")
                    DOWNLOAD_URL="https://dockpilot.oss-cn-shanghai.aliyuncs.com/qbittorrent.tgz"
                    TARGET_DIR="$QBITTORRENT_DIR"
                    ;;
                "transmission")
                    DOWNLOAD_URL="https://dockpilot.oss-cn-shanghai.aliyuncs.com/transmission.tgz"
                    TARGET_DIR="$TRANSMISSION_DIR"
                    ;;
                "embyserver")
                    DOWNLOAD_URL="https://dockpilot.oss-cn-shanghai.aliyuncs.com/embyserver.tgz"
                    TARGET_DIR="$EMBYSERVER_DIR"
                    ;;
                *)
                    continue
                    ;;
            esac
            
            TEMP_FILE="/tmp/${service}.tgz"
            
            # 下载文件
            if command -v wget >/dev/null 2>&1; then
                wget -O "$TEMP_FILE" "$DOWNLOAD_URL"
            elif command -v curl >/dev/null 2>&1; then
                curl -L -o "$TEMP_FILE" "$DOWNLOAD_URL"
            else
                log_error "未找到wget或curl，无法下载文件"
                exit 1
            fi
            
            if [ ! -f "$TEMP_FILE" ]; then
                log_warning "$service 配置文件下载失败，跳过"
                continue
            fi
            
            # 解压文件
            log_info "解压 $service 配置文件到 $TARGET_DIR"
            cd "$TARGET_DIR"
            tar -zxf "$TEMP_FILE" --strip-components=1 2>/dev/null || tar -zxf "$TEMP_FILE" --strip-components=1
            
            # 设置权限
            chmod -R 777 "$TARGET_DIR" 2>/dev/null || true
            
            # 清理临时文件
            rm -f "$TEMP_FILE"
            
            log_success "$service 配置文件处理完成"
        done
    fi
}

# 下载并解压Roon Server文件
download_roon_server() {
    if [ "$DEPLOY_ROON" = true ]; then
        log_info "下载Roon Server文件..."
        
        DOWNLOAD_URL="https://dockpilot.oss-cn-shanghai.aliyuncs.com/roon.tgz"
        TEMP_FILE="/tmp/roon.tgz"
        
        # 下载文件
        if command -v wget >/dev/null 2>&1; then
            wget -O "$TEMP_FILE" "$DOWNLOAD_URL"
        elif command -v curl >/dev/null 2>&1; then
            curl -L -o "$TEMP_FILE" "$DOWNLOAD_URL"
        else
            log_error "未找到wget或curl，无法下载文件"
            exit 1
        fi
        
        if [ ! -f "$TEMP_FILE" ]; then
            log_error "Roon Server文件下载失败"
            exit 1
        fi
        
        log_info "解压文件到 $ROON_DIR"
        
        # 解压文件
        cd "$ROON_DIR"
        tar -zxf "$TEMP_FILE" 2>/dev/null || tar -zxf "$TEMP_FILE"
        
        # 设置权限
        log_info "设置解压文件权限..."
        ulimit -n 65536 2>/dev/null || true
        
        if ! chmod -R 777 "$ROON_DIR" 2>/dev/null; then
            log_warning "遇到Too many open files，使用手动权限设置"
            chmod +x "$ROON_DIR"/RoonServer/start.sh 2>/dev/null || true
            chmod +x "$ROON_DIR"/RoonServer/Server/RoonServer 2>/dev/null || true
            chmod +x "$ROON_DIR"/RoonDotnet/RoonServer 2>/dev/null || true
        fi
        
        # 清理临时文件
        rm -f "$TEMP_FILE"
        
        log_success "Roon Server文件处理完成"
    fi
}

# 下载并解压Clash配置文件
download_clash_config() {
    if [ "$DEPLOY_CLASH" = true ]; then
        log_info "下载Clash配置文件..."
        
        DOWNLOAD_URL="https://dockpilot.oss-cn-shanghai.aliyuncs.com/clash.tgz"
        TEMP_FILE="/tmp/clash.tgz"
        
        # 下载文件
        if command -v wget >/dev/null 2>&1; then
            wget -O "$TEMP_FILE" "$DOWNLOAD_URL"
        elif command -v curl >/dev/null 2>&1; then
            curl -L -o "$TEMP_FILE" "$DOWNLOAD_URL"
        else
            log_error "未找到wget或curl，无法下载文件"
            exit 1
        fi
        
        if [ ! -f "$TEMP_FILE" ]; then
            log_error "Clash配置文件下载失败"
            exit 1
        fi
        
        log_info "解压文件到 $CLASH_DIR"
        
        # 解压文件
        cd "$CLASH_DIR"
        tar -zxf "$TEMP_FILE" 2>/dev/null || tar -zxf "$TEMP_FILE"
        
        # 设置权限
        chmod -R 777 "$CLASH_DIR" 2>/dev/null || true
        
        # 清理临时文件
        rm -f "$TEMP_FILE"
        
        log_success "Clash配置文件处理完成"
    fi
}

# 创建FRP Client配置文件
create_frpc_config() {
    if [ "$DEPLOY_FRPC" = true ]; then
        log_info "创建FRP Client配置文件..."
        
        # 获取本机IP地址
        local local_ip
        local_ip=$(hostname -I | awk '{print $1}' 2>/dev/null || ip route get 1 | awk '{print $7; exit}' 2>/dev/null || echo "127.0.0.1")
        
        # 生成随机远程端口号 (8000-65535)
        RANDOM_PORT=$((RANDOM % 57536 + 8000))
        
        # 创建frpc.toml配置文件
        cat > "$FRPC_DIR/frpc.toml" << EOF
# 与服务端建立连接，跟上面的配置要对应
serverAddr = "122.51.73.200"
serverPort = 7000

# 配置Token鉴权，要与服务端一致
auth.method = "token"
auth.token = "gbfvzhsybvtybsibvuipqfnnvlkashfgiawug"

# 配置日志信息
log.level = "warn"
log.to = "/opt/frpc/frpc.log"

# 该内网穿透起名为mp-home，基于TCP协议将本机的3000端口映射到公网的$RANDOM_PORT
[[proxies]]
name = "mp-home"
type = "tcp"
localIP = "$local_ip"
localPort = 3000
remotePort = $RANDOM_PORT
EOF
        
        # 设置权限
        chmod 644 "$FRPC_DIR/frpc.toml" 2>/dev/null || true
        
        log_info "自动检测到本机IP: $local_ip"
        log_info "随机生成的远程端口: $RANDOM_PORT"
        log_success "FRP Client配置文件创建完成"
        
        # 保存信息供完成信息显示使用
        FRPC_REMOTE_PORT=$RANDOM_PORT
        FRPC_LOCAL_IP=$local_ip
    fi
}

# 启动MoviePilot容器
run_moviepilot() {
    if [ "$DEPLOY_MOVIEPILOT" = true ]; then
        log_info "启动MoviePilot容器..."
        
        docker stop moviepilot 2>/dev/null || true
        docker rm moviepilot 2>/dev/null || true
        
        local docker_cmd="docker run -d \
            --name moviepilot \
            --hostname moviepilot-v2 \
            --restart unless-stopped \
            --network moviepilot-network \
            -i -t \
            -p 3000:3000 \
            -p 3001:3001 \
            -v \"$MEDIA_DIR:/media\" \
            -v \"$MOVIEPILOT_DIR/config:/config\" \
            -v \"$MOVIEPILOT_DIR/core:/moviepilot/.cache/ms-playwright\" \
            -v \"/var/run/docker.sock:/var/run/docker.sock:ro\" \
            -e \"NGINX_PORT=3000\" \
            -e \"PORT=3001\" \
            -e \"PUID=0\" \
            -e \"PGID=0\" \
            -e \"UMASK=000\" \
            -e \"TZ=Asia/Shanghai\" \
            -e \"SUPERUSER=$MP_SUPERUSER\" \
            -e \"SUPERUSER_PASSWORD=$MP_PASSWORD\""
        
        if [ -n "$PROXY_HOST" ]; then
            docker_cmd="$docker_cmd -e \"PROXY_HOST=$PROXY_HOST\""
        fi
        
        docker_cmd="$docker_cmd \
            -e \"AUTH_SITE=hhclub\" \
            -e \"HHCLUB_USERNAME=$HHCLUB_USERNAME\" \
            -e \"HHCLUB_PASSKEY=$HHCLUB_PASSKEY\" \
            --add-host \"host.docker.internal:host-gateway\" \
            jxxghp/moviepilot-v2:latest"
        
        eval "$docker_cmd"
        log_success "MoviePilot容器启动成功"
    fi
}

# 启动qBittorrent容器
run_qbittorrent() {
    if [ "$DEPLOY_QBITTORRENT" = true ]; then
        log_info "启动qBittorrent容器..."
        
        docker stop qbittorrent 2>/dev/null || true
        docker rm qbittorrent 2>/dev/null || true
        
        docker run -d \
            --name qbittorrent \
            --restart unless-stopped \
            --network moviepilot-network \
            -p 8080:8080 \
            -e "PUID=0" \
            -e "PGID=0" \
            -e "TZ=Asia/Shanghai" \
            -e "WEBUI_PORT=8080" \
            -v "$MEDIA_DIR:/media" \
            -v "$QBITTORRENT_DIR:/config" \
            --memory=1g \
            linuxserver/qbittorrent:latest
        
        log_success "qBittorrent容器启动成功"
    fi
}

# 启动Transmission容器
run_transmission() {
    if [ "$DEPLOY_TRANSMISSION" = true ]; then
        log_info "启动Transmission容器..."
        
        docker stop transmission 2>/dev/null || true
        docker rm transmission 2>/dev/null || true
        
        docker run -d \
            --name transmission \
            --restart unless-stopped \
            --network moviepilot-network \
            -p 9091:9091 \
            -e "PUID=0" \
            -e "PGID=0" \
            -e "TZ=Asia/Shanghai" \
            -e "USER=$TRANS_USER" \
            -e "PASS=$TRANS_PASS" \
            -v "$MEDIA_DIR:/media" \
            -v "$TRANSMISSION_DIR:/config" \
            linuxserver/transmission:4.0.5
        
        log_success "Transmission容器启动成功"
    fi
}

# 启动EmbyServer容器
run_embyserver() {
    if [ "$DEPLOY_EMBYSERVER" = true ]; then
        log_info "启动EmbyServer容器..."
        
        docker stop embyserver 2>/dev/null || true
        docker rm embyserver 2>/dev/null || true
        
        docker run -d \
            --name embyserver \
            --restart unless-stopped \
            --network moviepilot-network \
            -p 8096:8096 \
            --device "/dev/dri:/dev/dri" \
            -v "$MEDIA_DIR:/media" \
            -v "$EMBYSERVER_DIR:/config" \
            -e "UID=0" \
            -e "GID=0" \
            -e "GIDLIST=0" \
            -e "TZ=Asia/Shanghai" \
            amilys/embyserver:latest
        
        log_success "EmbyServer容器启动成功"
    fi
}

# 启动Roon Server容器
run_roon_server() {
    if [ "$DEPLOY_ROON" = true ]; then
        log_info "启动Roon Server容器..."
        
        docker stop docker-roonserver 2>/dev/null || true
        docker rm docker-roonserver 2>/dev/null || true
        
        docker run -d \
            --name docker-roonserver \
            --restart always \
            --network host \
            -v "$ROON_DIR:/app" \
            -v "$ROON_DATA_DIR:/backup" \
            -v "$ROON_DATA_DIR:/data" \
            -v "$MUSIC_DIR:/music" \
            steefdebruijn/docker-roonserver:latest
        
        log_success "Roon Server容器启动成功"
    fi
}

# 启动BiliLive直播录制容器
run_bililive() {
    if [ "$DEPLOY_BILILIVE" = true ]; then
        log_info "启动BiliLive直播录制容器..."
        
        docker stop "$BILILIVE_CONTAINER_NAME" 2>/dev/null || true
        docker rm "$BILILIVE_CONTAINER_NAME" 2>/dev/null || true
        
        docker run -d \
            --name "$BILILIVE_CONTAINER_NAME" \
            --restart always \
            --network bridge \
            -p "$BILILIVE_PORT:8080" \
            -v "$BILILIVE_DIR:/srv/bililive" \
            chigusa/bililive-go:latest
        
        log_success "BiliLive容器启动成功"
    fi
}

# 启动Clash容器
run_clash() {
    if [ "$DEPLOY_CLASH" = true ]; then
        log_info "启动Clash容器..."
        
        docker stop "$CLASH_CONTAINER_NAME" 2>/dev/null || true
        docker rm "$CLASH_CONTAINER_NAME" 2>/dev/null || true
        
        docker run -d \
            --name "$CLASH_CONTAINER_NAME" \
            --restart always \
            --log-opt max-size=1m \
            -v "$CLASH_DIR:/root/.config/clash" \
            -p "$CLASH_WEB_PORT:8080" \
            -p "$CLASH_PROXY_PORT:7890" \
            laoyutang/clash-and-dashboard:latest
        
        log_success "Clash容器启动成功"
    fi
}

# 启动FRP Client容器
run_frpc() {
    if [ "$DEPLOY_FRPC" = true ]; then
        log_info "启动FRP Client容器..."
        
        docker stop "$FRPC_CONTAINER_NAME" 2>/dev/null || true
        docker rm "$FRPC_CONTAINER_NAME" 2>/dev/null || true
        
        docker run --name frpc \
            --restart always \
            -e TZ=Asia/Shanghai \
            -v "$FRPC_DIR:/opt/frpc" \
            -d fatedier/frpc:v0.61.2 -c /opt/frpc/frpc.toml
        
        log_success "FRP Client容器启动成功"
    fi
}

# 显示完成信息
show_completion_info() {
    # 获取本机IP地址
    local server_ip
    server_ip=$(hostname -I | awk '{print $1}' 2>/dev/null || ip route get 1 | awk '{print $7; exit}' 2>/dev/null || echo "localhost")
    
    echo
    echo "================================================="
    log_success "服务部署完成!"
    echo "================================================="
    echo
    
    # 显示已启动的服务
    local has_services=false
    
    if [ "$DEPLOY_MOVIEPILOT" = true ] || [ "$DEPLOY_QBITTORRENT" = true ] || [ "$DEPLOY_TRANSMISSION" = true ] || [ "$DEPLOY_EMBYSERVER" = true ]; then
        log_info "已启动的媒体服务:"
        has_services=true
        
        [ "$DEPLOY_MOVIEPILOT" = true ] && log_info "- MoviePilot: http://${server_ip}:3000 (管理端口: 3001)"
        [ "$DEPLOY_QBITTORRENT" = true ] && log_info "- qBittorrent: http://${server_ip}:8080"
        [ "$DEPLOY_TRANSMISSION" = true ] && log_info "- Transmission: http://${server_ip}:9091"
        [ "$DEPLOY_EMBYSERVER" = true ] && log_info "- EmbyServer: http://${server_ip}:8096"
        
        echo
        log_info "用户凭证:"
        [ "$DEPLOY_MOVIEPILOT" = true ] && log_info "- MoviePilot: $MP_SUPERUSER / $MP_PASSWORD"
        [ "$DEPLOY_TRANSMISSION" = true ] && log_info "- Transmission: $TRANS_USER / $TRANS_PASS"
        [ "$DEPLOY_QBITTORRENT" = true ] && log_info "- qBittorrent: admin / a123456!@ (首次登录后修改)"
    fi
    
    if [ "$DEPLOY_MEDIA_SUITE" = true ]; then
        echo
        log_info "媒体目录结构:"
        log_info "- 下载目录: $MEDIA_DIR/downloads/"
        log_info "- 剧集: $MEDIA_DIR/links/剧集/"
        log_info "- 动漫: $MEDIA_DIR/links/动漫/"
        log_info "- 电影: $MEDIA_DIR/links/电影/"
    fi
    
    if [ "$DEPLOY_ROON" = true ]; then
        echo
        log_info "已启动的音乐服务:"
        log_info "- Roon Server: 请在Roon应用中搜索并连接"
        echo
        log_info "Roon Server信息:"
        log_info "- 容器名称: docker-roonserver"
        log_info "- 数据目录: $ROON_DATA_DIR"
        log_info "- 音乐目录: $MUSIC_DIR"
    fi
    
    if [ "$DEPLOY_BILILIVE" = true ]; then
        echo
        log_info "已启动的直播录制服务:"
        log_info "- BiliLive直播录制: http://${server_ip}:${BILILIVE_PORT}"
        echo
        log_info "BiliLive信息:"
        log_info "- 容器名称: $BILILIVE_CONTAINER_NAME"
        log_info "- 录制文件目录: $BILILIVE_DIR"
        log_info "- Web管理端口: $BILILIVE_PORT"
    fi
    
    if [ "$DEPLOY_CLASH" = true ]; then
        echo
        log_info "已启动的代理服务:"
        log_info "- Clash代理服务: http://${server_ip}:${CLASH_WEB_PORT}"
        echo
        log_info "Clash信息:"
        log_info "- 容器名称: $CLASH_CONTAINER_NAME"
        log_info "- 配置目录: $CLASH_DIR"
        log_info "- Web管理端口: $CLASH_WEB_PORT"
        log_info "- 代理端口: $CLASH_PROXY_PORT"
        log_info "- HTTP代理: http://${server_ip}:${CLASH_PROXY_PORT}"
        log_info "- SOCKS5代理: socks5://${server_ip}:7891 (如果配置中启用)"
    fi
    
    if [ "$DEPLOY_FRPC" = true ]; then
        echo
        log_info "已启动的内网穿透服务:"
        log_info "- FRP Client容器已启动"
        echo
        log_info "FRP Client信息:"
        log_info "- 容器名称: $FRPC_CONTAINER_NAME"
        log_info "- 配置目录: $FRPC_DIR"
        log_info "- 配置文件: $FRPC_DIR/frpc.toml"
        log_info "- 本地IP地址: $FRPC_LOCAL_IP"
        log_info "- 本地端口: 3000 (MoviePilot)"
        log_info "- 远程端口: $FRPC_REMOTE_PORT"
        log_info "- 访问地址: http://122.51.73.200:$FRPC_REMOTE_PORT"
        log_info "- 内网穿透状态: 请查看 docker logs frpc"
    fi
    
    echo
    log_info "容器管理命令:"
    log_info "- 查看所有容器状态: docker ps"
    log_info "- 查看容器日志: docker logs [容器名]"
    
    # 生成服务控制命令
    local media_services=""
    local all_services=""
    
    # 构建实际部署的媒体服务列表
    [ "$DEPLOY_MOVIEPILOT" = true ] && media_services="$media_services moviepilot"
    [ "$DEPLOY_QBITTORRENT" = true ] && media_services="$media_services qbittorrent"
    [ "$DEPLOY_TRANSMISSION" = true ] && media_services="$media_services transmission"
    [ "$DEPLOY_EMBYSERVER" = true ] && media_services="$media_services embyserver"
    
    all_services="$media_services"
    
    if [ "$DEPLOY_ROON" = true ]; then
        all_services="$all_services docker-roonserver"
    fi
    
    if [ "$DEPLOY_BILILIVE" = true ]; then
        all_services="$all_services $BILILIVE_CONTAINER_NAME"
    fi
    
    if [ "$DEPLOY_CLASH" = true ]; then
        all_services="$all_services $CLASH_CONTAINER_NAME"
    fi
    
    if [ "$DEPLOY_FRPC" = true ]; then
        all_services="$all_services $FRPC_CONTAINER_NAME"
    fi
    
    # 显示服务控制命令
    if [ -n "$all_services" ]; then
        log_info "- 停止所有服务: docker stop $all_services"
        log_info "- 启动所有服务: docker start $all_services"
    fi
    
    if [ -n "$media_services" ]; then
        log_info "- 停止媒体服务: docker stop $media_services"
        log_info "- 启动媒体服务: docker start $media_services"
    fi
    
    if [ "$DEPLOY_ROON" = true ]; then
        log_info "- 停止Roon服务: docker stop docker-roonserver"
        log_info "- 启动Roon服务: docker start docker-roonserver"
    fi
    
    if [ "$DEPLOY_BILILIVE" = true ]; then
        log_info "- 停止BiliLive服务: docker stop $BILILIVE_CONTAINER_NAME"
        log_info "- 启动BiliLive服务: docker start $BILILIVE_CONTAINER_NAME"
    fi
    
    if [ "$DEPLOY_CLASH" = true ]; then
        log_info "- 停止Clash服务: docker stop $CLASH_CONTAINER_NAME"
        log_info "- 启动Clash服务: docker start $CLASH_CONTAINER_NAME"
    fi
    
    if [ "$DEPLOY_FRPC" = true ]; then
        log_info "- 停止FRP Client服务: docker stop $FRPC_CONTAINER_NAME"
        log_info "- 启动FRP Client服务: docker start $FRPC_CONTAINER_NAME"
    fi
    
    echo
    log_info "提示:"
    log_info "- 如果IP地址显示不正确，请将 ${server_ip} 替换为实际的服务器IP"
    log_info "- 也可以使用 localhost 或 127.0.0.1 进行本地访问"
    echo "================================================="
}

# 主函数
main() {
    echo "================================================="
    echo "        全能服务器一键部署脚本 v1.0"
    echo "  支持媒体服务器套件 + Roon Music Server + 哔哩哔哩直播录制 + FRP内网穿透"
    echo "        需要Docker已安装且运行"
    echo "================================================="
    echo
    
    # 检查环境
    check_root
    check_docker_running
    
    # 主服务选择
    show_main_menu
    
    # 获取用户配置
    get_user_input
    
    # 创建目录
    create_directories
    
    # 创建Docker网络（如果需要）
    create_network
    
    # 下载配置文件
    download_media_configs
    download_roon_server
    download_clash_config
    create_frpc_config
    
    # 启动服务
    run_moviepilot
    run_qbittorrent
    run_transmission
    run_embyserver
    run_roon_server
    run_bililive
    run_clash
    run_frpc
    
    # 显示完成信息
    show_completion_info
}

# 错误处理
trap 'log_error "脚本执行失败，请检查错误信息"; exit 1' ERR

# 执行主函数
main "$@"
