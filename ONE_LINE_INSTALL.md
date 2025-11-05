# 🚀 DockSSH 一行安装命令

## 📦 方式一：从 GitHub 安装（推荐）

如果你的项目已上传到 GitHub，使用这个命令：

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/你的用户名/DockSSH/main/quick-install.sh)"
```

或者使用 wget：

```bash
bash -c "$(wget -qO- https://raw.githubusercontent.com/你的用户名/DockSSH/main/quick-install.sh)"
```

---

## 💻 方式二：本地项目快速安装（当前可用）

如果项目在本地，使用这个超级一行命令：

### macOS / Linux

```bash
cd /Users/lizhiqiang/coding-my/DockSSH && python3 -m pip install -q --trusted-host pypi.tuna.tsinghua.edu.cn -i http://pypi.tuna.tsinghua.edu.cn/simple fastapi uvicorn paramiko websockets 2>/dev/null || python3 -m pip install -q fastapi uvicorn paramiko websockets && mkdir -p data && echo "✅ 安装完成！启动命令: python3 main.py" && python3 main.py
```

**说明**：这一行命令会：
1. ✅ 进入项目目录
2. ✅ 安装所有依赖（优先使用清华源加速）
3. ✅ 创建数据目录
4. ✅ 直接启动服务

---

## 🎯 方式三：克隆并安装（推荐初次使用）

```bash
git clone https://github.com/你的用户名/DockSSH.git && cd DockSSH && pip3 install -r requirements.txt && python3 main.py
```

---

## 🔧 方式四：仅安装依赖（不启动）

```bash
cd /Users/lizhiqiang/coding-my/DockSSH && pip3 install -r requirements.txt && echo "✅ 依赖安装完成！"
```

---

## 📱 方式五：Docker 一键部署

```bash
docker run -d --name dockssh -p 8000:8000 -v $(pwd)/data:/app/data 你的用户名/dockssh:latest
```

---

## 🌟 方式六：极简版（适合演示）

最简洁的命令，适合快速演示：

```bash
python3 -m pip install -q fastapi uvicorn paramiko websockets && python3 main.py
```

---

## 🚀 启动后访问

安装完成后，打开浏览器访问：

- 本地访问：http://localhost:8000
- 局域网访问：http://你的IP:8000

---

## 💡 使用技巧

### 后台运行

```bash
nohup python3 main.py > dockssh.log 2>&1 &
```

### 查看日志

```bash
tail -f dockssh.log
```

### 停止服务

```bash
pkill -f "python3 main.py"
```

---

## 📋 系统要求

- ✅ Python 3.8+
- ✅ pip3
- ✅ 网络连接（用于安装依赖）

---

## 🐛 常见问题

### Q: 端口被占用怎么办？

```bash
# 查看占用端口的进程
lsof -i:8000

# 停止进程
kill -9 $(lsof -ti:8000)
```

### Q: 依赖安装失败？

尝试升级 pip：

```bash
python3 -m pip install --upgrade pip
```

### Q: macOS 提示权限问题？

```bash
pip3 install --user -r requirements.txt
```

---

## 📞 技术支持

如有问题，请查看：
- README.md - 项目说明
- USAGE.md - 使用指南
- GitHub Issues

---

**最后更新**: 2025-10-31

