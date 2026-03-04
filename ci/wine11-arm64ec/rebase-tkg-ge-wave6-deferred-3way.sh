#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${ROOT_DIR}/ci/runtime-sources/local-source-layout.sh"
source "${ROOT_DIR}/ci/lib/wcp_common.sh"
source "${ROOT_DIR}/ci/lib/gamenative-patch-base.sh"

LANE_DIR="${ROOT_DIR}/ci/wine11-arm64ec/transfer-lanes/tkg-ge-wave6-runtime"
ACTIVE_PATCH_DIR="${LANE_DIR}/patches"
SOURCE_PATCH_DIR="${LANE_DIR}/patches-pre-stack-rebase"
STACK_REBASE_TSV="${ROOT_DIR}/docs/WINE11_ARM64EC_TKG_GE_WAVE6_RUNTIME_STACK_REBASE.tsv"

WORK_DIR="${ROOT_DIR}/ci/wine11-arm64ec/tkg-ge-wave6-deferred-3way-work"
REBASING_OUT_DIR="${WORK_DIR}/rebased-patches"
REPORT_TSV="${ROOT_DIR}/docs/WINE11_ARM64EC_TKG_GE_WAVE6_DEFERRED_3WAY.tsv"
REPORT_MD="${ROOT_DIR}/docs/WINE11_ARM64EC_TKG_GE_WAVE6_DEFERRED_3WAY.md"

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

log() { printf '[wine11-wave6-deferred-3way] %s\n' "$*"; }
fail() { printf '[wine11-wave6-deferred-3way][error] %s\n' "$*" >&2; exit 1; }
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

main() {
  local clone_dir out_dir report_file
  local baseline_commit deferred_patch patch_name rebased_patch
  local total=0 kept=0 failed=0
  local reason check_err
  local -a deferred_list

  require_dir "${SOURCE_PATCH_DIR}"
  require_dir "${ACTIVE_PATCH_DIR}"
  require_file "${STACK_REBASE_TSV}"
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
  printf 'patch\tstatus\treason\trebased_patch\n' > "${REPORT_TSV}"

  mapfile -t deferred_list < <(awk -F'\t' 'NR>1 && $2=="deferred" {print $1}' "${STACK_REBASE_TSV}")
  if [[ "${#deferred_list[@]}" -eq 0 ]]; then
    log "No deferred patches in ${STACK_REBASE_TSV}"
    {
      printf '# Wine11 ARM64EC TKG GE Wave6 Deferred 3-way Rebase\n\n'
      printf 'No deferred patches were found in `%s`.\n' "${STACK_REBASE_TSV}"
    } > "${REPORT_MD}"
    exit 0
  fi

  tmp_dir="$(mktemp -d /tmp/wine11-wave6-deferred-3way-XXXXXX)"
  trap 'test -n "${tmp_dir-}" && rm -rf "${tmp_dir}"' EXIT
  clone_dir="${tmp_dir}/src"
  out_dir="${tmp_dir}/out"
  report_file="${out_dir}/gamenative-patchset-wine11-wave6-deferred-3way.tsv"

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
  apply_patch_dir "${clone_dir}" "${ACTIVE_PATCH_DIR}"

  git -C "${clone_dir}" add -A
  git -C "${clone_dir}" commit -q -m "baseline wave6 deferred 3way"
  baseline_commit="$(git -C "${clone_dir}" rev-parse HEAD)"

  for patch_name in "${deferred_list[@]}"; do
    total=$((total + 1))
    deferred_patch="${SOURCE_PATCH_DIR}/${patch_name}"
    if [[ ! -f "${deferred_patch}" ]]; then
      failed=$((failed + 1))
      printf '%s\t%s\t%s\t%s\n' "${patch_name}" "failed" "patch-file-not-found" "" >> "${REPORT_TSV}"
      continue
    fi

    git -C "${clone_dir}" reset --hard -q "${baseline_commit}"
    git -C "${clone_dir}" clean -fdq

    if git -C "${clone_dir}" apply --3way --index "${deferred_patch}" >/dev/null 2>&1; then
      rebased_patch="${REBASING_OUT_DIR}/${patch_name}"
      git -C "${clone_dir}" diff --binary "${baseline_commit}" > "${rebased_patch}"
      if [[ ! -s "${rebased_patch}" ]]; then
        failed=$((failed + 1))
        printf '%s\t%s\t%s\t%s\n' "${patch_name}" "failed" "empty-diff-after-3way" "" >> "${REPORT_TSV}"
        continue
      fi
      kept=$((kept + 1))
      printf '%s\t%s\t%s\t%s\n' "${patch_name}" "rebased" "3way-ok" "${rebased_patch}" >> "${REPORT_TSV}"
      continue
    fi

    check_err="$(git -C "${clone_dir}" apply --3way --index "${deferred_patch}" 2>&1 || true)"
    reason="$(printf '%s\n' "${check_err}" | awk 'NR<=2 { print }' | tr '\t' ' ' | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g' | sed 's/[[:space:]]*$//')"
    failed=$((failed + 1))
    printf '%s\t%s\t%s\t%s\n' "${patch_name}" "failed" "${reason:-3way-failed}" "" >> "${REPORT_TSV}"
  done

  {
    printf '# Wine11 ARM64EC TKG GE Wave6 Deferred 3-way Rebase\n\n'
    printf 'Deferred Wave6 patches were tested with `git apply --3way --index` on top of the current owned Wine11 chain.\n\n'
    printf -- '- deferred input: `%s`\n' "${total}"
    printf -- '- rebased (3way ok): `%s`\n' "${kept}"
    printf -- '- failed: `%s`\n' "${failed}"
    printf -- '- rebased patch output dir: `%s`\n' "${REBASING_OUT_DIR}"
    printf -- '- machine-readable report: `%s`\n' "${REPORT_TSV}"
    if [[ "${kept}" -gt 0 ]]; then
      printf '\n## Rebased Patches\n\n'
      printf '| Patch | Rebased Patch |\n'
      printf '| --- | --- |\n'
      awk -F'\t' 'NR>1 && $2=="rebased" { printf("| `%s` | `%s` |\n", $1, $4) }' "${REPORT_TSV}"
    fi
    if [[ "${failed}" -gt 0 ]]; then
      printf '\n## Failed Patches\n\n'
      printf '| Patch | Reason |\n'
      printf '| --- | --- |\n'
      awk -F'\t' 'NR>1 && $2=="failed" { printf("| `%s` | `%s` |\n", $1, $3) }' "${REPORT_TSV}"
    fi
  } > "${REPORT_MD}"

  log "done: deferred=${total} rebased=${kept} failed=${failed}"
  log "report: ${REPORT_MD}"
}

main "$@"
