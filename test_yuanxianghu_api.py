#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
远香湖强电控制API测试脚本
测试地址: http://101.132.154.250:30412/
"""

import requests
import json
from datetime import datetime


class YuanXiangHuAPITester:
    """远香湖API测试器"""
    
    def __init__(self):
        """初始化测试器"""
        self.base_url = "http://101.132.154.250:30412"
        
        # 固定的认证参数
        self.fixed_headers = {
            "Authorization": "bGFtcF93ZWJfcHJvOmxhbXBfd2ViX3Byb19zZWNyZXQ=",
            "TenantId": "475909185582661645",
            "ProjectId": "687560153112772608",
            "ApplicationId": "3",
            "Content-Type": "application/json"
        }
        
        # 登录凭证
        self.username = "yxh_gy"
        self.password = "yxhgy123@"
        
        # 登录后获取的token
        self.token = None
        self.tenant_id = None
        
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
    
    def test_1_login(self):
        """测试1: 用户登录（获取Token）"""
        print("\n" + "="*60)
        print("测试 1: POST /api/oauth/anyTenant/login")
        print("="*60)
        
        try:
            url = f"{self.base_url}/api/oauth/anyTenant/login"
            
            headers = {
                "Authorization": self.fixed_headers["Authorization"],
                "Content-Type": "application/json"
            }
            
            payload = {
                "grantType": "PASSWORD",
                "username": self.username,
                "password": self.password
            }
            
            print(f"📤 请求地址: {url}")
            print(f"📤 请求参数: {json.dumps(payload, ensure_ascii=False)}")
            
            response = requests.post(url, headers=headers, json=payload, timeout=10)
            data = response.json()
            
            print(f"📥 响应状态: HTTP {response.status_code}")
            print(f"📥 响应数据: {json.dumps(data, ensure_ascii=False, indent=2)}")
            
            # 成功条件: code=0 或 200
            if data.get("code") in [0, 200] and data.get("isSuccess"):
                self.token = data.get("data", {}).get("token")
                self.tenant_id = data.get("data", {}).get("tenantId")
                
                self._log(
                    "用户登录",
                    True,
                    f"登录成功！Token已获取 (有效期: {data.get('data', {}).get('expiration')})",
                    {
                        "token_preview": self.token[:50] + "..." if self.token else None,
                        "tenantId": self.tenant_id,
                        "expiration": data.get("data", {}).get("expiration")
                    }
                )
                print(f"   💾 Token: {self.token[:50]}...")
                print(f"   💾 TenantId: {self.tenant_id}")
            else:
                self._log("用户登录", False, f"登录失败: {data.get('msg')}", data)
                
        except requests.RequestException as e:
            self._log("用户登录", False, f"请求异常: {str(e)}")
        except Exception as e:
            self._log("用户登录", False, f"错误: {str(e)}")
    
    def test_2_query_scene_list(self):
        """测试2: 查询场景列表"""
        print("\n" + "="*60)
        print("测试 2: GET /api/strategy/scene/querySceneList")
        print("="*60)
        
        if not self.token:
            self._log("查询场景列表", False, "未登录，无法测试")
            return
        
        try:
            url = f"{self.base_url}/api/strategy/scene/querySceneList"
            
            headers = self.fixed_headers.copy()
            headers["Token"] = self.token
            
            print(f"📤 请求地址: {url}")
            print(f"📤 请求头: Token={self.token[:30]}...")
            
            response = requests.get(url, headers=headers, timeout=10)
            data = response.json()
            
            print(f"📥 响应状态: HTTP {response.status_code}")
            
            if data.get("code") in [0, 200] and data.get("isSuccess"):
                scenes = data.get("data", [])
                self._log(
                    "查询场景列表",
                    True,
                    f"成功获取 {len(scenes)} 个场景",
                    {"scene_count": len(scenes)}
                )
                
                # 打印场景列表
                print("\n   📋 可用场景列表:")
                for scene in scenes:
                    print(f"      • {scene.get('name')} (ID: {scene.get('id')})")
                    print(f"        备注: {scene.get('remark')}")
                    print(f"        状态: {'✅ 可用' if scene.get('state') else '❌ 不可用'}")
                
                # 保存场景ID供后续测试
                if scenes:
                    self.test_scene_ids = {
                        scene.get('name'): scene.get('id') 
                        for scene in scenes
                    }
            else:
                self._log("查询场景列表", False, f"查询失败: {data.get('msg')}", data)
                
        except requests.RequestException as e:
            self._log("查询场景列表", False, f"请求异常: {str(e)}")
        except Exception as e:
            self._log("查询场景列表", False, f"错误: {str(e)}")
    
    def test_3_execute_scene(self, scene_name: str = None, scene_id: str = None):
        """测试3: 执行场景控制"""
        print("\n" + "="*60)
        print("测试 3: GET /api/strategy/scene/executeOneScene")
        print("="*60)
        
        if not self.token:
            self._log("执行场景", False, "未登录，无法测试")
            return
        
        if not scene_id:
            if not hasattr(self, 'test_scene_ids') or not self.test_scene_ids:
                self._log("执行场景", False, "没有可用的场景ID，请先运行查询场景列表")
                return
            
            # 如果没指定scene_id，使用第一个场景
            if scene_name and scene_name in self.test_scene_ids:
                scene_id = self.test_scene_ids[scene_name]
            else:
                scene_name = list(self.test_scene_ids.keys())[0]
                scene_id = self.test_scene_ids[scene_name]
        
        print(f"⚠️  准备执行场景: {scene_name}")
        print(f"   场景ID: {scene_id}")
        print("   ⚠️  注意: 这将实际执行场景控制!")
        
        try:
            user_input = input("   是否继续执行? (y/N): ").strip().lower()
            if user_input != 'y':
                self._log("执行场景", False, "用户取消执行")
                return
        except:
            self._log("执行场景", False, "跳过执行测试(非交互环境)")
            return
        
        try:
            url = f"{self.base_url}/api/strategy/scene/executeOneScene"
            
            headers = self.fixed_headers.copy()
            headers["Token"] = self.token
            del headers["TenantId"]  # 执行场景不需要TenantId
            
            params = {"id": scene_id}
            
            print(f"📤 请求地址: {url}")
            print(f"📤 场景ID: {scene_id}")
            
            response = requests.get(url, headers=headers, params=params, timeout=10)
            data = response.json()
            
            print(f"📥 响应状态: HTTP {response.status_code}")
            print(f"📥 响应数据: {json.dumps(data, ensure_ascii=False, indent=2)}")
            
            if data.get("code") in [0, 200] and data.get("isSuccess"):
                self._log(
                    f"执行场景: {scene_name}",
                    True,
                    "场景执行成功 ✅",
                    data
                )
            else:
                self._log(
                    f"执行场景: {scene_name}",
                    False,
                    f"执行失败: {data.get('msg')}",
                    data
                )
                
        except requests.RequestException as e:
            self._log("执行场景", False, f"请求异常: {str(e)}")
        except Exception as e:
            self._log("执行场景", False, f"错误: {str(e)}")
    
    def run_all_tests(self):
        """运行所有测试"""
        print("\n" + "🚀 "*30)
        print("开始测试远香湖强电控制API")
        print(f"API地址: {self.base_url}")
        print(f"测试时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print("🚀 "*30)
        
        # 按顺序执行测试
        self.test_1_login()
        
        if self.token:
            self.test_2_query_scene_list()
            
            if hasattr(self, 'test_scene_ids') and self.test_scene_ids:
                # 测试执行场景
                self.test_3_execute_scene()
        
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
        if total > 0:
            print(f"成功率: {success/total*100:.1f}%")
        
        if failed > 0:
            print("\n失败的测试:")
            for result in self.test_results:
                if not result["success"]:
                    print(f"  ❌ {result['test']}: {result['message']}")
        
        print("\n" + "="*60)
        
        # 保存详细报告
        report_file = f"yuanxianghu_test_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        with open(report_file, 'w', encoding='utf-8') as f:
            json.dump({
                "summary": {
                    "total": total,
                    "success": success,
                    "failed": failed,
                    "success_rate": f"{success/total*100:.1f}%" if total > 0 else "0%"
                },
                "details": self.test_results
            }, f, ensure_ascii=False, indent=2)
        
        print(f"📄 详细报告已保存: {report_file}")


def main():
    """主函数"""
    tester = YuanXiangHuAPITester()
    tester.run_all_tests()


if __name__ == "__main__":
    main()


