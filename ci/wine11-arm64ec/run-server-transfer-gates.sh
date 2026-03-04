#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${ROOT_DIR}/ci/lib/aeolator_forensics.sh"

log() { printf '[wine11-server-gates] %s\n' "$*"; }

main() {
  aeo_forensics_run_stage "run-signal-transfer-gates" \
    bash "${ROOT_DIR}/ci/wine11-arm64ec/run-signal-transfer-gates.sh"
  aeo_forensics_run_stage "reflect-server-transfer-overlap" \
    bash "${ROOT_DIR}/ci/wine11-arm64ec/reflect-server-transfer-overlap.sh"
  aeo_forensics_run_stage "check-server-transfer-lane" \
    bash "${ROOT_DIR}/ci/wine11-arm64ec/check-server-transfer-lane.sh"
  log "Wine11 server transfer gates passed"
}

aeo_forensics_wrap_main "wine11-server-transfer-gates" main "$@"
