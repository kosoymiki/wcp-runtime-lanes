#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${REPO_ROOT}/build-wine"
LOG_DIR="${REPO_ROOT}/out/freewine11-local/logs"
LOG_FILE="${LOG_DIR}/wine-build.log"

mkdir -p "${LOG_DIR}"

if [[ ! -d "${BUILD_DIR}" ]]; then
  echo "build dir not found: ${BUILD_DIR}" >&2
  exit 1
fi

export PATH="${REPO_ROOT}/.cache/llvm-mingw/bin:${PATH}"
export PKG_CONFIG_PATH="${REPO_ROOT}/.localdeps/libusb/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig:/usr/share/pkgconfig:/usr/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
export PKG_CONFIG_LIBDIR="${REPO_ROOT}/.localdeps/libusb/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig:/usr/share/pkgconfig:/usr/lib/pkgconfig:${PKG_CONFIG_LIBDIR:-}"
export CPPFLAGS="-I${REPO_ROOT}/.localdeps/libusb/root/usr/include/libusb-1.0 ${CPPFLAGS:-}"
export LDFLAGS="-L${REPO_ROOT}/.localdeps/libusb/root/usr/lib/x86_64-linux-gnu ${LDFLAGS:-}"

declare -a SYNCED_RUNTIME_FILES=()

sync_modified_runtime_sources() {
  local source_root="/home/mikhail/wcp-sources/freewine11"
  local mirror_root="${REPO_ROOT}/wine-src"
  local rel src dst
  local synced=()
  local prune_name prune_src prune_dst

  while IFS= read -r -d '' rel; do
    [[ -n "${rel}" ]] || continue
    case "${rel}" in
      AGENTS.md|README.md|.freewine11/*)
        continue
        ;;
      *~|*.orig|*.rej)
        continue
        ;;
    esac

    src="${source_root}/${rel}"
    dst="${mirror_root}/${rel}"

    if [[ ! -f "${src}" ]]; then
      if [[ -e "${dst}" ]]; then
        rm -f "${dst}"
        synced+=("${rel}")
        SYNCED_RUNTIME_FILES+=("${rel}")
      fi
      continue
    fi

    if [[ -f "${dst}" ]] && cmp -s "${src}" "${dst}"; then
      continue
    fi

    mkdir -p "$(dirname "${dst}")"
    cp -p "${src}" "${dst}"
    synced+=("${rel}")
    SYNCED_RUNTIME_FILES+=("${rel}")
  done < <(
    {
      git -C "${source_root}" diff --name-only -z HEAD --
      git -C "${source_root}" ls-files --others --exclude-standard -z
    } | awk -v RS='\0' '!seen[$0]++ { printf "%s%c", $0, 0 }'
  )

  for prune_dst in "${mirror_root}"/libs/winecrt0/arm64_private_*; do
    [[ -e "${prune_dst}" ]] || continue
    prune_name="$(basename "${prune_dst}")"
    prune_src="${source_root}/libs/winecrt0/${prune_name}"
    if [[ -e "${prune_src}" ]]; then
      continue
    fi
    rm -f "${prune_dst}"
    rel="libs/winecrt0/${prune_name}"
    synced+=("${rel}")
    SYNCED_RUNTIME_FILES+=("${rel}")
  done

  if ((${#synced[@]} == 0)); then
    return
  fi

  printf '[local] sync runtime source drift (%s)\n' "${#synced[@]}" | tee -a "${LOG_FILE}"
}

invalidate_stale_arm64_shim_outputs() {
  local mirror_root="${REPO_ROOT}/wine-src"
  local rel mod arch archdir
  local stale_entries=()
  declare -A touched_modules=()
  declare -A touched_i386_modules=()
  local invalidate_all_arm64_consumers=0

  add_all_arm64_consumers() {
    local root relpath
    for root in dlls libs; do
      if [[ ! -d "${mirror_root}/${root}" ]]; then
        continue
      fi
      while IFS= read -r -d '' relpath; do
        [[ -n "${relpath}" ]] || continue
        touched_modules["${relpath%/arm64_import_shims.c}"]=1
      done < <(cd "${mirror_root}" && find "${root}" -name arm64_import_shims.c -print0)
    done
  }

  for rel in "${SYNCED_RUNTIME_FILES[@]}"; do
    case "${rel}" in
      dlls/*/arm64_import_shims.c)
        mod="${rel%/arm64_import_shims.c}"
        touched_modules["${mod}"]=1
        ;;
      libs/*/arm64_import_shims.c)
        mod="${rel%/arm64_import_shims.c}"
        touched_modules["${mod}"]=1
        ;;
      dlls/*/Makefile.in|dlls/*/*.spec)
        mod="${rel%/*}"
        if [[ -f "${mirror_root}/${mod}/arm64_import_shims.c" ]]; then
          touched_modules["${mod}"]=1
        fi
        ;;
      libs/*/Makefile.in|libs/*/*.spec)
        mod="${rel%/*}"
        if [[ -f "${mirror_root}/${mod}/arm64_import_shims.c" ]]; then
          touched_modules["${mod}"]=1
        fi
        ;;
      libs/winecrt0/arm64_private_*_imports.c|libs/winecrt0/arm64_import_shims.c)
        touched_modules["libs/winecrt0"]=1
        touched_i386_modules["libs/winecrt0"]=1
        ;;
      libs/winecrt0/Makefile.in)
        touched_modules["libs/winecrt0"]=1
        touched_i386_modules["libs/winecrt0"]=1
        ;;
      include/wine/arm64_*_import_shims.inc)
        invalidate_all_arm64_consumers=1
        ;;
    esac
  done

  if ((invalidate_all_arm64_consumers)); then
    add_all_arm64_consumers
  fi

  if ((${#touched_modules[@]} == 0)); then
    return
  fi

  while IFS= read -r rel; do
    for arch in aarch64-windows arm64ec-windows; do
      archdir="${BUILD_DIR}/${rel}/${arch}"
      if [[ -d "${archdir}" ]]; then
        stale_entries+=("${rel}:${arch}")
      fi
    done
    if [[ -n "${touched_i386_modules[${rel}]:-}" ]]; then
      archdir="${BUILD_DIR}/${rel}/i386-windows"
      if [[ -d "${archdir}" ]]; then
        stale_entries+=("${rel}:i386-windows")
      fi
    fi
  done < <(printf '%s\n' "${!touched_modules[@]}" | sort)

  if ((${#stale_entries[@]} == 0)); then
    return
  fi

  printf '[local] invalidate stale arm64 shim outputs (%s)\n' "${#stale_entries[@]}" | tee -a "${LOG_FILE}"
  for entry in "${stale_entries[@]}"; do
    rel="${entry%%:*}"
    arch="${entry##*:}"
    archdir="${BUILD_DIR}/${rel}/${arch}"
    printf '[local] invalidate %s %s\n' "${rel}" "${arch}" | tee -a "${LOG_FILE}"
    rm -f "${archdir}/arm64_import_shims.o" "${archdir}"/*.dll "${archdir}"/lib*.a
  done
}

cd "${BUILD_DIR}"
sync_modified_runtime_sources
invalidate_stale_arm64_shim_outputs
echo "[local] RESUME make -j2 all with llvm-mingw PATH" | tee -a "${LOG_FILE}"
make -j2 all 2>&1 | tee -a "${LOG_FILE}"
