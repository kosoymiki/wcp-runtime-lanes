# Mainline Project State

This document is the repo-wide source of truth for the current mainline state.
Use it to understand which plans are still active, which documents are
authoritative, and which files are reflective history only.

## Snapshot (as of 2026-03-03)

- Branch: `main`
- Mainline tip: `8e1b23c2`
- Winlator patch base: consolidated `0001-mainline-full-stack-consolidated.patch`
- Review slices: folded back into `0001`; future `0002+` slices are temporary only
- Runtime surface: X11-first launch contracts, forensic control plane, runtime
  signal contract, and upgraded built-in Task Manager telemetry/control plane
- Repository state: the four-step stabilization series is landed on `main`; the
  current worktree contains active `wine11-arm64ec` lane edits and docs refresh
  for transfer queue closure
- Local validation already passed on this baseline:
  - `python3 ci/contents/validate-contents-json.py contents/contents.json`
  - `python3 ci/validation/check-contents-qa-contract.py --root . --output /tmp/contents-qa-post-commit.md`
  - `bash ci/winlator/validate-patch-sequence.sh ci/winlator/patches`
  - `bash ci/winlator/run-reflective-audits.sh ci/winlator/patches`
  - `bash ci/winlator/check-patch-stack.sh work/winlator-ludashi/src ci/winlator/patches`
  - `ANDROID_HOME=/home/mikhail/.local/android-sdk ANDROID_SDK_ROOT=/home/mikhail/.local/android-sdk ./gradlew :app:compileDebugJavaWithJavac`
  - `ANDROID_HOME=/home/mikhail/.local/android-sdk ANDROID_SDK_ROOT=/home/mikhail/.local/android-sdk ./gradlew :app:assembleDebug`
  - `git diff --check`
  - `adb devices` (`adb` present, no attached devices in the current session)
  - `bash ci/wine11-arm64ec/check-core-transfer-lane.sh`
  - `bash ci/wine11-arm64ec/check-loader-transfer-lane.sh`
  - `bash ci/wine11-arm64ec/check-signal-transfer-lane.sh`
  - `bash ci/wine11-arm64ec/check-server-transfer-lane.sh`
  - `bash ci/wine11-arm64ec/check-server-support-lane.sh`
  - `bash ci/wine11-arm64ec/check-wow64-support-lane.sh`
  - `bash ci/wine11-arm64ec/check-wow64-struct-support-lane.sh`
  - `bash ci/wine11-arm64ec/check-libs-wine-support-lane.sh`
  - `bash ci/wine11-arm64ec/check-winebuild-support-lane.sh`
  - `bash ci/wine11-arm64ec/check-kernelbase-runtime-lane.sh`
  - `bash ci/wine11-arm64ec/check-kernelbase-support-lane.sh`
  - `bash ci/wine11-arm64ec/check-win32u-runtime-lane.sh`
  - `bash ci/wine11-arm64ec/check-kernel32-runtime-lane.sh`
  - `bash ci/wine11-arm64ec/check-dlls-wave1-runtime-lane.sh`
  - `bash ci/wine11-arm64ec/check-include-libs-wave1-runtime-lane.sh`
  - `bash ci/wine11-arm64ec/check-nls-po-programs-server-tools-wave1-runtime-lane.sh`
  - `bash ci/wine11-arm64ec/check-documentation-fonts-root-wave1-runtime-lane.sh`

## Authoritative Documents

| Area | Authoritative doc | Current role |
| --- | --- | --- |
| Repo-wide state | `docs/MAINLINE_PROJECT_STATE.md` | Overall state, active gaps, doc-role map |
| Commit reduction | `docs/COMMIT_SERIES_MAINLINE.md` | Applied 4-commit landing record for the last mixed `main` delta |
| Runtime plan | `docs/HARVARD_RUNTIME_CONFLICT_BOARD.md` | Active runtime queue and completion criteria |
| Runtime behavior | `docs/UNIFIED_RUNTIME_CONTRACT.md` | Mainline runtime/env/forensic contract |
| Patch base | `ci/winlator/patches/README.md` | Patch-stack policy and fold/slice rules |
| Patch windows | `ci/winlator/patch-batch-plan.tsv` | Machine-readable patch phase map |
| Wine11 lane queue | `docs/WINE11_ARM64EC_LANE_VALIDATION_QUEUE.md` | Which Wine11 lane checks are done vs still queued |
| DLL patch ownership | `docs/WINE11_ARM64EC_DLLS_WAVE1_PATCH_INDEX.tsv` | Per-patch `dll` ownership map for `dlls-wave1-runtime` |
| Contents closure | `docs/CONTENTS_QA_CHECKLIST.md` | Remaining contents/UI/device QA checklist |
| Device execution | `docs/ADB_HARVARD_DEVICE_FORENSICS.md` | Real-device forensic runbook |
| Device pass | `docs/DEVICE_EXECUTION_CHECKLIST_RC005_CONTENTS.md` | Exact one-pass device checklist for `RC-005` + `Contents` QA |
| Proton11 scaffold sync | `ci/proton11-ge-arm64ec/sync-wine11-transfer-patch-base.sh` | Pushes lane patch-base + provenance manifest to local Proton11 GE scaffold |

## Reflective Comparison: Plans vs Current State

| Plan artifact | Original purpose | What is already done | What is still open | Status now |
| --- | --- | --- | --- | --- |
| `docs/HARVARD_RUNTIME_CONFLICT_BOARD.md` | Runtime conflict queue for Winlator mainline | `RC-001..RC-024` are implemented and documented, including one-patch fold-back and Task Manager telemetry | `RC-005` still needs real-device execution; matrix/QA closure remains open | Active source of truth |
| `docs/CONTENTS_QA_CHECKLIST.md` | End-to-end closure for contents/adrenotools/UI/install parity | Static repo-side contract gates, metadata parity, and split release topology (`wcp-runtime-lanes` + `wcp-graphics-lanes`) are already closed | Manual UI/device/install flows remain open | Active source of truth |
| `ci/winlator/patches/README.md` + `ci/winlator/patch-batch-plan.tsv` | Define patch-base operating model | Stack is back to `0001`, phase map is normalized to `1..1` | Only future temporary slice windows when bounded review is required | Active source of truth |
| `docs/UNIFIED_RUNTIME_CONTRACT.md` + runtime audit docs | Define and verify runtime marker/forensic contract | Current consolidated stack satisfies required runtime-contract checks | Need validation under the real ADB matrix, not only local apply/build paths | Active source of truth |
| `docs/WINE11_ARM64EC_TRANSFER_SUMMARY.md` + `docs/WINE11_ARM64EC_LANE_VALIDATION_QUEUE.md` | Track Wine11 transfer lanes and queue state | `core -> documentation-fonts-root-wave1` chain is gate-proven in current checkpoint (`17 / 17` checks pass) | Full donor parity and runtime/device benchmark parity are still not proven | Active source of truth |
| `docs/ADB_HARVARD_DEVICE_FORENSICS.md` | Device-side forensic execution plan | Wide suite and focused upscale/core loop are documented; runtime log assembler is integrated | Missing actual device artifacts for closure | Active source of truth |
| `docs/GN_GH_BACKLOG_MATRIX.md` | Research queue for future GN/GH behavior transfers | Baseline migration evidence and prioritization exist | No active blocking item from this matrix is currently driving mainline | Research input only |
| `docs/REFLECTIVE_HARVARD_LEDGER.md` + `docs/AEROSO_IMPLEMENTATION_REFLECTIVE_LOG.md` | Reflective evidence and historical rationale | Updated through the current one-patch baseline and Task Manager uplift | Should remain append-only, not turn into the operational queue | Append-only reflective history |

## What Mainline Already Has

- Consolidated Winlator mainline with Ae.solator branding and one-patch patch
  base.
- X11-first runtime path with deterministic DX/upscaler/runtime policy markers.
- Runtime signal contract and launcher/activity telemetry propagation.
- Forensic control plane, issue-bundle path, runtime mismatch/conflict analysis,
  and device-suite orchestration.
- Built-in Task Manager upgraded into a live runtime triage surface:
  - realtime X11 correlation
  - Linux `/proc` process telemetry
  - PID-level socket visibility
  - process-tree actions
  - telemetry JSON and issue-bundle export
- Contents overlay, packaging metadata, and validators aligned to split
  release topology (`FreeWine` runtime repo + graphics repo) with one shared contract.

## What Still Blocks Full Closure

1. Real-device Harvard matrix execution is still missing.
2. Contents QA still needs manual/device verification, not just repository-side
   contract gates.
3. No ADB device is currently attached in this session, so the remaining
   device-side closure work cannot be executed yet.

The already-applied 2026-03-01 worktree reduction is tracked in
`docs/WORKTREE_CHANGESET_MAP.md`, and the executed landing order is recorded in
`docs/COMMIT_SERIES_MAINLINE.md`.

## Repository Navigation

- Start at `README.md` for product/build entry.
- Read `docs/MAINLINE_PROJECT_STATE.md` for current repo state and document roles.
- Read `docs/WORKTREE_CHANGESET_MAP.md` if you need the decomposition of the
  already-landed 2026-03-01 stabilization series.
- Read `docs/COMMIT_SERIES_MAINLINE.md` if you need the exact applied commit
  order for that stabilization series.
- Use `docs/HARVARD_RUNTIME_CONFLICT_BOARD.md` for runtime work intake/handoff.
- Use `docs/CONTENTS_QA_CHECKLIST.md` for contents closure.
- Use `docs/WINE11_ARM64EC_TRANSFER_SUMMARY.md` for active lane dependency and transfer status.
- Use `docs/WINE11_ARM64EC_LANE_VALIDATION_QUEUE.md` for current lane check queue state.
- Use `docs/WINE11_ARM64EC_DLLS_WAVE1_PATCH_INDEX.tsv` for per-patch `dll` ownership mapping.
- Use `ci/winlator/patches/README.md` for patch-base decisions.
- Use `ci/proton11-ge-arm64ec/sync-wine11-transfer-patch-base.sh` when refreshing the local
  Proton11 GE scaffold with the current Wine11 transfer patch-base.
- Use `docs/UNIFIED_RUNTIME_CONTRACT.md` for behavior/marker guarantees.
- Use `docs/ADB_HARVARD_DEVICE_FORENSICS.md` when moving from local validation to
  device evidence.
- Use `docs/DEVICE_EXECUTION_CHECKLIST_RC005_CONTENTS.md` when a device is
  attached and you need the exact execution order for `RC-005` + `Contents` QA.
- Treat `docs/REFLECTIVE_HARVARD_LEDGER.md` and
  `docs/AEROSO_IMPLEMENTATION_REFLECTIVE_LOG.md` as append-only history.
