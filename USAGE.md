# DockSSH 使用指南

## 快速开始

### 1. 安装依赖

```bash
# 使用启动脚本（推荐）
./start.sh

# 或手动安装
python3 -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt
```

### 2. 启动服务

```bash
# 直接启动
python main.py

# 或使用启动脚本
./start.sh
```

服务启动后，访问：http://localhost:8000

---

## 功能详解

### 🌐 SSH 远程管理

#### 快速连接
在首页的"快速连接"区域，填写远程服务器信息：
- **主机地址**: 服务器 IP 或域名
- **端口**: SSH 端口（默认 22）
- **用户名**: SSH 登录用户名
- **密码**: SSH 密码

点击"连接"后，系统会建立 SSH 连接，连接状态显示在右上角。

#### SSH 配置管理
点击导航栏的"SSH 配置"：

1. **添加配置**
   - 点击"+ 添加配置"
   - 填写配置信息（名称、主机、端口、用户名）
   - 选择认证方式：
     - **密码认证**: 输入密码
     - **私钥认证**: 粘贴私钥内容（支持 RSA、ECDSA、Ed25519）

2. **使用配置**
   - 点击配置卡片上的"连接"按钮
   - 系统自动建立 SSH 连接

3. **管理配置**
   - **编辑**: 修改配置信息
   - **删除**: 删除不需要的配置

---

### ⚙️ 命令模板系统

#### 创建命令模板

1. 进入"命令模板"页面
2. 点击"+ 添加模板"
3. 填写模板信息：
   - **名称**: 模板名称（如"启动 Nginx"）
   - **描述**: 模板功能说明
   - **分类**: 模板分类（如 docker、system）
   - **命令**: 命令内容，使用 `${变量名}` 定义变量

**示例模板**：

```bash
# Docker 容器启动模板
docker run -d --name ${container_name} -p ${port}:80 -v ${data_path}:/data ${image}
```

系统会自动识别命令中的变量：
- `${container_name}`
- `${port}`
- `${data_path}`
- `${image}`

#### 执行命令模板

1. 点击模板卡片上的"执行"按钮
2. 选择要执行命令的 SSH 连接
3. 填写变量值：
   - 系统会为每个变量生成输入框
   - 可以看到实时命令预览
4. 点击"执行"
5. 查看执行结果（stdout、stderr、退出码）

---

### 🐳 Docker 应用中心

#### 预置应用

系统预置了常用的 Docker 应用：

- **Nginx** - Web 服务器
- **MySQL** - 关系型数据库
- **Redis** - 键值存储
- **Portainer** - Docker 管理工具
- **Nextcloud** - 私有云存储

#### 一键安装应用

1. 进入"Docker 应用"页面
2. 使用分类筛选（全部、Web 服务、数据库、存储、工具）
3. 点击应用卡片上的"一键安装"按钮
4. 选择目标 SSH 连接
5. 填写必要的参数（端口、路径、密码等）
6. 点击"执行"安装

**示例：安装 Nginx**

变量填写：
- `port`: 8080
- `html_path`: /data/html

生成的命令：
```bash
docker run -d --name nginx -p 8080:80 -v /data/html:/usr/share/nginx/html nginx:latest
```

#### 添加自定义应用

虽然界面暂不支持直接添加 Docker 应用，但你可以：
1. 通过"命令模板"功能添加
2. 或直接编辑 `data/docker_apps.json` 文件

**JSON 格式**：
```json
{
  "id": "app_custom",
  "name": "自定义应用",
  "description": "应用描述",
  "icon": "🚀",
  "category": "custom",
  "command": "docker run ...",
  "variables": [
    {
      "name": "port",
      "description": "端口号",
      "default": "8080"
    }
  ]
}
```

---

### 💻 实时终端

#### 连接终端

1. 进入"终端"页面
2. 从下拉菜单选择一个活动的 SSH 连接
3. 点击"连接终端"
4. 开始使用命令行界面

#### 终端功能

- **全功能终端**: 基于 xterm.js，支持颜色、光标控制
- **实时交互**: WebSocket 实时传输，低延迟
- **复制粘贴**: 支持标准的终端复制粘贴操作
- **窗口自适应**: 自动适应浏览器窗口大小

#### 终端快捷键

- `Ctrl+C`: 中断当前命令
- `Ctrl+D`: 退出/EOF
- `Tab`: 自动补全（如果远程 shell 支持）
- `↑/↓`: 历史命令

---

## 高级用法

### 命令模板变量

#### 变量语法
在命令中使用 `${变量名}` 定义变量。

#### 变量示例

**示例 1: Docker 端口映射**
```bash
docker run -d -p ${host_port}:${container_port} nginx
```

变量：
- `host_port`: 主机端口
- `container_port`: 容器端口

**示例 2: 文件备份**
```bash
tar -czf /backup/${backup_name}_$(date +%Y%m%d).tar.gz ${source_path}
```

变量：
- `backup_name`: 备份文件名
- `source_path`: 源文件路径

**示例 3: 批量操作**
```bash
for i in {1..${count}}; do
  docker run -d --name app_$i -p $((8080+$i)):80 ${image}
done
```

变量：
- `count`: 容器数量
- `image`: Docker 镜像

### 数据管理

所有配置和模板保存在 `data/` 目录：
- `ssh_configs.json`: SSH 配置
- `templates.json`: 命令模板
- `docker_apps.json`: Docker 应用

#### 备份数据
```bash
tar -czf dockssh_backup.tar.gz data/
```

#### 恢复数据
```bash
tar -xzf dockssh_backup.tar.gz
```

#### 批量导入模板

编辑 `data/templates.json`，添加模板：

```json
[
  {
    "id": "tpl_xxxxx",
    "name": "重启 Docker 服务",
    "description": "重启 Docker 守护进程",
    "command": "systemctl restart docker",
    "variables": [],
    "category": "system"
  }
]
```

---

## 安全建议

### 1. 网络安全
- 不要在公网直接暴露服务
- 使用 VPN 或堡垒机访问
- 配置防火墙规则限制访问

### 2. 认证安全
- **优先使用私钥认证**而非密码
- SSH 密码不会长期保存在服务器
- 连接断开后会自动清理

### 3. 命令安全
- 谨慎执行有 `sudo` 或 `rm -rf` 的命令
- 建议配置命令白名单（需修改代码）
- 执行前仔细检查命令预览

### 4. 生产环境
- 使用 Nginx/Apache 反向代理
- 配置 HTTPS 加密传输
- 启用访问日志和审计

**反向代理示例（Nginx）**：
```nginx
server {
    listen 443 ssl;
    server_name dockssh.yourdomain.com;
    
    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;
    
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

---

## 常见问题

### Q: SSH 连接失败怎么办？
A: 检查：
1. 目标服务器是否开启 SSH 服务
2. 防火墙是否允许 SSH 端口
3. 用户名和密码/私钥是否正确
4. 网络是否可达（ping 测试）

### Q: 私钥认证失败？
A: 确保：
1. 私钥格式正确（PEM 格式）
2. 私钥权限正确（600）
3. 公钥已添加到目标服务器的 `~/.ssh/authorized_keys`

### Q: 终端显示乱码？
A: 设置终端编码为 UTF-8：
```bash
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
```

### Q: Docker 命令执行失败？
A: 检查：
1. 目标服务器是否安装 Docker
2. 用户是否有 Docker 权限（`docker` 组）
3. 端口是否被占用
4. 镜像是否存在（先 `docker pull`）

### Q: 如何同时管理多台服务器？
A: 
1. 为每台服务器创建 SSH 配置
2. 连接不同服务器会创建独立的连接 ID
3. 执行命令时选择对应的连接

### Q: 命令执行超时？
A: 
- 默认超时时间 300 秒
- 长时间任务建议使用终端执行
- 或修改 `ssh_manager.py` 中的 `timeout` 参数

---

## API 文档

如果你想开发自己的客户端或集成，可以使用 REST API：

访问: http://localhost:8000/docs （Swagger UI）

主要接口：
- `POST /api/ssh/connect` - 建立 SSH 连接
- `POST /api/ssh/execute` - 执行命令
- `GET /api/templates` - 获取模板列表
- `POST /api/templates/{id}/execute` - 执行模板
- `GET /api/docker/apps` - 获取应用列表
- `WebSocket /ws/terminal/{connection_id}` - 终端连接

---

## 开发指南

### 项目结构
```
DockSSH/
├── main.py              # 主入口
├── api.py               # API 路由
├── ssh_manager.py       # SSH 连接管理
├── requirements.txt     # Python 依赖
├── static/              # 前端文件
│   ├── index.html       # 主页面
│   ├── css/
│   │   └── style.css    # 样式
│   └── js/
│       └── app.js       # 前端逻辑
└── data/                # 数据存储
    ├── ssh_configs.json
    ├── templates.json
    └── docker_apps.json
```

### 添加新功能

**后端（Python）**：
1. 在 `api.py` 添加路由
2. 在 `ssh_manager.py` 添加 SSH 操作
3. 重启服务

**前端（JavaScript）**：
1. 在 `app.js` 添加功能函数
2. 在 `index.html` 添加 UI 元素
3. 在 `style.css` 添加样式
4. 刷新浏览器

---

## 更新日志

### v1.0.0 (2025-10-31)
- ✅ SSH 远程连接管理
- ✅ 命令模板系统（变量支持）
- ✅ Docker 应用中心（预置 5 个应用）
- ✅ 实时终端（xterm.js + WebSocket）
- ✅ 原生 HTML 前端（无需构建）
- ✅ 支持密码和私钥认证

---

## 贡献与支持

- 提交 Issue: 反馈问题和建议
- Pull Request: 贡献代码
- Star ⭐: 如果觉得有用

---

## 许可证

MIT License - 自由使用和修改

