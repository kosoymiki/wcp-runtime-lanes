#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${ROOT_DIR}/ci/runtime-sources/local-source-layout.sh"

LANE_DIR="${ROOT_DIR}/ci/wine11-arm64ec/transfer-lanes/kernel32-runtime"
PREFIX_FILE="${LANE_DIR}/path-prefixes.txt"
PATCH_DIR="${LANE_DIR}/patches"
GN_MANIFEST="${ROOT_DIR}/ci/gamenative/patchsets/28c3a06/manifest.tsv"
GN_PATCH_ROOT="${ROOT_DIR}/ci/gamenative/patchsets/28c3a06/android/patches"

: "${WCP_WINE11_KERNEL32_RUNTIME_OVERLAP_OUT:=${ROOT_DIR}/docs/WINE11_ARM64EC_KERNEL32_RUNTIME_REPORT.md}"
: "${WCP_WINE11_KERNEL32_RUNTIME_OVERLAP_WINDOW:=250}"
: "${WCP_WINE11_KERNEL32_RUNTIME_OVERLAP_LIMIT:=30}"

log() { printf '[wine11-kernel32-runtime-overlap] %s\n' "$*" >&2; }
fail() { printf '[wine11-kernel32-runtime-overlap][error] %s\n' "$*" >&2; exit 1; }
tmp_dir=""

require_file() { [[ -f "$1" ]] || fail "file not found: $1"; }
require_dir() { [[ -d "$1" ]] || fail "directory not found: $1"; }

path_in_scope() {
  local path="$1" prefix
  while IFS= read -r prefix; do
    [[ -n "${prefix}" ]] || continue
    [[ "${path}" == "${prefix}"* ]] && return 0
  done < "${PREFIX_FILE}"
  return 1
}

extract_patch_paths() {
  local patch_file="$1" path
  while IFS= read -r path; do
    path="${path#+++ b/}"
    path="${path#--- a/}"
    [[ -n "${path}" ]] || continue
    [[ "${path}" == "/dev/null" ]] && continue
    path_in_scope "${path}" && printf '%s\n' "${path}"
  done < <(grep -E '^(--- a/|\+\+\+ b/)' "${patch_file}" || true)
  return 0
}

main() {
  local valve_list gn_list lane_list hot_list overlap_list
  local patch wine_action protonge_action required note patch_file
  local valve_ref valve_head lane_patch_count
  local -a pathspecs

  require_file "${PREFIX_FILE}"
  require_file "${GN_MANIFEST}"
  require_dir "${GN_PATCH_ROOT}"
  require_dir "${PATCH_DIR}"
  wcp_local_repo_exists "${WCP_LOCAL_VALVE_WINE_EXP10_DIR}" || fail "Missing Valve experimental anchor: ${WCP_LOCAL_VALVE_WINE_EXP10_DIR}"

  tmp_dir="$(mktemp -d /tmp/wine11-kernel32-runtime-overlap-XXXXXX)"
  trap 'test -n "${tmp_dir-}" && rm -rf "${tmp_dir}"' EXIT
  valve_list="${tmp_dir}/valve.txt"
  gn_list="${tmp_dir}/gn.txt"
  lane_list="${tmp_dir}/lane.txt"
  hot_list="${tmp_dir}/hot.txt"
  overlap_list="${tmp_dir}/overlap.txt"

  mapfile -t pathspecs < "${PREFIX_FILE}"
  valve_ref="origin/experimental_10.0"
  git -C "${WCP_LOCAL_VALVE_WINE_EXP10_DIR}" fetch --no-tags origin experimental_10.0 >/dev/null 2>&1
  valve_head="$(git -C "${WCP_LOCAL_VALVE_WINE_EXP10_DIR}" rev-parse --short=12 "${valve_ref}")"

  git -C "${WCP_LOCAL_VALVE_WINE_EXP10_DIR}" log --format= --name-only --max-count "${WCP_WINE11_KERNEL32_RUNTIME_OVERLAP_WINDOW}" "${valve_ref}" -- "${pathspecs[@]}" \
    | sed '/^$/d' | sort | uniq -c | sort -nr | head -n "${WCP_WINE11_KERNEL32_RUNTIME_OVERLAP_LIMIT}" > "${hot_list}"

  awk '{print $2}' "${hot_list}" | sort -u > "${valve_list}"

  {
    IFS= read -r _header || true
    while IFS=$'\t' read -r patch wine_action protonge_action required note; do
      [[ -n "${patch}" ]] || continue
      [[ "${patch}" == \#* ]] && continue
      [[ "${wine_action}" == "skip" ]] && continue
      patch_file="${GN_PATCH_ROOT}/${patch}"
      [[ -f "${patch_file}" ]] || continue
      extract_patch_paths "${patch_file}"
    done
  } < "${GN_MANIFEST}" | sort -u > "${gn_list}"

  find "${PATCH_DIR}" -maxdepth 1 -type f -name '*.patch' | sort | while IFS= read -r patch_file; do
    extract_patch_paths "${patch_file}"
  done | sort -u > "${lane_list}"

  lane_patch_count="$(find "${PATCH_DIR}" -maxdepth 1 -type f -name '*.patch' | wc -l | tr -d '[:space:]')"

  comm -12 "${valve_list}" "${gn_list}" > "${overlap_list}"

  mkdir -p "$(dirname "${WCP_WINE11_KERNEL32_RUNTIME_OVERLAP_OUT}")"
  {
    printf '# Wine11 Kernel32 Runtime Report\n\n'
    printf 'This report tracks the opened third non-core runtime lane after `kernelbase` and `win32u`.\n\n'
    printf '## Valve Source Window\n\n'
    printf '%s\n\n' "- Valve \`experimental_10.0\` head: \`${valve_head}\`"
    printf '%s\n\n' "- analyzed commit window: latest \`${WCP_WINE11_KERNEL32_RUNTIME_OVERLAP_WINDOW}\` commits"
    printf '## Kernel32 Runtime Scope\n\n```text\n'
    cat "${PREFIX_FILE}"
    printf '```\n\n## Valve Hot Files In Scope\n\n```text\n'
    cat "${hot_list}"
    printf '```\n\n## Existing GN Wine Patch Overlap\n\n```text\n'
    if [[ -s "${overlap_list}" ]]; then cat "${overlap_list}"; else printf '(no overlap found)\n'; fi
    printf '```\n\n## Current Kernel32 Runtime Files\n\n```text\n'
    if [[ -s "${lane_list}" ]]; then cat "${lane_list}"; else printf '(no kernel32-runtime patches yet)\n'; fi
    printf '```\n\n## Interpretation\n\n'
    printf 'Keep `kernel32-runtime` file-bounded, downstream of `win32u-runtime`, and avoid mixed ownership\n'
    printf 'merges while the core and early release-library lanes remain bounded. The lane is currently proven\n'
    printf 'with `%s` landed file-local runtime slice(s).\n' "${lane_patch_count}"
  } > "${WCP_WINE11_KERNEL32_RUNTIME_OVERLAP_OUT}"

  log "Report written: ${WCP_WINE11_KERNEL32_RUNTIME_OVERLAP_OUT}"
}

main "$@"
