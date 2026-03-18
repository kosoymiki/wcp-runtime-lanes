#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SOURCE_ROOT="/home/mikhail/wcp-sources/freewine11"
BUILD_DIR="${REPO_ROOT}/build-wine"
MIRROR_ROOT="${REPO_ROOT}/wine-src"
LOG_DIR="${REPO_ROOT}/out/freewine11-local/logs"
LOG_FILE="${LOG_DIR}/wine-build.log"
STAMP="$(date +%s)"

mkdir -p "${LOG_DIR}"

export PATH="${REPO_ROOT}/.cache/llvm-mingw/bin:${PATH}"
export PKG_CONFIG_PATH="${REPO_ROOT}/.localdeps/libusb/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig:/usr/share/pkgconfig:/usr/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
export PKG_CONFIG_LIBDIR="${REPO_ROOT}/.localdeps/libusb/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig:/usr/share/pkgconfig:/usr/lib/pkgconfig:${PKG_CONFIG_LIBDIR:-}"
export CPPFLAGS="-I${REPO_ROOT}/.localdeps/libusb/root/usr/include/libusb-1.0 ${CPPFLAGS:-}"
export LDFLAGS="-L${REPO_ROOT}/.localdeps/libusb/root/usr/lib/x86_64-linux-gnu ${LDFLAGS:-}"

backup_path() {
  local path="$1"
  if [[ -e "${path}" ]]; then
    mv "${path}" "${path}.prev.${STAMP}"
  fi
}

sync_fresh_runtime_mirror() {
  mkdir -p "${MIRROR_ROOT}"
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete \
      --exclude='.git' \
      --exclude='.freewine11' \
      --exclude='AGENTS.md' \
      --exclude='README.md' \
      "${SOURCE_ROOT}/" "${MIRROR_ROOT}/"
    return
  fi

  (
    cd "${SOURCE_ROOT}"
    tar \
      --exclude='.git' \
      --exclude='.freewine11' \
      --exclude='AGENTS.md' \
      --exclude='README.md' \
      -cf - .
  ) | (
    cd "${MIRROR_ROOT}"
    tar -xf -
  )
}

CONFIGURE_ARGS=(
  --prefix=/usr
  --disable-tests
  --with-mingw=clang
  --enable-archs=arm64ec,aarch64,i386
  --with-usb
)

printf '[local] FRESH rebuild from zero (%s)\n' "${STAMP}" | tee -a "${LOG_FILE}"
backup_path "${BUILD_DIR}"
backup_path "${MIRROR_ROOT}"
sync_fresh_runtime_mirror
mkdir -p "${BUILD_DIR}"

cd "${BUILD_DIR}"
printf '[local] CONFIGURE %s\n' "${MIRROR_ROOT}/configure ${CONFIGURE_ARGS[*]}" | tee -a "${LOG_FILE}"
"${MIRROR_ROOT}/configure" "${CONFIGURE_ARGS[@]}" 2>&1 | tee -a "${LOG_FILE}"
echo "[local] FRESH make -j2 all with llvm-mingw PATH" | tee -a "${LOG_FILE}"
make -j2 all 2>&1 | tee -a "${LOG_FILE}"
