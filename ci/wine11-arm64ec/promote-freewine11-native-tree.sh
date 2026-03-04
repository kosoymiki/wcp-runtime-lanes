#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${ROOT_DIR}/ci/runtime-sources/local-source-layout.sh"

: "${FREEWINE11_DEST_DIR:=${WCP_LOCAL_FREEWINE11_DIR}}"
: "${FREEWINE11_CLEAN_DEST:=1}"
: "${FREEWINE11_COMMIT:=1}"
: "${FREEWINE11_GN_STRICT:=1}"
: "${FREEWINE11_GN_PREFLIGHT:=1}"
: "${FREEWINE11_PROMOTE_RESEED_PROTON11_GE:=1}"

log() { printf '[freewine11-promote] %s\n' "$*"; }
warn() { printf '[freewine11-promote][warn] %s\n' "$*" >&2; }
fail() { printf '[freewine11-promote][error] %s\n' "$*" >&2; exit 1; }

require_bool() {
  [[ "$2" =~ ^[01]$ ]] || fail "$1 must be 0 or 1"
}

main() {
  local head

  require_bool FREEWINE11_CLEAN_DEST "${FREEWINE11_CLEAN_DEST}"
  require_bool FREEWINE11_COMMIT "${FREEWINE11_COMMIT}"
  require_bool FREEWINE11_GN_STRICT "${FREEWINE11_GN_STRICT}"
  require_bool FREEWINE11_GN_PREFLIGHT "${FREEWINE11_GN_PREFLIGHT}"
  require_bool FREEWINE11_PROMOTE_RESEED_PROTON11_GE "${FREEWINE11_PROMOTE_RESEED_PROTON11_GE}"

  log "Promoting native FreeWine11 tree into ${FREEWINE11_DEST_DIR}"
  FREEWINE11_DEST_DIR="${FREEWINE11_DEST_DIR}" \
  FREEWINE11_CLEAN_DEST="${FREEWINE11_CLEAN_DEST}" \
  FREEWINE11_COMMIT="${FREEWINE11_COMMIT}" \
  FREEWINE11_GN_STRICT="${FREEWINE11_GN_STRICT}" \
  FREEWINE11_GN_PREFLIGHT="${FREEWINE11_GN_PREFLIGHT}" \
  FREEWINE11_UPDATE_ACTIVE_LINKS=1 \
    bash "${ROOT_DIR}/ci/wine11-arm64ec/build-freewine11-tree.sh"

  if [[ "${FREEWINE11_PROMOTE_RESEED_PROTON11_GE}" == "1" ]]; then
    if [[ -d "${WCP_LOCAL_PROTON11_GE_ARM64EC_DIR}" || -f "${WCP_LOCAL_PROTON11_GE_ARM64EC_DIR}/.git" ]] \
      && wcp_local_repo_exists "${WCP_LOCAL_WINE11_DONOR_DIR}" \
      && wcp_local_repo_exists "${WCP_LOCAL_PROTON_GE_UPSTREAM_DIR}" \
      && wcp_local_repo_exists "${WCP_LOCAL_PROTON_GE_LINKED_DIR}" \
      && wcp_local_repo_exists "${WCP_LOCAL_GAMENATIVE_PROTON_DIR}"; then
      log "Reseeding Proton11 GE scaffold refs to active wine tree"
      bash "${ROOT_DIR}/ci/proton11-ge-arm64ec/bootstrap-proton11-ge-arm64ec.sh" >/dev/null
    else
      warn "Skipping Proton11 GE scaffold reseed: required local repos not ready"
    fi
  fi

  head="$(git -C "${FREEWINE11_DEST_DIR}" rev-parse --short HEAD)"
  log "Native tree ready: ${FREEWINE11_DEST_DIR} (${head})"
  log "Active wine tree: $(wcp_resolve_wine11_active_dir)"
}

main "$@"
