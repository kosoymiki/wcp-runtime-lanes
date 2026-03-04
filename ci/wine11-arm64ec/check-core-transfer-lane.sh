#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${ROOT_DIR}/ci/runtime-sources/local-source-layout.sh"
source "${ROOT_DIR}/ci/lib/wcp_common.sh"
source "${ROOT_DIR}/ci/lib/gamenative-patch-base.sh"

LANE_DIR="${ROOT_DIR}/ci/wine11-arm64ec/transfer-lanes/core-runtime"
PATCH_DIR="${LANE_DIR}/patches"
PREFIX_FILE="${LANE_DIR}/path-prefixes.txt"

log() { printf '[wine11-core-lane] %s\n' "$*"; }
fail() { printf '[wine11-core-lane][error] %s\n' "$*" >&2; exit 1; }
tmp_dir=""

require_file() { [[ -f "$1" ]] || fail "file not found: $1"; }
require_dir() { [[ -d "$1" ]] || fail "directory not found: $1"; }

emit_patch_paths() {
  local patch="$1"
  awk '
    /^\+\+\+ b\// { sub(/^\+\+\+ b\//, "", $0); print; next }
    /^--- a\// { sub(/^--- a\//, "", $0); print; next }
  ' "${patch}" | sort -u
}

path_in_scope() {
  local path="$1" prefix
  while IFS= read -r prefix; do
    [[ -n "${prefix}" ]] || continue
    [[ "${path}" == "${prefix}"* ]] && return 0
  done < "${PREFIX_FILE}"
  return 1
}

main() {
  local clone_dir out_dir report_file
  local patch patch_count=0 changed_file
  local -a patch_files

  require_file "${PREFIX_FILE}"
  require_dir "${PATCH_DIR}"
  wcp_local_repo_exists "${WCP_LOCAL_ANDRE_WINE11_DIR}" || fail "Missing local AndreRH anchor: ${WCP_LOCAL_ANDRE_WINE11_DIR}"

  tmp_dir="$(mktemp -d /tmp/wine11-core-lane-XXXXXX)"
  trap 'test -n "${tmp_dir-}" && rm -rf "${tmp_dir}"' EXIT
  clone_dir="${tmp_dir}/src"
  out_dir="${tmp_dir}/out"
  report_file="${out_dir}/gamenative-patchset-wine11-core.tsv"

  mkdir -p "${out_dir}"
  wcp_clone_clean_source_tree "${WCP_LOCAL_ANDRE_WINE11_DIR}" "${clone_dir}"

  export ROOT_DIR WCP_OUTPUT_DIR="${out_dir}" WCP_GN_PATCHSET_REPORT="${report_file}"
  export WCP_GN_PATCHSET_ENABLE=1 WCP_GN_PATCHSET_STRICT=1 WCP_GN_PATCHSET_VERIFY_AUTOFIX=1

  wcp_apply_unified_gamenative_patch_base wine "${clone_dir}" 1

  mapfile -t patch_files < <(find "${PATCH_DIR}" -maxdepth 1 -type f -name '*.patch' | sort)
  if [[ "${#patch_files[@]}" -eq 0 ]]; then
    log "No custom core-runtime patches yet; GN baseline preflight passed"
    return 0
  fi

  for patch in "${patch_files[@]}"; do
    patch_count=$((patch_count + 1))
    while IFS= read -r changed_file; do
      [[ -n "${changed_file}" ]] || continue
      path_in_scope "${changed_file}" || fail "Out-of-scope path touched by core-runtime lane: ${changed_file}"
    done < <(emit_patch_paths "${patch}")
    git -C "${clone_dir}" apply --check "${patch}" || fail "Patch does not apply cleanly: ${patch}"
    git -C "${clone_dir}" apply "${patch}" || fail "Unable to apply patch: ${patch}"
  done

  log "Core transfer lane passed: ${patch_count} custom patch(es) on top of GN baseline"
}

main "$@"
