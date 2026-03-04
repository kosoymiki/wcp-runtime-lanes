#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${ROOT_DIR}/ci/lib/aeolator_forensics.sh"

log() { printf '[wine11-signal-gates] %s\n' "$*"; }

main() {
  aeo_forensics_run_stage "run-loader-transfer-gates" \
    bash "${ROOT_DIR}/ci/wine11-arm64ec/run-loader-transfer-gates.sh"
  aeo_forensics_run_stage "reflect-signal-transfer-overlap" \
    bash "${ROOT_DIR}/ci/wine11-arm64ec/reflect-signal-transfer-overlap.sh"
  aeo_forensics_run_stage "check-signal-transfer-lane" \
    bash "${ROOT_DIR}/ci/wine11-arm64ec/check-signal-transfer-lane.sh"
  log "Wine11 signal transfer gates passed"
}

aeo_forensics_wrap_main "wine11-signal-transfer-gates" main "$@"
