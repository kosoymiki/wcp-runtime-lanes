#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${ROOT_DIR}/ci/lib/aeolator_forensics.sh"

log() { printf '[wine11-server-support-gates] %s\n' "$*"; }

main() {
  aeo_forensics_run_stage "run-server-transfer-gates" \
    bash "${ROOT_DIR}/ci/wine11-arm64ec/run-server-transfer-gates.sh"
  aeo_forensics_run_stage "reflect-server-support-overlap" \
    bash "${ROOT_DIR}/ci/wine11-arm64ec/reflect-server-support-overlap.sh"
  aeo_forensics_run_stage "check-server-support-lane" \
    bash "${ROOT_DIR}/ci/wine11-arm64ec/check-server-support-lane.sh"
  log "Wine11 server support gates passed"
}

aeo_forensics_wrap_main "wine11-server-support-gates" main "$@"
