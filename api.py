#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
API 路由定义
"""

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional, List, Dict
import json
from pathlib import Path
import re

from ssh_manager import SSHManager

# 创建路由
ssh_router = APIRouter()
docker_router = APIRouter()

# SSH 管理器
ssh_manager = SSHManager()

# 数据文件路径
DATA_DIR = Path("data")
SSH_CONFIGS_FILE = DATA_DIR / "ssh_configs.json"
DOCKER_APPS_FILE = DATA_DIR / "docker_apps.json"


# ===== 数据模型 =====

class SSHConfig(BaseModel):
    """SSH 配置"""
    id: Optional[str] = None
    name: str
    host: str
    port: int = 22
    username: str
    auth_type: str = "password"  # password 或 private_key
    password: Optional[str] = None
    private_key: Optional[str] = None


class SSHConnectRequest(BaseModel):
    """SSH 连接请求"""
    config_id: Optional[str] = None
    host: Optional[str] = None
    port: Optional[int] = 22
    username: Optional[str] = None
    password: Optional[str] = None
    private_key: Optional[str] = None


class CommandRequest(BaseModel):
    """命令执行请求"""
    connection_id: str
    command: str


class DockerApp(BaseModel):
    """Docker 应用"""
    id: Optional[str] = None
    name: str
    description: str
    icon: str = "🐳"
    command: str
    variables: List[Dict[str, str]] = []
    category: str = "general"


# ===== 工具函数 =====

def load_json_file(filepath: Path) -> list:
    """加载 JSON 文件"""
    if filepath.exists():
        with open(filepath, "r", encoding="utf-8") as f:
            return json.load(f)
    return []


def save_json_file(filepath: Path, data: list):
    """保存 JSON 文件"""
    with open(filepath, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)


def generate_id(prefix: str = "") -> str:
    """生成唯一 ID"""
    import uuid
    return f"{prefix}{uuid.uuid4().hex[:8]}"


def extract_variables(command: str) -> list:
    """从命令中提取变量"""
    pattern = r'\$\{([^}]+)\}'
    variables = re.findall(pattern, command)
    return list(set(variables))  # 去重


def replace_variables(command: str, values: dict) -> str:
    """替换命令中的变量"""
    for key, value in values.items():
        command = command.replace(f"${{{key}}}", value)
    return command


# ===== SSH 管理 API =====

@ssh_router.post("/configs")
async def create_ssh_config(config: SSHConfig):
    """创建 SSH 配置"""
    configs = load_json_file(SSH_CONFIGS_FILE)
    
    config.id = generate_id("ssh_")
    configs.append(config.dict())
    
    save_json_file(SSH_CONFIGS_FILE, configs)
    return {"message": "配置已保存", "config": config}


@ssh_router.get("/configs")
async def list_ssh_configs():
    """列出所有 SSH 配置"""
    configs = load_json_file(SSH_CONFIGS_FILE)
    # 不返回密码和私钥
    for config in configs:
        config.pop('password', None)
        config.pop('private_key', None)
    return {"configs": configs}


@ssh_router.get("/configs/{config_id}")
async def get_ssh_config(config_id: str):
    """获取指定 SSH 配置"""
    configs = load_json_file(SSH_CONFIGS_FILE)
    for config in configs:
        if config['id'] == config_id:
            return {"config": config}
    raise HTTPException(status_code=404, detail="配置不存在")


@ssh_router.put("/configs/{config_id}")
async def update_ssh_config(config_id: str, config: SSHConfig):
    """更新 SSH 配置"""
    configs = load_json_file(SSH_CONFIGS_FILE)
    
    for i, c in enumerate(configs):
        if c['id'] == config_id:
            config.id = config_id
            configs[i] = config.dict()
            save_json_file(SSH_CONFIGS_FILE, configs)
            return {"message": "配置已更新", "config": config}
    
    raise HTTPException(status_code=404, detail="配置不存在")


@ssh_router.delete("/configs/{config_id}")
async def delete_ssh_config(config_id: str):
    """删除 SSH 配置"""
    configs = load_json_file(SSH_CONFIGS_FILE)
    configs = [c for c in configs if c['id'] != config_id]
    save_json_file(SSH_CONFIGS_FILE, configs)
    return {"message": "配置已删除"}


@ssh_router.post("/connect")
async def connect_ssh(request: SSHConnectRequest):
    """连接 SSH"""
    # 如果提供了 config_id，从配置中加载
    config_name = None
    if request.config_id:
        configs = load_json_file(SSH_CONFIGS_FILE)
        config = next((c for c in configs if c['id'] == request.config_id), None)
        if not config:
            raise HTTPException(status_code=404, detail="配置不存在")
        
        host = config['host']
        port = config['port']
        username = config['username']
        password = config.get('password')
        private_key = config.get('private_key')
        config_name = config.get('name', f"{username}@{host}")
    else:
        # 使用直接提供的参数
        host = request.host
        port = request.port
        username = request.username
        password = request.password
        private_key = request.private_key
    
    # 创建连接
    connection_id, error = ssh_manager.create_connection(
        host=host,
        port=port,
        username=username,
        password=password,
        private_key=private_key,
        name=config_name
    )
    
    if error:
        raise HTTPException(status_code=400, detail=error)
    
    return {
        "message": "连接成功",
        "connection_id": connection_id,
        "info": ssh_manager.get_connection_info(connection_id)
    }


@ssh_router.get("/connections")
async def list_connections():
    """列出所有活动连接"""
    connections = ssh_manager.list_connections()
    return {"connections": connections}


@ssh_router.delete("/connections/{connection_id}")
async def disconnect_ssh(connection_id: str):
    """断开 SSH 连接"""
    ssh_manager.close_connection(connection_id)
    return {"message": "连接已断开"}


@ssh_router.post("/execute")
async def execute_command(request: CommandRequest):
    """执行命令"""
    stdout, stderr, exit_code = ssh_manager.execute_command(
        request.connection_id,
        request.command
    )
    
    return {
        "stdout": stdout,
        "stderr": stderr,
        "exit_code": exit_code,
        "success": exit_code == 0
    }


@ssh_router.post("/setup-docker-mirror/{connection_id}")
async def setup_docker_mirror(connection_id: str):
    """一键配置 Docker 镜像加速器"""
    
    # 获取SSH连接的密码（用于sudo）
    # 从配置中查找对应的密码
    configs = load_json_file(SSH_CONFIGS_FILE)
    password = None
    
    # 通过connection查找对应的config
    conn_info = ssh_manager.get_connection_info(connection_id)
    if conn_info:
        for config in configs:
            if config['host'] == conn_info['host'] and config['username'] == conn_info['username']:
                password = config.get('password')
                break
    
    if not password:
        return {
            "stdout": "",
            "stderr": "未找到SSH密码，无法执行sudo命令",
            "exit_code": 1,
            "success": False,
            "message": "配置失败：需要sudo密码"
        }
    
    # 配置脚本（使用echo传递密码给sudo -S）
    setup_script = f'''
# 创建配置脚本
cat > /tmp/setup_mirror.sh <<'SETUP_EOF'
#!/bin/bash

# 备份原配置
if [ -f /etc/docker/daemon.json ]; then
    cp /etc/docker/daemon.json /etc/docker/daemon.json.backup.$(date +%Y%m%d_%H%M%S)
fi

# 创建新配置
cat > /tmp/daemon.json <<EOF
{{
  "registry-mirrors": ["https://docker.1ms.run"]
}}
EOF

# 应用配置
mkdir -p /etc/docker
mv /tmp/daemon.json /etc/docker/daemon.json

# 重载 Docker（不停止容器）
systemctl daemon-reload
systemctl reload docker 2>/dev/null 

# 验证配置
echo ""
echo "✅ 镜像加速器配置完成"
echo "📌 镜像源: docker.1ms.run"
echo "💡 所有 docker pull 命令将自动加速"
echo ""
SETUP_EOF

chmod +x /tmp/setup_mirror.sh

# 使用 sudo -S 从标准输入读取密码
echo '{password}' | sudo -S bash /tmp/setup_mirror.sh

# 清理临时文件
rm -f /tmp/setup_mirror.sh
'''
    
    # 执行配置脚本
    stdout, stderr, exit_code = ssh_manager.execute_command(
        connection_id,
        setup_script
    )
    
    return {
        "stdout": stdout,
        "stderr": stderr,
        "exit_code": exit_code,
        "success": exit_code == 0,
        "message": "Docker 镜像加速器配置完成" if exit_code == 0 else "配置失败"
    }


@ssh_router.post("/restore-docker-config/{connection_id}")
async def restore_docker_config(connection_id: str):
    """恢复 Docker 原配置"""
    
    # 获取密码
    configs = load_json_file(SSH_CONFIGS_FILE)
    password = None
    
    conn_info = ssh_manager.get_connection_info(connection_id)
    if conn_info:
        for config in configs:
            if config['host'] == conn_info['host'] and config['username'] == conn_info['username']:
                password = config.get('password')
                break
    
    if not password:
        return {
            "stdout": "",
            "stderr": "未找到SSH密码",
            "exit_code": 1,
            "success": False,
            "message": "恢复失败"
        }
    
    # 恢复脚本（清空镜像加速配置）
    restore_script = f'''
cat > /tmp/restore_docker.sh <<'RESTORE_EOF'
#!/bin/bash

echo "↩️ 正在移除镜像加速器配置..."

# 创建空配置（完全清除镜像加速器）
cat > /etc/docker/daemon.json <<EOF
{{}}
EOF

# 重启 Docker（reload 无法完全清除配置）
echo "⚠️ 重启 Docker 服务（容器短暂中断1-2秒）..."
systemctl daemon-reload
systemctl restart docker 2>&1 >/dev/null

echo ""
echo "✅ 已恢复为默认配置"
echo "💡 docker pull 将使用 Docker Hub 官方源"
echo ""
RESTORE_EOF

chmod +x /tmp/restore_docker.sh
echo '{password}' | sudo -S bash /tmp/restore_docker.sh
rm -f /tmp/restore_docker.sh
'''
    
    stdout, stderr, exit_code = ssh_manager.execute_command(connection_id, restore_script)
    
    return {
        "stdout": stdout,
        "stderr": stderr,
        "exit_code": exit_code,
        "success": exit_code == 0,
        "message": "配置已恢复" if exit_code == 0 else "恢复失败"
    }


# ===== Docker 应用 API =====

@docker_router.get("/apps")
async def list_docker_apps():
    """列出所有 Docker 应用（从GitHub拉取）"""
    import httpx
    
    # 在线应用库URL
    ONLINE_APPS_URL = "https://raw.githubusercontent.com/kidoneself/dockssh/main/data/docker_apps.json"
    ONLINE_SCRIPTS_BASE = "https://raw.githubusercontent.com/kidoneself/dockssh/main/"
    
    apps = []
    source = "cached"
    
    try:
        # 从GitHub获取最新应用列表
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(ONLINE_APPS_URL)
            if response.status_code == 200:
                apps = response.json()
                source = "online"
                # 缓存到本地（离线时使用）
                save_json_file(DATA_DIR / "apps_cache.json", apps)
                print(f"✓ 从GitHub加载了 {len(apps)} 个应用")
    except Exception as e:
        # 在线获取失败，使用缓存
        print(f"在线应用库获取失败: {e}，使用缓存")
        cache_file = DATA_DIR / "apps_cache.json"
        if cache_file.exists():
            apps = load_json_file(cache_file)
            source = "cached"
        else:
            # 使用内置默认应用
            apps = get_default_docker_apps()
            source = "builtin"
    
    # 读取脚本内容（优先从GitHub，本地兜底）
    for app in apps:
        if 'script' in app:
            script_content = ''
            
            # 尝试从GitHub获取脚本
            if source == "online":
                try:
                    async with httpx.AsyncClient(timeout=5.0) as client:
                        script_url = ONLINE_SCRIPTS_BASE + app['script']
                        response = await client.get(script_url)
                        if response.status_code == 200:
                            script_content = response.text
                except:
                    pass
            
            # GitHub获取失败，尝试本地文件
            if not script_content:
                script_path = Path(app['script'])
                if script_path.exists():
                    with open(script_path, 'r', encoding='utf-8') as f:
                        script_content = f.read()
            
            app['script_content'] = script_content
    
    return {"apps": apps, "source": source}


@docker_router.post("/apps")
async def create_docker_app(app: DockerApp):
    """创建 Docker 应用"""
    apps = load_json_file(DOCKER_APPS_FILE)
    
    app.id = generate_id("app_")
    
    # 自动提取变量
    if not app.variables:
        vars_list = extract_variables(app.command)
        app.variables = [
            {"name": var, "description": f"请输入 {var}", "default": ""}
            for var in vars_list
        ]
    
    apps.append(app.dict())
    save_json_file(DOCKER_APPS_FILE, apps)
    
    return {"message": "应用已添加", "app": app}


@docker_router.post("/apps/{app_id}/install")
async def install_docker_app(app_id: str, connection_id: str, variables: Dict[str, str]):
    """安装 Docker 应用"""
    apps = load_json_file(DOCKER_APPS_FILE)
    app = next((a for a in apps if a['id'] == app_id), None)
    
    if not app:
        raise HTTPException(status_code=404, detail="应用不存在")
    
    # 替换变量
    command = replace_variables(app['command'], variables)
    
    # 执行命令
    stdout, stderr, exit_code = ssh_manager.execute_command(connection_id, command)
    
    return {
        "command": command,
        "stdout": stdout,
        "stderr": stderr,
        "exit_code": exit_code,
        "success": exit_code == 0
    }


@docker_router.get("/scripts/{script_name}")
async def get_docker_script(script_name: str):
    """获取 Docker 安装脚本（用于远程执行）"""
    from fastapi.responses import PlainTextResponse
    
    # 安全检查：只允许访问 scripts/docker/ 目录下的脚本
    if '..' in script_name or '/' in script_name:
        raise HTTPException(status_code=400, detail="非法的脚本名称")
    
    script_path = Path(f"scripts/docker/{script_name}")
    
    if not script_path.exists():
        raise HTTPException(status_code=404, detail="脚本不存在")
    
    with open(script_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    return PlainTextResponse(content, media_type='text/plain')


def get_default_docker_apps() -> list:
    """获取默认 Docker 应用列表"""
    return [
        {
            "id": "app_nginx",
            "name": "Nginx",
            "description": "高性能的 Web 服务器和反向代理",
            "icon": "🌐",
            "category": "web",
            "command": "docker run -d --name nginx -p ${port}:80 -v ${html_path}:/usr/share/nginx/html nginx:latest",
            "variables": [
                {"name": "port", "description": "映射端口", "default": "8080"},
                {"name": "html_path", "description": "HTML 文件路径", "default": "/data/html"}
            ]
        },
        {
            "id": "app_mysql",
            "name": "MySQL",
            "description": "流行的关系型数据库",
            "icon": "🗄️",
            "category": "database",
            "command": "docker run -d --name mysql -p ${port}:3306 -e MYSQL_ROOT_PASSWORD=${password} -v ${data_path}:/var/lib/mysql mysql:latest",
            "variables": [
                {"name": "port", "description": "映射端口", "default": "3306"},
                {"name": "password", "description": "Root 密码", "default": ""},
                {"name": "data_path", "description": "数据目录", "default": "/data/mysql"}
            ]
        },
        {
            "id": "app_redis",
            "name": "Redis",
            "description": "高性能的键值存储数据库",
            "icon": "📦",
            "category": "database",
            "command": "docker run -d --name redis -p ${port}:6379 redis:latest",
            "variables": [
                {"name": "port", "description": "映射端口", "default": "6379"}
            ]
        },
        {
            "id": "app_portainer",
            "name": "Portainer",
            "description": "Docker 可视化管理工具",
            "icon": "🎛️",
            "category": "tools",
            "command": "docker run -d --name portainer -p ${port}:9000 -v /var/run/docker.sock:/var/run/docker.sock -v ${data_path}:/data portainer/portainer-ce:latest",
            "variables": [
                {"name": "port", "description": "映射端口", "default": "9000"},
                {"name": "data_path", "description": "数据目录", "default": "/data/portainer"}
            ]
        },
        {
            "id": "app_nextcloud",
            "name": "Nextcloud",
            "description": "开源私有云存储",
            "icon": "☁️",
            "category": "storage",
            "command": "docker run -d --name nextcloud -p ${port}:80 -v ${data_path}:/var/www/html nextcloud:latest",
            "variables": [
                {"name": "port", "description": "映射端口", "default": "8080"},
                {"name": "data_path", "description": "数据目录", "default": "/data/nextcloud"}
            ]
        }
    ]

