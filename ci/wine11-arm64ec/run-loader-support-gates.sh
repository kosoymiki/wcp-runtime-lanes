#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${ROOT_DIR}/ci/lib/aeolator_forensics.sh"

log() { printf '[wine11-loader-support-gates] %s\n' "$*"; }

main() {
  aeo_forensics_run_stage "run-loader-transfer-gates" \
    bash "${ROOT_DIR}/ci/wine11-arm64ec/run-loader-transfer-gates.sh"
  aeo_forensics_run_stage "reflect-loader-support-overlap" \
    bash "${ROOT_DIR}/ci/wine11-arm64ec/reflect-loader-support-overlap.sh"
  aeo_forensics_run_stage "check-loader-support-lane" \
    bash "${ROOT_DIR}/ci/wine11-arm64ec/check-loader-support-lane.sh"
  log "Wine11 loader support gates passed"
}

aeo_forensics_wrap_main "wine11-loader-support-gates" main "$@"
