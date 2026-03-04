#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${ROOT_DIR}/ci/lib/aeolator_forensics.sh"

log() { printf '[wine11-loader-gates] %s\n' "$*"; }

main() {
  aeo_forensics_run_stage "run-core-transfer-gates" \
    bash "${ROOT_DIR}/ci/wine11-arm64ec/run-core-transfer-gates.sh"
  aeo_forensics_run_stage "reflect-loader-transfer-overlap" \
    bash "${ROOT_DIR}/ci/wine11-arm64ec/reflect-loader-transfer-overlap.sh"
  aeo_forensics_run_stage "check-loader-transfer-lane" \
    bash "${ROOT_DIR}/ci/wine11-arm64ec/check-loader-transfer-lane.sh"
  log "Wine11 loader transfer gates passed"
}

aeo_forensics_wrap_main "wine11-loader-transfer-gates" main "$@"
