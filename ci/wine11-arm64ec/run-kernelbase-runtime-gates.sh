#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${ROOT_DIR}/ci/lib/aeolator_forensics.sh"

log() { printf '[wine11-kernelbase-runtime-gates] %s\n' "$*"; }

main() {
  aeo_forensics_run_stage "run-winebuild-support-gates" \
    bash "${ROOT_DIR}/ci/wine11-arm64ec/run-winebuild-support-gates.sh"
  aeo_forensics_run_stage "reflect-kernelbase-runtime-overlap" \
    bash "${ROOT_DIR}/ci/wine11-arm64ec/reflect-kernelbase-runtime-overlap.sh"
  aeo_forensics_run_stage "check-kernelbase-runtime-lane" \
    bash "${ROOT_DIR}/ci/wine11-arm64ec/check-kernelbase-runtime-lane.sh"
  log "Wine11 kernelbase runtime gates passed"
}

aeo_forensics_wrap_main "wine11-kernelbase-runtime-gates" main "$@"
