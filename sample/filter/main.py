#!/usr/bin/env python3
"""
IM 数据筛选工具（按比例筛选）

从 sampler 输出的分片文件中按比例筛选部分文件，
将筛选结果复制到指定的输出文件夹。

支持两种筛选模式：
  - even（默认）：等间距均匀抽取，保持时序覆盖
  - random：随机抽取

用法:
    uv run main.py <分片文件夹路径> [选项]

示例:
    uv run main.py ../sampler/output --ratio 0.1
    uv run main.py ../sampler/output --count 10 --mode random
"""

import random
import shutil
import sys
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


def get_part_files(dir_path: Path) -> list[Path]:
    """获取文件夹下所有分片文件（part_*.jsonl），按名称排序"""
    files = sorted(dir_path.glob("part_*.jsonl"))
    return files


def select_even(files: list[Path], count: int) -> list[Path]:
    """等间距均匀抽取

    从 N 份文件中均匀抽取 count 份。
    例如 100 份取 10 份 → 第 1, 11, 21, 31, ... 份（间距 10）
    """
    n = len(files)
    if count >= n:
        return list(files)

    step = n / count
    selected_indices = [int(i * step) for i in range(count)]
    return [files[i] for i in selected_indices]


def select_random(files: list[Path], count: int) -> list[Path]:
    """随机抽取 count 份文件"""
    n = len(files)
    if count >= n:
        return list(files)

    selected = random.sample(files, count)
    # 按文件名排序，方便查看
    return sorted(selected)


def copy_files(selected: list[Path], output_dir: Path) -> None:
    """将筛选的文件复制到输出目录"""
    output_dir.mkdir(parents=True, exist_ok=True)

    for i, src in enumerate(selected):
        dst = output_dir / src.name
        shutil.copy2(src, dst)

        # 进度显示
        pct = (i + 1) / len(selected) * 100
        print(
            f"\r  ⏳ 复制进度: {pct:.0f}% ({i + 1}/{len(selected)})",
            end="",
            flush=True,
        )

    print(f"\r  ✅ 复制完成！共 {len(selected)} 个文件{' ' * 20}")


def main():
    # 解析参数
    args = sys.argv[1:]
    if not args or args[0] in ("-h", "--help"):
        print("用法: uv run main.py <分片文件夹路径> [选项]")
        print()
        print("选项:")
        print("  --ratio R        筛选比例 0~1（与 --count 二选一，默认 0.1）")
        print("  --count N        筛选数量（与 --ratio 二选一）")
        print("  --mode MODE      筛选模式: even（均匀，默认）/ random（随机）")
        print("  --output-dir DIR 输出文件夹（默认 ./selected）")
        print("  --seed S         随机种子（仅 random 模式生效）")
        print()
        print("示例:")
        print("  uv run main.py ../sampler/output --ratio 0.1")
        print("  uv run main.py ../sampler/output --count 10 --mode random")
        print(
            "  uv run main.py ../sampler/output --ratio 0.2 --output-dir ./my_selected"
        )
        sys.exit(0 if args else 1)

    input_dir = args[0]
    ratio = None
    count = None
    mode = "even"
    output_dir = "./selected"
    seed = None

    i = 1
    while i < len(args):
        if args[i] == "--ratio" and i + 1 < len(args):
            ratio = float(args[i + 1])
            i += 2
        elif args[i] == "--count" and i + 1 < len(args):
            count = int(args[i + 1])
            i += 2
        elif args[i] == "--mode" and i + 1 < len(args):
            mode = args[i + 1]
            i += 2
        elif args[i] == "--output-dir" and i + 1 < len(args):
            output_dir = args[i + 1]
            i += 2
        elif args[i] == "--seed" and i + 1 < len(args):
            seed = int(args[i + 1])
            i += 2
        else:
            print(f"❌ 未知参数: {args[i]}")
            sys.exit(1)

    # 参数校验
    if mode not in ("even", "random"):
        print(f"❌ 未知模式: {mode}（支持 even / random）")
        sys.exit(1)

    dir_path = Path(input_dir)
    if not dir_path.exists():
        print(f"❌ 路径不存在: {input_dir}")
        sys.exit(1)
    if not dir_path.is_dir():
        print(f"❌ 不是文件夹: {input_dir}")
        sys.exit(1)

    part_files = get_part_files(dir_path)
    if not part_files:
        print(f"❌ 文件夹中没有分片文件 (part_*.jsonl): {input_dir}")
        sys.exit(1)

    total_count = len(part_files)

    # 计算筛选数量
    if count is not None and ratio is not None:
        print("❌ --ratio 和 --count 不能同时指定")
        sys.exit(1)

    if count is not None:
        select_count = count
    elif ratio is not None:
        select_count = max(1, round(total_count * ratio))
    else:
        # 默认 10%
        select_count = max(1, round(total_count * 0.1))

    if select_count < 1:
        print("❌ 筛选数量必须 >= 1")
        sys.exit(1)

    if select_count > total_count:
        print(
            f"⚠️  筛选数量 ({select_count}) 大于总文件数 ({total_count})，"
            f"将选取全部文件"
        )
        select_count = total_count

    out_path = Path(output_dir)
    total_size = sum(f.stat().st_size for f in part_files)
    mode_label = "均匀等间距" if mode == "even" else "随机"

    # 打印概要
    print("=" * 60)
    print("  🔍 IM 数据筛选工具")
    print("=" * 60)
    print(f"\n📂 输入目录:   {dir_path.resolve()}")
    print(f"📄 分片文件:   {total_count} 个")
    print(f"📦 总大小:     {format_bytes(total_size)}")
    print(f"🎯 筛选数量:   {select_count} / {total_count}")
    print(f"📊 筛选比例:   {select_count / total_count * 100:.1f}%")
    print(f"🔀 筛选模式:   {mode_label} ({mode})")
    print(f"📁 输出目录:   {out_path.resolve()}")
    if mode == "random" and seed is not None:
        print(f"🎲 随机种子:   {seed}")
    print()

    # 执行筛选
    if mode == "random":
        if seed is not None:
            random.seed(seed)
        selected = select_random(part_files, select_count)
    else:
        selected = select_even(part_files, select_count)

    # 显示筛选结果
    print(f"📋 筛选结果（{len(selected)} 个文件）:")
    if len(selected) <= 20:
        for fp in selected:
            print(f"  ├── {fp.name}  ({format_bytes(fp.stat().st_size)})")
    else:
        for fp in selected[:5]:
            print(f"  ├── {fp.name}  ({format_bytes(fp.stat().st_size)})")
        print(f"  ├── ... (省略 {len(selected) - 10} 个)")
        for fp in selected[-5:]:
            print(f"  ├── {fp.name}  ({format_bytes(fp.stat().st_size)})")
    print()

    # 复制文件
    print("📦 开始复制文件...")
    copy_files(selected, out_path)

    # 输出概要
    selected_size = sum(f.stat().st_size for f in selected)

    print()
    print("=" * 60)
    print("  📋 筛选结果概要")
    print("=" * 60)
    print(f"\n  输出目录:     {out_path.resolve()}")
    print(f"  筛选文件数:   {len(selected)} / {total_count}")
    print(f"  筛选比例:     {len(selected) / total_count * 100:.1f}%")
    print(f"  筛选总大小:   {format_bytes(selected_size)}")
    print(f"  原始总大小:   {format_bytes(total_size)}")
    print(f"  大小比例:     {selected_size / total_size * 100:.1f}%")
    print()

    # 列出输出目录中的文件
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
    print("  筛选完成 ✅")
    print("=" * 60)


if __name__ == "__main__":
    main()
