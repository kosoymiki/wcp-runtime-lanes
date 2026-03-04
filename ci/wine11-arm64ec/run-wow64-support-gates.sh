#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${ROOT_DIR}/ci/lib/aeolator_forensics.sh"

log() { printf '[wine11-wow64-support-gates] %s\n' "$*"; }

main() {
  aeo_forensics_run_stage "run-server-transfer-gates" \
    bash "${ROOT_DIR}/ci/wine11-arm64ec/run-server-transfer-gates.sh"
  aeo_forensics_run_stage "reflect-wow64-support-overlap" \
    bash "${ROOT_DIR}/ci/wine11-arm64ec/reflect-wow64-support-overlap.sh"
  aeo_forensics_run_stage "check-wow64-support-lane" \
    bash "${ROOT_DIR}/ci/wine11-arm64ec/check-wow64-support-lane.sh"
  log "Wine11 wow64 support gates passed"
}

aeo_forensics_wrap_main "wine11-wow64-support-gates" main "$@"
