# DockSSH - SSH 远程管理与 Docker 应用中心

🚀 一个基于 Web 的 SSH 远程管理工具，支持命令模板和 Docker 应用一键部署。

## ✨ 功能特性

- 🌐 **SSH 远程管理**: 通过网页配置和连接远程 Linux 设备
- ⚙️ **命令模板系统**: 支持变量替换的命令模板
- 🧱 **Docker 应用中心**: 一键安装 Docker 应用
- 💾 **模板管理**: 新增、编辑、删除命令模板
- 🔐 **安全**: 支持密码和私钥登录，不长期保存敏感信息
- 📺 **实时终端**: 基于 xterm.js 的实时命令输出

## 🛠️ 技术栈

- **后端**: Python + FastAPI + WebSocket
- **SSH**: paramiko
- **前端**: 原生 HTML + CSS + JavaScript
- **终端**: xterm.js
- **存储**: JSON 文件

## 🚀 一行安装命令

### 方式一：超快安装（推荐）

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/你的用户名/DockSSH/main/quick-install.sh)
```

### 方式二：克隆并安装

```bash
git clone https://github.com/你的用户名/DockSSH.git && cd DockSSH && pip3 install -r requirements.txt && python3 main.py
```

### 方式三：本地项目安装

如果已经下载了项目：

```bash
cd DockSSH && pip3 install -r requirements.txt && python3 main.py
```

### 方式四：极简版（仅依赖）

```bash
pip3 install fastapi uvicorn paramiko websockets && python3 main.py
```

## 📦 手动安装

```bash
# 1. 克隆项目
git clone https://github.com/你的用户名/DockSSH.git
cd DockSSH

# 2. 安装依赖
pip3 install -r requirements.txt

# 3. 启动服务
python3 main.py

# 4. 或者后台运行
nohup python3 main.py > dockssh.log 2>&1 &
```

## 🌐 访问地址

- 本地访问: **http://localhost:8000**
- 局域网访问: **http://你的IP:8000**

## 📖 使用说明

1. **配置 SSH 连接**: 在"SSH 配置"页面添加远程设备信息
2. **创建命令模板**: 定义可重用的命令模板，支持变量 `${变量名}`
3. **Docker 应用中心**: 选择预置应用一键安装
4. **实时终端**: 查看命令执行的实时输出

## 🔒 安全建议

- 不建议在公网直接暴露此服务
- 建议使用反向代理（Nginx）+ HTTPS
- SSH 密码不会长期保存（仅会话期间）
- 支持私钥认证（更安全）

## 📝 License

MIT

