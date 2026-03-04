# Aeolator Forensic Sync Contract

## Scope

Unified CI forensic capture for mainline runtime build:

- `build.sh` -> `ci/ci-build.sh`
- native hook scaffold in `ci/forensics/native-hooks/apply-native-forensics.sh`

## Enable/Disable

- `AEO_FORENSIC_ENABLE=1` (default): enable forensic capture.
- `AEO_FORENSIC_ENABLE=0`: disable forensic capture.

## Root And Native Sync

- Root path: `AEO_FORENSIC_ROOT` (default: `/tmp/aeolator-forensics`).
- Native sync target: `AEO_FORENSIC_SYNC_TARGET` (default: `aeolator`).
- Sync mode: `AEO_FORENSIC_SYNC_MODE` (default: `native`).
- Aliases: `AEO_FORENSIC_SYNC_ALIASES` (default: `aeolator,aeolater,aesolator`).

At root level each run updates:

- `latest-session` symlink
- `latest-<pipeline>` symlink
- `aeolator-sync.json`
- `aeolater-sync.json`
- `aesolator-sync.json`

## Session Layout

```
${AEO_FORENSIC_ROOT}/
  <session-id>/
    session.meta.env
    <pipeline>/
      events.jsonl
      status.env
      sync.json
      stages/
        001-<stage>/command.sh.txt
        001-<stage>/stdout.log
        001-<stage>/stderr.log
        001-<stage>/exit_code.txt
```

## Event Model

- `CI_PIPELINE_START` / `CI_PIPELINE_END`
- `CI_STAGE_START` / `CI_STAGE_END`
- optional `CI_STAGE_META` emitted by lane scripts

Every event includes:

- `session`, `pipeline`, `event`, `stage`, `status`
- `syncTarget`, `syncMode`, `syncAliases`
- UTC timestamp and process id

## Quick Smoke

```bash
AEO_FORENSIC_ENABLE=1 \
AEO_FORENSIC_ROOT=/tmp/aeolator-forensics-smoke \
bash build.sh
```

Then inspect:

```bash
find /tmp/aeolator-forensics-smoke -maxdepth 7 -type f | sort
```
