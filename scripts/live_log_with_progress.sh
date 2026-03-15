#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="${1:?log file required}"
BUILD_DIR="${2:?build dir required}"
TOTAL_FILES="${3:?total file count required}"

if [[ ! -f "$LOG_FILE" ]]; then
  echo "log file not found: $LOG_FILE" >&2
  exit 1
fi

if [[ ! -d "$BUILD_DIR" ]]; then
  echo "build dir not found: $BUILD_DIR" >&2
  exit 1
fi

print_status() {
  local count percent now
  count=$(find "$BUILD_DIR" -type f | wc -l)
  percent=$(awk -v count="$count" -v total="$TOTAL_FILES" 'BEGIN { printf "%.1f", (count / total) * 100 }')
  now=$(date '+%H:%M:%S')
  printf '\n[%s] progress %s%% (%s / %s)\n\n' "$now" "$percent" "$count" "$TOTAL_FILES"
}

print_status

(
  while true; do
    sleep 5
    print_status
  done
) &
STATUS_PID=$!

cleanup() {
  kill "$STATUS_PID" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

tail -n 400 -F "$LOG_FILE"
