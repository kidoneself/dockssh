#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
DockSSH - SSH 远程管理与 Docker 应用中心
主入口文件
"""

import uvicorn
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from fastapi.middleware.cors import CORSMiddleware
import json
import os
from pathlib import Path

from api import ssh_router, docker_router, ssh_manager
from ssh_manager import SSHManager

# 创建 FastAPI 应用
app = FastAPI(title="DockSSH", description="SSH 远程管理与 Docker 应用中心", version="1.0.0")

# 配置 CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 注册路由（必须在挂载静态文件之前）
app.include_router(ssh_router, prefix="/api/ssh", tags=["SSH 管理"])
app.include_router(docker_router, prefix="/api/docker", tags=["Docker 应用"])

# 挂载静态文件（放在最后，避免拦截API路由）
app.mount("/static", StaticFiles(directory="static"), name="static")


@app.get("/")
async def root():
    """返回首页"""
    return FileResponse("static/index.html")


@app.websocket("/ws/terminal/{connection_id}")
async def websocket_terminal(websocket: WebSocket, connection_id: str):
    """WebSocket 终端连接"""
    import asyncio
    import select
    
    await websocket.accept()
    channel = None
    
    try:
        # 获取 SSH 连接
        ssh_client = ssh_manager.get_connection(connection_id)
        if not ssh_client:
            await websocket.send_json({
                "type": "error",
                "data": "SSH 连接不存在或已断开"
            })
            await websocket.close()
            return
        
        # 创建交互式 shell
        channel = ssh_client.invoke_shell(term='xterm', width=120, height=40)
        channel.setblocking(0)  # 非阻塞模式
        
        await websocket.send_json({
            "type": "connected",
            "data": "终端已连接\r\n"
        })
        
        # 创建异步任务
        async def read_from_ssh():
            """从 SSH 读取数据并发送到前端"""
            while True:
                try:
                    # 使用 select 检查是否有数据可读
                    if channel.recv_ready():
                        output = channel.recv(8192).decode('utf-8', errors='ignore')
                        if output:
                            await websocket.send_json({
                                "type": "output",
                                "data": output
                            })
                    await asyncio.sleep(0.01)  # 10ms 轮询间隔
                except Exception as e:
                    print(f"读取 SSH 输出错误: {e}")
                    break
        
        async def write_to_ssh():
            """从前端接收输入并发送到 SSH"""
            while True:
                try:
                    data = await websocket.receive_text()
                    if data:
                        channel.send(data)
                except WebSocketDisconnect:
                    break
                except Exception as e:
                    print(f"写入 SSH 输入错误: {e}")
                    break
        
        # 并发执行读写任务
        await asyncio.gather(
            read_from_ssh(),
            write_to_ssh(),
            return_exceptions=True
        )
                
    except WebSocketDisconnect:
        print(f"WebSocket 断开: {connection_id}")
    except Exception as e:
        print(f"WebSocket 错误: {e}")
        try:
            await websocket.send_json({
                "type": "error",
                "data": str(e)
            })
        except:
            pass
    finally:
        if channel:
            try:
                channel.close()
            except:
                pass
        try:
            await websocket.close()
        except:
            pass


@app.on_event("startup")
async def startup_event():
    """启动时初始化"""
    # 创建必要的目录
    Path("data").mkdir(exist_ok=True)
    Path("static").mkdir(exist_ok=True)
    
    # 初始化数据文件
    for filename in ["ssh_configs.json", "docker_apps.json"]:
        filepath = Path("data") / filename
        if not filepath.exists():
            with open(filepath, "w", encoding="utf-8") as f:
                json.dump([], f, ensure_ascii=False, indent=2)
    
    print("🚀 DockSSH 启动成功!")
    print("📍 访问地址: http://localhost:8000")


@app.on_event("shutdown")
async def shutdown_event():
    """关闭时清理"""
    ssh_manager.close_all()
    print("👋 DockSSH 已关闭")


if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
        log_level="info"
    )

