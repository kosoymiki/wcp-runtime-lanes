#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${ROOT_DIR}/ci/lib/aeolator_forensics.sh"

log() { printf '[wine11-libs-wine-support-gates] %s\n' "$*"; }

main() {
  aeo_forensics_run_stage "run-wow64-struct-support-gates" \
    bash "${ROOT_DIR}/ci/wine11-arm64ec/run-wow64-struct-support-gates.sh"
  aeo_forensics_run_stage "reflect-libs-wine-support-overlap" \
    bash "${ROOT_DIR}/ci/wine11-arm64ec/reflect-libs-wine-support-overlap.sh"
  aeo_forensics_run_stage "check-libs-wine-support-lane" \
    bash "${ROOT_DIR}/ci/wine11-arm64ec/check-libs-wine-support-lane.sh"
  log "Wine11 libs/wine support gates passed"
}

aeo_forensics_wrap_main "wine11-libs-wine-support-gates" main "$@"
