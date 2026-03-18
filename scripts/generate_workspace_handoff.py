#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
from datetime import datetime, timezone
from pathlib import Path


HOME = Path("/home/mikhail")
WORKSPACE_ROOT = HOME / "wcp-sources"
FREEWINE_ROOT = WORKSPACE_ROOT / "freewine11"
LANES_ROOT = WORKSPACE_ROOT / "wcp-runtime-lanes"
OUTPUT_MD = HOME / "WORKSPACE_HANDOFF.md"
OUTPUT_JSON = HOME / "WORKSPACE_HANDOFF.json"
VERSIONED_DOC = LANES_ROOT / "docs" / "WORKSPACE_MIGRATION_AND_HANDOFF.md"

TRANSFER_PATHS = [
    HOME / "AGENTS.md",
    HOME / ".codex",
    WORKSPACE_ROOT,
]

OPTIONAL_AUTH_PATHS = [
    HOME / ".gitconfig",
    HOME / ".ssh",
    HOME / ".config" / "gh",
    HOME / ".git-credentials",
]

ENTRYPOINTS = [
    HOME / "AGENTS.md",
    FREEWINE_ROOT / "AGENTS.md",
    FREEWINE_ROOT / ".freewine11" / "BUILD_FAILURE_CLASS_MEMORY.md",
    FREEWINE_ROOT / ".freewine11" / "ARM64_OMEGA_CLOSURE_REPORT.md",
    FREEWINE_ROOT / ".freewine11" / "ARM64_CRT_HEADER_SURFACE.md",
    LANES_ROOT / "AGENTS.md",
    LANES_ROOT / "scripts" / "rebuild_freewine_local_build.sh",
    LANES_ROOT / "scripts" / "resume_freewine_local_build.sh",
    LANES_ROOT / "scripts" / "open_freewine_live_log.sh",
]


def quote(path: Path) -> str:
    return subprocess.list2cmdline([str(path)])


def run(command: str, timeout: int = 120) -> str:
    completed = subprocess.run(
        ["bash", "-lc", command],
        capture_output=True,
        text=True,
        timeout=timeout,
        check=False,
    )
    return completed.stdout.strip()


def path_size(path: Path) -> tuple[int, str]:
    if not path.exists():
        return 0, "missing"
    size_bytes = int(run(f"du -sb {quote(path)} | awk '{{print $1}}'") or "0")
    size_human = run(f"du -sh {quote(path)} | awk '{{print $1}}'") or "0"
    return size_bytes, size_human


def repo_summary(path: Path) -> dict[str, object]:
    summary = {
        "path": str(path),
        "branch": None,
        "head": None,
        "remote": None,
        "dirty_count": None,
        "status_preview": [],
    }
    if not (path / ".git").exists():
        return summary
    summary["head"] = run(f"git -C {quote(path)} rev-parse HEAD")
    summary["branch"] = run(f"git -C {quote(path)} branch --show-current")
    summary["remote"] = run(f"git -C {quote(path)} remote get-url origin")
    summary["dirty_count"] = int(run(f"git -C {quote(path)} status --short | wc -l") or "0")
    preview = run(f"git -C {quote(path)} status --short | sed -n '1,40p'")
    summary["status_preview"] = [line for line in preview.splitlines() if line]
    return summary


def host_snapshot() -> dict[str, str]:
    distro = run("lsb_release -ds 2>/dev/null || sed -n 's/^PRETTY_NAME=//p' /etc/os-release | head -n1").strip('"')
    return {
        "uname": run("uname -a"),
        "distro": distro,
        "python": run("python3 --version"),
        "clang": run("clang --version | head -n1"),
        "git": run("git --version"),
        "rsync": run("rsync --version | head -n1"),
    }


def workspace_top_level() -> list[dict[str, object]]:
    entries: list[dict[str, object]] = []
    for path in sorted(WORKSPACE_ROOT.iterdir()):
        if not path.is_dir():
            continue
        size_bytes, size_human = path_size(path)
        entries.append(
            {
                "path": str(path),
                "size_bytes": size_bytes,
                "size_human": size_human,
                "is_git_repo": (path / ".git").exists(),
            }
        )
    return entries


def parser_inventory() -> list[str]:
    parser_root = FREEWINE_ROOT / ".freewine11"
    return [str(path) for path in sorted(parser_root.iterdir()) if path.is_file()]


def agents_inventory() -> list[str]:
    paths = []
    for candidate in [
        HOME / "AGENTS.md",
        FREEWINE_ROOT / "AGENTS.md",
        LANES_ROOT / "AGENTS.md",
        WORKSPACE_ROOT / "aeolator" / "AGENTS.md",
        WORKSPACE_ROOT / "wcp-graphics-lanes" / "AGENTS.md",
    ]:
        if candidate.exists():
            paths.append(str(candidate))
    return paths


def active_build_state() -> dict[str, object]:
    log_path = LANES_ROOT / "out" / "freewine11-local" / "logs" / "wine-build.log"
    tail_text = ""
    if log_path.exists():
        tail_text = run(f"tail -n 40 {quote(log_path)}", timeout=30)
    processes = run("pgrep -af 'rebuild_freewine_local_build.sh|resume_freewine_local_build.sh|make -j[0-9]+ all'", timeout=15)
    return {
        "build_dir": str(LANES_ROOT / "build-wine"),
        "wine_src": str(LANES_ROOT / "wine-src"),
        "log_path": str(log_path),
        "processes": [line for line in processes.splitlines() if line],
        "log_tail": tail_text.splitlines(),
    }


def optional_auth_inventory() -> list[dict[str, object]]:
    entries = []
    for path in OPTIONAL_AUTH_PATHS:
        exists = path.exists()
        size_bytes, size_human = path_size(path) if exists else (0, "missing")
        entries.append(
            {
                "path": str(path),
                "present": exists,
                "size_bytes": size_bytes,
                "size_human": size_human,
            }
        )
    return entries


def transfer_units() -> list[dict[str, object]]:
    entries = []
    for path in TRANSFER_PATHS:
        size_bytes, size_human = path_size(path)
        entries.append(
            {
                "path": str(path),
                "size_bytes": size_bytes,
                "size_human": size_human,
            }
        )
    return entries


def build_payload() -> dict[str, object]:
    return {
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "required_restore_home": str(HOME),
        "required_workspace_root": str(WORKSPACE_ROOT),
        "host": host_snapshot(),
        "transfer_units": transfer_units(),
        "workspace_top_level": workspace_top_level(),
        "repo_summaries": [
            repo_summary(FREEWINE_ROOT),
            repo_summary(LANES_ROOT),
            repo_summary(WORKSPACE_ROOT / "aeolator"),
            repo_summary(WORKSPACE_ROOT / "wcp-graphics-lanes"),
        ],
        "parser_inventory": parser_inventory(),
        "agents_inventory": agents_inventory(),
        "entrypoints": [str(path) for path in ENTRYPOINTS if path.exists()],
        "active_build_state": active_build_state(),
        "optional_auth_inventory": optional_auth_inventory(),
        "versioned_migration_doc": str(VERSIONED_DOC),
        "restore_notes": [
            "Restore the tree to /home/mikhail whenever possible; many AGENTS and scripts use absolute paths.",
            "For immediate Codex continuity, copy /home/mikhail/AGENTS.md, /home/mikhail/.codex, and the whole /home/mikhail/wcp-sources tree.",
            "If auth continuity is needed, also copy the optional auth paths listed in the manifest.",
            "The current runtime build loop lives in wcp-runtime-lanes/build-wine with logs under out/freewine11-local/logs/wine-build.log.",
            "If the copied build tree is invalid on the new host, rerun scripts/rebuild_freewine_local_build.sh from wcp-runtime-lanes.",
        ],
    }


def write_outputs(payload: dict[str, object]) -> None:
    OUTPUT_JSON.write_text(json.dumps(payload, indent=2, ensure_ascii=True) + "\n", encoding="utf-8")

    md_lines = [
        "# Workspace Handoff",
        "",
        f"- Generated: `{payload['generated_at_utc']}`",
        f"- Required restore home: `{payload['required_restore_home']}`",
        f"- Required workspace root: `{payload['required_workspace_root']}`",
        "",
        "## Host Snapshot",
        "",
        f"- Kernel: `{payload['host']['uname']}`",
        f"- Distro: `{payload['host']['distro']}`",
        f"- Python: `{payload['host']['python']}`",
        f"- Clang: `{payload['host']['clang']}`",
        f"- Git: `{payload['host']['git']}`",
        f"- Rsync: `{payload['host']['rsync']}`",
        "",
        "## Copy Units",
        "",
    ]
    for item in payload["transfer_units"]:
        md_lines.append(f"- `{item['path']}` -> `{item['size_human']}`")

    md_lines.extend(["", "## Workspace Top Level", ""])
    for item in payload["workspace_top_level"]:
        git_flag = "git" if item["is_git_repo"] else "plain"
        md_lines.append(f"- `{item['path']}` -> `{item['size_human']}` ({git_flag})")

    md_lines.extend(["", "## Repo State", ""])
    for repo in payload["repo_summaries"]:
        md_lines.append(
            f"- `{repo['path']}` -> branch `{repo['branch']}`, head `{repo['head']}`, dirty `{repo['dirty_count']}`"
        )
        if repo["remote"]:
            md_lines.append(f"  remote: `{repo['remote']}`")
        for line in repo["status_preview"][:8]:
            md_lines.append(f"  status: `{line}`")

    md_lines.extend(
        [
            "",
            "## Runtime Resume",
            "",
            f"- Build dir: `{payload['active_build_state']['build_dir']}`",
            f"- Mirror: `{payload['active_build_state']['wine_src']}`",
            f"- Log: `{payload['active_build_state']['log_path']}`",
            "- Active processes:",
        ]
    )
    for line in payload["active_build_state"]["processes"]:
        md_lines.append(f"  - `{line}`")
    md_lines.append("- Log tail:")
    for line in payload["active_build_state"]["log_tail"][:20]:
        md_lines.append(f"  - `{line}`")

    md_lines.extend(["", "## Entry Points", ""])
    for entry in payload["entrypoints"]:
        md_lines.append(f"- `{entry}`")

    md_lines.extend(["", "## Optional Auth Paths", ""])
    for item in payload["optional_auth_inventory"]:
        presence = "present" if item["present"] else "missing"
        md_lines.append(f"- `{item['path']}` -> {presence} (`{item['size_human']}`)")

    md_lines.extend(["", "## Restore Notes", ""])
    for note in payload["restore_notes"]:
        md_lines.append(f"- {note}")

    OUTPUT_MD.write_text("\n".join(md_lines) + "\n", encoding="utf-8")


def main() -> int:
    payload = build_payload()
    write_outputs(payload)
    print(str(OUTPUT_MD))
    print(str(OUTPUT_JSON))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
