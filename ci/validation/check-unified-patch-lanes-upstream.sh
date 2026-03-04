#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

: "${WLT_UPSTREAM_PATCH_OUT_DIR:=/tmp/unified-patch-upstream-$(date +%Y%m%d_%H%M%S)}"
: "${WLT_UPSTREAM_PATCH_RUN_WINE:=1}"
: "${WLT_UPSTREAM_PATCH_RUN_PROTONGE:=1}"
: "${WLT_UPSTREAM_PATCH_RUN_PROTONWINE:=1}"
: "${WLT_UPSTREAM_PATCH_ANDRE_WINE_REPO:=https://github.com/AndreRH/wine.git}"
: "${WLT_UPSTREAM_PATCH_ANDRE_WINE_REF:=arm64ec}"
: "${WLT_UPSTREAM_PATCH_PROTONWINE_REPO:=https://github.com/GameNative/proton-wine.git}"
: "${WLT_UPSTREAM_PATCH_PROTONWINE_REF:=proton_10.0}"
: "${WLT_UPSTREAM_PATCH_PROTON_GE_REPO:=https://github.com/GloriousEggroll/proton-ge-custom.git}"
: "${WLT_UPSTREAM_PATCH_PROTON_GE_REF:=GE-Proton10-32}"

log() { printf '[upstream-patch] %s\n' "$*" >&2; }
fail() { printf '[upstream-patch][error] %s\n' "$*" >&2; exit 1; }

mkdir -p "${WLT_UPSTREAM_PATCH_OUT_DIR}"

source "${ROOT_DIR}/ci/lib/wcp_common.sh"
source "${ROOT_DIR}/ci/runtime-sources/local-source-layout.sh"

run_capture() {
  local name="$1"; shift
  local out="${WLT_UPSTREAM_PATCH_OUT_DIR}/${name}.log"
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

retry_cmd() {
  local attempts delay n
  attempts="${RETRY_ATTEMPTS:-3}"
  delay="${RETRY_DELAY_SEC:-5}"
  n=1
  while true; do
    if "$@"; then
      return 0
    fi
    if [[ "${n}" -ge "${attempts}" ]]; then
      return 1
    fi
    log "retrying in ${delay}s: $*"
    sleep "${delay}"
    n=$((n + 1))
  done
}

run_gn_preflight_cmd() {
  local lane="$1" patch_target="$2" source_dir="$3" strict="$4"
  local report_dir="${WLT_UPSTREAM_PATCH_OUT_DIR}/${lane}"
  local mode

  mkdir -p "${report_dir}"
  export WCP_OUTPUT_DIR="${report_dir}"
  export WCP_GN_PATCHSET_REPORT="${report_dir}/gamenative-patchset-${lane}.tsv"
  mode="$(wcp_resolve_gamenative_patchset_mode)"
  wcp_preflight_unified_gamenative_patch_base "${lane}" "${patch_target}" "${source_dir}" "${mode}" "${strict}"
}

clone_remote_ref() {
  local repo="$1" ref="$2" clone_dir="$3"
  rm -rf "${clone_dir}"
  if [[ "${ref}" =~ ^[A-Za-z0-9._/-]+$ && ! "${ref}" =~ ^[0-9a-f]{7,40}$ ]]; then
    retry_cmd git clone --filter=blob:none --single-branch --branch "${ref}" "${repo}" "${clone_dir}" >/dev/null 2>&1 \
      || fail "Unable to clone ${repo}#${ref}"
  else
    retry_cmd git clone --filter=blob:none "${repo}" "${clone_dir}" >/dev/null 2>&1 \
      || fail "Unable to clone ${repo}"
  fi
  if ! git -C "${clone_dir}" checkout "${ref}" >/dev/null 2>&1; then
    retry_cmd git -C "${clone_dir}" fetch --force --depth 1 origin "${ref}" >/dev/null 2>&1 \
      || fail "Unable to fetch ${ref} from ${repo}"
    git -C "${clone_dir}" checkout --detach FETCH_HEAD >/dev/null 2>&1
  fi
  git -C "${clone_dir}" reset --hard -q HEAD
  git -C "${clone_dir}" clean -fdqx
}

prepare_wine_upstream() {
  local source_dir="${WLT_UPSTREAM_PATCH_OUT_DIR}/src-wine"
  if wcp_local_repo_exists "${WCP_LOCAL_ANDRE_WINE11_DIR}"; then
    wcp_clone_from_seed_or_remote "${WLT_UPSTREAM_PATCH_ANDRE_WINE_REPO}" "${WLT_UPSTREAM_PATCH_ANDRE_WINE_REF}" "${WCP_LOCAL_ANDRE_WINE11_DIR}" "${source_dir}" \
      || fail "Unable to prepare wine upstream from local seed"
  else
    clone_remote_ref "${WLT_UPSTREAM_PATCH_ANDRE_WINE_REPO}" "${WLT_UPSTREAM_PATCH_ANDRE_WINE_REF}" "${source_dir}"
  fi
  printf '%s\n' "${source_dir}"
}

prepare_protonwine_upstream() {
  local source_dir="${WLT_UPSTREAM_PATCH_OUT_DIR}/src-protonwine"
  if wcp_local_repo_exists "${WCP_LOCAL_GAMENATIVE_PROTON_DIR}"; then
    wcp_clone_from_seed_or_remote "${WLT_UPSTREAM_PATCH_PROTONWINE_REPO}" "${WLT_UPSTREAM_PATCH_PROTONWINE_REF}" "${WCP_LOCAL_GAMENATIVE_PROTON_DIR}" "${source_dir}" \
      || fail "Unable to prepare protonwine upstream from local seed"
  else
    clone_remote_ref "${WLT_UPSTREAM_PATCH_PROTONWINE_REPO}" "${WLT_UPSTREAM_PATCH_PROTONWINE_REF}" "${source_dir}"
  fi
  printf '%s\n' "${source_dir}"
}

prepare_protonge_upstream() {
  local temp_root="${WLT_UPSTREAM_PATCH_OUT_DIR}/protonge-prep"
  local proton10_work="${temp_root}/proton10"
  local proton10_out="${temp_root}/out"
  local proton_ge_root="${temp_root}/proton-ge10"
  local proton_ge_dir="${proton_ge_root}/proton-ge-custom"
  local prepared_wine_dir="${proton10_work}/wine-src"
  local wine_parent
  local -a required_submodules

  rm -rf "${temp_root}"
  mkdir -p "${proton10_out}" "${proton_ge_root}"

  ROOT_DIR="${ROOT_DIR}" \
  WORK_DIR="${proton10_work}" \
  WCP_OUTPUT_DIR="${proton10_out}" \
  ARM64EC_SERIES_FILE="${proton10_out}/arm64ec-series.txt" \
  ARM64EC_REVIEW_REPORT="${proton10_out}/ARM64EC_PATCH_REVIEW.md" \
  bash "${ROOT_DIR}/ci/proton10/arm64ec-commit-review.sh" 1>&2

  ROOT_DIR="${ROOT_DIR}" \
  WORK_DIR="${proton10_work}" \
  WCP_OUTPUT_DIR="${proton10_out}" \
  ARM64EC_SERIES_FILE="${proton10_out}/arm64ec-series.txt" \
  bash "${ROOT_DIR}/ci/proton10/apply-arm64ec-series.sh" 1>&2

  if wcp_local_repo_exists "${WCP_LOCAL_PROTON_GE_UPSTREAM_DIR}"; then
    wcp_clone_from_seed_or_remote "${WLT_UPSTREAM_PATCH_PROTON_GE_REPO}" "${WLT_UPSTREAM_PATCH_PROTON_GE_REF}" "${WCP_LOCAL_PROTON_GE_UPSTREAM_DIR}" "${proton_ge_dir}" \
      || fail "Unable to prepare proton-ge upstream from local seed"
  else
    git clone --filter=blob:none "${WLT_UPSTREAM_PATCH_PROTON_GE_REPO}" "${proton_ge_dir}" >/dev/null 2>&1
    git -C "${proton_ge_dir}" checkout "${WLT_UPSTREAM_PATCH_PROTON_GE_REF}" >/dev/null 2>&1
  fi

  required_submodules=(
    dxvk
    vkd3d-proton
    dxvk-nvapi
    gstreamer
    protonfixes
    wine-staging
  )
  for submodule in "${required_submodules[@]}"; do
    git -C "${proton_ge_dir}" submodule update --init "${submodule}" >/dev/null 2>&1
  done

  rm -rf "${proton_ge_dir}/wine"
  ln -s "${prepared_wine_dir}" "${proton_ge_dir}/wine"

  wine_parent="$(dirname "${prepared_wine_dir}")"
  ln -sfn "${proton_ge_dir}/patches" "${wine_parent}/patches"
  ln -sfn "${proton_ge_dir}/wine-staging" "${wine_parent}/wine-staging"

  "${proton_ge_dir}/patches/protonprep-valve-staging.sh" > "${proton10_out}/patchlog.txt" 2>&1

  printf '%s\n' "${prepared_wine_dir}"
}

run_wine_upstream() {
  local source_dir
  source_dir="$(prepare_wine_upstream)"
  run_gn_preflight_cmd wine wine "${source_dir}" 1
}

run_protonwine_upstream() {
  local source_dir
  source_dir="$(prepare_protonwine_upstream)"
  run_gn_preflight_cmd protonwine wine "${source_dir}" 0
}

run_protonge_upstream() {
  local source_dir
  source_dir="$(prepare_protonge_upstream)"
  run_gn_preflight_cmd protonge protonge "${source_dir}" 1
}

wine_seen=0
protonge_seen=0
protonwine_seen=0
wine_rc=0
protonge_rc=0
protonwine_rc=0

if [[ "${WLT_UPSTREAM_PATCH_RUN_WINE}" == "1" ]]; then
  wine_seen=1
  wine_rc="$(run_capture upstream-wine run_wine_upstream)"
fi

if [[ "${WLT_UPSTREAM_PATCH_RUN_PROTONGE}" == "1" ]]; then
  protonge_seen=1
  protonge_rc="$(run_capture upstream-protonge run_protonge_upstream)"
fi

if [[ "${WLT_UPSTREAM_PATCH_RUN_PROTONWINE}" == "1" ]]; then
  protonwine_seen=1
  protonwine_rc="$(run_capture upstream-protonwine run_protonwine_upstream)"
fi

{
  printf 'time_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'wine_seen=%s\n' "${wine_seen}"
  printf 'protonge_seen=%s\n' "${protonge_seen}"
  printf 'protonwine_seen=%s\n' "${protonwine_seen}"
  printf 'wine_rc=%s\n' "${wine_rc}"
  printf 'protonge_rc=%s\n' "${protonge_rc}"
  printf 'protonwine_rc=%s\n' "${protonwine_rc}"
} > "${WLT_UPSTREAM_PATCH_OUT_DIR}/summary.meta"

if [[ "${wine_rc}" != "0" || "${protonge_rc}" != "0" || "${protonwine_rc}" != "0" ]]; then
  fail "Upstream patch lane validation failed (summary: ${WLT_UPSTREAM_PATCH_OUT_DIR}/summary.meta)"
fi

log "Upstream patch lane validation passed: ${WLT_UPSTREAM_PATCH_OUT_DIR}"
