#!/usr/bin/env python3
from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from collections import deque
from pathlib import Path

from PyQt5 import QtCore, QtGui, QtWidgets


DEFAULT_TOTAL_FILES = 16057
DEFAULT_OMEGA_REPORT = Path("/home/mikhail/wcp-sources/freewine11/.freewine11/ARM64_OMEGA_CLOSURE_REPORT.md")
PROGRESS_PATTERN = r"(^| )(gcc|clang|tools/winegcc|tools/widl|tools/wrc|tools/winebuild) "
MAKE_PID_PATTERN = r"make -j[0-9]+ all"


def read_tail(path: Path, line_count: int) -> str:
    try:
        with path.open("r", encoding="utf-8", errors="replace") as handle:
            lines = deque(handle, maxlen=line_count)
        return "".join(lines)
    except FileNotFoundError:
        return ""


def run_shell(command: str, timeout: int = 120) -> str:
    completed = subprocess.run(
        ["bash", "-lc", command],
        capture_output=True,
        text=True,
        timeout=timeout,
        check=False,
    )
    return completed.stdout.strip()


def compute_build_progress(build_dir: Path, total_files: int) -> tuple[int, float]:
    quoted = subprocess.list2cmdline([str(build_dir)])
    remaining_text = run_shell(
        f'cd {quoted} && make -n all 2>/dev/null | grep -E "{PROGRESS_PATTERN}" | wc -l',
        timeout=180,
    )
    try:
        remaining = int(remaining_text or "0")
    except ValueError:
        remaining = total_files
    total = max(total_files, 1)
    percent = ((total - remaining) / total) * 100.0
    percent = max(0.0, min(100.0, percent))
    return remaining, percent


def parse_omega_report(path: Path) -> dict[str, str]:
    result = {
        "processed": "0",
        "total": "0",
        "percent": "0.0",
        "overlap": "missing",
        "duplicates": "n/a",
    }
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except FileNotFoundError:
        return result

    processed_match = re.search(r"Processed modules:\s*`(\d+)`\s*/\s*`(\d+)`", text)
    overlap_match = re.search(r"Recursive overlap status:\s*`([^`]+)`", text)
    duplicate_match = re.search(r"Live duplicate symbols:\s*`(\d+)`", text)

    if processed_match:
        processed = int(processed_match.group(1))
        total = int(processed_match.group(2))
        percent = 0.0 if total <= 0 else min(100.0, max(0.0, (processed / total) * 100.0))
        result["processed"] = str(processed)
        result["total"] = str(total)
        result["percent"] = f"{percent:.1f}"
    if overlap_match:
        result["overlap"] = overlap_match.group(1)
    if duplicate_match:
        result["duplicates"] = duplicate_match.group(1)
    return result


def current_make_elapsed() -> str:
    pid = run_shell(f"pgrep -f '{MAKE_PID_PATTERN}' | head -n1", timeout=10)
    if not pid:
        return "n/a"
    elapsed = run_shell(f"ps -o etime= -p {pid}", timeout=10)
    return elapsed or "n/a"


class LiveLogWindow(QtWidgets.QWidget):
    def __init__(self, log_file: Path, build_dir: Path, total_files: int, omega_report: Path) -> None:
        super().__init__()
        self.log_file = log_file
        self.build_dir = build_dir
        self.total_files = total_files
        self.omega_report = omega_report

        self.setWindowTitle("FreeWine Live Status")
        self.resize(1340, 820)

        layout = QtWidgets.QVBoxLayout(self)
        layout.setContentsMargins(10, 10, 10, 10)
        layout.setSpacing(8)

        self.summary = QtWidgets.QLabel(self)
        self.summary.setTextInteractionFlags(QtCore.Qt.TextSelectableByMouse)
        self.summary.setWordWrap(True)
        summary_font = QtGui.QFont("Monospace")
        summary_font.setStyleHint(QtGui.QFont.TypeWriter)
        summary_font.setPointSize(10)
        self.summary.setFont(summary_font)

        self.text = QtWidgets.QPlainTextEdit(self)
        self.text.setReadOnly(True)
        text_font = QtGui.QFont("Monospace")
        text_font.setStyleHint(QtGui.QFont.TypeWriter)
        text_font.setPointSize(9)
        self.text.setFont(text_font)
        self.text.setLineWrapMode(QtWidgets.QPlainTextEdit.NoWrap)

        layout.addWidget(self.summary)
        layout.addWidget(self.text, 1)

        self.timer = QtCore.QTimer(self)
        self.timer.setInterval(5000)
        self.timer.timeout.connect(self.refresh)
        self.refresh()
        self.timer.start()

    def refresh(self) -> None:
        remaining, build_percent = compute_build_progress(self.build_dir, self.total_files)
        omega = parse_omega_report(self.omega_report)
        elapsed = current_make_elapsed()
        now = QtCore.QDateTime.currentDateTime().toString("yyyy-MM-dd HH:mm:ss t")

        summary_lines = [
            f"[{now}] build {build_percent:.1f}% (remaining {remaining} / baseline {self.total_files}) | "
            f"fundamental {omega['percent']}% (omega {omega['processed']}/{omega['total']}, "
            f"overlap {omega['overlap']}, dup {omega['duplicates']}) | elapsed {elapsed}",
            f"log: {self.log_file}",
            f"build: {self.build_dir}",
            f"omega: {self.omega_report}",
        ]
        self.summary.setText("\n".join(summary_lines))

        tail_text = read_tail(self.log_file, 180)
        self.text.setPlainText(tail_text)
        cursor = self.text.textCursor()
        cursor.movePosition(QtGui.QTextCursor.End)
        self.text.setTextCursor(cursor)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("log_file", nargs="?", default=None)
    parser.add_argument("build_dir", nargs="?", default=None)
    parser.add_argument("total_files", nargs="?", type=int, default=DEFAULT_TOTAL_FILES)
    parser.add_argument("--omega-report", default=str(DEFAULT_OMEGA_REPORT))
    args = parser.parse_args()

    script_dir = Path(__file__).resolve().parent
    repo_root = script_dir.parent
    log_file = Path(args.log_file or repo_root / "out/freewine11-local/logs/wine-build.log")
    build_dir = Path(args.build_dir or repo_root / "build-wine")
    omega_report = Path(args.omega_report)

    log_file.parent.mkdir(parents=True, exist_ok=True)
    log_file.touch(exist_ok=True)

    if not build_dir.is_dir():
        print(f"build dir not found: {build_dir}", file=sys.stderr)
        return 1

    app = QtWidgets.QApplication(sys.argv)
    app.setApplicationName("FreeWine Live Status")
    window = LiveLogWindow(log_file, build_dir, args.total_files, omega_report)
    window.show()
    return app.exec_()


if __name__ == "__main__":
    raise SystemExit(main())
