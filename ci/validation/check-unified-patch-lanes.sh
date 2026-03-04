#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

: "${WLT_UNIFIED_PATCH_OUT_DIR:=/tmp/unified-patch-lanes-$(date +%Y%m%d_%H%M%S)}"
: "${WLT_UNIFIED_PATCH_REQUIRED:=0}"
: "${WLT_UNIFIED_PATCH_RUN_WINLATOR:=1}"
: "${WLT_UNIFIED_PATCH_RUN_GAMENATIVE:=1}"
: "${WLT_UNIFIED_PATCH_WINLATOR_SOURCE_DIR:=${ROOT_DIR}/work/winlator-ludashi/src}"
: "${WLT_UNIFIED_PATCH_WINE_SOURCE_DIR:=${ROOT_DIR}/work/wine-src}"
: "${WLT_UNIFIED_PATCH_PROTONGE_SOURCE_DIR:=${ROOT_DIR}/work/proton-ge10/wine-src}"
: "${WLT_UNIFIED_PATCH_PROTONWINE_SOURCE_DIR:=${ROOT_DIR}/work/protonwine10/wine-src}"
: "${WLT_UNIFIED_PATCH_PATCH_DIR:=${ROOT_DIR}/ci/winlator/patches}"

log() { printf '[unified-patch] %s\n' "$*" >&2; }
fail() { printf '[unified-patch][error] %s\n' "$*" >&2; exit 1; }

[[ "${WLT_UNIFIED_PATCH_REQUIRED}" =~ ^[01]$ ]] || fail "WLT_UNIFIED_PATCH_REQUIRED must be 0 or 1"
[[ "${WLT_UNIFIED_PATCH_RUN_WINLATOR}" =~ ^[01]$ ]] || fail "WLT_UNIFIED_PATCH_RUN_WINLATOR must be 0 or 1"
[[ "${WLT_UNIFIED_PATCH_RUN_GAMENATIVE}" =~ ^[01]$ ]] || fail "WLT_UNIFIED_PATCH_RUN_GAMENATIVE must be 0 or 1"
[[ -d "${WLT_UNIFIED_PATCH_PATCH_DIR}" ]] || fail "Patch dir not found: ${WLT_UNIFIED_PATCH_PATCH_DIR}"

mkdir -p "${WLT_UNIFIED_PATCH_OUT_DIR}"

source "${ROOT_DIR}/ci/lib/wcp_common.sh"

run_capture() {
  local name="$1"; shift
  local out="${WLT_UNIFIED_PATCH_OUT_DIR}/${name}.log"
  log "running ${name}"
  if "$@" > "${out}" 2>&1; then
    log "ok: ${name}"
    printf '0\n'
  else
    local rc=$?
    tail -n 120 "${out}" >&2 || true
    log "failed: ${name} (rc=${rc})"
    printf '%s\n' "${rc}"
  fi
}

is_git_tree() {
  local dir="$1"
  [[ -d "${dir}" ]] || return 1
  git -C "${dir}" rev-parse --is-inside-work-tree >/dev/null 2>&1
}

run_gn_preflight_cmd() {
  local lane="$1" source_dir="$2" strict="$3"
  local patch_target report_dir mode

  case "${lane}" in
    wine|protonwine) patch_target="wine" ;;
    protonge) patch_target="protonge" ;;
    *) wcp_fail "Unsupported lane: ${lane}" ;;
  esac

  report_dir="${WLT_UNIFIED_PATCH_OUT_DIR}/${lane}"
  mkdir -p "${report_dir}"
  export WCP_OUTPUT_DIR="${report_dir}"
  export WCP_GN_PATCHSET_REPORT="${report_dir}/gamenative-patchset-${lane}.tsv"
  mode="$(wcp_resolve_gamenative_patchset_mode)"
  wcp_preflight_unified_gamenative_patch_base "${lane}" "${patch_target}" "${source_dir}" "${mode}" "${strict}"
}

winlator_seen=0
wine_seen=0
protonge_seen=0
protonwine_seen=0
winlator_rc=0
wine_rc=0
protonge_rc=0
protonwine_rc=0

if [[ "${WLT_UNIFIED_PATCH_RUN_WINLATOR}" == "1" ]] && is_git_tree "${WLT_UNIFIED_PATCH_WINLATOR_SOURCE_DIR}"; then
  winlator_seen=1
  winlator_rc="$(run_capture winlator-stack \
    bash "${ROOT_DIR}/ci/winlator/check-patch-stack.sh" \
      "${WLT_UNIFIED_PATCH_WINLATOR_SOURCE_DIR}" \
      "${WLT_UNIFIED_PATCH_PATCH_DIR}")"
fi

if [[ "${WLT_UNIFIED_PATCH_RUN_GAMENATIVE}" == "1" ]]; then
  if is_git_tree "${WLT_UNIFIED_PATCH_WINE_SOURCE_DIR}"; then
    wine_seen=1
    wine_rc="$(run_capture gn-wine \
      run_gn_preflight_cmd wine "${WLT_UNIFIED_PATCH_WINE_SOURCE_DIR}" 1)"
  fi
  if is_git_tree "${WLT_UNIFIED_PATCH_PROTONGE_SOURCE_DIR}"; then
    protonge_seen=1
    protonge_rc="$(run_capture gn-protonge \
      run_gn_preflight_cmd protonge "${WLT_UNIFIED_PATCH_PROTONGE_SOURCE_DIR}" 1)"
  fi
  if is_git_tree "${WLT_UNIFIED_PATCH_PROTONWINE_SOURCE_DIR}"; then
    protonwine_seen=1
    protonwine_rc="$(run_capture gn-protonwine \
      run_gn_preflight_cmd protonwine "${WLT_UNIFIED_PATCH_PROTONWINE_SOURCE_DIR}" 0)"
  fi
fi

seen_total=$((winlator_seen + wine_seen + protonge_seen + protonwine_seen))
{
  printf 'time_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'winlator_seen=%s\n' "${winlator_seen}"
  printf 'wine_seen=%s\n' "${wine_seen}"
  printf 'protonge_seen=%s\n' "${protonge_seen}"
  printf 'protonwine_seen=%s\n' "${protonwine_seen}"
  printf 'winlator_rc=%s\n' "${winlator_rc}"
  printf 'wine_rc=%s\n' "${wine_rc}"
  printf 'protonge_rc=%s\n' "${protonge_rc}"
  printf 'protonwine_rc=%s\n' "${protonwine_rc}"
  printf 'seen_total=%s\n' "${seen_total}"
  printf 'patch_dir=%s\n' "${WLT_UNIFIED_PATCH_PATCH_DIR}"
} > "${WLT_UNIFIED_PATCH_OUT_DIR}/summary.meta"

if [[ "${WLT_UNIFIED_PATCH_REQUIRED}" == "1" && "${seen_total}" == "0" ]]; then
  fail "No source checkouts found for unified patch lanes"
fi

if [[ "${winlator_rc}" != "0" || "${wine_rc}" != "0" || "${protonge_rc}" != "0" || "${protonwine_rc}" != "0" ]]; then
  fail "Unified patch lane validation failed (summary: ${WLT_UNIFIED_PATCH_OUT_DIR}/summary.meta)"
fi

log "Unified patch lane validation passed: ${WLT_UNIFIED_PATCH_OUT_DIR}"
