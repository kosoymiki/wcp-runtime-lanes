#!/usr/bin/env python3
"""Static contract gate for WCP Archive runtime repository."""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import List, Sequence

WORKFLOW_PATH = ".github/workflows/ci-arm64ec-wine.yml"
COMMON_SH_PATH = "ci/lib/wcp_common.sh"
RUNTIME_INSPECT_PATH = "ci/validation/inspect-wcp-runtime-contract.sh"

WORKFLOW_ENV_EXPECTATIONS = {
    "WCP_VERSION_CODE": "\"1\"",
    "WCP_CHANNEL": "nightly",
    "WCP_DELIVERY": "remote",
    "WCP_PROFILE_TYPE": "Wine",
    "WCP_DISPLAY_CATEGORY": "Wine",
    "WCP_SOURCE_REPO": "kosoymiki/wcp-runtime-lanes",
    "WCP_RELEASE_TAG": "freewine11-arm64ec-latest",
    "WCP_RELEASE_REPO": "wcp-runtime-lanes",
    "WCP_REQUIRE_USB_RUNTIME": "\"1\"",
    "WCP_RUNTIME_CLASS_TARGET": "bionic-native",
}

WORKFLOW_REQUIRED_TOKENS = [
    "Resolve FreeWine clone URL",
    "Inspect WCP runtime contract",
    "--strict-bionic --require-usb",
    "freewine11-arm64ec.wcp",
]

COMMON_SH_REQUIRED_TOKENS = [
    ': "${WCP_SOURCE_REPO:=${GITHUB_REPOSITORY:-kosoymiki/wcp-runtime-lanes}}"',
    ': "${WCP_RUNTIME_CLASS_TARGET:=bionic-native}"',
]

INSPECTOR_REQUIRED_TOKENS = [
    "--strict-bionic",
    "--require-usb",
    "winebus",
    "wineusb",
]


@dataclass
class CheckResult:
    failures: List[str]
    warnings: List[str]


def fail(msg: str, failures: List[str]) -> None:
    failures.append(msg)


def check_workflow(workflow_path: Path, failures: List[str]) -> None:
    text = workflow_path.read_text(encoding="utf-8", errors="ignore")

    for key, value in WORKFLOW_ENV_EXPECTATIONS.items():
        pattern = rf"^\s*{re.escape(key)}\s*:\s*{re.escape(value)}\s*$"
        if not re.search(pattern, text, re.MULTILINE):
            fail(f"workflow missing env contract: {key}: {value}", failures)

    for token in WORKFLOW_REQUIRED_TOKENS:
        if token not in text:
            fail(f"workflow missing required token: {token}", failures)


def check_common_sh(common_sh_path: Path, failures: List[str]) -> None:
    text = common_sh_path.read_text(encoding="utf-8", errors="ignore")
    for token in COMMON_SH_REQUIRED_TOKENS:
        if token not in text:
            fail(f"wcp_common.sh missing required token: {token}", failures)


def check_runtime_inspector(inspect_path: Path, failures: List[str]) -> None:
    text = inspect_path.read_text(encoding="utf-8", errors="ignore")
    for token in INSPECTOR_REQUIRED_TOKENS:
        if token not in text:
            fail(f"inspect-wcp-runtime-contract.sh missing required token: {token}", failures)


def render_markdown(result: CheckResult) -> str:
    status = "PASS" if not result.failures else "FAIL"
    lines: List[str] = [
        "# WCP Archive Contract",
        "",
        f"- status: **{status}**",
        f"- failures: **{len(result.failures)}**",
        f"- warnings: **{len(result.warnings)}**",
        "",
        "## Failures",
        "",
    ]
    if not result.failures:
        lines.append("- none")
    else:
        for item in result.failures:
            lines.append(f"- {item}")

    lines.extend(["", "## Warnings", ""])
    if not result.warnings:
        lines.append("- none")
    else:
        for item in result.warnings:
            lines.append(f"- {item}")
    lines.append("")
    return "\n".join(lines)


def write_report(output: Path, result: CheckResult) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(render_markdown(result), encoding="utf-8")
    output.with_suffix(".json").write_text(
        json.dumps(
            {
                "passed": not result.failures,
                "failures": result.failures,
                "warnings": result.warnings,
            },
            indent=2,
            ensure_ascii=True,
        )
        + "\n",
        encoding="utf-8",
    )


def parse_args(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate static WCP Archive contract")
    parser.add_argument("--root", default=".", help="Repository root")
    parser.add_argument("--output", default="-", help="Markdown report path or '-' for stdout")
    parser.add_argument("--strict", action="store_true", help="Exit non-zero on warnings too")
    return parser.parse_args(argv)


def main(argv: Sequence[str]) -> int:
    args = parse_args(argv)
    root = Path(args.root).resolve()

    workflow_path = root / WORKFLOW_PATH
    common_sh_path = root / COMMON_SH_PATH
    inspect_path = root / RUNTIME_INSPECT_PATH

    failures: List[str] = []
    warnings: List[str] = []

    for path in (workflow_path, common_sh_path, inspect_path):
        if not path.is_file():
            fail(f"required file missing: {path}", failures)

    if not failures:
        check_workflow(workflow_path, failures)
        check_common_sh(common_sh_path, failures)
        check_runtime_inspector(inspect_path, failures)

    result = CheckResult(failures=failures, warnings=warnings)

    if args.output == "-":
        sys.stdout.write(render_markdown(result))
    else:
        write_report(Path(args.output), result)

    if result.failures:
        return 1
    if args.strict and result.warnings:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
