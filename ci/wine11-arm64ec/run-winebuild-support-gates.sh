#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${ROOT_DIR}/ci/lib/aeolator_forensics.sh"

log() { printf '[wine11-winebuild-support-gates] %s\n' "$*"; }

main() {
  aeo_forensics_run_stage "run-libs-wine-support-gates" \
    bash "${ROOT_DIR}/ci/wine11-arm64ec/run-libs-wine-support-gates.sh"
  aeo_forensics_run_stage "reflect-winebuild-support-overlap" \
    bash "${ROOT_DIR}/ci/wine11-arm64ec/reflect-winebuild-support-overlap.sh"
  aeo_forensics_run_stage "check-winebuild-support-lane" \
    bash "${ROOT_DIR}/ci/wine11-arm64ec/check-winebuild-support-lane.sh"
  log "Wine11 winebuild support gates passed"
}

aeo_forensics_wrap_main "wine11-winebuild-support-gates" main "$@"
