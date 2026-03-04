#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${ROOT_DIR}/ci/runtime-sources/local-source-layout.sh"
source "${ROOT_DIR}/ci/lib/wcp_common.sh"
source "${ROOT_DIR}/ci/lib/gamenative-patch-base.sh"

LANE_DIR="${ROOT_DIR}/ci/wine11-arm64ec/transfer-lanes/tkg-ge-wave6-runtime"
ACTIVE_PATCH_DIR="${LANE_DIR}/patches"
SOURCE_PATCH_DIR="${LANE_DIR}/patches-pre-stack-rebase"
DEFERRED3_TSV="${ROOT_DIR}/docs/WINE11_ARM64EC_TKG_GE_WAVE6_DEFERRED_3WAY.tsv"
BASELINE_3WAY_DIR="${ROOT_DIR}/ci/wine11-arm64ec/tkg-ge-wave6-deferred-3way-work/rebased-patches"

WORK_DIR="${ROOT_DIR}/ci/wine11-arm64ec/tkg-ge-wave6-deferred-seq-work"
REBASING_OUT_DIR="${WORK_DIR}/rebased-patches"
REPORT_TSV="${ROOT_DIR}/docs/WINE11_ARM64EC_TKG_GE_WAVE6_DEFERRED_SEQ.tsv"
REPORT_MD="${ROOT_DIR}/docs/WINE11_ARM64EC_TKG_GE_WAVE6_DEFERRED_SEQ.md"

CORE_PATCH_DIR="${ROOT_DIR}/ci/wine11-arm64ec/transfer-lanes/core-runtime/patches"
LOADER_PATCH_DIR="${ROOT_DIR}/ci/wine11-arm64ec/transfer-lanes/loader-runtime/patches"
SIGNAL_PATCH_DIR="${ROOT_DIR}/ci/wine11-arm64ec/transfer-lanes/signal-runtime/patches"
SERVER_PATCH_DIR="${ROOT_DIR}/ci/wine11-arm64ec/transfer-lanes/server-runtime/patches"
SERVER_SUPPORT_PATCH_DIR="${ROOT_DIR}/ci/wine11-arm64ec/transfer-lanes/server-support/patches"
WOW64_SUPPORT_PATCH_DIR="${ROOT_DIR}/ci/wine11-arm64ec/transfer-lanes/wow64-support/patches"
WOW64_STRUCT_SUPPORT_PATCH_DIR="${ROOT_DIR}/ci/wine11-arm64ec/transfer-lanes/wow64-struct-support/patches"
LIBS_WINE_SUPPORT_PATCH_DIR="${ROOT_DIR}/ci/wine11-arm64ec/transfer-lanes/libs-wine-support/patches"
WINEBUILD_SUPPORT_PATCH_DIR="${ROOT_DIR}/ci/wine11-arm64ec/transfer-lanes/winebuild-support/patches"
KERNELBASE_RUNTIME_PATCH_DIR="${ROOT_DIR}/ci/wine11-arm64ec/transfer-lanes/kernelbase-runtime/patches"
KERNELBASE_SUPPORT_PATCH_DIR="${ROOT_DIR}/ci/wine11-arm64ec/transfer-lanes/kernelbase-support/patches"
WIN32U_RUNTIME_PATCH_DIR="${ROOT_DIR}/ci/wine11-arm64ec/transfer-lanes/win32u-runtime/patches"
KERNEL32_RUNTIME_PATCH_DIR="${ROOT_DIR}/ci/wine11-arm64ec/transfer-lanes/kernel32-runtime/patches"
DLLS_WAVE1_RUNTIME_PATCH_DIR="${ROOT_DIR}/ci/wine11-arm64ec/transfer-lanes/dlls-wave1-runtime/patches"
INCLUDE_LIBS_WAVE1_RUNTIME_PATCH_DIR="${ROOT_DIR}/ci/wine11-arm64ec/transfer-lanes/include-libs-wave1-runtime/patches"
NPSST_WAVE1_RUNTIME_PATCH_DIR="${ROOT_DIR}/ci/wine11-arm64ec/transfer-lanes/nls-po-programs-server-tools-wave1-runtime/patches"
DOC_FONTS_ROOT_WAVE1_RUNTIME_PATCH_DIR="${ROOT_DIR}/ci/wine11-arm64ec/transfer-lanes/documentation-fonts-root-wave1-runtime/patches"

BASELINE_PATCHES=(
  "0052-0001-dmscript-IDirectMusicScript-EnumRoutine-return-S_FAL.patch"
  "0282-0001-kernel32-Always-start-debugger-on-WinSta0.patch"
  "0308-0001-msxml3-Write-to-DOMDocument-mxwriter-destination-in-.patch"
  "1487-0002-wintab32-Set-lcSysExtX-Y-for-the-first-index-of-WTI_.patch"
)

log() { printf '[wine11-wave6-deferred-seq] %s\n' "$*"; }
fail() { printf '[wine11-wave6-deferred-seq][error] %s\n' "$*" >&2; exit 1; }
tmp_dir=""

require_dir() { [[ -d "$1" ]] || fail "directory not found: $1"; }
require_file() { [[ -f "$1" ]] || fail "file not found: $1"; }

apply_patch_dir() {
  local source_dir="$1" patch_dir="$2" patch
  local -a patch_files

  mapfile -t patch_files < <(find "${patch_dir}" -maxdepth 1 -type f -name '*.patch' | sort)
  for patch in "${patch_files[@]}"; do
    git -C "${source_dir}" apply --check "${patch}" || fail "Patch does not apply cleanly: ${patch}"
    git -C "${source_dir}" apply "${patch}" || fail "Unable to apply patch: ${patch}"
  done
}

attempt_git_apply() {
  local clone_dir="$1" patch_file="$2"
  shift 2
  local -a opts=("$@")
  git -C "${clone_dir}" apply --check "${opts[@]}" "${patch_file}" >/dev/null 2>&1 || return 1
  git -C "${clone_dir}" apply "${opts[@]}" "${patch_file}" >/dev/null 2>&1 || return 1
  return 0
}

attempt_patch_fuzzy() {
  local clone_dir="$1" patch_file="$2" fuzz="$3"
  (cd "${clone_dir}" && patch -p1 --forward --batch --no-backup-if-mismatch --fuzz="${fuzz}" --dry-run < "${patch_file}" >/dev/null 2>&1) || return 1
  (cd "${clone_dir}" && patch -p1 --forward --batch --no-backup-if-mismatch --fuzz="${fuzz}" < "${patch_file}" >/dev/null 2>&1) || return 1
  find "${clone_dir}" -type f -name '*.rej' | grep -q . && return 1
  return 0
}

attempt_git_am_3way() {
  local clone_dir="$1" patch_file="$2"
  git -C "${clone_dir}" am -q --3way "${patch_file}" >/dev/null 2>&1 && return 0
  git -C "${clone_dir}" am --abort >/dev/null 2>&1 || true
  return 1
}

patch_source_for() {
  local patch_name="$1"
  if [[ -f "${SOURCE_PATCH_DIR}/${patch_name}" ]]; then
    printf '%s' "${SOURCE_PATCH_DIR}/${patch_name}"
    return 0
  fi
  if [[ -f "${ACTIVE_PATCH_DIR}/${patch_name}" ]]; then
    printf '%s' "${ACTIVE_PATCH_DIR}/${patch_name}"
    return 0
  fi
  return 1
}

baseline_patch_source_for() {
  local patch_name="$1"
  if [[ -f "${BASELINE_3WAY_DIR}/${patch_name}" ]]; then
    printf '%s' "${BASELINE_3WAY_DIR}/${patch_name}"
    return 0
  fi
  if [[ -f "${ACTIVE_PATCH_DIR}/${patch_name}" ]]; then
    printf '%s' "${ACTIVE_PATCH_DIR}/${patch_name}"
    return 0
  fi
  if [[ -f "${SOURCE_PATCH_DIR}/${patch_name}" ]]; then
    printf '%s' "${SOURCE_PATCH_DIR}/${patch_name}"
    return 0
  fi
  return 1
}

main() {
  local clone_dir out_dir report_file
  local patch_name patch_file reason method rebased_patch check_err
  local total=0 rebased=0 failed=0 absorbed=0
  local -a deferred_list

  require_dir "${SOURCE_PATCH_DIR}"
  require_dir "${ACTIVE_PATCH_DIR}"
  require_file "${DEFERRED3_TSV}"
  require_dir "${BASELINE_3WAY_DIR}"
  require_dir "${CORE_PATCH_DIR}"
  require_dir "${LOADER_PATCH_DIR}"
  require_dir "${SIGNAL_PATCH_DIR}"
  require_dir "${SERVER_PATCH_DIR}"
  require_dir "${SERVER_SUPPORT_PATCH_DIR}"
  require_dir "${WOW64_SUPPORT_PATCH_DIR}"
  require_dir "${WOW64_STRUCT_SUPPORT_PATCH_DIR}"
  require_dir "${LIBS_WINE_SUPPORT_PATCH_DIR}"
  require_dir "${WINEBUILD_SUPPORT_PATCH_DIR}"
  require_dir "${KERNELBASE_RUNTIME_PATCH_DIR}"
  require_dir "${KERNELBASE_SUPPORT_PATCH_DIR}"
  require_dir "${WIN32U_RUNTIME_PATCH_DIR}"
  require_dir "${KERNEL32_RUNTIME_PATCH_DIR}"
  require_dir "${DLLS_WAVE1_RUNTIME_PATCH_DIR}"
  require_dir "${INCLUDE_LIBS_WAVE1_RUNTIME_PATCH_DIR}"
  require_dir "${NPSST_WAVE1_RUNTIME_PATCH_DIR}"
  require_dir "${DOC_FONTS_ROOT_WAVE1_RUNTIME_PATCH_DIR}"
  wcp_local_repo_exists "${WCP_LOCAL_ANDRE_WINE11_DIR}" || fail "Missing local AndreRH anchor: ${WCP_LOCAL_ANDRE_WINE11_DIR}"

  rm -rf "${WORK_DIR}"
  mkdir -p "${REBASING_OUT_DIR}"
  printf 'patch\tstatus\tmethod\treason\trebased_patch\n' > "${REPORT_TSV}"

  mapfile -t deferred_list < <(awk -F'\t' 'NR>1 && $2=="failed" {print $1}' "${DEFERRED3_TSV}")
  if [[ "${#deferred_list[@]}" -eq 0 ]]; then
    log "No failed patches in ${DEFERRED3_TSV}"
    {
      printf '# Wine11 ARM64EC TKG GE Wave6 Deferred Sequential Rebase\n\n'
      printf 'No failed deferred patches were found in `%s`.\n' "${DEFERRED3_TSV}"
    } > "${REPORT_MD}"
    exit 0
  fi

  tmp_dir="$(mktemp -d /tmp/wine11-wave6-deferred-seq-XXXXXX)"
  trap 'test -n "${tmp_dir-}" && rm -rf "${tmp_dir}"' EXIT
  clone_dir="${tmp_dir}/src"
  out_dir="${tmp_dir}/out"
  report_file="${out_dir}/gamenative-patchset-wine11-wave6-deferred-seq.tsv"

  mkdir -p "${out_dir}"
  wcp_clone_clean_source_tree "${WCP_LOCAL_ANDRE_WINE11_DIR}" "${clone_dir}"

  export ROOT_DIR WCP_OUTPUT_DIR="${out_dir}" WCP_GN_PATCHSET_REPORT="${report_file}"
  export WCP_GN_PATCHSET_ENABLE=1 WCP_GN_PATCHSET_STRICT=1 WCP_GN_PATCHSET_VERIFY_AUTOFIX=1
  export GIT_AUTHOR_NAME="wcp-bot" GIT_AUTHOR_EMAIL="wcp-bot@example.invalid"
  export GIT_COMMITTER_NAME="wcp-bot" GIT_COMMITTER_EMAIL="wcp-bot@example.invalid"

  wcp_apply_unified_gamenative_patch_base wine "${clone_dir}" 1
  apply_patch_dir "${clone_dir}" "${CORE_PATCH_DIR}"
  apply_patch_dir "${clone_dir}" "${LOADER_PATCH_DIR}"
  apply_patch_dir "${clone_dir}" "${SIGNAL_PATCH_DIR}"
  apply_patch_dir "${clone_dir}" "${SERVER_PATCH_DIR}"
  apply_patch_dir "${clone_dir}" "${SERVER_SUPPORT_PATCH_DIR}"
  apply_patch_dir "${clone_dir}" "${WOW64_SUPPORT_PATCH_DIR}"
  apply_patch_dir "${clone_dir}" "${WOW64_STRUCT_SUPPORT_PATCH_DIR}"
  apply_patch_dir "${clone_dir}" "${LIBS_WINE_SUPPORT_PATCH_DIR}"
  apply_patch_dir "${clone_dir}" "${WINEBUILD_SUPPORT_PATCH_DIR}"
  apply_patch_dir "${clone_dir}" "${KERNELBASE_RUNTIME_PATCH_DIR}"
  apply_patch_dir "${clone_dir}" "${KERNELBASE_SUPPORT_PATCH_DIR}"
  apply_patch_dir "${clone_dir}" "${WIN32U_RUNTIME_PATCH_DIR}"
  apply_patch_dir "${clone_dir}" "${KERNEL32_RUNTIME_PATCH_DIR}"
  apply_patch_dir "${clone_dir}" "${DLLS_WAVE1_RUNTIME_PATCH_DIR}"
  apply_patch_dir "${clone_dir}" "${INCLUDE_LIBS_WAVE1_RUNTIME_PATCH_DIR}"
  apply_patch_dir "${clone_dir}" "${NPSST_WAVE1_RUNTIME_PATCH_DIR}"
  apply_patch_dir "${clone_dir}" "${DOC_FONTS_ROOT_WAVE1_RUNTIME_PATCH_DIR}"

  for patch_name in "${BASELINE_PATCHES[@]}"; do
    patch_file="$(baseline_patch_source_for "${patch_name}" || true)"
    [[ -n "${patch_file}" ]] || fail "baseline patch not found: ${patch_name}"
    git -C "${clone_dir}" apply --check "${patch_file}" || fail "Baseline patch does not apply: ${patch_file}"
    git -C "${clone_dir}" apply "${patch_file}" || fail "Unable to apply baseline patch: ${patch_file}"
  done

  git -C "${clone_dir}" add -A
  git -C "${clone_dir}" commit -q -m "baseline wave6 deferred sequential"

  for patch_name in "${deferred_list[@]}"; do
    total=$((total + 1))
    patch_file="$(patch_source_for "${patch_name}" || true)"
    if [[ -z "${patch_file}" ]]; then
      failed=$((failed + 1))
      printf '%s\t%s\t%s\t%s\t%s\n' "${patch_name}" "failed" "" "patch-file-not-found" "" >> "${REPORT_TSV}"
      continue
    fi

    if git -C "${clone_dir}" apply --reverse --check "${patch_file}" >/dev/null 2>&1; then
      absorbed=$((absorbed + 1))
      printf '%s\t%s\t%s\t%s\t%s\n' "${patch_name}" "absorbed" "reverse-check" "already-present-on-current-chain" "" >> "${REPORT_TSV}"
      continue
    fi

    method=""
    if attempt_git_apply "${clone_dir}" "${patch_file}"; then
      method="git-plain"
    elif attempt_git_apply "${clone_dir}" "${patch_file}" --recount; then
      method="git-recount"
    elif attempt_git_apply "${clone_dir}" "${patch_file}" --ignore-space-change --ignore-whitespace; then
      method="git-ignore-ws"
    elif attempt_git_apply "${clone_dir}" "${patch_file}" --recount --ignore-space-change --ignore-whitespace; then
      method="git-recount-ignore-ws"
    elif attempt_git_apply "${clone_dir}" "${patch_file}" --3way --index; then
      method="git-3way-index"
    elif attempt_git_am_3way "${clone_dir}" "${patch_file}"; then
      method="git-am-3way"
    elif attempt_patch_fuzzy "${clone_dir}" "${patch_file}" 3; then
      method="patch-fuzz3"
    elif attempt_patch_fuzzy "${clone_dir}" "${patch_file}" 5; then
      method="patch-fuzz5"
    else
      check_err="$(git -C "${clone_dir}" apply --check "${patch_file}" 2>&1 || true)"
      reason="$(printf '%s\n' "${check_err}" | awk 'NR<=2 { print }' | tr '\t' ' ' | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g' | sed 's/[[:space:]]*$//')"
      failed=$((failed + 1))
      printf '%s\t%s\t%s\t%s\t%s\n' "${patch_name}" "failed" "" "${reason:-no-apply-mode-succeeded}" "" >> "${REPORT_TSV}"
      continue
    fi

    git -C "${clone_dir}" add -A
    if git -C "${clone_dir}" diff --cached --quiet; then
      absorbed=$((absorbed + 1))
      printf '%s\t%s\t%s\t%s\t%s\n' "${patch_name}" "absorbed" "${method}" "empty-diff-after-apply" "" >> "${REPORT_TSV}"
      continue
    fi

    git -C "${clone_dir}" commit -q -m "wave6-deferred-seq ${patch_name}"
    rebased_patch="${REBASING_OUT_DIR}/${patch_name}"
    git -C "${clone_dir}" diff --binary HEAD~1 HEAD > "${rebased_patch}"
    if [[ ! -s "${rebased_patch}" ]]; then
      failed=$((failed + 1))
      printf '%s\t%s\t%s\t%s\t%s\n' "${patch_name}" "failed" "${method}" "empty-rebased-patch" "" >> "${REPORT_TSV}"
      continue
    fi

    rebased=$((rebased + 1))
    printf '%s\t%s\t%s\t%s\t%s\n' "${patch_name}" "rebased" "${method}" "ok" "${rebased_patch}" >> "${REPORT_TSV}"
  done

  {
    printf '# Wine11 ARM64EC TKG GE Wave6 Deferred Sequential Rebase\n\n'
    printf 'Deferred patches were rebased as a single cumulative chain on top of owned Wine11 stack and the known stable Wave6 baseline.\n\n'
    printf -- '- deferred input from 3-way report: `%s`\n' "${total}"
    printf -- '- rebased: `%s`\n' "${rebased}"
    printf -- '- absorbed: `%s`\n' "${absorbed}"
    printf -- '- failed: `%s`\n' "${failed}"
    printf -- '- rebased patch output dir: `%s`\n' "${REBASING_OUT_DIR}"
    printf -- '- machine-readable report: `%s`\n' "${REPORT_TSV}"
    if [[ "${rebased}" -gt 0 ]]; then
      printf '\n## Rebased Patches\n\n'
      printf '| Patch | Method | Rebased Patch |\n'
      printf '| --- | --- | --- |\n'
      awk -F'\t' 'NR>1 && $2=="rebased" { printf("| `%s` | `%s` | `%s` |\n", $1, $3, $5) }' "${REPORT_TSV}"
    fi
    if [[ "${absorbed}" -gt 0 ]]; then
      printf '\n## Absorbed Patches\n\n'
      printf '| Patch | Method | Reason |\n'
      printf '| --- | --- | --- |\n'
      awk -F'\t' 'NR>1 && $2=="absorbed" { printf("| `%s` | `%s` | `%s` |\n", $1, $3, $4) }' "${REPORT_TSV}"
    fi
    if [[ "${failed}" -gt 0 ]]; then
      printf '\n## Failed Patches\n\n'
      printf '| Patch | Reason |\n'
      printf '| --- | --- |\n'
      awk -F'\t' 'NR>1 && $2=="failed" { printf("| `%s` | `%s` |\n", $1, $4) }' "${REPORT_TSV}"
    fi
  } > "${REPORT_MD}"

  log "done: input=${total} rebased=${rebased} absorbed=${absorbed} failed=${failed}"
  log "report: ${REPORT_MD}"
}

main "$@"
