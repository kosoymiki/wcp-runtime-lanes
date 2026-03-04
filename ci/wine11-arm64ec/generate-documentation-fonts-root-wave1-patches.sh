#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${ROOT_DIR}/ci/runtime-sources/local-source-layout.sh"
source "${ROOT_DIR}/ci/lib/wcp_common.sh"
source "${ROOT_DIR}/ci/lib/gamenative-patch-base.sh"

LANE_DIR="${ROOT_DIR}/ci/wine11-arm64ec/transfer-lanes/documentation-fonts-root-wave1-runtime"
PATCH_DIR="${LANE_DIR}/patches"
PREFIX_FILE="${LANE_DIR}/path-prefixes.txt"
EXCLUDE_FILE="${LANE_DIR}/exclude-paths.txt"
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

BASE_ROOT="${WCP_LOCAL_ANDRE_WINE11_DIR}"
DONOR_ROOT="${WCP_LOCAL_VALVE_WINE_EXP10_DIR}"

log() { printf '[wine11-dfr-wave1-gen] %s\n' "$*"; }
fail() { printf '[wine11-dfr-wave1-gen][error] %s\n' "$*" >&2; exit 1; }
tmp_dir=""

require_dir() { [[ -d "$1" ]] || fail "directory not found: $1"; }
require_file() { [[ -f "$1" ]] || fail "file not found: $1"; }

slugify() {
  local s="$1"
  s="$(printf '%s' "${s}" | sed -e 's#[/.]#-#g' -e 's#[^A-Za-z0-9_-]#-#g' -e 's#--*#-#g' -e 's#^-##' -e 's#-$##')"
  if [[ -z "${s}" ]]; then
    s="path"
  fi
  printf '%.80s' "${s}"
}

apply_patch_dir() {
  local source_dir="$1" patch_dir="$2" patch
  local -a patch_files

  mapfile -t patch_files < <(find "${patch_dir}" -maxdepth 1 -type f -name '*.patch' | sort)
  for patch in "${patch_files[@]}"; do
    git -C "${source_dir}" apply --check "${patch}" || fail "Patch does not apply cleanly: ${patch}"
    git -C "${source_dir}" apply "${patch}" || fail "Unable to apply patch: ${patch}"
  done
}

prepare_base_tree() {
  local prepared_root="$1"
  local out_dir="${tmp_dir}/out"

  mkdir -p "${out_dir}"
  wcp_clone_clean_source_tree "${BASE_ROOT}" "${prepared_root}"

  export ROOT_DIR WCP_OUTPUT_DIR="${out_dir}" WCP_GN_PATCHSET_ENABLE=1 WCP_GN_PATCHSET_STRICT=1 WCP_GN_PATCHSET_VERIFY_AUTOFIX=1
  wcp_apply_unified_gamenative_patch_base wine "${prepared_root}" 1
  apply_patch_dir "${prepared_root}" "${CORE_PATCH_DIR}"
  apply_patch_dir "${prepared_root}" "${LOADER_PATCH_DIR}"
  apply_patch_dir "${prepared_root}" "${SIGNAL_PATCH_DIR}"
  apply_patch_dir "${prepared_root}" "${SERVER_PATCH_DIR}"
  apply_patch_dir "${prepared_root}" "${SERVER_SUPPORT_PATCH_DIR}"
  apply_patch_dir "${prepared_root}" "${WOW64_SUPPORT_PATCH_DIR}"
  apply_patch_dir "${prepared_root}" "${WOW64_STRUCT_SUPPORT_PATCH_DIR}"
  apply_patch_dir "${prepared_root}" "${LIBS_WINE_SUPPORT_PATCH_DIR}"
  apply_patch_dir "${prepared_root}" "${WINEBUILD_SUPPORT_PATCH_DIR}"
  apply_patch_dir "${prepared_root}" "${KERNELBASE_RUNTIME_PATCH_DIR}"
  apply_patch_dir "${prepared_root}" "${KERNELBASE_SUPPORT_PATCH_DIR}"
  apply_patch_dir "${prepared_root}" "${WIN32U_RUNTIME_PATCH_DIR}"
  apply_patch_dir "${prepared_root}" "${KERNEL32_RUNTIME_PATCH_DIR}"
  apply_patch_dir "${prepared_root}" "${DLLS_WAVE1_RUNTIME_PATCH_DIR}"
  apply_patch_dir "${prepared_root}" "${INCLUDE_LIBS_WAVE1_RUNTIME_PATCH_DIR}"
  apply_patch_dir "${prepared_root}" "${NPSST_WAVE1_RUNTIME_PATCH_DIR}"
}

main() {
  local rel_file rel base_file donor_file patch_tmp patch_out prepared_root
  local rc idx=0 generated=0 skipped=0
  local slug hash
  local -A excluded=()
  local -a prefixes

  require_dir "${BASE_ROOT}"
  require_dir "${DONOR_ROOT}"
  require_file "${PREFIX_FILE}"
  require_file "${EXCLUDE_FILE}"
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
  wcp_local_repo_exists "${BASE_ROOT}" || fail "Missing local AndreRH anchor: ${BASE_ROOT}"
  wcp_local_repo_exists "${DONOR_ROOT}" || fail "Missing local Valve anchor: ${DONOR_ROOT}"

  while IFS= read -r rel; do
    [[ -n "${rel}" ]] || continue
    [[ "${rel}" == \#* ]] && continue
    excluded["${rel}"]=1
  done < "${EXCLUDE_FILE}"

  mapfile -t prefixes < "${PREFIX_FILE}"
  if [[ "${#prefixes[@]}" -eq 0 ]]; then
    fail "No prefixes configured in ${PREFIX_FILE}"
  fi

  tmp_dir="$(mktemp -d /tmp/wine11-dfr-wave1-gen-XXXXXX)"
  trap 'test -n "${tmp_dir-}" && rm -rf "${tmp_dir}"' EXIT
  prepared_root="${tmp_dir}/prepared"
  prepare_base_tree "${prepared_root}"

  rel_file="${tmp_dir}/paths.txt"

  : > "${rel_file}"
  for rel in "${prefixes[@]}"; do
    find "${prepared_root}/${rel}" -type f -printf "${rel}%P\n" 2>/dev/null || true
    find "${DONOR_ROOT}/${rel}" -type f -printf "${rel}%P\n" 2>/dev/null || true
  done | sort -u > "${rel_file}"

  find "${PATCH_DIR}" -maxdepth 1 -type f -name '*.patch' -delete

  while IFS= read -r rel; do
    [[ -n "${rel}" ]] || continue
    if [[ -n "${excluded[${rel}]:-}" ]]; then
      skipped=$((skipped + 1))
      continue
    fi

    base_file="${prepared_root}/${rel}"
    donor_file="${DONOR_ROOT}/${rel}"

    if [[ -f "${base_file}" && -f "${donor_file}" ]]; then
      if cmp -s "${base_file}" "${donor_file}"; then
        continue
      fi
      patch_tmp="${tmp_dir}/raw.patch"
      set +e
      git diff --no-index --binary --full-index --src-prefix=a/ --dst-prefix=b/ "${base_file}" "${donor_file}" > "${patch_tmp}" 2>/dev/null
      rc=$?
      set -e
      if [[ "${rc}" -ne 1 && "${rc}" -ne 0 ]]; then
        fail "git diff failed for ${rel}"
      fi
    elif [[ -f "${donor_file}" ]]; then
      patch_tmp="${tmp_dir}/raw.patch"
      set +e
      git diff --no-index --binary --full-index --src-prefix=a/ --dst-prefix=b/ /dev/null "${donor_file}" > "${patch_tmp}" 2>/dev/null
      rc=$?
      set -e
      if [[ "${rc}" -ne 1 && "${rc}" -ne 0 ]]; then
        fail "git diff(new file) failed for ${rel}"
      fi
    elif [[ -f "${base_file}" ]]; then
      patch_tmp="${tmp_dir}/raw.patch"
      set +e
      git diff --no-index --binary --full-index --src-prefix=a/ --dst-prefix=b/ "${base_file}" /dev/null > "${patch_tmp}" 2>/dev/null
      rc=$?
      set -e
      if [[ "${rc}" -ne 1 && "${rc}" -ne 0 ]]; then
        fail "git diff(delete file) failed for ${rel}"
      fi
    else
      continue
    fi

    if [[ ! -s "${patch_tmp}" ]]; then
      continue
    fi

    idx=$((idx + 1))
    slug="$(slugify "${rel}")"
    hash="$(printf '%s' "${rel}" | sha1sum | awk '{print substr($1,1,8)}')"
    patch_out="${PATCH_DIR}/$(printf '%04d' "${idx}")-${slug}-${hash}.patch"

    awk -v rel="${rel}" '
      /^diff --git / { printf "diff --git a/%s b/%s\n", rel, rel; next }
      /^--- / {
        if ($2 == "/dev/null") { print "--- /dev/null"; next }
        printf "--- a/%s\n", rel
        next
      }
      /^\+\+\+ / {
        if ($2 == "/dev/null") { print "+++ /dev/null"; next }
        printf "+++ b/%s\n", rel
        next
      }
      { print }
    ' "${patch_tmp}" > "${patch_out}"

    if [[ ! -s "${patch_out}" ]]; then
      rm -f "${patch_out}"
      idx=$((idx - 1))
      continue
    fi
    generated=$((generated + 1))
  done < "${rel_file}"

  log "Generated patches: ${generated}"
  log "Skipped excluded paths: ${skipped}"
  log "Base snapshot: AndreRH + GN + core/loader/signal/server/server-support/wow64/wow64-struct/libs-wine/winebuild/kernelbase/win32u/kernel32/dlls-wave1/include-libs/nls-po-programs-server-tools"
  log "Patch dir: ${PATCH_DIR}"
}

main "$@"
