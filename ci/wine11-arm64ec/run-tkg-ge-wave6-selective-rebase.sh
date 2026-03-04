#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${ROOT_DIR}/ci/lib/aeolator_forensics.sh"

main() {
  aeo_forensics_run_stage "open-selective-rebase" \
    python3 "$ROOT_DIR/ci/proton11-ge-arm64ec/open-tkg-ge-selective-rebase.py" \
      --queue-out "$ROOT_DIR/docs/WINE11_TKG_GE_WAVE6_SELECTIVE_REBASE_QUEUE.tsv" \
      --deferred-out "$ROOT_DIR/docs/WINE11_TKG_GE_WAVE6_SELECTIVE_REBASE_DEFERRED.tsv" \
      --report-out "$ROOT_DIR/docs/WINE11_TKG_GE_WAVE6_SELECTIVE_REBASE_PLAN.md"

  aeo_forensics_run_stage "build-wave6-selective-lane" \
    python3 "$ROOT_DIR/ci/proton11-ge-arm64ec/build-tkg-ge-wave4-low-lane.py" \
      --low-queue "$ROOT_DIR/docs/WINE11_TKG_GE_WAVE6_SELECTIVE_REBASE_QUEUE.tsv" \
      --output-dir "$ROOT_DIR/ci/wine11-arm64ec/tkg-ge-wave6-selective-rebase-lane" \
      --report-out "$ROOT_DIR/docs/WINE11_TKG_GE_WAVE6_SELECTIVE_REBASE_REPORT.md" \
      --lane-name "Wine11 Wave6 Selective Rebase" \
      --wine-target "/home/mikhail/wcp-sources/andre-wine11-arm64ec" \
      --overrides-dir "$ROOT_DIR/ci/wine11-arm64ec/patch-overrides/wave6-selective-rebase" \
      --active-routes wine,binutils

  aeo_forensics_run_stage "plan-rebase-batches" \
    python3 "$ROOT_DIR/ci/proton11-ge-arm64ec/plan-tkg-ge-wave6-rebase-batches.py" \
      --pending "$ROOT_DIR/ci/wine11-arm64ec/tkg-ge-wave6-selective-rebase-lane/manifests/pending.tsv" \
      --batches-out "$ROOT_DIR/docs/WINE11_TKG_GE_WAVE6_REBASE_BATCHES.tsv" \
      --report-out "$ROOT_DIR/docs/WINE11_TKG_GE_WAVE6_REBASE_BATCHES.md"
}

aeo_forensics_wrap_main "wine11-wave6-selective-rebase" main "$@"
