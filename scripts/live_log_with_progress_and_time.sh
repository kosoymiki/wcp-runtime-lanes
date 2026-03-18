#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEFAULT_LOG_FILE="$REPO_ROOT/out/freewine11-local/logs/wine-build.log"
LOG_FILE="${1:-$DEFAULT_LOG_FILE}"

BUILD_DIR="$REPO_ROOT/build-wine"
TOTAL_FILES="16057"
OMEGA_REPORT="${OMEGA_REPORT:-/home/mikhail/wcp-sources/freewine11/.freewine11/ARM64_OMEGA_CLOSURE_REPORT.md}"

if [[ $# -ge 2 ]]; then
  if [[ "$2" =~ ^[0-9]+$ ]]; then
    TOTAL_FILES="$2"
  else
    BUILD_DIR="$2"
  fi
fi

if [[ $# -ge 3 ]]; then
  TOTAL_FILES="$3"
fi

mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

if [[ ! -d "$BUILD_DIR" ]]; then
  echo "build dir not found: $BUILD_DIR" >&2
  exit 1
fi

export PATH="$REPO_ROOT/.cache/llvm-mingw/bin:$PATH"
export PKG_CONFIG_PATH="$REPO_ROOT/.localdeps/libusb/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig:/usr/share/pkgconfig:/usr/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
export PKG_CONFIG_LIBDIR="$REPO_ROOT/.localdeps/libusb/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig:/usr/share/pkgconfig:/usr/lib/pkgconfig:${PKG_CONFIG_LIBDIR:-}"
export CPPFLAGS="-I$REPO_ROOT/.localdeps/libusb/root/usr/include/libusb-1.0 ${CPPFLAGS:-}"
export LDFLAGS="-L$REPO_ROOT/.localdeps/libusb/root/usr/lib/x86_64-linux-gnu ${LDFLAGS:-}"

PROGRESS_CACHE="${TMPDIR:-/tmp}/freewine-live-progress.cache"
STATUS_ROWS=4
TAIL_PID=""

compute_fundamental_status() {
  local processed total percent overlap duplicates
  if [[ -f "$OMEGA_REPORT" ]]; then
    read -r processed total < <(
      python3 - "$OMEGA_REPORT" <<'PY'
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
      python3 - "$OMEGA_REPORT" <<'PY'
import re
import sys

text = open(sys.argv[1], 'r', encoding='utf-8', errors='replace').read()
match = re.search(r"Recursive overlap status:\s*`([^`]+)`", text)
print(match.group(1) if match else "unknown")
PY
    )
    duplicates=$(
      python3 - "$OMEGA_REPORT" <<'PY'
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

  percent=$(awk -v processed="$processed" -v total="$total" 'BEGIN {
    if (total <= 0) {
      printf "0.0";
      exit;
    }
    value = (processed / total) * 100;
    if (value < 0) value = 0;
    if (value > 100) value = 100;
    printf "%.1f", value;
  }')

  printf '%s %s %s %s\n' "$processed" "$total" "$percent" "$overlap/$duplicates"
}

cleanup() {
  if [[ -n "${TAIL_PID:-}" ]]; then
    kill "$TAIL_PID" 2>/dev/null || true
  fi
  printf '\033[r\033[?25h'
}

trap cleanup EXIT INT TERM

compute_progress() {
  local remaining percent
  remaining=$(
    cd "$BUILD_DIR" && make -n all 2>/dev/null | \
      grep -E '(^| )(gcc|clang|tools/winegcc|tools/widl|tools/wrc|tools/winebuild) ' | \
      wc -l
  )
  percent=$(awk -v remaining="$remaining" -v total="$TOTAL_FILES" 'BEGIN {
    value = ((total - remaining) / total) * 100;
    if (value < 0) value = 0;
    if (value > 100) value = 100;
    printf "%.1f", value;
  }')
  printf '%s %s\n' "$remaining" "$percent" > "$PROGRESS_CACHE"
}

print_status() {
  local remaining percent now make_pid elapsed fundamental_processed fundamental_total fundamental_percent fundamental_meta
  if [[ -f "$PROGRESS_CACHE" ]]; then
    read -r remaining percent < "$PROGRESS_CACHE"
  else
    remaining="$TOTAL_FILES"
    percent="0.0"
  fi
  read -r fundamental_processed fundamental_total fundamental_percent fundamental_meta < <(compute_fundamental_status)
  now=$(date '+%Y-%m-%d %H:%M:%S %Z')
  make_pid=$(pgrep -f "make -j[0-9]+ all" | head -n1 || true)
  if [[ -n "$make_pid" ]]; then
    elapsed=$(ps -o etime= -p "$make_pid" | awk '{print $1}')
  else
    elapsed="n/a"
  fi
  printf '[%s] build %s%% (remaining %s / baseline %s) | fundamental %s%% (omega %s/%s, overlap/dup %s) | elapsed %s' \
    "$now" "$percent" "$remaining" "$TOTAL_FILES" "$fundamental_percent" \
    "$fundamental_processed" "$fundamental_total" "$fundamental_meta" "$elapsed"
}

render_header() {
  printf '\033[s'
  printf '\033[H'
  printf '\033[2K'
  printf 'FreeWine Live Status\n'
  printf '\033[2K'
  print_status
  printf '\n'
  printf '\033[2K'
  printf 'log: %s\n' "$LOG_FILE"
  printf '\033[2K'
  printf 'build: %s\n' "$BUILD_DIR"
  printf '\033[u'
}

rows=$(tput lines 2>/dev/null || echo 40)
if (( rows <= STATUS_ROWS + 2 )); then
  rows=40
fi
tail_lines=$((rows - STATUS_ROWS - 1))

printf '\033[2J\033[H\033[?25l'
printf '\033[%d;%dr' "$((STATUS_ROWS + 1))" "$rows"

compute_progress
render_header

printf '\033[%d;1H' "$((STATUS_ROWS + 1))"
tail -n "$tail_lines" -F --retry "$LOG_FILE" &
TAIL_PID=$!

while true; do
  compute_progress
  render_header
  sleep 5
done
