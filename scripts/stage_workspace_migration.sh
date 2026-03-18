#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_ROOT="/home/mikhail"
GENERATOR="${SCRIPT_DIR}/generate_workspace_handoff.py"

usage() {
  echo "usage: $0 DEST_DIR [--with-auth]" >&2
  exit 1
}

DEST_DIR="${1:-}"
WITH_AUTH=0

if [[ -z "${DEST_DIR}" ]]; then
  usage
fi
shift || true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --with-auth)
      WITH_AUTH=1
      ;;
    *)
      usage
      ;;
  esac
  shift
done

mkdir -p "${DEST_DIR}/home/mikhail"
python3 "${GENERATOR}"

copy_path() {
  local src="$1"
  local parent
  parent="$(dirname "${src}")"
  mkdir -p "${DEST_DIR}${parent}"
  rsync -aHAX --info=progress2 "${src}" "${DEST_DIR}${parent}/"
}

copy_path "${HOME_ROOT}/AGENTS.md"
copy_path "${HOME_ROOT}/WORKSPACE_HANDOFF.md"
copy_path "${HOME_ROOT}/WORKSPACE_HANDOFF.json"
copy_path "${HOME_ROOT}/.codex"
copy_path "${HOME_ROOT}/wcp-sources"

if [[ "${WITH_AUTH}" == "1" ]]; then
  for path in \
    "${HOME_ROOT}/.gitconfig" \
    "${HOME_ROOT}/.ssh" \
    "${HOME_ROOT}/.config/gh" \
    "${HOME_ROOT}/.git-credentials"
  do
    if [[ -e "${path}" ]]; then
      copy_path "${path}"
    fi
  done
fi

echo "staged workspace migration under ${DEST_DIR}/home/mikhail"
