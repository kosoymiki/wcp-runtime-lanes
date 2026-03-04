#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${ROOT_DIR}/ci/lib/aeolator_forensics.sh"

log() { printf '[wine11-kernelbase-support-gates] %s\n' "$*"; }

main() {
  aeo_forensics_run_stage "run-kernelbase-runtime-gates" \
    bash "${ROOT_DIR}/ci/wine11-arm64ec/run-kernelbase-runtime-gates.sh"
  aeo_forensics_run_stage "reflect-kernelbase-support-overlap" \
    bash "${ROOT_DIR}/ci/wine11-arm64ec/reflect-kernelbase-support-overlap.sh"
  aeo_forensics_run_stage "check-kernelbase-support-lane" \
    bash "${ROOT_DIR}/ci/wine11-arm64ec/check-kernelbase-support-lane.sh"
  log "Wine11 kernelbase support gates passed"
}

aeo_forensics_wrap_main "wine11-kernelbase-support-gates" main "$@"
