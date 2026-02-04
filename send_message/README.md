# send_message 项目介绍

这是一个使用 Python 编写的 Easemob 消息发送工具。从 `data` 文件夹读取 JSON 数据，提取消息内容并通过 Easemob REST API 发送。

## 功能特性

- ✅ 流式读取大文件，内存友好
- ✅ 支持 txt 和 cmd 类型消息
- ✅ 可配置的发送频率控制
- ✅ 通过 `.env` 文件配置参数（格式参考.env.example）
- ✅ 详细的发送日志和统计

## 环境要求

- Python 3.12+
- [uv](https://docs.astral.sh/uv/) - Python 包管理器

## 安装

### 1. 安装 uv

```bash
# macOS/Linux
curl -LsSf https://astral.sh/uv/install.sh | sh

# 或者使用 Homebrew
brew install uv
```

### 2. 安装项目依赖

```bash
cd send_message
uv sync
```

## 配置

### 1. 创建配置文件

```bash
cp .env.example .env
```

### 2. 编辑 `.env` 文件

```bash
# API 主机地址
EM_HOST=a1.easemob.com

# 组织名
EM_ORG=easemob

# 应用名
EM_APP=easeim

# Bearer Token (必填)
EM_TOKEN=your_bearer_token_here

# 消息接收者
EM_TARGET=zuoyu2

# 消息发送者
EM_FROM=zuoyu1

# 发送间隔毫秒数 (默认: 1000)
EM_INTERVAL_MS=1000
```

## 数据文件格式

将 JSON 数据文件放在 `data` 文件夹下。每个文件包含多行 JSON 数据，每行一条记录。

支持的消息类型：

**txt 类型**：

```json
{"payload": {"bodies": [{"msg": "Hello", "type": "txt"}], ...}, ...}
```

**cmd 类型**：

```json
{"payload": {"bodies": [{"action": "TypingBegin", "type": "cmd"}], ...}, ...}
```

工具会自动提取 `payload.bodies[0].action` 或 `payload.bodies[0].msg` 作为消息内容。

## 使用方法

```bash
# 运行工具
uv run main.py
```

## 输出示例

```
==================================================
🚀 send_message - Easemob 消息发送工具
==================================================
🌐 API 地址: https://a1.easemob.com/easemob/easeim/messages
📁 找到 1 个数据文件
🎯 发送目标: zuoyu2 (从 zuoyu1)
⏱️  发送间隔: 1000ms
--------------------------------------------------

📄 处理文件: 2026012714
  ✅ 行 1: 发送成功 - 当前版本过低，无法展示对应内容。...
  ✅ 行 2: 发送成功 - TypingBegin...
  ...

==================================================
📊 发送统计:
   ✅ 成功: 56
   ❌ 失败: 0
   ⚠️  跳过: 0

✨ 完成!
```

## 注意事项

1. **发送频率**: 默认间隔 1000ms，发送太快可能导致 API 限流
2. **Token 有效期**: 请确保 Bearer Token 未过期
3. **大文件处理**: 工具采用流式读取，不会一次性加载整个文件到内存
