# IM 数据抽样工具（等分切割）

将文件夹下所有 JSONL 数据文件等分切割为 N 份小文件，保持数据的时序连续性。

## 使用方法

```bash
cd sample/sampler
uv run main.py <数据文件夹路径> [选项]
```

### 选项

| 参数               | 说明           | 默认值     |
| ------------------ | -------------- | ---------- |
| `--parts N`        | 切割份数       | 100        |
| `--output-dir DIR` | 输出文件夹路径 | `./output` |

### 示例

```bash
# 切割为 100 份
uv run main.py ../../sdkTest/tmp --parts 100

# 切割为 50 份，指定输出目录
uv run main.py ../../sdkTest/tmp --parts 100 --output-dir ./my_output
```

切割完成后，从输出目录中选取若干份文件用于压缩率测试。
