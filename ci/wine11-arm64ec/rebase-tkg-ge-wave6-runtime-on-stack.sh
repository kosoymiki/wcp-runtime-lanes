#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${ROOT_DIR}/ci/runtime-sources/local-source-layout.sh"
source "${ROOT_DIR}/ci/lib/wcp_common.sh"
source "${ROOT_DIR}/ci/lib/gamenative-patch-base.sh"

LANE_DIR="${ROOT_DIR}/ci/wine11-arm64ec/transfer-lanes/tkg-ge-wave6-runtime"
PATCH_DIR="${LANE_DIR}/patches"
PATCH_BACKUP_DIR="${LANE_DIR}/patches-pre-stack-rebase"
WORK_DIR="${ROOT_DIR}/ci/wine11-arm64ec/tkg-ge-wave6-runtime-rebase-work"
REPORT_TSV="${ROOT_DIR}/docs/WINE11_ARM64EC_TKG_GE_WAVE6_RUNTIME_STACK_REBASE.tsv"
REPORT_MD="${ROOT_DIR}/docs/WINE11_ARM64EC_TKG_GE_WAVE6_RUNTIME_STACK_REBASE.md"

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

log() { printf '[wine11-tkg-ge-wave6-rebase] %s\n' "$*"; }
fail() { printf '[wine11-tkg-ge-wave6-rebase][error] %s\n' "$*" >&2; exit 1; }
tmp_dir=""

require_dir() { [[ -d "$1" ]] || fail "directory not found: $1"; }

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
  local keep_dir deferred_dir patch patch_name check_err
  local kept=0 absorbed=0 deferred=0 total=0
  local -a patch_files

  require_dir "${PATCH_DIR}"
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
  mkdir -p "${WORK_DIR}"
  keep_dir="${WORK_DIR}/kept"
  deferred_dir="${WORK_DIR}/deferred"
  mkdir -p "${keep_dir}" "${deferred_dir}"

  mapfile -t patch_files < <(find "${PATCH_DIR}" -maxdepth 1 -type f -name '*.patch' | sort)
  if [[ "${#patch_files[@]}" -eq 0 ]]; then
    log "No patches in ${PATCH_DIR}; nothing to rebase"
    exit 0
  fi

  tmp_dir="$(mktemp -d /tmp/wine11-tkg-ge-wave6-rebase-XXXXXX)"
  trap 'test -n "${tmp_dir-}" && rm -rf "${tmp_dir}"' EXIT
  clone_dir="${tmp_dir}/src"
  out_dir="${tmp_dir}/out"
  report_file="${out_dir}/gamenative-patchset-wine11-tkg-ge-wave6-rebase.tsv"

  mkdir -p "${out_dir}"
  wcp_clone_clean_source_tree "${WCP_LOCAL_ANDRE_WINE11_DIR}" "${clone_dir}"

  export ROOT_DIR WCP_OUTPUT_DIR="${out_dir}" WCP_GN_PATCHSET_REPORT="${report_file}"
  export WCP_GN_PATCHSET_ENABLE=1 WCP_GN_PATCHSET_STRICT=1 WCP_GN_PATCHSET_VERIFY_AUTOFIX=1

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

  printf 'patch\tstatus\treason\n' > "${REPORT_TSV}"
  for patch in "${patch_files[@]}"; do
    total=$((total + 1))
    patch_name="$(basename "${patch}")"
    if git -C "${clone_dir}" apply --check "${patch}" >/dev/null 2>&1; then
      git -C "${clone_dir}" apply "${patch}" >/dev/null 2>&1 || fail "Unable to apply: ${patch}"
      cp -f "${patch}" "${keep_dir}/${patch_name}"
      kept=$((kept + 1))
      printf '%s\t%s\t%s\n' "${patch_name}" "kept" "applies-on-current-stack" >> "${REPORT_TSV}"
      continue
    fi

    if git -C "${clone_dir}" apply --reverse --check "${patch}" >/dev/null 2>&1; then
      absorbed=$((absorbed + 1))
      printf '%s\t%s\t%s\n' "${patch_name}" "absorbed" "already-present-on-current-stack" >> "${REPORT_TSV}"
      continue
    fi

    check_err="$(git -C "${clone_dir}" apply --check "${patch}" 2>&1 || true)"
    check_err="$(printf '%s\n' "${check_err}" | awk 'NR<=2 { print }' | tr '\t' ' ' | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g' | sed 's/[[:space:]]*$//')"
    cp -f "${patch}" "${deferred_dir}/${patch_name}"
    deferred=$((deferred + 1))
    printf '%s\t%s\t%s\n' "${patch_name}" "deferred" "${check_err:-patch-does-not-apply}" >> "${REPORT_TSV}"
  done

  rm -rf "${PATCH_BACKUP_DIR}"
  mkdir -p "${PATCH_BACKUP_DIR}"
  if find "${PATCH_DIR}" -maxdepth 1 -type f -name '*.patch' | grep -q .; then
    cp -f "${PATCH_DIR}"/*.patch "${PATCH_BACKUP_DIR}/"
  fi
  rm -f "${PATCH_DIR}"/*.patch
  if find "${keep_dir}" -maxdepth 1 -type f -name '*.patch' | grep -q .; then
    cp -f "${keep_dir}"/*.patch "${PATCH_DIR}/"
  fi

  {
    printf '# Wine11 ARM64EC TKG GE Wave6 Runtime Stack Rebase\n\n'
    printf 'Wave6 runtime lane was rebased against the current owned Wine11 stack '
    printf '(GN baseline + core/loader/signal/server/wow64/support + kernelbase/win32u/kernel32 + wave1 lanes).\n\n'
    printf -- '- total input patches: `%s`\n' "${total}"
    printf -- '- kept on current stack: `%s`\n' "${kept}"
    printf -- '- absorbed (already present): `%s`\n' "${absorbed}"
    printf -- '- deferred (conflict): `%s`\n' "${deferred}"
    printf -- '- lane patch dir: `%s`\n' "${PATCH_DIR}"
    printf -- '- backup of pre-rebase lane: `%s`\n' "${PATCH_BACKUP_DIR}"
    printf -- '- detailed report: `%s`\n' "${REPORT_TSV}"
    if [[ "${kept}" -gt 0 ]]; then
      printf '\n## Kept Patches\n\n'
      printf '| Patch | Reason |\n'
      printf '| --- | --- |\n'
      awk -F'\t' 'NR>1 && $2=="kept" { printf("| `%s` | `%s` |\n", $1, $3) }' "${REPORT_TSV}"
    fi
    if [[ "${absorbed}" -gt 0 ]]; then
      printf '\n## Absorbed Patches\n\n'
      printf '| Patch | Reason |\n'
      printf '| --- | --- |\n'
      awk -F'\t' 'NR>1 && $2=="absorbed" { printf("| `%s` | `%s` |\n", $1, $3) }' "${REPORT_TSV}"
    fi
    if [[ "${deferred}" -gt 0 ]]; then
      printf '\n## Deferred Patches\n\n'
      printf '| Patch | Reason |\n'
      printf '| --- | --- |\n'
      awk -F'\t' 'NR>1 && $2=="deferred" { printf("| `%s` | `%s` |\n", $1, $3) }' "${REPORT_TSV}"
    fi
  } > "${REPORT_MD}"

  log "done: total=${total} kept=${kept} absorbed=${absorbed} deferred=${deferred}"
  log "report: ${REPORT_MD}"
}

main "$@"
