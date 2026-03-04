#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${ROOT_DIR}/ci/runtime-sources/local-source-layout.sh"

: "${WCP_WINE11_REFLECT_OUT:=${ROOT_DIR}/docs/WINE11_ARM64EC_VALVE_EXPERIMENTAL10_REPORT.md}"
: "${WCP_WINE11_REFLECT_LIMIT:=80}"
: "${WCP_WINE11_REFLECT_MODE:=fast}"
: "${WCP_WINE11_REFLECT_WINDOW:=1500}"
: "${WCP_WINE11_REFLECT_ANDRE_REF:=arm64ec}"
: "${WCP_WINE11_REFLECT_VALVE_REF:=experimental_10.0}"

if wcp_local_repo_exists "${WCP_LOCAL_ANDRE_WINE11_DIR}"; then
  : "${WCP_WINE11_REFLECT_ANDRE_REPO:=${WCP_LOCAL_ANDRE_WINE11_DIR}}"
else
  : "${WCP_WINE11_REFLECT_ANDRE_REPO:=https://github.com/AndreRH/wine.git}"
fi

log() { printf '[wine11-reflect] %s\n' "$*" >&2; }
fail() { printf '[wine11-reflect][error] %s\n' "$*" >&2; exit 1; }

require_repo() {
  local repo_dir="$1" label="$2"
  wcp_local_repo_exists "${repo_dir}" || fail "Missing ${label}: ${repo_dir}"
}

emit_ranked_path_table() {
  local repo_dir="$1" range="$2" limit="$3"
  (
    set +o pipefail
    git -C "${repo_dir}" log --format= --name-only "${range}" \
      | sed '/^$/d' \
      | awk -F/ '
        {
          top=$1
          if (top == "") next
          counts[top]++
        }
        END {
          for (k in counts) {
            printf "%7d %s\n", counts[k], k
          }
        }
      ' \
      | sort -nr \
      | head -n "${limit}"
  )
}

emit_ranked_core_file_table() {
  local repo_dir="$1" range="$2" limit="$3"
  (
    set +o pipefail
    git -C "${repo_dir}" log --format= --name-only "${range}" \
      | sed '/^$/d' \
      | awk '
        /^(dlls\/ntdll\/|dlls\/kernelbase\/|dlls\/kernel32\/|dlls\/win32u\/|dlls\/wow64\/|server\/|loader\/|tools\/winebuild\/|programs\/winecfg\/|libs\/wine\/)/ {
          counts[$0]++
        }
        END {
          for (k in counts) {
            printf "%7d %s\n", counts[k], k
          }
        }
      ' \
      | sort -nr \
      | head -n "${limit}"
  )
}

main() {
  local repo_dir andre_ref valve_ref base_commit range_spec start_commit
  local ahead_andre ahead_valve
  local andre_head valve_head
  local andre_objects_dir alt_env

  require_repo "${WCP_LOCAL_ANDRE_WINE11_DIR}" "AndreRH wine11 arm64ec"
  require_repo "${WCP_LOCAL_VALVE_WINE_EXP10_DIR}" "Valve wine experimental_10.0"

  repo_dir="${WCP_LOCAL_VALVE_WINE_EXP10_DIR}"
  git -C "${repo_dir}" fetch --no-tags origin "${WCP_WINE11_REFLECT_VALVE_REF}" >/dev/null 2>&1

  andre_ref="$(git -C "${WCP_LOCAL_ANDRE_WINE11_DIR}" rev-parse "${WCP_WINE11_REFLECT_ANDRE_REF}")"
  valve_ref="origin/${WCP_WINE11_REFLECT_VALVE_REF}"
  andre_head="$(git -C "${WCP_LOCAL_ANDRE_WINE11_DIR}" rev-parse --short=12 "${andre_ref}")"
  valve_head="$(git -C "${repo_dir}" rev-parse --short=12 "${valve_ref}")"
  andre_objects_dir="$(git -C "${WCP_LOCAL_ANDRE_WINE11_DIR}" rev-parse --git-path objects)"
  alt_env="GIT_ALTERNATE_OBJECT_DIRECTORIES=${andre_objects_dir}"

  if [[ "${WCP_WINE11_REFLECT_MODE}" == "full" ]]; then
    base_commit="$(env "${alt_env}" git -C "${repo_dir}" merge-base "${andre_ref}" "${valve_ref}")"
    ahead_andre="$(env "${alt_env}" git -C "${repo_dir}" rev-list --count "${valve_ref}..${andre_ref}")"
    ahead_valve="$(env "${alt_env}" git -C "${repo_dir}" rev-list --count "${andre_ref}..${valve_ref}")"
    range_spec="${base_commit}..${valve_ref}"
  else
    start_commit="$(git -C "${repo_dir}" rev-list --max-count "${WCP_WINE11_REFLECT_WINDOW}" "${valve_ref}" | tail -n 1)"
    if [[ -n "${start_commit}" ]]; then
      range_spec="${start_commit}..${valve_ref}"
    else
      range_spec="${valve_ref}"
    fi
    base_commit="not-computed-fast-mode"
    ahead_andre="not-computed-fast-mode"
    ahead_valve="window:${WCP_WINE11_REFLECT_WINDOW}"
  fi

  mkdir -p "$(dirname "${WCP_WINE11_REFLECT_OUT}")"

  {
    printf '# Wine11 ARM64EC vs Valve experimental_10.0 Reflective Report\n\n'
    printf 'Generated against long-lived local anchors, not disposable temp clones.\n\n'
    printf '## Heads\n\n'
    printf '%s\n' "- AndreRH \`arm64ec\`: \`${andre_head}\`"
    printf '%s\n' "- Valve \`experimental_10.0\`: \`${valve_head}\`"
    printf '%s\n\n' "- merge-base: \`${base_commit}\`"

    printf '## Divergence\n\n'
    printf '%s\n' "- AndreRH-only commits after merge-base: \`${ahead_andre}\`"
    printf '%s\n\n' "- Valve-only commits after merge-base: \`${ahead_valve}\`"

    printf '## Valve Hot Top-Level Paths\n\n'
    printf '```text\n'
    emit_ranked_path_table "${repo_dir}" "${range_spec}" "${WCP_WINE11_REFLECT_LIMIT}"
    printf '```\n\n'

    printf '## Valve Hot Core Files\n\n'
    printf '```text\n'
    emit_ranked_core_file_table "${repo_dir}" "${range_spec}" "${WCP_WINE11_REFLECT_LIMIT}"
    printf '```\n\n'

    printf '## First Safe Transfer Lanes\n\n'
    printf '1. `dlls/ntdll`, `dlls/wow64`, `loader`, `server` - ARM64EC/WoW64 core only.\n'
    printf '2. `libs/wine`, `tools/winebuild` - ABI/build glue that must match the core.\n'
    printf '3. `dlls/kernel32`, `dlls/kernelbase`, `dlls/win32u` - only after core is stable.\n'
    printf '4. Media/input/graphics peripheral layers only after runtime regression gates exist.\n\n'

    printf '## Explicit Non-Goal\n\n'
    printf 'This report is a transfer map, not a claim that every Valve commit can be merged automatically.\n'
    printf 'A safe migration means slicing by ownership and replaying deltas through the existing per-lane patch model.\n'
    if [[ "${WCP_WINE11_REFLECT_MODE}" != "full" ]]; then
      printf 'Fast mode intentionally skips exact cross-repo merge-base calculation and instead ranks the latest `%s` Valve commits.\n' "${WCP_WINE11_REFLECT_WINDOW}"
    fi
  } > "${WCP_WINE11_REFLECT_OUT}"

  log "Report written: ${WCP_WINE11_REFLECT_OUT}"
}

main "$@"
