#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BATCH="${1:-1}"

python3 "$ROOT_DIR/ci/proton11-ge-arm64ec/rebase-tkg-ge-wave6-batch.py" \
  --batch-map "$ROOT_DIR/docs/WINE11_TKG_GE_WAVE6_REBASE_BATCHES.tsv" \
  --batch "$BATCH" \
  --target "/home/mikhail/wcp-sources/andre-wine11-arm64ec" \
  --overrides-dir "$ROOT_DIR/ci/wine11-arm64ec/patch-overrides/wave6-selective-rebase" \
  --work-root "$ROOT_DIR/ci/wine11-arm64ec/tkg-ge-wave6-rebase-work" \
  --report-out "$ROOT_DIR/docs/WINE11_TKG_GE_WAVE6_BATCH${BATCH}_REBASE_REPORT.tsv"
