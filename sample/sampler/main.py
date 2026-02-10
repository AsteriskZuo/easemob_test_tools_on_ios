#!/usr/bin/env python3
"""
IM 数据抽样工具（等分切割）

将文件夹下所有 JSONL 数据文件等分切割为 N 份小文件，
保持数据的时序连续性，适用于 LZ4 压缩率测试抽样。

用法:
    uv run main.py <数据文件夹路径> [选项]

示例:
    uv run main.py ../../sdkTest/tmp --parts 100
    uv run main.py ../../sdkTest/tmp --parts 50 --output-dir ./my_output
"""

import sys
import time
from pathlib import Path


def format_bytes(n: float) -> str:
    """格式化字节数为可读字符串"""
    if n < 1024:
        return f"{n:.0f} B"
    elif n < 1024 * 1024:
        return f"{n / 1024:.1f} KB"
    elif n < 1024 * 1024 * 1024:
        return f"{n / (1024 * 1024):.2f} MB"
    else:
        return f"{n / (1024 * 1024 * 1024):.2f} GB"


def get_data_files(dir_path: Path) -> list[Path]:
    """获取文件夹下所有数据文件（排除隐藏文件），按名称排序"""
    files = []
    for entry in sorted(dir_path.iterdir()):
        if entry.is_file() and not entry.name.startswith("."):
            files.append(entry)
    return files


def count_total_lines(data_files: list[Path], total_file_size: int) -> int:
    """第一遍：流式统计总行数"""
    print("📊 第一遍：统计总行数...")
    total_lines = 0
    bytes_read = 0
    last_progress_time = time.time()

    for file_idx, filepath in enumerate(data_files):
        with open(filepath, "r", encoding="utf-8") as f:
            for raw_line in f:
                if raw_line.strip():
                    total_lines += 1
                bytes_read += len(raw_line.encode("utf-8"))

                now = time.time()
                if now - last_progress_time >= 1.0:
                    pct = bytes_read / total_file_size * 100 if total_file_size else 0
                    print(
                        f"\r  ⏳ 进度: {pct:.1f}% | "
                        f"文件 {file_idx + 1}/{len(data_files)} | "
                        f"已统计 {total_lines:,} 行",
                        end="",
                        flush=True,
                    )
                    last_progress_time = now

    print(f"\r  ✅ 总行数: {total_lines:,}{' ' * 40}")
    return total_lines


def split_files(
    data_files: list[Path],
    total_lines: int,
    total_file_size: int,
    parts: int,
    output_dir: Path,
) -> None:
    """第二遍：流式读取并按行数切割写入"""
    lines_per_part = total_lines // parts
    remainder = total_lines % parts

    print(f"\n✂️  第二遍：切割为 {parts} 份...")
    print(f"  每份约 {lines_per_part:,} 行", end="")
    if remainder > 0:
        print(f"（前 {remainder} 份多 1 行）")
    else:
        print()

    output_dir.mkdir(parents=True, exist_ok=True)

    current_part = 1
    lines_in_current_part = 0
    # 前 remainder 份每份多分 1 行
    current_part_limit = lines_per_part + (1 if current_part <= remainder else 0)
    digits = len(str(parts))
    out_filename = f"part_{current_part:0{digits}d}.jsonl"
    out_file = open(output_dir / out_filename, "w", encoding="utf-8")

    global_line = 0
    bytes_read = 0
    last_progress_time = time.time()

    for file_idx, filepath in enumerate(data_files):
        with open(filepath, "r", encoding="utf-8") as f:
            for raw_line in f:
                stripped = raw_line.strip()
                if not stripped:
                    continue

                bytes_read += len(raw_line.encode("utf-8"))
                global_line += 1

                out_file.write(stripped + "\n")
                lines_in_current_part += 1

                # 当前分片满了，切换到下一个
                if lines_in_current_part >= current_part_limit and current_part < parts:
                    out_file.close()
                    current_part += 1
                    lines_in_current_part = 0
                    current_part_limit = lines_per_part + (
                        1 if current_part <= remainder else 0
                    )
                    out_filename = f"part_{current_part:0{digits}d}.jsonl"
                    out_file = open(output_dir / out_filename, "w", encoding="utf-8")

                # 进度显示
                now = time.time()
                if now - last_progress_time >= 1.0:
                    pct = bytes_read / total_file_size * 100 if total_file_size else 0
                    print(
                        f"\r  ⏳ 进度: {pct:.1f}% | "
                        f"正在写入 part {current_part}/{parts} | "
                        f"已处理 {global_line:,} 行",
                        end="",
                        flush=True,
                    )
                    last_progress_time = now

    out_file.close()
    print(f"\r  ✅ 切割完成！共 {current_part} 份{' ' * 40}")


def main():
    # 解析参数
    args = sys.argv[1:]
    if not args or args[0] in ("-h", "--help"):
        print("用法: uv run main.py <数据文件夹路径> [选项]")
        print()
        print("选项:")
        print("  --parts N        切割份数（默认 100）")
        print("  --output-dir DIR 输出文件夹（默认 ./output）")
        print()
        print("示例:")
        print("  uv run main.py ../../sdkTest/tmp --parts 100")
        print("  uv run main.py ../../sdkTest/tmp --parts 50 --output-dir ./my_output")
        sys.exit(0 if args else 1)

    input_dir = args[0]
    parts = 100
    output_dir = "./output"

    i = 1
    while i < len(args):
        if args[i] == "--parts" and i + 1 < len(args):
            parts = int(args[i + 1])
            i += 2
        elif args[i] == "--output-dir" and i + 1 < len(args):
            output_dir = args[i + 1]
            i += 2
        else:
            print(f"❌ 未知参数: {args[i]}")
            sys.exit(1)

    if parts < 1:
        print("❌ --parts 必须 >= 1")
        sys.exit(1)

    dir_path = Path(input_dir)
    if not dir_path.exists():
        print(f"❌ 路径不存在: {input_dir}")
        sys.exit(1)
    if not dir_path.is_dir():
        print(f"❌ 不是文件夹: {input_dir}")
        sys.exit(1)

    data_files = get_data_files(dir_path)
    if not data_files:
        print(f"❌ 文件夹中没有数据文件: {input_dir}")
        sys.exit(1)

    total_file_size = sum(f.stat().st_size for f in data_files)
    out_path = Path(output_dir)

    print("=" * 60)
    print("  ✂️  IM 数据等分切割工具")
    print("=" * 60)
    print(f"\n📂 输入目录: {input_dir}")
    print(f"📄 数据文件: {len(data_files)} 个")
    print(f"📦 总大小:   {format_bytes(total_file_size)}")
    print(f"🔢 切割份数: {parts}")
    print(f"📁 输出目录: {out_path.resolve()}\n")

    # 第一遍：统计总行数
    total_lines = count_total_lines(data_files, total_file_size)

    if total_lines < parts:
        print(f"⚠️  总行数 ({total_lines:,}) 少于切割份数 ({parts})，调整为 {total_lines} 份")
        parts = total_lines

    # 第二遍：切割
    split_files(data_files, total_lines, total_file_size, parts, out_path)

    # 输出概要
    print()
    print("=" * 60)
    print("  📋 切割结果")
    print("=" * 60)
    print(f"\n  输出目录:   {out_path.resolve()}")
    print(f"  总行数:     {total_lines:,}")
    print(f"  切割份数:   {parts}")
    print(f"  每份约:     {total_lines // parts:,} 行")
    print()

    # 列出生成的文件
    output_files = sorted(out_path.glob("part_*.jsonl"))
    if len(output_files) <= 10:
        for fp in output_files:
            print(f"  {fp.name:20s} {format_bytes(fp.stat().st_size):>10s}")
    else:
        for fp in output_files[:3]:
            print(f"  {fp.name:20s} {format_bytes(fp.stat().st_size):>10s}")
        print(f"  {'...':20s}")
        for fp in output_files[-3:]:
            print(f"  {fp.name:20s} {format_bytes(fp.stat().st_size):>10s}")

    print()
    print("=" * 60)
    print("  切割完成 ✅")
    print("=" * 60)


if __name__ == "__main__":
    main()
