#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import shutil
from collections import Counter
from pathlib import Path
import re


DIFF_RE = re.compile(r"^diff --git a/(.+?) b/(.+)$")


def repo_root_from_script() -> Path:
    return Path(__file__).resolve().parents[2]


def write_tsv(path: Path, header: str, rows: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as handle:
        handle.write(header.rstrip("\n") + "\n")
        for row in rows:
            handle.write(row.rstrip("\n") + "\n")


def parse_patch_paths(patch_file: Path) -> set[str]:
    touched: set[str] = set()
    with patch_file.open("r", encoding="utf-8", errors="ignore") as handle:
        for raw in handle:
            line = raw.rstrip("\r\n")
            match = DIFF_RE.match(line)
            if match:
                touched.add(match.group(1))
                touched.add(match.group(2))
                continue
            if line.startswith("+++ b/"):
                path = line[6:].strip()
                if path != "/dev/null":
                    touched.add(path)
                continue
            if line.startswith("--- a/"):
                path = line[6:].strip()
                if path != "/dev/null":
                    touched.add(path)
                continue
    return {path for path in touched if path}


def path_prefix(path: str) -> str:
    parts = path.split("/")
    if not parts:
        return path
    if parts[0] == "dlls" and len(parts) >= 2:
        return f"dlls/{parts[1]}"
    if parts[0] in {"programs", "libs", "include"} and len(parts) >= 2:
        return f"{parts[0]}/{parts[1]}"
    return parts[0]


def main() -> int:
    parser = argparse.ArgumentParser(description="Promote Wine11 Wave6 proven patches into transfer-lane ownership.")
    parser.add_argument(
        "--proven",
        default="ci/wine11-arm64ec/tkg-ge-wave6-selective-rebase-lane/manifests/proven.tsv",
    )
    parser.add_argument(
        "--lane-dir",
        default="ci/wine11-arm64ec/transfer-lanes/tkg-ge-wave6-runtime",
    )
    parser.add_argument(
        "--report-out",
        default="docs/WINE11_ARM64EC_TKG_GE_WAVE6_RUNTIME_REPORT.md",
    )
    parser.add_argument(
        "--index-out",
        default="docs/WINE11_ARM64EC_TKG_GE_WAVE6_RUNTIME_PATCH_INDEX.tsv",
    )
    args = parser.parse_args()

    root = repo_root_from_script()
    proven_path = (root / args.proven).resolve() if not Path(args.proven).is_absolute() else Path(args.proven)
    lane_dir = (root / args.lane_dir).resolve() if not Path(args.lane_dir).is_absolute() else Path(args.lane_dir)
    report_out = (root / args.report_out).resolve() if not Path(args.report_out).is_absolute() else Path(args.report_out)
    index_out = (root / args.index_out).resolve() if not Path(args.index_out).is_absolute() else Path(args.index_out)

    patch_dir = lane_dir / "patches"
    patch_dir.mkdir(parents=True, exist_ok=True)

    for old in patch_dir.iterdir():
        if old.is_file():
            old.unlink()

    rows_out: list[str] = []
    copied = 0
    family_counter: Counter[str] = Counter()
    prefix_counter: Counter[str] = Counter()

    with proven_path.open("r", encoding="utf-8") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        for row in reader:
            if row.get("route") != "wine":
                continue
            src = Path(row["dest_path"])
            if not src.is_file():
                continue
            dst_name = src.name
            if not dst_name.endswith(".patch"):
                patch_pos = dst_name.find(".patch")
                if patch_pos >= 0:
                    dst_name = f"{dst_name[:patch_pos + len('.patch')]}"
                else:
                    dst_name = f"{dst_name}.patch"
            dst = patch_dir / dst_name
            shutil.copy2(src, dst)
            copied += 1
            family = row["family"]
            family_counter[family] += 1

            touched = parse_patch_paths(dst)
            for touched_path in touched:
                prefix_counter[path_prefix(touched_path)] += 1

            rows_out.append(
                "\t".join(
                    [
                        row["id"],
                        row["family"],
                        row["rel_path"],
                        row["source_patch"],
                        row["effective_patch"],
                        src.as_posix(),
                        dst.as_posix(),
                        row["target"],
                    ]
                )
            )

    rows_out.sort(key=lambda item: int(item.split("\t", 1)[0]))
    write_tsv(
        index_out,
        "id\tfamily\trel_path\tsource_patch\teffective_patch\tlane_source_patch\tlane_patch\ttarget",
        rows_out,
    )

    prefixes = sorted(prefix_counter.keys())
    (lane_dir / "path-prefixes.txt").write_text("\n".join(prefixes) + ("\n" if prefixes else ""), encoding="utf-8")

    readme_lines: list[str] = []
    readme_lines.append("# tkg-ge-wave6-runtime")
    readme_lines.append("")
    readme_lines.append("Owned Wine11 transfer lane promoted from Wave6 selective-rebase proven set.")
    readme_lines.append("")
    readme_lines.append(f"- source manifest: `{proven_path.as_posix()}`")
    readme_lines.append(f"- promoted patches: `{copied}`")
    readme_lines.append(f"- target base: `/home/mikhail/wcp-sources/andre-wine11-arm64ec`")
    readme_lines.append("")
    readme_lines.append("Top families:")
    for family, count in family_counter.most_common(15):
        readme_lines.append(f"- `{family}`: `{count}`")
    (lane_dir / "README.md").write_text("\n".join(readme_lines) + "\n", encoding="utf-8")

    report_lines: list[str] = []
    report_lines.append("# Wine11 ARM64EC TKG/GE Wave6 Runtime Report")
    report_lines.append("")
    report_lines.append("Promotion report for Wave6 selective-rebase proven patches into a dedicated Wine11 transfer lane.")
    report_lines.append("")
    report_lines.append(f"- promoted patches: `{copied}`")
    report_lines.append(f"- source manifest: `{proven_path.as_posix()}`")
    report_lines.append(f"- lane dir: `{lane_dir.as_posix()}`")
    report_lines.append(f"- index: `{index_out.as_posix()}`")
    report_lines.append("")
    report_lines.append("## Top Families")
    report_lines.append("")
    for family, count in family_counter.most_common(20):
        report_lines.append(f"- `{family}`: `{count}`")
    report_lines.append("")
    report_lines.append("## Top Prefixes")
    report_lines.append("")
    for prefix, count in prefix_counter.most_common(20):
        report_lines.append(f"- `{prefix}`: `{count}`")

    report_out.parent.mkdir(parents=True, exist_ok=True)
    report_out.write_text("\n".join(report_lines) + "\n", encoding="utf-8")

    print(f"[wine11-wave6-promote] copied={copied}")
    print(f"[wine11-wave6-promote] lane={lane_dir}")
    print(f"[wine11-wave6-promote] report={report_out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
