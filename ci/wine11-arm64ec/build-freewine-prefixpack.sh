#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

: "${FREEWINE_PREFIXPACK_SRC_URL:=https://raw.githubusercontent.com/GameNative/bionic-prefix-files/main/prefixPack-arm64ec.txz}"
: "${FREEWINE_PREFIXPACK_SRC_FILE:=}"
: "${FREEWINE_PREFIXPACK_WORK_DIR:=${ROOT_DIR}/out/freewine11/prefixpack-work}"
: "${FREEWINE_PREFIXPACK_OUT:=${ROOT_DIR}/prefixPack.txz}"
: "${FREEWINE_PREFIXPACK_FONT_PREFIX_NAME:=freewine11-arm64ec}"
: "${FREEWINE_PREFIXPACK_D_DRIVE:=/storage/emulated/0/Download}"
: "${FREEWINE_PREFIXPACK_E_DRIVE:=/storage/emulated/0}"
: "${FREEWINE_PREFIXPACK_Z_DRIVE:=/data/data/com.termux/files}"
: "${FREEWINE_PREFIXPACK_XZ_OPT:=-1 -T0}"
: "${FREEWINE_PREFIXPACK_KEEP_TEMP:=0}"

log() { printf '[freewine-prefixpack] %s\n' "$*"; }
fail() { printf '[freewine-prefixpack][error] %s\n' "$*" >&2; exit 1; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

require_bool() {
  case "${2}" in
    0|1) ;;
    *) fail "${1} must be 0 or 1 (got: ${2})" ;;
  esac
}

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
    return
  fi
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
    return
  fi
  fail "Neither sha256sum nor shasum is available"
}

download_source_if_needed() {
  local out_file="$1"
  if [[ -n "${FREEWINE_PREFIXPACK_SRC_FILE}" ]]; then
    [[ -f "${FREEWINE_PREFIXPACK_SRC_FILE}" ]] || fail "FREEWINE_PREFIXPACK_SRC_FILE is missing: ${FREEWINE_PREFIXPACK_SRC_FILE}"
    cp -f "${FREEWINE_PREFIXPACK_SRC_FILE}" "${out_file}"
    return
  fi
  require_cmd curl
  curl -fL --retry 5 --retry-delay 2 -o "${out_file}" "${FREEWINE_PREFIXPACK_SRC_URL}" \
    || fail "Failed to download source prefix pack from ${FREEWINE_PREFIXPACK_SRC_URL}"
}

rewrite_drive_links() {
  local root="$1"
  local dosdevices="${root}/.wine/dosdevices"
  mkdir -p "${dosdevices}"
  rm -f "${dosdevices}/c:" "${dosdevices}/d:" "${dosdevices}/e:" "${dosdevices}/z:"
  ln -s "../drive_c" "${dosdevices}/c:"
  ln -s "${FREEWINE_PREFIXPACK_D_DRIVE}" "${dosdevices}/d:"
  ln -s "${FREEWINE_PREFIXPACK_E_DRIVE}" "${dosdevices}/e:"
  ln -s "${FREEWINE_PREFIXPACK_Z_DRIVE}" "${dosdevices}/z:"
}

rewrite_registry_refs() {
  local root="$1"
  local reg
  for reg in "${root}/.wine/user.reg" "${root}/.wine/system.reg" "${root}/.wine/userdef.reg"; do
    [[ -f "${reg}" ]] || continue
    sed -i "s|proton-10-arm64ec|${FREEWINE_PREFIXPACK_FONT_PREFIX_NAME}|g" "${reg}"
  done
}

write_metadata() {
  local root="$1" source_sha="$2"
  cat > "${root}/.wine/.freewine-prefixpack-meta.env" <<EOF
builder=build-freewine-prefixpack.sh
builtAtUtc=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
sourceUrl=${FREEWINE_PREFIXPACK_SRC_URL}
sourceSha256=${source_sha}
fontPrefixName=${FREEWINE_PREFIXPACK_FONT_PREFIX_NAME}
driveD=${FREEWINE_PREFIXPACK_D_DRIVE}
driveE=${FREEWINE_PREFIXPACK_E_DRIVE}
driveZ=${FREEWINE_PREFIXPACK_Z_DRIVE}
EOF
}

main() {
  local source_archive extract_dir source_sha apple_before apple_after out_sha archive_index

  require_bool FREEWINE_PREFIXPACK_KEEP_TEMP "${FREEWINE_PREFIXPACK_KEEP_TEMP}"
  require_cmd tar
  require_cmd find
  require_cmd sed

  rm -rf "${FREEWINE_PREFIXPACK_WORK_DIR}"
  mkdir -p "${FREEWINE_PREFIXPACK_WORK_DIR}"
  source_archive="${FREEWINE_PREFIXPACK_WORK_DIR}/prefixPack-source.txz"
  extract_dir="${FREEWINE_PREFIXPACK_WORK_DIR}/extract"

  log "Preparing source archive"
  download_source_if_needed "${source_archive}"
  source_sha="$(sha256_file "${source_archive}")"
  log "Source sha256=${source_sha}"

  mkdir -p "${extract_dir}"
  tar -xJf "${source_archive}" -C "${extract_dir}" || fail "Failed to extract source prefix pack"
  [[ -d "${extract_dir}/.wine" ]] || fail "Source prefix pack is invalid: missing .wine root"

  apple_before="$(find "${extract_dir}" -name '._*' | wc -l | tr -d ' ')"
  find "${extract_dir}" -name '._*' -delete
  apple_after="$(find "${extract_dir}" -name '._*' | wc -l | tr -d ' ')"
  log "Removed AppleDouble sidecars: ${apple_before} -> ${apple_after}"

  rewrite_drive_links "${extract_dir}"
  rewrite_registry_refs "${extract_dir}"
  write_metadata "${extract_dir}" "${source_sha}"

  mkdir -p "$(dirname -- "${FREEWINE_PREFIXPACK_OUT}")"
  XZ_OPT="${FREEWINE_PREFIXPACK_XZ_OPT}" tar -cJf "${FREEWINE_PREFIXPACK_OUT}" -C "${extract_dir}" .wine \
    || fail "Failed to repack FreeWine prefix pack"
  archive_index="$(tar -tf "${FREEWINE_PREFIXPACK_OUT}")"
  printf '%s\n' "${archive_index}" | grep -Eq '(^|[.]/)\.wine/user.reg$' \
    || fail "Packed prefix missing .wine/user.reg"
  printf '%s\n' "${archive_index}" | grep -Eq '(^|[.]/)\.wine/system.reg$' \
    || fail "Packed prefix missing .wine/system.reg"
  printf '%s\n' "${archive_index}" | grep -Eq '(^|[.]/)\.wine/userdef.reg$' \
    || fail "Packed prefix missing .wine/userdef.reg"

  out_sha="$(sha256_file "${FREEWINE_PREFIXPACK_OUT}")"
  log "Built FreeWine prefix pack: ${FREEWINE_PREFIXPACK_OUT}"
  log "Output sha256=${out_sha}"
  ls -lh "${FREEWINE_PREFIXPACK_OUT}"

  if [[ "${FREEWINE_PREFIXPACK_KEEP_TEMP}" != "1" ]]; then
    rm -rf "${FREEWINE_PREFIXPACK_WORK_DIR}"
  fi
}

main "$@"
