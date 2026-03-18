# Workspace Migration And Handoff

Use the runtime-lanes scripts as the canonical migration path when the full WCP
workspace moves to another device and Codex must continue immediately.

## Contract

- Preserve the absolute layout under `/home/mikhail` whenever possible.
- For immediate continuity, copy:
  - `/home/mikhail/AGENTS.md`
  - `/home/mikhail/.codex`
  - `/home/mikhail/wcp-sources`
- Treat `wcp-sources` as one unit. Do not split out only the active repos if
  you want the same donor mirrors, parsers, build trees, reports, and local
  working state on the new device.
- If push/auth continuity is needed, also migrate the optional auth material:
  - `/home/mikhail/.gitconfig`
  - `/home/mikhail/.ssh`
  - `/home/mikhail/.config/gh`
  - `/home/mikhail/.git-credentials`

## Canonical Tools

- Manifest generator:
  - `/home/mikhail/wcp-sources/wcp-runtime-lanes/scripts/generate_workspace_handoff.py`
- Staging copier:
  - `/home/mikhail/wcp-sources/wcp-runtime-lanes/scripts/stage_workspace_migration.sh`

## Generated Outputs

- `/home/mikhail/WORKSPACE_HANDOFF.md`
- `/home/mikhail/WORKSPACE_HANDOFF.json`

These generated files capture:

- current host/toolchain snapshot
- top-level workspace inventory with sizes
- repo branch/head/dirty state
- runtime parser/report entry points
- live build loop state and current log tail
- optional auth-path presence

## Restore Guidance

1. Restore the staged tree back under `/home/mikhail`.
2. Start Codex in `/home/mikhail`.
3. Read `/home/mikhail/AGENTS.md` first, then the generated
   `/home/mikhail/WORKSPACE_HANDOFF.md`.
4. Resume from the runtime entry points recorded in the handoff.
5. If the copied `build-wine` tree is invalid on the new host, rebuild it from
   `wcp-runtime-lanes/scripts/rebuild_freewine_local_build.sh`.
