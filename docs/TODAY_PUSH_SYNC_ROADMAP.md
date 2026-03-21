# 2026-03-21 Push / Sync Roadmap

## Purpose

This file is the live operator checkpoint for agents entering
`wcp-runtime-lanes` during the active 2026-03-21 sync window.

## Current Intent

- Keep `wcp-runtime-lanes` aligned with the exact runtime source-of-truth state
  being pushed from `freewine11`.
- Publish the source-first omega handoff batch before opening new local-only
  runtime work.

## Last Known Head Before The Next Push

- `origin/main` -> `a80ebf8`

If a newer head appears, it supersedes the value above.

## Required Push Payload

Push the coherent handoff batch together:

- `AGENTS.md`
- `scripts/resume_freewine_local_build.sh`
- `docs/WORKSPACE_MIGRATION_AND_HANDOFF.md`
- `scripts/generate_workspace_handoff.py`
- `scripts/live_log_gui.py`
- `scripts/live_log_with_zenity_progress.sh`
- `scripts/open_freewine_live_log.sh`
- `scripts/rebuild_freewine_local_build.sh`
- `scripts/stage_workspace_migration.sh`
- `scripts/live_log_with_progress_and_time.sh`

Only include the items above that already belong to the same logical operator
batch and are ready to publish together.

## Companion Source Requirement

Do not treat this repo as independently done while `freewine11` still holds an
unpushed ARM64 omega/parser/handoff source batch. The `freewine11` push is the
source-of-truth event; this repo is the paired packaging/handoff side.

## Do Not Push

- `__pycache__`
- `.rej`
- `.orig`
- device-local temp outputs
- stale logs or ad-hoc forensic bundles

## Immediate Operator Order

1. `git fetch --all --tags --prune`
2. inspect today's freshest remote heads
3. verify whether the matching `freewine11` source batch is already remote
4. push this repo's paired handoff batch
5. only then resume local mirror/build work
