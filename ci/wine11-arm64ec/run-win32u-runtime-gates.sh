#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${ROOT_DIR}/ci/lib/aeolator_forensics.sh"

log() { printf '[wine11-win32u-runtime-gates] %s\n' "$*"; }

main() {
  aeo_forensics_run_stage "run-kernelbase-support-gates" \
    bash "${ROOT_DIR}/ci/wine11-arm64ec/run-kernelbase-support-gates.sh"
  aeo_forensics_run_stage "reflect-win32u-runtime-overlap" \
    bash "${ROOT_DIR}/ci/wine11-arm64ec/reflect-win32u-runtime-overlap.sh"
  aeo_forensics_run_stage "check-win32u-runtime-lane" \
    bash "${ROOT_DIR}/ci/wine11-arm64ec/check-win32u-runtime-lane.sh"
  log "Wine11 win32u runtime gates passed"
}

aeo_forensics_wrap_main "wine11-win32u-runtime-gates" main "$@"
