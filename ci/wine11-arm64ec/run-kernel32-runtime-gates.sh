#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${ROOT_DIR}/ci/lib/aeolator_forensics.sh"

log() { printf '[wine11-kernel32-runtime-gates] %s\n' "$*"; }

main() {
  aeo_forensics_run_stage "run-win32u-runtime-gates" \
    bash "${ROOT_DIR}/ci/wine11-arm64ec/run-win32u-runtime-gates.sh"
  aeo_forensics_run_stage "reflect-kernel32-runtime-overlap" \
    bash "${ROOT_DIR}/ci/wine11-arm64ec/reflect-kernel32-runtime-overlap.sh"
  aeo_forensics_run_stage "check-kernel32-runtime-lane" \
    bash "${ROOT_DIR}/ci/wine11-arm64ec/check-kernel32-runtime-lane.sh"
  log "Wine11 kernel32 runtime gates passed"
}

aeo_forensics_wrap_main "wine11-kernel32-runtime-gates" main "$@"
