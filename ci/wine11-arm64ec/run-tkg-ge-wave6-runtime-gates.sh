#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${ROOT_DIR}/ci/lib/aeolator_forensics.sh"

log() { printf '[wine11-tkg-ge-wave6-runtime-gates] %s\n' "$*"; }

main() {
  aeo_forensics_run_stage "check-documentation-fonts-root-wave1-runtime-lane" \
    bash "${ROOT_DIR}/ci/wine11-arm64ec/check-documentation-fonts-root-wave1-runtime-lane.sh"
  aeo_forensics_run_stage "check-tkg-ge-wave6-runtime-lane" \
    bash "${ROOT_DIR}/ci/wine11-arm64ec/check-tkg-ge-wave6-runtime-lane.sh"
  log "Wine11 TKG GE Wave6 runtime apply-chain gates passed"
}

aeo_forensics_wrap_main "wine11-tkg-ge-wave6-runtime-gates" main "$@"
