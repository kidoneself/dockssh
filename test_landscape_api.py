#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
景观场景控制API测试脚本
独立测试脚本，用于测试 landscape-frontend-api.html 文档中的所有接口
"""

import requests
import json
from typing import Optional
from datetime import datetime


class LandscapeAPITester:
    """景观API测试器"""
    
    def __init__(self, base_url: str = "http://localhost:8080", token: Optional[str] = None):
        """
        初始化测试器
        
        Args:
            base_url: API基础URL
            token: 可选的Bearer Token
        """
        self.base_url = base_url
        self.api_base = f"{base_url}/api/landscape/scene"
        self.headers = {
            "Content-Type": "application/json"
        }
        if token:
            self.headers["Authorization"] = f"Bearer {token}"
        
        self.test_results = []
    
    def _log(self, test_name: str, success: bool, message: str, response_data: dict = None):
        """记录测试结果"""
        result = {
            "test": test_name,
            "success": success,
            "message": message,
            "time": datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        }
        if response_data:
            result["data"] = response_data
        
        self.test_results.append(result)
        
        status = "✅" if success else "❌"
        print(f"\n{status} {test_name}")
        print(f"   {message}")
        if response_data and not success:
            print(f"   响应: {json.dumps(response_data, ensure_ascii=False, indent=2)}")
    
    def test_1_get_available_scenes(self):
        """测试1: 查询可用场景列表"""
        print("\n" + "="*60)
        print("测试 1: GET /api/landscape/scene/available")
        print("="*60)
        
        try:
            # 测试获取所有场景
            response = requests.get(f"{self.api_base}/available", headers=self.headers)
            data = response.json()
            
            if response.status_code == 200 and data.get("code") == 200:
                scenes = data.get("data", [])
                self._log(
                    "获取所有场景",
                    True,
                    f"成功获取 {len(scenes)} 个场景",
                    {"count": len(scenes), "sample": scenes[0] if scenes else None}
                )
                
                # 保存第一个场景ID供后续测试使用
                if scenes:
                    self.test_scene_id = scenes[0].get("id")
                    print(f"   💾 保存测试场景ID: {self.test_scene_id}")
            else:
                self._log("获取所有场景", False, f"HTTP {response.status_code}", data)
            
            # 测试按分类筛选
            response = requests.get(
                f"{self.api_base}/available",
                params={"category": "强电"},
                headers=self.headers
            )
            data = response.json()
            
            if response.status_code == 200:
                scenes = data.get("data", [])
                self._log(
                    "按分类筛选场景",
                    True,
                    f"成功获取'强电'分类 {len(scenes)} 个场景"
                )
            else:
                self._log("按分类筛选场景", False, f"HTTP {response.status_code}", data)
                
        except requests.RequestException as e:
            self._log("查询可用场景", False, f"请求异常: {str(e)}")
        except Exception as e:
            self._log("查询可用场景", False, f"错误: {str(e)}")
    
    def test_2_get_categories(self):
        """测试2: 获取所有场景分类"""
        print("\n" + "="*60)
        print("测试 2: GET /api/landscape/scene/categories")
        print("="*60)
        
        try:
            response = requests.get(f"{self.api_base}/categories", headers=self.headers)
            data = response.json()
            
            if response.status_code == 200 and data.get("code") == 200:
                categories = data.get("data", [])
                self._log(
                    "获取场景分类",
                    True,
                    f"成功获取 {len(categories)} 个分类: {', '.join(categories)}"
                )
            else:
                self._log("获取场景分类", False, f"HTTP {response.status_code}", data)
                
        except requests.RequestException as e:
            self._log("获取场景分类", False, f"请求异常: {str(e)}")
        except Exception as e:
            self._log("获取场景分类", False, f"错误: {str(e)}")
    
    def test_3_get_scene_page(self):
        """测试3: 分页查询场景列表"""
        print("\n" + "="*60)
        print("测试 3: GET /api/landscape/scene/page")
        print("="*60)
        
        try:
            params = {
                "current": 1,
                "size": 10
            }
            response = requests.get(
                f"{self.api_base}/page",
                params=params,
                headers=self.headers
            )
            data = response.json()
            
            if response.status_code == 200 and data.get("code") == 200:
                total = data.get("total", 0)
                current = data.get("current", 0)
                size = data.get("size", 0)
                scenes = data.get("data", [])
                
                self._log(
                    "分页查询场景",
                    True,
                    f"第{current}页, 每页{size}条, 共{total}条记录, 返回{len(scenes)}条"
                )
            else:
                self._log("分页查询场景", False, f"HTTP {response.status_code}", data)
                
        except requests.RequestException as e:
            self._log("分页查询场景", False, f"请求异常: {str(e)}")
        except Exception as e:
            self._log("分页查询场景", False, f"错误: {str(e)}")
    
    def test_4_get_scene_detail(self):
        """测试4: 查询场景详情"""
        print("\n" + "="*60)
        print("测试 4: GET /api/landscape/scene/{id}")
        print("="*60)
        
        if not hasattr(self, 'test_scene_id'):
            self._log("查询场景详情", False, "没有可用的测试场景ID，跳过此测试")
            return
        
        try:
            response = requests.get(
                f"{self.api_base}/{self.test_scene_id}",
                headers=self.headers
            )
            data = response.json()
            
            if response.status_code == 200 and data.get("code") == 200:
                scene = data.get("data", {})
                self._log(
                    "查询场景详情",
                    True,
                    f"成功获取场景: {scene.get('sceneName')}",
                    {
                        "id": scene.get("id"),
                        "name": scene.get("sceneName"),
                        "category": scene.get("category"),
                        "executeCount": scene.get("executeCount")
                    }
                )
            else:
                self._log("查询场景详情", False, f"HTTP {response.status_code}", data)
                
        except requests.RequestException as e:
            self._log("查询场景详情", False, f"请求异常: {str(e)}")
        except Exception as e:
            self._log("查询场景详情", False, f"错误: {str(e)}")
    
    def test_5_execute_scene(self):
        """测试5: 执行场景控制 ⭐ 核心接口"""
        print("\n" + "="*60)
        print("测试 5: POST /api/landscape/scene/execute/{id} ⭐")
        print("="*60)
        
        if not hasattr(self, 'test_scene_id'):
            self._log("执行场景", False, "没有可用的测试场景ID，跳过此测试")
            return
        
        print(f"⚠️  将执行场景ID: {self.test_scene_id}")
        print("   注意: 此操作会实际执行场景控制!")
        
        # 询问用户是否继续
        try:
            user_input = input("   是否继续执行? (y/N): ").strip().lower()
            if user_input != 'y':
                self._log("执行场景", False, "用户取消执行")
                return
        except:
            self._log("执行场景", False, "跳过执行测试(非交互环境)")
            return
        
        try:
            response = requests.post(
                f"{self.api_base}/execute/{self.test_scene_id}",
                headers=self.headers
            )
            data = response.json()
            
            # 注意: 成功时 code=0 (不是200)
            if data.get("code") == 0:
                self._log(
                    "执行场景",
                    True,
                    "场景执行成功 ✅",
                    data
                )
            elif data.get("code") == 403:
                self._log(
                    "执行场景",
                    False,
                    "⚠️  权限不足 (第三方平台限制)",
                    data
                )
            elif data.get("code") == 500:
                self._log(
                    "执行场景",
                    False,
                    "❌ 系统异常",
                    data
                )
            else:
                self._log("执行场景", False, f"未知返回码: {data.get('code')}", data)
                
        except requests.RequestException as e:
            self._log("执行场景", False, f"请求异常: {str(e)}")
        except Exception as e:
            self._log("执行场景", False, f"错误: {str(e)}")
    
    def test_6_get_scene_logs(self):
        """测试6: 查询场景执行日志"""
        print("\n" + "="*60)
        print("测试 6: GET /api/landscape/scene/{id}/logs")
        print("="*60)
        
        if not hasattr(self, 'test_scene_id'):
            self._log("查询执行日志", False, "没有可用的测试场景ID，跳过此测试")
            return
        
        try:
            params = {
                "current": 1,
                "size": 10
            }
            response = requests.get(
                f"{self.api_base}/{self.test_scene_id}/logs",
                params=params,
                headers=self.headers
            )
            data = response.json()
            
            if response.status_code == 200 and data.get("code") == 200:
                logs = data.get("data", [])
                total = data.get("total", 0)
                
                self._log(
                    "查询执行日志",
                    True,
                    f"成功获取 {len(logs)} 条日志记录 (共{total}条)",
                    {"total": total, "sample": logs[0] if logs else None}
                )
            else:
                self._log("查询执行日志", False, f"HTTP {response.status_code}", data)
                
        except requests.RequestException as e:
            self._log("查询执行日志", False, f"请求异常: {str(e)}")
        except Exception as e:
            self._log("查询执行日志", False, f"错误: {str(e)}")
    
    def test_7_update_scene_status(self):
        """测试7: 更新场景状态 (管理员功能)"""
        print("\n" + "="*60)
        print("测试 7: PUT /api/landscape/scene/{id}/status")
        print("="*60)
        
        if not hasattr(self, 'test_scene_id'):
            self._log("更新场景状态", False, "没有可用的测试场景ID，跳过此测试")
            return
        
        print("⚠️  此操作会修改场景状态!")
        try:
            user_input = input("   是否继续? (y/N): ").strip().lower()
            if user_input != 'y':
                self._log("更新场景状态", False, "用户取消操作")
                return
        except:
            self._log("更新场景状态", False, "跳过测试(非交互环境)")
            return
        
        try:
            # 测试启用场景
            response = requests.put(
                f"{self.api_base}/{self.test_scene_id}/status",
                params={"localState": 1},
                headers=self.headers
            )
            data = response.json()
            
            if response.status_code == 200 and data.get("code") == 200:
                self._log("更新场景状态", True, "场景状态更新成功")
            else:
                self._log("更新场景状态", False, f"HTTP {response.status_code}", data)
                
        except requests.RequestException as e:
            self._log("更新场景状态", False, f"请求异常: {str(e)}")
        except Exception as e:
            self._log("更新场景状态", False, f"错误: {str(e)}")
    
    def test_8_sync_scenes(self):
        """测试8: 手动同步场景列表 (管理员功能)"""
        print("\n" + "="*60)
        print("测试 8: POST /api/landscape/scene/sync")
        print("="*60)
        
        print("⚠️  此操作会从第三方平台同步场景!")
        try:
            user_input = input("   是否继续? (y/N): ").strip().lower()
            if user_input != 'y':
                self._log("同步场景列表", False, "用户取消操作")
                return
        except:
            self._log("同步场景列表", False, "跳过测试(非交互环境)")
            return
        
        try:
            response = requests.post(
                f"{self.api_base}/sync",
                params={"platformConfigId": 1},
                headers=self.headers
            )
            data = response.json()
            
            if response.status_code == 200 and data.get("code") == 200:
                sync_count = data.get("data", 0)
                self._log("同步场景列表", True, f"成功同步 {sync_count} 个场景")
            else:
                self._log("同步场景列表", False, f"HTTP {response.status_code}", data)
                
        except requests.RequestException as e:
            self._log("同步场景列表", False, f"请求异常: {str(e)}")
        except Exception as e:
            self._log("同步场景列表", False, f"错误: {str(e)}")
    
    def run_all_tests(self):
        """运行所有测试"""
        print("\n" + "🚀 "*30)
        print("开始测试景观场景控制API")
        print(f"API地址: {self.api_base}")
        print(f"测试时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print("🚀 "*30)
        
        # 按顺序执行测试
        self.test_1_get_available_scenes()
        self.test_2_get_categories()
        self.test_3_get_scene_page()
        self.test_4_get_scene_detail()
        self.test_5_execute_scene()
        self.test_6_get_scene_logs()
        self.test_7_update_scene_status()
        self.test_8_sync_scenes()
        
        # 打印测试总结
        self.print_summary()
    
    def print_summary(self):
        """打印测试总结"""
        print("\n" + "📊 "*30)
        print("测试总结")
        print("📊 "*30)
        
        total = len(self.test_results)
        success = sum(1 for r in self.test_results if r["success"])
        failed = total - success
        
        print(f"\n总测试数: {total}")
        print(f"✅ 成功: {success}")
        print(f"❌ 失败: {failed}")
        print(f"成功率: {success/total*100:.1f}%")
        
        if failed > 0:
            print("\n失败的测试:")
            for result in self.test_results:
                if not result["success"]:
                    print(f"  ❌ {result['test']}: {result['message']}")
        
        print("\n" + "="*60)
        
        # 保存详细报告
        report_file = f"test_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        with open(report_file, 'w', encoding='utf-8') as f:
            json.dump({
                "summary": {
                    "total": total,
                    "success": success,
                    "failed": failed,
                    "success_rate": f"{success/total*100:.1f}%"
                },
                "details": self.test_results
            }, f, ensure_ascii=False, indent=2)
        
        print(f"📄 详细报告已保存: {report_file}")


def main():
    """主函数"""
    import argparse
    
    parser = argparse.ArgumentParser(description="景观场景控制API测试工具")
    parser.add_argument(
        "--base-url",
        default="http://localhost:8080",
        help="API基础URL (默认: http://localhost:8080)"
    )
    parser.add_argument(
        "--token",
        help="可选的Bearer Token"
    )
    parser.add_argument(
        "--test",
        type=int,
        choices=range(1, 9),
        help="只运行指定的测试 (1-8)"
    )
    
    args = parser.parse_args()
    
    # 创建测试器
    tester = LandscapeAPITester(base_url=args.base_url, token=args.token)
    
    # 运行测试
    if args.test:
        test_methods = {
            1: tester.test_1_get_available_scenes,
            2: tester.test_2_get_categories,
            3: tester.test_3_get_scene_page,
            4: tester.test_4_get_scene_detail,
            5: tester.test_5_execute_scene,
            6: tester.test_6_get_scene_logs,
            7: tester.test_7_update_scene_status,
            8: tester.test_8_sync_scenes,
        }
        print(f"\n只运行测试 {args.test}")
        test_methods[args.test]()
        tester.print_summary()
    else:
        tester.run_all_tests()


if __name__ == "__main__":
    main()


