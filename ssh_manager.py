#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
SSH 连接管理器
负责 SSH 连接的创建、维护和销毁
"""

import paramiko
import uuid
import time
from typing import Dict, Optional
import io


class SSHManager:
    """SSH 连接管理器"""
    
    def __init__(self):
        self.connections: Dict[str, dict] = {}
    
    def create_connection(self, host: str, port: int, username: str, 
                         password: str = None, private_key: str = None, name: str = None) -> tuple:
        """
        创建 SSH 连接
        
        返回: (connection_id, error_message)
        """
        try:
            # 创建 SSH 客户端
            client = paramiko.SSHClient()
            client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            
            # 连接参数
            connect_kwargs = {
                'hostname': host,
                'port': port,
                'username': username,
                'timeout': 10,
            }
            
            # 使用密码或私钥
            if private_key:
                # 解析私钥
                try:
                    key_file = io.StringIO(private_key)
                    pkey = paramiko.RSAKey.from_private_key(key_file)
                    connect_kwargs['pkey'] = pkey
                except:
                    # 尝试其他密钥类型
                    try:
                        key_file = io.StringIO(private_key)
                        pkey = paramiko.Ed25519Key.from_private_key(key_file)
                        connect_kwargs['pkey'] = pkey
                    except:
                        key_file = io.StringIO(private_key)
                        pkey = paramiko.ECDSAKey.from_private_key(key_file)
                        connect_kwargs['pkey'] = pkey
            elif password:
                connect_kwargs['password'] = password
            else:
                return None, "必须提供密码或私钥"
            
            # 连接
            client.connect(**connect_kwargs)
            
            # 生成唯一 ID
            connection_id = str(uuid.uuid4())
            
            # 保存连接信息
            self.connections[connection_id] = {
                'client': client,
                'host': host,
                'port': port,
                'username': username,
                'name': name or f"{username}@{host}",
                'created_at': time.time(),
            }
            
            return connection_id, None
            
        except paramiko.AuthenticationException:
            return None, "认证失败: 用户名或密码/私钥错误"
        except paramiko.SSHException as e:
            return None, f"SSH 连接错误: {str(e)}"
        except Exception as e:
            return None, f"连接失败: {str(e)}"
    
    def get_connection(self, connection_id: str) -> Optional[paramiko.SSHClient]:
        """获取 SSH 连接"""
        conn = self.connections.get(connection_id)
        if conn:
            return conn['client']
        return None
    
    def execute_command(self, connection_id: str, command: str) -> tuple:
        """
        执行命令
        
        返回: (stdout, stderr, exit_code)
        """
        client = self.get_connection(connection_id)
        if not client:
            return None, "连接不存在", -1
        
        try:
            stdin, stdout, stderr = client.exec_command(command, timeout=300)
            exit_code = stdout.channel.recv_exit_status()
            
            stdout_text = stdout.read().decode('utf-8', errors='ignore')
            stderr_text = stderr.read().decode('utf-8', errors='ignore')
            
            return stdout_text, stderr_text, exit_code
            
        except Exception as e:
            return None, str(e), -1
    
    def close_connection(self, connection_id: str):
        """关闭 SSH 连接"""
        if connection_id in self.connections:
            try:
                self.connections[connection_id]['client'].close()
            except:
                pass
            del self.connections[connection_id]
    
    def close_all(self):
        """关闭所有连接"""
        for connection_id in list(self.connections.keys()):
            self.close_connection(connection_id)
    
    def get_connection_info(self, connection_id: str) -> Optional[dict]:
        """获取连接信息"""
        conn = self.connections.get(connection_id)
        if conn:
            return {
                'connection_id': connection_id,
                'host': conn['host'],
                'port': conn['port'],
                'username': conn['username'],
                'name': conn.get('name', f"{conn['username']}@{conn['host']}"),
                'created_at': conn['created_at'],
            }
        return None
    
    def list_connections(self) -> list:
        """列出所有连接"""
        return [
            self.get_connection_info(conn_id)
            for conn_id in self.connections.keys()
        ]

