#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DEFAULT_LOG_FILE="${REPO_ROOT}/out/freewine11-local/logs/wine-build.log"
LOG_FILE="${1:-${DEFAULT_LOG_FILE}}"
BUILD_DIR="${2:-${REPO_ROOT}/build-wine}"
TOTAL_FILES="${3:-16057}"
OMEGA_REPORT="${OMEGA_REPORT:-/home/mikhail/wcp-sources/freewine11/.freewine11/ARM64_OMEGA_CLOSURE_REPORT.md}"

if [[ ! -d "${BUILD_DIR}" ]]; then
  echo "build dir not found: ${BUILD_DIR}" >&2
  exit 1
fi

mkdir -p "$(dirname "${LOG_FILE}")"
touch "${LOG_FILE}"

compute_build_progress() {
  local remaining percent
  remaining=$(
    cd "${BUILD_DIR}" && make -n all 2>/dev/null | \
      grep -E '(^| )(gcc|clang|tools/winegcc|tools/widl|tools/wrc|tools/winebuild) ' | \
      wc -l
  )
  percent=$(awk -v remaining="${remaining}" -v total="${TOTAL_FILES}" 'BEGIN {
    value = ((total - remaining) / total) * 100;
    if (value < 0) value = 0;
    if (value > 100) value = 100;
    printf "%.1f", value;
  }')
  printf '%s %s\n' "${remaining}" "${percent}"
}

compute_fundamental_status() {
  local processed total percent overlap duplicates
  if [[ -f "${OMEGA_REPORT}" ]]; then
    read -r processed total < <(
      python3 - "${OMEGA_REPORT}" <<'PY'
import re
import sys

text = open(sys.argv[1], 'r', encoding='utf-8', errors='replace').read()
match = re.search(r"Processed modules:\s*`(\d+)`\s*/\s*`(\d+)`", text)
if match:
    print(match.group(1), match.group(2))
else:
    print("0 0")
PY
    )
    overlap=$(
      python3 - "${OMEGA_REPORT}" <<'PY'
import re
import sys

text = open(sys.argv[1], 'r', encoding='utf-8', errors='replace').read()
match = re.search(r"Recursive overlap status:\s*`([^`]+)`", text)
print(match.group(1) if match else "unknown")
PY
    )
    duplicates=$(
      python3 - "${OMEGA_REPORT}" <<'PY'
import re
import sys

text = open(sys.argv[1], 'r', encoding='utf-8', errors='replace').read()
match = re.search(r"Live duplicate symbols:\s*`(\d+)`", text)
print(match.group(1) if match else "n/a")
PY
    )
  else
    processed="0"
    total="0"
    overlap="missing"
    duplicates="n/a"
  fi

  percent=$(awk -v processed="${processed}" -v total="${total}" 'BEGIN {
    if (total <= 0) {
      printf "0.0";
      exit;
    }
    value = (processed / total) * 100;
    if (value < 0) value = 0;
    if (value > 100) value = 100;
    printf "%.1f", value;
  }')

  printf '%s %s %s %s %s\n' "${processed}" "${total}" "${percent}" "${overlap}" "${duplicates}"
}

emit_status() {
  local remaining build_percent processed total fundamental_percent overlap duplicates now elapsed make_pid
  read -r remaining build_percent < <(compute_build_progress)
  read -r processed total fundamental_percent overlap duplicates < <(compute_fundamental_status)
  now=$(date '+%Y-%m-%d %H:%M:%S %Z')
  make_pid=$(pgrep -f "make -j[0-9]+ all" | head -n1 || true)
  if [[ -n "${make_pid}" ]]; then
    elapsed=$(ps -o etime= -p "${make_pid}" | awk '{print $1}')
  else
    elapsed="n/a"
  fi
  printf '=== [%s] build %s%% (remaining %s / baseline %s) | fundamental %s%% (omega %s/%s, overlap %s, dup %s) | elapsed %s ===\n' \
    "${now}" "${build_percent}" "${remaining}" "${TOTAL_FILES}" "${fundamental_percent}" \
    "${processed}" "${total}" "${overlap}" "${duplicates}" "${elapsed}"
}

status_loop() {
  while true; do
    emit_status
    sleep 5
  done
}

cleanup() {
  if [[ -n "${STATUS_PID:-}" ]]; then
    kill "${STATUS_PID}" 2>/dev/null || true
  fi
  if [[ -n "${TAIL_PID:-}" ]]; then
    kill "${TAIL_PID}" 2>/dev/null || true
  fi
}

trap cleanup EXIT INT TERM

printf 'FreeWine Live Log\n'
printf 'log: %s\n' "${LOG_FILE}"
printf 'build: %s\n' "${BUILD_DIR}"
printf 'omega: %s\n' "${OMEGA_REPORT}"
printf '\n'

emit_status
status_loop &
STATUS_PID=$!

tail -n 160 -F --retry "${LOG_FILE}" &
TAIL_PID=$!

wait -n "${STATUS_PID}" "${TAIL_PID}"
