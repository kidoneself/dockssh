---
name: 应用需求
about: 提交新的 Docker 应用需求
title: '【应用需求】'
labels: enhancement
assignees: ''
---

## 📦 应用信息

**应用名称：**
<!-- 例如：Nginx、MySQL、Redis 等 -->

**应用描述：**
<!-- 简要说明这个应用是做什么的 -->

**应用分类：**
<!-- 选择一个：web、database、media、tools、storage -->

**Emoji图标：**
<!-- 选择一个代表应用的emoji，例如：🌐🗄️📦🎬🚀 -->

---

## 🐳 Docker 配置

**Docker 镜像名称：**
<!-- 例如：nginx:latest、mysql:8.0、redis:alpine -->

**镜像官方地址：**
<!-- Docker Hub链接，例如：https://hub.docker.com/_/nginx -->

---

## ⚙️ 安装参数

**需要哪些参数：**
<!-- 
例如：
- 端口号（默认值：8080）
- 数据目录（默认值：/data/xxx）
- 密码（默认值：无）
-->

---

## 📝 安装步骤

**安装前需要做什么：**
<!-- 
例如：
1. 创建目录
2. 设置权限
3. 下载配置文件
-->

**Docker启动命令：**
```bash
# 请提供完整的 docker run 命令示例
docker run -d \
  --name 容器名 \
  -p 端口:端口 \
  -v 数据目录:/container/path \
  镜像名:标签
```

---

## 💡 其他说明

<!-- 其他需要注意的事项 -->

---

**提交后我会尽快添加到应用库，所有用户刷新页面即可获得新应用！** 🎉

