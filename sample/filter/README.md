# IM 数据筛选工具（按比例筛选）

从 `sampler` 输出的分片文件中按比例筛选部分文件，将筛选结果复制到指定文件夹。

## 使用方法

```bash
cd sample/filter
uv run main.py <分片文件夹路径> [选项]
```

### 选项

| 参数               | 说明                                       | 默认值       |
| ------------------ | ------------------------------------------ | ------------ |
| `--ratio R`        | 筛选比例 0~1（与 `--count` 二选一）        | 0.1          |
| `--count N`        | 筛选数量（与 `--ratio` 二选一）            | -            |
| `--mode MODE`      | 筛选模式: `even`（均匀）/ `random`（随机） | `even`       |
| `--output-dir DIR` | 输出文件夹路径                             | `./selected` |
| `--seed S`         | 随机种子（仅 `random` 模式生效）           | -            |

### 筛选模式

- **even（均匀，默认）**：等间距抽取，保持时序覆盖。例如 100 份取 10% → 第 1, 11, 21, 31, ... 份
- **random（随机）**：随机抽取指定数量的文件

### 示例

```bash
# 默认：均匀筛选 10%
uv run main.py ../sampler/output

# 均匀筛选 20%
uv run main.py ../sampler/output --ratio 0.2

# 筛选指定数量
uv run main.py ../sampler/output --count 10

# 随机筛选 10%，指定种子保证可复现
uv run main.py ../sampler/output --ratio 0.1 --mode random --seed 42

# 指定输出目录
uv run main.py ../sampler/output --ratio 0.1 --output-dir ./my_selected

# 实际场景中
uv run main.py ../sampler/my_output --ratio 0.1 --mode even --output-dir ./my_selected
```

## 工作流

1. 使用 `sampler` 将原始数据切割为 N 份
2. 使用 `filter` 按比例筛选 M 份
3. 将筛选结果用于后续测试
