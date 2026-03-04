#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${ROOT_DIR}/ci/lib/aeolator_forensics.sh"

log() { printf '[wine11-signal-support-gates] %s\n' "$*"; }

main() {
  aeo_forensics_run_stage "run-signal-transfer-gates" \
    bash "${ROOT_DIR}/ci/wine11-arm64ec/run-signal-transfer-gates.sh"
  aeo_forensics_run_stage "reflect-signal-support-overlap" \
    bash "${ROOT_DIR}/ci/wine11-arm64ec/reflect-signal-support-overlap.sh"
  aeo_forensics_run_stage "check-signal-support-lane" \
    bash "${ROOT_DIR}/ci/wine11-arm64ec/check-signal-support-lane.sh"
  log "Wine11 signal support gates passed"
}

aeo_forensics_wrap_main "wine11-signal-support-gates" main "$@"
