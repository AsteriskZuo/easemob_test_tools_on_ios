#!/usr/bin/env python3
"""
send_message - 从 data 文件夹读取 JSON 数据并发送消息的工具

使用方法:
    uv run main.py

配置:
    通过 .env 文件或环境变量配置以下参数:
    - EM_HOST: API 主机地址 (默认: a1.easemob.com)
    - EM_ORG: 组织名 (默认: easemob)
    - EM_APP: 应用名 (默认: easeim)
    - EM_TOKEN: Bearer Token (必填)
    - EM_TARGET: 消息接收者 (默认: zuoyu2)
    - EM_FROM: 消息发送者 (默认: zuoyu1)
    - EM_INTERVAL_MS: 发送间隔毫秒数 (默认: 1000)
"""

import json
import os
import time
from pathlib import Path

import httpx
from dotenv import load_dotenv


def load_config() -> dict:
    """加载配置，优先使用 .env 文件，否则使用默认值"""
    load_dotenv()
    
    return {
        "host": os.getenv("EM_HOST", "a1.easemob.com"),
        "org": os.getenv("EM_ORG", "easemob"),
        "app": os.getenv("EM_APP", "easeim"),
        "token": os.getenv("EM_TOKEN", ""),
        "target": os.getenv("EM_TARGET", "zuoyu2"),
        "from_user": os.getenv("EM_FROM", "zuoyu1"),
        "interval_ms": int(os.getenv("EM_INTERVAL_MS", "1000")),
    }


def extract_action(data: dict) -> str | None:
    """从 JSON 数据中提取 action 或 msg 内容"""
    try:
        bodies = data.get("payload", {}).get("bodies", [])
        if not bodies:
            return None
        
        body = bodies[0]
        # 优先获取 action，否则获取 msg
        return body.get("action") or body.get("msg")
    except (KeyError, IndexError, TypeError):
        return None


def send_message(config: dict, action: str) -> dict:
    """发送消息到 Easemob API"""
    url = f"https://{config['host']}/{config['org']}/{config['app']}/messages"
    
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {config['token']}",
    }
    
    payload = {
        "target_type": "users",
        "target": [config["target"]],
        "msg": {
            "type": "cmd",
            "action": action,
        },
        "from": config["from_user"],
        "appkey": f"{config['org']}#{config['app']}",
        "sync_device": True,
    }
    
    with httpx.Client(timeout=30.0) as client:
        response = client.post(url, json=payload, headers=headers)
        return {
            "status_code": response.status_code,
            "response": response.json() if response.status_code == 200 else response.text,
        }


def process_data_files(data_dir: Path, config: dict) -> None:
    """流式读取 data 文件夹下的所有文件并发送消息"""
    if not data_dir.exists():
        print(f"❌ Data 目录不存在: {data_dir}")
        return
    
    # 获取所有文件（不包括子文件夹）
    files = [f for f in data_dir.iterdir() if f.is_file()]
    
    if not files:
        print(f"❌ Data 目录为空: {data_dir}")
        return
    
    print(f"📁 找到 {len(files)} 个数据文件")
    print(f"🎯 发送目标: {config['target']} (从 {config['from_user']})")
    print(f"⏱️  发送间隔: {config['interval_ms']}ms")
    print("-" * 50)
    
    total_sent = 0
    total_failed = 0
    total_skipped = 0
    
    for file_path in files:
        print(f"\n📄 处理文件: {file_path.name}")
        
        # 流式读取文件，逐行处理
        with open(file_path, "r", encoding="utf-8") as f:
            for line_num, line in enumerate(f, 1):
                line = line.strip()
                if not line:
                    continue
                
                try:
                    data = json.loads(line)
                except json.JSONDecodeError as e:
                    print(f"  ⚠️  行 {line_num}: JSON 解析错误 - {e}")
                    total_skipped += 1
                    continue
                
                action = extract_action(data)
                if not action:
                    print(f"  ⚠️  行 {line_num}: 无法提取 action/msg")
                    total_skipped += 1
                    continue
                
                # 发送消息
                try:
                    result = send_message(config, action)
                    if result["status_code"] == 200:
                        print(f"  ✅ 行 {line_num}: 发送成功 - {action[:50]}...")
                        total_sent += 1
                    else:
                        print(f"  ❌ 行 {line_num}: 发送失败 ({result['status_code']}) - {result['response']}")
                        total_failed += 1
                except Exception as e:
                    print(f"  ❌ 行 {line_num}: 请求异常 - {e}")
                    total_failed += 1
                
                # 控制发送频率
                time.sleep(config["interval_ms"] / 1000.0)
    
    print("\n" + "=" * 50)
    print(f"📊 发送统计:")
    print(f"   ✅ 成功: {total_sent}")
    print(f"   ❌ 失败: {total_failed}")
    print(f"   ⚠️  跳过: {total_skipped}")


def main():
    """主函数"""
    print("=" * 50)
    print("🚀 send_message - Easemob 消息发送工具")
    print("=" * 50)
    
    config = load_config()
    
    # 检查 token 是否配置
    if not config["token"]:
        print("❌ 错误: EM_TOKEN 未配置，请在 .env 文件中设置")
        print("   示例: EM_TOKEN=your_bearer_token_here")
        return
    
    print(f"🌐 API 地址: https://{config['host']}/{config['org']}/{config['app']}/messages")
    
    # 获取 data 目录路径
    script_dir = Path(__file__).parent
    data_dir = script_dir / "data"
    
    process_data_files(data_dir, config)
    
    print("\n✨ 完成!")


if __name__ == "__main__":
    main()
