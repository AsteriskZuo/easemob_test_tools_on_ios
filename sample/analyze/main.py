#!/usr/bin/env python3
"""
IM 数据分析工具

分析文件夹下所有 JSONL 格式的 IM 数据文件，输出数据特征报告。
每行一条 JSON 记录，用于了解数据分布，为后续抽样提供依据。

用法:
    uv run main.py <数据文件夹路径>
"""

import json
import math
import os
import sys
import time
from collections import Counter
from pathlib import Path


# ── 长度分桶定义 ──
BUCKET_BOUNDARIES = [
    (200, "<200B"),
    (500, "200-500B"),
    (1024, "500B-1KB"),
    (5120, "1-5KB"),
    (float("inf"), ">5KB"),
]

# 用于近似百分位数的细粒度分桶（以字节为单位的对数分桶）
HIST_BOUNDARIES: list[int] = []
_v = 1
while _v <= 100_000_000:  # 最大 ~100MB 每行
    HIST_BOUNDARIES.append(_v)
    # 按 ~1.5 倍递增，覆盖从 1B 到 100MB
    _v = max(_v + 1, int(_v * 1.5))
HIST_BOUNDARIES.append(int(1e18))  # 哨兵


class StreamingStats:
    """流式统计：不保存全量数据，使用分桶近似百分位数"""

    def __init__(self) -> None:
        self.count = 0
        self.total = 0
        self.min_val = float("inf")
        self.max_val = 0
        # 对数分桶直方图
        self.hist: list[int] = [0] * len(HIST_BOUNDARIES)

    def add(self, value: int) -> None:
        self.count += 1
        self.total += value
        if value < self.min_val:
            self.min_val = value
        if value > self.max_val:
            self.max_val = value
        # 放入直方图桶
        for i, boundary in enumerate(HIST_BOUNDARIES):
            if value < boundary:
                self.hist[i] += 1
                break

    def avg(self) -> float:
        return self.total / self.count if self.count else 0

    def percentile(self, p: float) -> float:
        """从直方图近似计算第 p 百分位数 (0-100)"""
        if self.count == 0:
            return 0.0
        target = self.count * p / 100.0
        cumulative = 0
        for i, c in enumerate(self.hist):
            cumulative += c
            if cumulative >= target:
                # 返回该桶的上界作为近似值
                return float(HIST_BOUNDARIES[i])
        return float(self.max_val)


def format_bytes(n: float) -> str:
    """格式化字节数为可读字符串"""
    if n < 1024:
        return f"{n:.0f} B"
    elif n < 1024 * 1024:
        return f"{n / 1024:.1f} KB"
    else:
        return f"{n / (1024 * 1024):.2f} MB"


def get_data_files(dir_path: Path) -> list[Path]:
    """获取文件夹下所有数据文件（排除隐藏文件）"""
    files = []
    for entry in sorted(dir_path.iterdir()):
        if entry.is_file() and not entry.name.startswith("."):
            files.append(entry)
    return files


def analyze_directory(dirpath: str) -> None:
    dir_path = Path(dirpath)
    if not dir_path.exists():
        print(f"❌ 路径不存在: {dirpath}")
        sys.exit(1)
    if not dir_path.is_dir():
        print(f"❌ 不是文件夹: {dirpath}")
        sys.exit(1)

    data_files = get_data_files(dir_path)
    if not data_files:
        print(f"❌ 文件夹中没有数据文件: {dirpath}")
        sys.exit(1)

    # 计算总文件大小（用于进度显示）
    total_file_size = sum(f.stat().st_size for f in data_files)

    # 统计容器
    total_lines = 0
    parse_errors = 0
    body_type_counter: Counter[str] = Counter()
    content_type_counter: Counter[str] = Counter()
    chat_type_counter: Counter[str] = Counter()
    bucket_counts: Counter[str] = Counter()
    line_stats = StreamingStats()
    body_stats = StreamingStats()

    print(f"📂 分析目录: {dirpath}")
    print(f"📄 数据文件: {len(data_files)} 个")
    print(f"📦 总大小: {format_bytes(total_file_size)}")
    print()

    bytes_read = 0
    last_progress_time = time.time()

    for file_idx, filepath in enumerate(data_files):
        try:
            f = open(filepath, "r", encoding="utf-8")
        except (OSError, FileNotFoundError):
            print(f"  ⚠️  无法打开文件: {filepath.name}，跳过")
            continue

        with f:
            for raw_line in f:
                stripped = raw_line.strip()
                if not stripped:
                    continue

                total_lines += 1
                line_bytes = len(stripped.encode("utf-8"))
                bytes_read += line_bytes + 1  # +1 换行符

                # 流式统计
                line_stats.add(line_bytes)

                # 行长度分桶
                for boundary, label in BUCKET_BOUNDARIES:
                    if line_bytes < boundary:
                        bucket_counts[label] += 1
                        break

                # 解析 JSON
                try:
                    record = json.loads(stripped)
                except json.JSONDecodeError:
                    parse_errors += 1
                    continue

                # content_type
                ct = record.get("content_type", "unknown")
                content_type_counter[ct] += 1

                # chat_type
                chat_t = record.get("chat_type", "unknown")
                chat_type_counter[chat_t] += 1

                # payload.bodies[0]
                payload = record.get("payload", {})
                bodies = payload.get("bodies", [])
                if bodies:
                    body = bodies[0]
                    body_type = body.get("type", "unknown")
                    body_type_counter[body_type] += 1
                    body_json = json.dumps(body, ensure_ascii=False)
                    body_bytes = len(body_json.encode("utf-8"))
                    body_stats.add(body_bytes)
                else:
                    body_type_counter["(empty)"] += 1
                    body_stats.add(0)

                # 进度显示（每秒最多更新一次）
                now = time.time()
                if now - last_progress_time >= 1.0:
                    pct = bytes_read / total_file_size * 100 if total_file_size else 0
                    print(
                        f"\r  ⏳ 进度: {pct:.1f}% | "
                        f"文件 {file_idx + 1}/{len(data_files)} | "
                        f"已处理 {total_lines:,} 行",
                        end="",
                        flush=True,
                    )
                    last_progress_time = now

    # 清除进度行
    print(f"\r{' ' * 80}\r", end="")

    # ── 输出报告 ──
    print("=" * 60)
    print("  📊 数据分析报告")
    print("=" * 60)

    # 基本信息
    print(f"\n{'── 基本信息 ──':─^56}")
    print(f"  数据文件数:         {len(data_files)}")
    print(f"  总记录数 (有效行):  {total_lines:,}")
    print(f"  解析失败:           {parse_errors}")
    print(f"  总文件大小:         {format_bytes(total_file_size)}")
    if total_lines > 0:
        avg_line = total_file_size / total_lines
        print(f"  平均行大小:         {format_bytes(avg_line)}")

    # 各文件信息
    print(f"\n{'── 文件列表 ──':─^56}")
    for fp in data_files:
        try:
            size_str = format_bytes(fp.stat().st_size)
        except (OSError, FileNotFoundError):
            size_str = "(不可用)"
        print(f"  {fp.name:30s} {size_str:>10s}")

    # body type 分布
    print(f"\n{'── bodies[0].type 分布 ──':─^50}")
    print(f"  {'类型':<20} {'数量':>8} {'占比':>10}")
    print(f"  {'─' * 20} {'─' * 8} {'─' * 10}")
    for t, count in body_type_counter.most_common():
        pct = count / total_lines * 100 if total_lines else 0
        print(f"  {t:<20} {count:>8,} {pct:>9.1f}%")

    # content_type 分布
    print(f"\n{'── content_type 分布 ──':─^50}")
    print(f"  {'类型':<35} {'数量':>8} {'占比':>10}")
    print(f"  {'─' * 35} {'─' * 8} {'─' * 10}")
    for t, count in content_type_counter.most_common():
        pct = count / total_lines * 100 if total_lines else 0
        print(f"  {t:<35} {count:>8,} {pct:>9.1f}%")

    # chat_type 分布
    print(f"\n{'── chat_type 分布 ──':─^50}")
    print(f"  {'类型':<20} {'数量':>8} {'占比':>10}")
    print(f"  {'─' * 20} {'─' * 8} {'─' * 10}")
    for t, count in chat_type_counter.most_common():
        pct = count / total_lines * 100 if total_lines else 0
        print(f"  {t:<20} {count:>8,} {pct:>9.1f}%")

    # 长度统计
    if line_stats.count > 0:
        print(f"\n{'── 整行长度统计 (bytes) ──':─^48}")
        print(f"  Min:   {format_bytes(line_stats.min_val)}")
        print(f"  Max:   {format_bytes(line_stats.max_val)}")
        print(f"  Avg:   {format_bytes(line_stats.avg())}")
        print(f"  P50:   {format_bytes(line_stats.percentile(50))}")
        print(f"  P90:   {format_bytes(line_stats.percentile(90))}")
        print(f"  P99:   {format_bytes(line_stats.percentile(99))}")

        print(f"\n{'── bodies[0] 长度统计 (bytes) ──':─^44}")
        print(f"  Min:   {format_bytes(body_stats.min_val)}")
        print(f"  Max:   {format_bytes(body_stats.max_val)}")
        print(f"  Avg:   {format_bytes(body_stats.avg())}")
        print(f"  P50:   {format_bytes(body_stats.percentile(50))}")
        print(f"  P90:   {format_bytes(body_stats.percentile(90))}")
        print(f"  P99:   {format_bytes(body_stats.percentile(99))}")

    # 长度分桶
    print(f"\n{'── 行长度分桶 ──':─^52}")
    print(f"  {'桶':<12} {'数量':>8} {'占比':>10} {'柱状图'}")
    print(f"  {'─' * 12} {'─' * 8} {'─' * 10} {'─' * 20}")
    max_count = max(bucket_counts.values()) if bucket_counts else 1
    for _, label in BUCKET_BOUNDARIES:
        count = bucket_counts.get(label, 0)
        pct = count / total_lines * 100 if total_lines else 0
        bar_len = int(count / max_count * 20) if max_count else 0
        bar = "█" * bar_len
        print(f"  {label:<12} {count:>8,} {pct:>9.1f}% {bar}")

    print()
    print("=" * 60)
    print("  分析完成 ✅")
    print("=" * 60)


def main():
    if len(sys.argv) < 2:
        print("用法: uv run main.py <数据文件夹路径>")
        print("示例: uv run main.py ../../sdkTest/tmp")
        sys.exit(1)

    analyze_directory(sys.argv[1])


if __name__ == "__main__":
    main()
