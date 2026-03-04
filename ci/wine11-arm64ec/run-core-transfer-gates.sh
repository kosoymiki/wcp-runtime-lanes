#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${ROOT_DIR}/ci/lib/aeolator_forensics.sh"

: "${WCP_WINE11_FULL_REFLECT_GATE:=0}"

log() { printf '[wine11-core-gates] %s\n' "$*"; }
fail() { printf '[wine11-core-gates][error] %s\n' "$*" >&2; exit 1; }

main() {
  aeo_forensics_run_stage "reflect-valve-experimental10" \
    bash "${ROOT_DIR}/ci/wine11-arm64ec/reflect-valve-experimental10.sh"
  aeo_forensics_run_stage "reflect-core-transfer-overlap" \
    bash "${ROOT_DIR}/ci/wine11-arm64ec/reflect-core-transfer-overlap.sh"
  aeo_forensics_run_stage "check-core-transfer-lane" \
    bash "${ROOT_DIR}/ci/wine11-arm64ec/check-core-transfer-lane.sh"

  if [[ "${WCP_WINE11_FULL_REFLECT_GATE}" == "1" ]]; then
    log "Running full reflective gate"
    aeo_forensics_run_stage "reflect-valve-experimental10-full" \
      env WCP_WINE11_REFLECT_MODE=full \
      bash "${ROOT_DIR}/ci/wine11-arm64ec/reflect-valve-experimental10.sh"
  fi

  log "Wine11 core transfer gates passed"
}

aeo_forensics_wrap_main "wine11-core-transfer-gates" main "$@"
