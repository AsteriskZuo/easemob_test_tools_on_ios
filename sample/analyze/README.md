# IM 数据分析工具

分析文件夹下所有 JSONL 格式的 IM 数据文件，输出数据特征报告，为后续抽样提供依据。

## 使用方法

```bash
cd sample/analyze
uv run main.py <数据文件夹路径>
```

### 示例

```bash
uv run main.py ../../sdkTest/tmp
```

## 分析项目

| 统计项            | 说明                                             |
| ----------------- | ------------------------------------------------ |
| 总记录数          | 文件夹中所有文件的有效行数（每行一条 JSON）      |
| body type 分布    | `payload.bodies[0].type` 分类计数（txt、cmd 等） |
| content_type 分布 | 顶层 `content_type` 分类计数                     |
| chat_type 分布    | `chat` / `groupchat` 分类计数                    |
| bodies[0] 长度    | body JSON 字节长度的 Min/Max/Avg/P50/P90/P99     |
| 整行长度          | 每行原始字节长度的 Min/Max/Avg/P50/P90/P99       |
| 行长度分桶        | 按行长度分 5 档，统计数量和占比                  |

> 注：百分位数使用对数分桶近似计算，适用于大文件（GB 级）分析场景。

## 数据格式要求

每行一条完整 JSON，包含 `payload.bodies` 数组（实际只有一条）。
