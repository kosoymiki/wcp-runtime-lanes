#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${ROOT_DIR}/ci/runtime-sources/local-source-layout.sh"

: "${WCP_LOCAL_ANDRE_WINE11_REPO:=https://github.com/AndreRH/wine.git}"
: "${WCP_LOCAL_ANDRE_WINE11_REF:=arm64ec}"
: "${WCP_LOCAL_VALVE_WINE_EXP10_REPO:=https://github.com/ValveSoftware/wine.git}"
: "${WCP_LOCAL_VALVE_WINE_EXP10_REF:=experimental_10.0}"
: "${WCP_LOCAL_GAMENATIVE_PROTON_REPO:=https://github.com/GameNative/proton-wine.git}"
: "${WCP_LOCAL_GAMENATIVE_PROTON_REF:=bleeding-edge}"
: "${WCP_LOCAL_PROTON_GE_REPO:=https://github.com/GloriousEggroll/proton-ge-custom.git}"
: "${WCP_LOCAL_PROTON_GE_REF:=stable}"
: "${WCP_LOCAL_PROTON_GE_LINK_REF:=GE-Proton10-32}"

log() { printf '[local-sources] %s\n' "$*"; }
fail() { printf '[local-sources][error] %s\n' "$*" >&2; exit 1; }
require_cmd() { command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"; }

sync_repo() {
  local repo_url="$1" checkout_ref="$2" target_dir="$3"

  if wcp_local_repo_exists "${target_dir}"; then
    log "Refreshing ${target_dir}"
    git -C "${target_dir}" remote set-url origin "${repo_url}"
    git -C "${target_dir}" remote set-branches origin '*'
    git -C "${target_dir}" fetch --prune origin '+refs/heads/*:refs/remotes/origin/*'
    git -C "${target_dir}" fetch --prune --tags origin
  else
    log "Cloning ${repo_url} -> ${target_dir}"
    git clone --filter=blob:none "${repo_url}" "${target_dir}"
    git -C "${target_dir}" remote set-branches origin '*'
    git -C "${target_dir}" fetch --prune origin '+refs/heads/*:refs/remotes/origin/*'
    git -C "${target_dir}" fetch --prune --tags origin
  fi

  if git -C "${target_dir}" checkout "${checkout_ref}" >/dev/null 2>&1; then
    :
  elif git -C "${target_dir}" checkout --detach "${checkout_ref}" >/dev/null 2>&1; then
    :
  elif git -C "${target_dir}" checkout --detach "origin/${checkout_ref}" >/dev/null 2>&1; then
    :
  else
    fail "Unable to checkout ${checkout_ref} in ${target_dir}"
  fi
}

main() {
  local wine11_active_dir

  require_cmd git

  mkdir -p "${WCP_LOCAL_SOURCE_ROOT}"

  sync_repo "${WCP_LOCAL_ANDRE_WINE11_REPO}" "${WCP_LOCAL_ANDRE_WINE11_REF}" "${WCP_LOCAL_ANDRE_WINE11_DIR}"
  sync_repo "${WCP_LOCAL_VALVE_WINE_EXP10_REPO}" "${WCP_LOCAL_VALVE_WINE_EXP10_REF}" "${WCP_LOCAL_VALVE_WINE_EXP10_DIR}"
  sync_repo "${WCP_LOCAL_GAMENATIVE_PROTON_REPO}" "${WCP_LOCAL_GAMENATIVE_PROTON_REF}" "${WCP_LOCAL_GAMENATIVE_PROTON_DIR}"
  sync_repo "${WCP_LOCAL_PROTON_GE_REPO}" "${WCP_LOCAL_PROTON_GE_REF}" "${WCP_LOCAL_PROTON_GE_UPSTREAM_DIR}"

  if [[ -d "${WCP_LOCAL_PROTON_GE_LINKED_DIR}" || -f "${WCP_LOCAL_PROTON_GE_LINKED_DIR}/.git" ]]; then
    git -C "${WCP_LOCAL_PROTON_GE_UPSTREAM_DIR}" worktree remove --force "${WCP_LOCAL_PROTON_GE_LINKED_DIR}" >/dev/null 2>&1 || rm -rf "${WCP_LOCAL_PROTON_GE_LINKED_DIR}"
  fi

  log "Creating linked GE worktree at ${WCP_LOCAL_PROTON_GE_LINKED_DIR}"
  git -C "${WCP_LOCAL_PROTON_GE_UPSTREAM_DIR}" worktree add --force --detach "${WCP_LOCAL_PROTON_GE_LINKED_DIR}" "${WCP_LOCAL_PROTON_GE_LINK_REF}" >/dev/null 2>&1
  wine11_active_dir="$(wcp_resolve_wine11_active_dir)"
  log "Using Wine11 active tree for links: ${wine11_active_dir}"
  rm -rf "${WCP_LOCAL_PROTON_GE_LINKED_DIR}/wine"
  ln -sfn "${wine11_active_dir}" "${WCP_LOCAL_PROTON_GE_LINKED_DIR}/wine"

  mkdir -p "${WCP_LOCAL_PROTON11_STACK_DIR}"
  ln -sfn "${wine11_active_dir}" "${WCP_LOCAL_PROTON11_STACK_DIR}/wine11-arm64ec"
  ln -sfn "${WCP_LOCAL_WINE11_DONOR_DIR}" "${WCP_LOCAL_PROTON11_STACK_DIR}/wine11-donor"
  ln -sfn "${WCP_LOCAL_PROTON_GE_LINKED_DIR}" "${WCP_LOCAL_PROTON11_STACK_DIR}/proton-ge"
  ln -sfn "${WCP_LOCAL_GAMENATIVE_PROTON_DIR}" "${WCP_LOCAL_PROTON11_STACK_DIR}/gamenative-proton"
  ln -sfn "${WCP_LOCAL_FREEWINE11_DIR}" "${WCP_LOCAL_PROTON11_STACK_DIR}/freewine11"

  bash "${ROOT_DIR}/ci/proton11-ge-arm64ec/bootstrap-proton11-ge-arm64ec.sh" >/dev/null

  wcp_print_local_source_layout
  printf 'WCP_LOCAL_PROTON_GE_LINK_REF=%s\n' "${WCP_LOCAL_PROTON_GE_LINK_REF}"
}

main "$@"
