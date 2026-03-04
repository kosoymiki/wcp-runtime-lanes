#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${ROOT_DIR}/ci/runtime-sources/local-source-layout.sh"
source "${ROOT_DIR}/ci/lib/wcp_common.sh"
source "${ROOT_DIR}/ci/lib/gamenative-patch-base.sh"

if [[ -f "${ROOT_DIR}/ci/lib/aeolator_forensics.sh" ]]; then
  source "${ROOT_DIR}/ci/lib/aeolator_forensics.sh"
else
  aeo_forensics_emit_event() { return 0; }
  aeo_forensics_wrap_main() { local _p="$1" _f="$2"; shift 2; "${_f}" "$@"; }
fi

: "${FREEWINE11_SOURCE_DIR:=${WCP_LOCAL_ANDRE_WINE11_DIR}}"
: "${FREEWINE11_DEST_DIR:=${WCP_LOCAL_FREEWINE11_DIR}}"
: "${FREEWINE11_BRANCH:=freewine11-main}"
: "${FREEWINE11_CLEAN_DEST:=1}"
: "${FREEWINE11_APPLY_GN_BASE:=1}"
: "${FREEWINE11_GN_STRICT:=1}"
: "${FREEWINE11_GN_PREFLIGHT:=1}"
: "${FREEWINE11_COMMIT:=1}"
: "${FREEWINE11_MANIFEST_DIR:=.freewine11/provenance}"
: "${FREEWINE11_UPDATE_ACTIVE_LINKS:=1}"

LANES_ROOT="${ROOT_DIR}/ci/wine11-arm64ec/transfer-lanes"
PATCH_MANIFEST_TSV="${FREEWINE11_MANIFEST_DIR}/freewine11-lane-manifest.tsv"
BUILD_ENV_FILE="${FREEWINE11_MANIFEST_DIR}/freewine11-build.env"
BUILD_SUMMARY_MD="${FREEWINE11_MANIFEST_DIR}/freewine11-build-summary.md"

LANE_ORDER=(
  "core-runtime"
  "loader-runtime"
  "loader-support"
  "signal-runtime"
  "signal-support"
  "server-runtime"
  "server-support"
  "wow64-support"
  "wow64-struct-support"
  "libs-wine-support"
  "winebuild-support"
  "kernelbase-runtime"
  "kernelbase-support"
  "win32u-runtime"
  "kernel32-runtime"
  "dlls-wave1-runtime"
  "aeolator-bionic-only-runtime"
  "include-libs-wave1-runtime"
  "nls-po-programs-server-tools-wave1-runtime"
  "documentation-fonts-root-wave1-runtime"
  "tkg-ge-wave6-runtime"
)

log() { printf '[freewine11] %s\n' "$*"; }
fail() { printf '[freewine11][error] %s\n' "$*" >&2; exit 1; }
require_dir() { [[ -d "$1" ]] || fail "directory not found: $1"; }

dir_hash() {
  local patches_dir="$1"
  local patch_count
  patch_count="$(find "${patches_dir}" -maxdepth 1 -type f -name '*.patch' | wc -l | tr -d ' ')"
  if [[ "${patch_count}" == "0" ]]; then
    printf 'empty'
    return 0
  fi

  find "${patches_dir}" -maxdepth 1 -type f -name '*.patch' -print0 \
    | sort -z \
    | xargs -0 sha256sum \
    | sha256sum \
    | awk '{ print $1 }'
}

patch_count_for_lane() {
  local lane="$1"
  local patch_dir="${LANES_ROOT}/${lane}/patches"
  if [[ ! -d "${patch_dir}" ]]; then
    printf '0'
    return 0
  fi
  find "${patch_dir}" -maxdepth 1 -type f -name '*.patch' | wc -l | tr -d ' '
}

verify_inputs() {
  local lane patch_dir

  wcp_require_bool FREEWINE11_CLEAN_DEST "${FREEWINE11_CLEAN_DEST}"
  wcp_require_bool FREEWINE11_APPLY_GN_BASE "${FREEWINE11_APPLY_GN_BASE}"
  wcp_require_bool FREEWINE11_GN_STRICT "${FREEWINE11_GN_STRICT}"
  wcp_require_bool FREEWINE11_GN_PREFLIGHT "${FREEWINE11_GN_PREFLIGHT}"
  wcp_require_bool FREEWINE11_COMMIT "${FREEWINE11_COMMIT}"
  wcp_require_bool FREEWINE11_UPDATE_ACTIVE_LINKS "${FREEWINE11_UPDATE_ACTIVE_LINKS}"

  require_dir "${FREEWINE11_SOURCE_DIR}"
  require_dir "${LANES_ROOT}"

  for lane in "${LANE_ORDER[@]}"; do
    patch_dir="${LANES_ROOT}/${lane}/patches"
    [[ -d "${patch_dir}" ]] || fail "lane patch dir not found: ${patch_dir}"
  done
}

prepare_dest_tree() {
  if [[ "${FREEWINE11_DEST_DIR}" == "/" || "${FREEWINE11_DEST_DIR}" == "${HOME}" || "${FREEWINE11_DEST_DIR}" == "${WCP_LOCAL_SOURCE_ROOT}" ]]; then
    fail "unsafe FREEWINE11_DEST_DIR: ${FREEWINE11_DEST_DIR}"
  fi

  if [[ "${FREEWINE11_CLEAN_DEST}" == "1" && -e "${FREEWINE11_DEST_DIR}" ]]; then
    log "Cleaning existing freewine11 tree: ${FREEWINE11_DEST_DIR}"
    rm -rf "${FREEWINE11_DEST_DIR}"
  fi

  if [[ ! -d "${FREEWINE11_DEST_DIR}/.git" ]]; then
    log "Cloning base AndreRH tree into ${FREEWINE11_DEST_DIR}"
    mkdir -p "$(dirname -- "${FREEWINE11_DEST_DIR}")"
    wcp_clone_clean_source_tree "${FREEWINE11_SOURCE_DIR}" "${FREEWINE11_DEST_DIR}"
  else
    log "Reusing existing git tree at ${FREEWINE11_DEST_DIR}"
    git -C "${FREEWINE11_DEST_DIR}" reset --hard -q HEAD
    git -C "${FREEWINE11_DEST_DIR}" clean -fdqx
  fi

  git -C "${FREEWINE11_DEST_DIR}" checkout -B "${FREEWINE11_BRANCH}" >/dev/null 2>&1 \
    || fail "unable to switch branch ${FREEWINE11_BRANCH} in ${FREEWINE11_DEST_DIR}"
}

apply_patch_dir() {
  local lane="$1"
  local patch_dir="${LANES_ROOT}/${lane}/patches"
  local patch
  local -a patch_files

  mapfile -t patch_files < <(find "${patch_dir}" -maxdepth 1 -type f -name '*.patch' | sort)
  if [[ "${#patch_files[@]}" -eq 0 ]]; then
    log "Lane ${lane}: no patches"
    aeo_forensics_emit_event "info" "FREEWINE11_LANE_END" "${lane}" "empty" "no patches in lane"
    return 0
  fi

  aeo_forensics_emit_event "info" "FREEWINE11_LANE_START" "${lane}" "start" "patches=${#patch_files[@]}"
  log "Lane ${lane}: applying ${#patch_files[@]} patch(es)"

  for patch in "${patch_files[@]}"; do
    if ! git -C "${FREEWINE11_DEST_DIR}" apply --check --whitespace=nowarn "${patch}"; then
      aeo_forensics_emit_event "error" "FREEWINE11_PATCH_CHECK" "${lane}" "failed" "${patch}"
      fail "Patch check failed in lane ${lane}: ${patch}"
    fi
    if ! git -C "${FREEWINE11_DEST_DIR}" apply --whitespace=nowarn "${patch}"; then
      aeo_forensics_emit_event "error" "FREEWINE11_PATCH_APPLY" "${lane}" "failed" "${patch}"
      fail "Patch apply failed in lane ${lane}: ${patch}"
    fi
  done

  aeo_forensics_emit_event "info" "FREEWINE11_LANE_END" "${lane}" "success" "patches=${#patch_files[@]}"
}

apply_gn_baseline() {
  if [[ "${FREEWINE11_APPLY_GN_BASE}" != "1" ]]; then
    log "Skipping GN baseline (FREEWINE11_APPLY_GN_BASE=0)"
    aeo_forensics_emit_event "info" "FREEWINE11_GN_BASELINE" "gn-baseline" "skipped" "apply disabled"
    return 0
  fi

  log "Applying unified GameNative patch baseline"
  aeo_forensics_emit_event "info" "FREEWINE11_GN_BASELINE" "gn-baseline" "start" "strict=${FREEWINE11_GN_STRICT} preflight=${FREEWINE11_GN_PREFLIGHT}"

  mkdir -p "${FREEWINE11_DEST_DIR}/.freewine11/logs"
  export ROOT_DIR
  export WCP_OUTPUT_DIR="${FREEWINE11_DEST_DIR}/.freewine11"
  export WCP_GN_PATCHSET_ENABLE=1
  export WCP_GN_PATCHSET_STRICT="${FREEWINE11_GN_STRICT}"
  export WCP_GN_PATCHSET_PREFLIGHT="${FREEWINE11_GN_PREFLIGHT}"
  export WCP_GN_PATCHSET_VERIFY_AUTOFIX=1

  wcp_apply_unified_gamenative_patch_base wine "${FREEWINE11_DEST_DIR}" "${FREEWINE11_GN_STRICT}"
  aeo_forensics_emit_event "info" "FREEWINE11_GN_BASELINE" "gn-baseline" "success" "baseline applied"
}

write_provenance() {
  local lane patch_dir patch_count digest
  local andrerh_head source_ref source_remote repo_head
  local applied_total=0
  local lane_total=0
  local manifest_dir="${FREEWINE11_DEST_DIR}/${FREEWINE11_MANIFEST_DIR}"

  mkdir -p "${manifest_dir}"

  {
    printf 'lane\tpatch_count\tpatch_sha256\tsource_path\n'
    for lane in "${LANE_ORDER[@]}"; do
      patch_dir="${LANES_ROOT}/${lane}/patches"
      patch_count="$(patch_count_for_lane "${lane}")"
      digest="$(dir_hash "${patch_dir}")"
      applied_total=$((applied_total + patch_count))
      lane_total=$((lane_total + 1))
      printf '%s\t%s\t%s\t%s\n' "${lane}" "${patch_count}" "${digest}" "ci/wine11-arm64ec/transfer-lanes/${lane}/patches"
    done
  } > "${FREEWINE11_DEST_DIR}/${PATCH_MANIFEST_TSV}"

  andrerh_head="$(git -C "${FREEWINE11_SOURCE_DIR}" rev-parse HEAD 2>/dev/null || true)"
  source_ref="$(git -C "${FREEWINE11_SOURCE_DIR}" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  source_remote="$(git -C "${FREEWINE11_SOURCE_DIR}" remote get-url origin 2>/dev/null || true)"
  repo_head="$(git -C "${ROOT_DIR}" rev-parse HEAD 2>/dev/null || true)"

  {
    printf 'generated_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'freewine11_dest=%s\n' "${FREEWINE11_DEST_DIR}"
    printf 'freewine11_branch=%s\n' "${FREEWINE11_BRANCH}"
    printf 'andre_source_dir=%s\n' "${FREEWINE11_SOURCE_DIR}"
    printf 'andre_source_ref=%s\n' "${source_ref}"
    printf 'andre_source_head=%s\n' "${andrerh_head}"
    printf 'andre_source_remote=%s\n' "${source_remote}"
    printf 'repo_head=%s\n' "${repo_head}"
    printf 'gn_patchset_ref=%s\n' "${WCP_GN_PATCHSET_REF:-unset}"
    printf 'gn_patchset_strict=%s\n' "${FREEWINE11_GN_STRICT}"
    printf 'gn_patchset_preflight=%s\n' "${FREEWINE11_GN_PREFLIGHT}"
    printf 'lanes_total=%s\n' "${lane_total}"
    printf 'patches_total=%s\n' "${applied_total}"
    printf 'lane_manifest=%s\n' "${PATCH_MANIFEST_TSV}"
  } > "${FREEWINE11_DEST_DIR}/${BUILD_ENV_FILE}"

  {
    printf '# FreeWine11 Build Summary\n\n'
    printf '%s\n' "- destination: \`${FREEWINE11_DEST_DIR}\`"
    printf '%s\n' "- branch: \`${FREEWINE11_BRANCH}\`"
    printf '%s\n' "- andrerh source: \`${FREEWINE11_SOURCE_DIR}\` (\`${andrerh_head}\`)"
    printf '%s\n' "- repo head: \`${repo_head}\`"
    printf '%s\n' "- gn patchset ref: \`${WCP_GN_PATCHSET_REF:-unset}\`"
    printf '%s\n' "- lane count: \`${lane_total}\`"
    printf '%s\n' "- patch count: \`${applied_total}\`"
    printf '%s\n' "- lane manifest: \`${PATCH_MANIFEST_TSV}\`"
  } > "${FREEWINE11_DEST_DIR}/${BUILD_SUMMARY_MD}"
}

commit_tree() {
  if [[ "${FREEWINE11_COMMIT}" != "1" ]]; then
    log "Commit skipped (FREEWINE11_COMMIT=0)"
    return 0
  fi

  git -C "${FREEWINE11_DEST_DIR}" add -A
  if git -C "${FREEWINE11_DEST_DIR}" diff --cached --quiet; then
    log "No staged changes; nothing to commit"
    return 0
  fi

  git -C "${FREEWINE11_DEST_DIR}" commit -m "freewine11: integrate valve+tkg-ge+forensic transfer base" >/dev/null
  log "Committed freewine11 tree: $(git -C "${FREEWINE11_DEST_DIR}" rev-parse --short HEAD)"
}

update_active_links() {
  if [[ "${FREEWINE11_UPDATE_ACTIVE_LINKS}" != "1" ]]; then
    log "Skipping active-link updates (FREEWINE11_UPDATE_ACTIVE_LINKS=0)"
    return 0
  fi

  mkdir -p "${WCP_LOCAL_PROTON11_STACK_DIR}"
  ln -sfn "${FREEWINE11_DEST_DIR}" "${WCP_LOCAL_PROTON11_STACK_DIR}/wine11-arm64ec"
  ln -sfn "${FREEWINE11_DEST_DIR}" "${WCP_LOCAL_PROTON11_STACK_DIR}/freewine11"
  if [[ -d "${WCP_LOCAL_WINE11_DONOR_DIR}" ]]; then
    ln -sfn "${WCP_LOCAL_WINE11_DONOR_DIR}" "${WCP_LOCAL_PROTON11_STACK_DIR}/wine11-donor"
  fi

  if [[ -d "${WCP_LOCAL_PROTON_GE_LINKED_DIR}" ]]; then
    rm -rf "${WCP_LOCAL_PROTON_GE_LINKED_DIR}/wine"
    ln -sfn "${FREEWINE11_DEST_DIR}" "${WCP_LOCAL_PROTON_GE_LINKED_DIR}/wine"
  fi

  if [[ -d "${WCP_LOCAL_PROTON11_GE_ARM64EC_DIR}/refs" ]]; then
    ln -sfn "${FREEWINE11_DEST_DIR}" "${WCP_LOCAL_PROTON11_GE_ARM64EC_DIR}/refs/wine11-arm64ec"
    if [[ -d "${WCP_LOCAL_WINE11_DONOR_DIR}" ]]; then
      ln -sfn "${WCP_LOCAL_WINE11_DONOR_DIR}" "${WCP_LOCAL_PROTON11_GE_ARM64EC_DIR}/refs/wine11-donor"
    fi
  fi

  log "Updated active Wine11 links to ${FREEWINE11_DEST_DIR}"
}

main() {
  local lane

  verify_inputs
  prepare_dest_tree
  apply_gn_baseline

  for lane in "${LANE_ORDER[@]}"; do
    apply_patch_dir "${lane}"
  done

  write_provenance
  commit_tree
  update_active_links

  log "FreeWine11 tree is ready: ${FREEWINE11_DEST_DIR}"
  log "Current HEAD: $(git -C "${FREEWINE11_DEST_DIR}" rev-parse --short HEAD)"
}

aeo_forensics_wrap_main "freewine11-build-tree" main "$@"
