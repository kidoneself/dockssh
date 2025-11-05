FROM python:3.9-slim

LABEL maintainer="kidoneself"
LABEL description="DockSSH - SSH远程管理与Docker应用中心"

WORKDIR /app

# 安装系统依赖
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        openssh-client && \
    rm -rf /var/lib/apt/lists/*

# 复制依赖文件并安装
COPY requirements.txt .
RUN pip install --no-cache-dir \
    -i https://pypi.tuna.tsinghua.edu.cn/simple \
    -r requirements.txt

# 复制应用代码
COPY main.py api.py ssh_manager.py ./
COPY static/ ./static/
COPY scripts/ ./scripts/

# 创建数据目录
RUN mkdir -p /app/data

# 暴露端口
EXPOSE 8000

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s \
    CMD curl -f http://localhost:8000/ || exit 1

# 启动命令
CMD ["python", "main.py"]

