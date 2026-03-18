#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
VIEWER="${SCRIPT_DIR}/live_log_with_progress_and_time.sh"
GUI_VIEWER="${SCRIPT_DIR}/live_log_gui.py"
ZENITY_VIEWER="${SCRIPT_DIR}/live_log_with_zenity_progress.sh"
LOG_FILE="${1:-${REPO_ROOT}/out/freewine11-local/logs/wine-build.log}"

if [[ ! -x "${VIEWER}" ]]; then
  echo "viewer script not executable: ${VIEWER}" >&2
  exit 1
fi

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=${XDG_RUNTIME_DIR}/bus}"
if [[ -z "${WAYLAND_DISPLAY:-}" ]] && compgen -G "${XDG_RUNTIME_DIR}/wayland-*" >/dev/null; then
  export WAYLAND_DISPLAY="$(basename "$(ls "${XDG_RUNTIME_DIR}"/wayland-* 2>/dev/null | head -n1)")"
fi
if [[ -z "${DISPLAY:-}" && -z "${WAYLAND_DISPLAY:-}" ]]; then
  export DISPLAY=":0"
fi

launch() {
  local terminal="$1"
  shift
  "${terminal}" "$@"
}

if command -v zenity >/dev/null 2>&1 && [[ -x "${ZENITY_VIEWER}" ]]; then
  exec bash -lc "\"${ZENITY_VIEWER}\" \"${LOG_FILE}\" \"${REPO_ROOT}/build-wine\" | zenity --text-info --auto-scroll --font='monospace 9' --title='FreeWine Live Log' --width=1280 --height=760"
fi

if command -v python3 >/dev/null 2>&1 && [[ -f "${GUI_VIEWER}" ]]; then
  if python3 - <<'PY' >/dev/null 2>&1
import PyQt5
PY
  then
    exec python3 "${GUI_VIEWER}" "${LOG_FILE}" "${REPO_ROOT}/build-wine"
  fi
fi

if command -v gnome-terminal >/dev/null 2>&1; then
  launch gnome-terminal \
    --wait \
    --title="FreeWine Live Status" \
    -- \
    bash -lc "exec \"${VIEWER}\" \"${LOG_FILE}\""
  exit 0
fi

if command -v x-terminal-emulator >/dev/null 2>&1; then
  launch x-terminal-emulator \
    -T "FreeWine Live Status" \
    -e bash -lc "exec \"${VIEWER}\" \"${LOG_FILE}\""
  exit 0
fi

if command -v xterm >/dev/null 2>&1; then
  launch xterm \
    -T "FreeWine Live Status" \
    -e bash -lc "exec \"${VIEWER}\" \"${LOG_FILE}\""
  exit 0
fi

echo "no supported terminal emulator found" >&2
exit 1
