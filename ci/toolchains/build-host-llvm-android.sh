#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
LLVM_VERSION="${LLVM_VERSION:-22.1.1}"
ANDROID_API="${ANDROID_API:-24}"
BUILD_ROOT="${LLVM_BUILD_ROOT:-${ROOT_DIR}/out/host-llvm}"
SOURCE_CACHE_DIR="${LLVM_SOURCE_CACHE_DIR:-${ROOT_DIR}/.cache/llvm}"
ANDROID_NDK_ROOT="${ANDROID_NDK_ROOT:?ANDROID_NDK_ROOT is required}"
JOBS="${JOBS:-$(nproc)}"
LINK_JOBS="${LINK_JOBS:-1}"

SRC_ARCHIVE="${SOURCE_CACHE_DIR}/llvm-project-${LLVM_VERSION}.tar.gz"
SRC_DIR="${SOURCE_CACHE_DIR}/llvm-project-${LLVM_VERSION}"
STAGE1_DIR="${BUILD_ROOT}/stage1-host"
STAGE2_DIR="${BUILD_ROOT}/stage2-android-arm64"
PREFIX_PARENT="${BUILD_ROOT}/prefix"
PREFIX_DIR="${PREFIX_PARENT}/llvm-${LLVM_VERSION}-termux"
PACKAGE_DIR="${BUILD_ROOT}/package"
ASSET_BASENAME="llvm-${LLVM_VERSION}-termux-android-aarch64"
ASSET_PATH="${BUILD_ROOT}/${ASSET_BASENAME}.tar.zst"
SHA256_PATH="${BUILD_ROOT}/${ASSET_BASENAME}.sha256"
SOURCE_URL="https://github.com/llvm/llvm-project/archive/refs/tags/llvmorg-${LLVM_VERSION}.tar.gz"

log() { printf '[host-llvm-ci] %s\n' "$*"; }
fail() { printf '[host-llvm-ci][error] %s\n' "$*" >&2; exit 1; }

prepare_dirs() {
  mkdir -p "${SOURCE_CACHE_DIR}" "${BUILD_ROOT}" "${PREFIX_PARENT}" "${PACKAGE_DIR}"
}

fetch_source() {
  if [[ ! -f "${SRC_ARCHIVE}" ]]; then
    log "Downloading llvm-project ${LLVM_VERSION}"
    curl --fail --location --retry 5 --retry-delay 3 --output "${SRC_ARCHIVE}" "${SOURCE_URL}"
  fi

  if [[ ! -d "${SRC_DIR}" ]]; then
    log "Extracting llvm-project ${LLVM_VERSION}"
    tar -C "${SOURCE_CACHE_DIR}" -xf "${SRC_ARCHIVE}"
    mv "${SOURCE_CACHE_DIR}/llvm-project-llvmorg-${LLVM_VERSION}" "${SRC_DIR}"
  fi
}

configure_stage1() {
  rm -rf "${STAGE1_DIR}"
  cmake -S "${SRC_DIR}/llvm" -B "${STAGE1_DIR}" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DLLVM_ENABLE_PROJECTS="clang" \
    -DLLVM_TARGETS_TO_BUILD="AArch64;ARM;X86" \
    -DLLVM_ENABLE_BINDINGS=OFF \
    -DLLVM_ENABLE_TERMINFO=OFF \
    -DLLVM_ENABLE_LIBXML2=OFF \
    -DLLVM_INCLUDE_BENCHMARKS=OFF \
    -DLLVM_INCLUDE_EXAMPLES=OFF \
    -DLLVM_INCLUDE_TESTS=OFF \
    -DCLANG_INCLUDE_TESTS=OFF \
    -DLLVM_BUILD_TOOLS=ON \
    -DLLVM_BUILD_UTILS=ON \
    -DLLVM_USE_LINKER=lld \
    -DLLVM_PARALLEL_LINK_JOBS="${LINK_JOBS}" \
    -DCMAKE_C_COMPILER=clang \
    -DCMAKE_CXX_COMPILER=clang++
}

build_stage1() {
  log "Building stage1 host tblgen tools"
  cmake --build "${STAGE1_DIR}" --target llvm-tblgen clang-tblgen llvm-min-tblgen -- -j"${JOBS}"
}

configure_stage2() {
  rm -rf "${STAGE2_DIR}" "${PREFIX_DIR}"
  cmake -S "${SRC_DIR}/llvm" -B "${STAGE2_DIR}" -G Ninja \
    -DCMAKE_TOOLCHAIN_FILE="${ANDROID_NDK_ROOT}/build/cmake/android.toolchain.cmake" \
    -DANDROID_ABI=arm64-v8a \
    -DANDROID_PLATFORM="android-${ANDROID_API}" \
    -DANDROID_STL=c++_static \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${PREFIX_DIR}" \
    -DLLVM_ENABLE_PROJECTS="clang;lld" \
    -DLLVM_TARGETS_TO_BUILD="AArch64;ARM;X86" \
    -DLLVM_ENABLE_BINDINGS=OFF \
    -DLLVM_ENABLE_TERMINFO=OFF \
    -DLLVM_ENABLE_LIBXML2=OFF \
    -DLLVM_INCLUDE_BENCHMARKS=OFF \
    -DLLVM_INCLUDE_EXAMPLES=OFF \
    -DLLVM_INCLUDE_TESTS=OFF \
    -DCLANG_INCLUDE_TESTS=OFF \
    -DLLVM_BUILD_TOOLS=ON \
    -DLLVM_BUILD_UTILS=ON \
    -DLLVM_USE_LINKER=lld \
    -DLLVM_PARALLEL_LINK_JOBS="${LINK_JOBS}" \
    -DLLVM_TABLEGEN="${STAGE1_DIR}/bin/llvm-tblgen" \
    -DCLANG_TABLEGEN="${STAGE1_DIR}/bin/clang-tblgen" \
    -DLLVM_NATIVE_TOOL_DIR="${STAGE1_DIR}/bin" \
    -DLLVM_DISTRIBUTION_COMPONENTS="clang;clang-resource-headers;lld;llvm-ar;llvm-as;llvm-config;llvm-cxxfilt;llvm-dlltool;llvm-lib;llvm-link;llvm-nm;llvm-objcopy;llvm-objdump;llvm-rc;llvm-ranlib;llvm-readelf;llvm-readobj;llvm-strip;llvm-windres" \
    -DCMAKE_C_COMPILER=clang \
    -DCMAKE_CXX_COMPILER=clang++
}

build_stage2() {
  log "Building stage2 Android ARM64 LLVM distribution"
  cmake --build "${STAGE2_DIR}" --target install-distribution -- -j"${JOBS}"
}

package_output() {
  rm -rf "${PACKAGE_DIR}/${ASSET_BASENAME}"
  mkdir -p "${PACKAGE_DIR}"
  cp -a "${PREFIX_DIR}" "${PACKAGE_DIR}/${ASSET_BASENAME}"
  tar --zstd -cf "${ASSET_PATH}" -C "${PACKAGE_DIR}" "${ASSET_BASENAME}"
  sha256sum "${ASSET_PATH}" > "${SHA256_PATH}"
}

emit_metadata() {
  log "Asset: ${ASSET_PATH}"
  log "SHA256: ${SHA256_PATH}"
  "${PREFIX_DIR}/bin/clang" --version | sed -n '1,4p'
  "${PREFIX_DIR}/bin/llvm-strip" --version | sed -n '1,4p'
}

main() {
  command -v cmake >/dev/null 2>&1 || fail "cmake is required"
  command -v ninja >/dev/null 2>&1 || fail "ninja is required"
  command -v curl >/dev/null 2>&1 || fail "curl is required"
  command -v zstd >/dev/null 2>&1 || fail "zstd is required"

  prepare_dirs
  fetch_source
  configure_stage1
  build_stage1
  configure_stage2
  build_stage2
  package_output
  emit_metadata
}

main "$@"
