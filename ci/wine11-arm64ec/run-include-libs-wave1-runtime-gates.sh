#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${ROOT_DIR}/ci/lib/aeolator_forensics.sh"

log() { printf '[wine11-include-libs-wave1-runtime-gates] %s\n' "$*"; }

main() {
  aeo_forensics_run_stage "run-dlls-wave1-runtime-gates" \
    bash "${ROOT_DIR}/ci/wine11-arm64ec/run-dlls-wave1-runtime-gates.sh"
  aeo_forensics_run_stage "reflect-include-libs-wave1-runtime-overlap" \
    bash "${ROOT_DIR}/ci/wine11-arm64ec/reflect-include-libs-wave1-runtime-overlap.sh"
  aeo_forensics_run_stage "check-include-libs-wave1-runtime-lane" \
    bash "${ROOT_DIR}/ci/wine11-arm64ec/check-include-libs-wave1-runtime-lane.sh"
  log "Wine11 include/libs wave1 runtime gates passed"
}

aeo_forensics_wrap_main "wine11-include-libs-wave1-runtime-gates" main "$@"
