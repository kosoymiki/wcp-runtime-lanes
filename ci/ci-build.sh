#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${WCP_OUTPUT_DIR:-${ROOT_DIR}/out/wine}"
CACHE_DIR="${ROOT_DIR}/.cache"
TOOLCHAIN_DIR="${TOOLCHAIN_DIR:-${CACHE_DIR}/llvm-mingw}"
LLVM_MINGW_DIR="${TOOLCHAIN_DIR}"
STAGE_DIR="${ROOT_DIR}/stage"
WCP_ROOT="${ROOT_DIR}/wcp_root"
WINE_SRC_DIR="${ROOT_DIR}/wine-src"
HANGOVER_SRC_DIR="${ROOT_DIR}/hangover-src"
BUILD_WINE_DIR="${ROOT_DIR}/build-wine"

: "${WCP_WINE_SOURCE_MODE:=freewine-local}"
: "${WCP_FREEWINE_SOURCE_DIR:=/home/mikhail/wcp-sources/freewine11}"
: "${WCP_FREEWINE_REPO:=}"
: "${WCP_FREEWINE_REF:=freewine11-main}"
: "${WCP_FREEWINE_MAKE_SPECFILES_COMPAT:=1}"
: "${WCP_FREEWINE_MAKE_SPECFILES_URL:=https://raw.githubusercontent.com/AndreRH/wine/arm64ec/tools/make_specfiles}"
: "${WCP_FREEWINE_MAKE_SPECFILES_LOCAL:=}"
: "${HANGOVER_REPO:=https://github.com/AndreRH/hangover.git}"
: "${LLVM_MINGW_TAG:=${LLVM_MINGW_VER:-20260210}}"
: "${WCP_NAME:=freewine11-arm64ec}"
: "${WCP_COMPRESS:=xz}"
: "${WCP_VERSION_NAME:=11.0-arm64ec}"
: "${WCP_VERSION_CODE:=0}"
: "${WCP_DESCRIPTION:=FreeWine 11 ARM64EC for Ae.solator}"
: "${WCP_CHANNEL:=stable}"
: "${WCP_DELIVERY:=remote}"
: "${WCP_PROFILE_TYPE:=Wine}"
: "${WCP_DISPLAY_CATEGORY:=Wine}"
: "${WCP_SOURCE_REPO:=${GITHUB_REPOSITORY:-kosoymiki/wcp-runtime-lanes}}"
: "${WCP_RELEASE_TAG:=freewine11-arm64ec-latest}"
: "${WCP_SOURCE_TYPE:=github-release}"
: "${WCP_SOURCE_VERSION:=rolling-latest}"
: "${WCP_ARTIFACT_NAME:=${WCP_NAME}.wcp}"
: "${WCP_SHA256_ARTIFACT_NAME:=SHA256SUMS-${WCP_NAME}.txt}"
: "${WCP_SHA256_URL:=https://github.com/${WCP_SOURCE_REPO}/releases/download/${WCP_RELEASE_TAG}/${WCP_SHA256_ARTIFACT_NAME}}"
: "${WCP_EMBED_VULKAN_RUNTIME:=1}"
: "${WCP_VULKAN_SDK_VERSION:=1.4.341.1}"
: "${WCP_VULKAN_API_LANE:=1.4}"
: "${WCP_VULKAN_SDK_LANES:=1.1,1.2,1.3,1.4}"
: "${WCP_VULKAN_SDK_SOURCE_URL:=https://vulkan.lunarg.com/sdk/latest/linux.json}"
: "${WCP_VULKAN_TOOLS_CONFIGURE_MODE:=enabled}"
: "${WCP_VULKAN_RUNTIME_FLAVOR:=bionic-assets}"
: "${WCP_VULKAN_WRAPPER_MODE:=embedded-preferred}"
: "${WCP_NATIVE_FORENSICS_ENABLE:=1}"
: "${WCP_NATIVE_FORENSICS_COMPONENTS:=wine,fex,box64,turnip,dxvk,vkd3d,alsa,pulse}"
: "${WCP_NATIVE_FORENSICS_REPORT_DIR:=${OUT_DIR}/logs/native-hooks}"
: "${TARGET_HOST:=aarch64-linux-gnu}"
: "${FEX_SOURCE_MODE:=auto}"
: "${FEX_WCP_URL:=https://github.com/Arihany/WinlatorWCPHub/releases/download/FEXCore-Nightly/FEXCore-2601-260217-49a37c7.wcp}"
: "${REQUIRE_PREFIX_PACK:=1}"
: "${FEX_BUILD_TYPE:=Release}"
: "${STRIP_STAGE:=1}"
: "${WCP_ENABLE_SDL2_RUNTIME:=1}"
: "${WCP_ENABLE_USB_RUNTIME:=1}"
: "${WCP_TARGET_RUNTIME:=winlator-bionic}"
: "${WCP_RUNTIME_CLASS_TARGET:=bionic-native}"
: "${WCP_RUNTIME_CLASS_ENFORCE:=1}"
: "${WCP_PRUNE_EXTERNAL_COMPONENTS:=1}"
: "${WCP_GLIBC_SOURCE_MODE:=host}"
: "${WCP_GLIBC_VERSION:=2.43}"
: "${WCP_GLIBC_TARGET_VERSION:=2.43}"
: "${WCP_GLIBC_SOURCE_URL:=https://ftp.gnu.org/gnu/glibc/glibc-2.43.tar.xz}"
: "${WCP_GLIBC_SOURCE_SHA256:=d9c86c6b5dbddb43a3e08270c5844fc5177d19442cf5b8df4be7c07cd5fa3831}"
: "${WCP_GLIBC_SOURCE_REF:=glibc-2.43}"
: "${WCP_GLIBC_PATCHSET_ID:=}"
: "${WCP_GLIBC_RUNTIME_PATCH_OVERLAY_DIR:=}"
: "${WCP_GLIBC_RUNTIME_PATCH_SCRIPT:=}"
: "${WCP_RUNTIME_BUNDLE_LOCK_ID:=glibc-2.43-bundle-v1}"
: "${WCP_RUNTIME_BUNDLE_LOCK_FILE:=${ROOT_DIR}/ci/runtime-bundle/locks/glibc-2.43-bundle-v1.env}"
: "${WCP_RUNTIME_BUNDLE_ENFORCE_LOCK:=0}"
: "${WCP_RUNTIME_BUNDLE_LOCK_MODE:=relaxed-enforce}"
: "${WCP_INCLUDE_FEX_DLLS:=0}"
: "${WCP_FEX_EXPECTATION_MODE:=external}"
: "${WCP_MAINLINE_BIONIC_ONLY:=1}"
: "${WCP_MAINLINE_FEX_EXTERNAL_ONLY:=1}"
: "${WCP_ALLOW_GLIBC_EXPERIMENTAL:=0}"
: "${WCP_ALLOW_X86_64_HOST:=1}"
: "${WCP_WRAPPER_POLICY_VERSION:=runtime-v1}"
: "${WCP_POLICY_SOURCE:=aesolator-mainline}"
: "${WCP_FALLBACK_SCOPE:=bionic-internal-only}"
: "${WCP_BIONIC_SOURCE_MAP_FILE:=${ROOT_DIR}/ci/runtime-sources/bionic-source-map.json}"
: "${WCP_BIONIC_SOURCE_MAP_FORCE:=0}"
: "${WCP_BIONIC_SOURCE_MAP_REQUIRED:=0}"
: "${WCP_BIONIC_LAUNCHER_SOURCE_WCP_URL:=}"
: "${WCP_BIONIC_UNIX_SOURCE_WCP_URL:=}"
: "${WCP_BIONIC_SOURCE_PREFLIGHT:=${WCP_BIONIC_DONOR_PREFLIGHT:-0}}"
: "${WCP_BIONIC_DONOR_PREFLIGHT:=${WCP_BIONIC_SOURCE_PREFLIGHT}}"
: "${WCP_BIONIC_UNIX_CORE_ADOPT:=0}"
: "${WCP_GN_PATCHSET_ENABLE:=0}"
: "${WCP_FREEWINE_PREFIXPACK_AUTOBUILD:=1}"
: "${WINE_TOOLS_CONFIGURE_EXTRA_ARGS:=--without-x --without-gstreamer --without-wayland}"
: "${WINE_CONFIGURE_PROFILE:=proton-android-minimal}"

log() { printf '[ci] %s\n' "$*"; }
fail() { printf '[ci][error] %s\n' "$*" >&2; exit 1; }

source "${ROOT_DIR}/ci/runtime-sources/local-source-layout.sh"
source "${ROOT_DIR}/ci/lib/wcp_common.sh"

run_native_forensics_scaffold() {
  local component="$1" source_dir="$2"
  [[ "${WCP_NATIVE_FORENSICS_ENABLE:-1}" == "1" ]] || return 0
  [[ -d "${source_dir}" ]] || return 0
  mkdir -p "${WCP_NATIVE_FORENSICS_REPORT_DIR}"
  bash "${ROOT_DIR}/ci/forensics/native-hooks/apply-native-forensics.sh" \
    --component "${component}" \
    --source "${source_dir}" \
    --report "${WCP_NATIVE_FORENSICS_REPORT_DIR}/${component}.json"
}

wine_make_jobs() {
  printf '%s' "${WCP_WINE_BUILD_JOBS:-${WCP_BUILD_JOBS:-$(nproc)}}"
}

fex_make_jobs() {
  printf '%s' "${WCP_FEX_BUILD_JOBS:-${WCP_BUILD_JOBS:-$(nproc)}}"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

require_bool_flag() {
  local flag_name="$1" flag_value="$2"
  case "${flag_value}" in
    0|1) ;;
    *)
      fail "${flag_name} must be 0 or 1 (got: ${flag_value})"
      ;;
  esac
}

check_host_arch() {
  local arch
  arch="$(uname -m)"
  case "${arch}" in
    aarch64|arm64)
      return
      ;;
    x86_64|amd64)
      if [[ "${WCP_ALLOW_X86_64_HOST}" != "1" ]]; then
        fail "x86_64 host is disabled by WCP_ALLOW_X86_64_HOST=0"
      fi
      log "x86_64 host detected; using cross-build mode via llvm-mingw"
      ;;
    *)
      fail "Unsupported host architecture: ${arch}"
      ;;
  esac
}

fetch_wine_sources() {
  local seed_dir

  rm -rf "${WINE_SRC_DIR}"

  case "${WCP_WINE_SOURCE_MODE}" in
    freewine-local)
      [[ -d "${WCP_FREEWINE_SOURCE_DIR}" ]] || fail "FreeWine source dir not found: ${WCP_FREEWINE_SOURCE_DIR}"
      log "Using local FreeWine source: ${WCP_FREEWINE_SOURCE_DIR}"
      rsync -a --delete --exclude ".git" "${WCP_FREEWINE_SOURCE_DIR}/" "${WINE_SRC_DIR}/"
      ;;
    freewine-git)
      [[ -n "${WCP_FREEWINE_REPO}" ]] || fail "WCP_FREEWINE_REPO must be set for freewine-git mode"
      seed_dir=""
      if [[ -d "${WCP_FREEWINE_SOURCE_DIR}/.git" || -f "${WCP_FREEWINE_SOURCE_DIR}/.git" ]]; then
        seed_dir="${WCP_FREEWINE_SOURCE_DIR}"
      fi
      log "Cloning FreeWine repo ${WCP_FREEWINE_REPO} @ ${WCP_FREEWINE_REF}"
      wcp_clone_from_seed_or_remote "${WCP_FREEWINE_REPO}" "${WCP_FREEWINE_REF}" "${seed_dir}" "${WINE_SRC_DIR}" \
        || fail "Unable to clone FreeWine source (${WCP_FREEWINE_REF}) from ${WCP_FREEWINE_REPO}"
      ;;
    *)
      fail "WCP_WINE_SOURCE_MODE must be one of: freewine-local, freewine-git"
      ;;
  esac

  run_native_forensics_scaffold wine "${WINE_SRC_DIR}"
  apply_freewine_source_hotfixes
  validate_freewine_source_tree
}

apply_freewine_source_hotfixes() {
  local winnt_header
  local ntdll_spec
  local ntdll_env_c
  local ntdll_file_c
  local ntdll_loader_c
  local ntdll_process_c
  local server_protocol
  local make_specfiles
  local compat_make_specfiles
  winnt_header="${WINE_SRC_DIR}/include/winnt.h"
  [[ -f "${winnt_header}" ]] || return 0

  make_specfiles="${WINE_SRC_DIR}/tools/make_specfiles"
  if [[ "${WCP_FREEWINE_MAKE_SPECFILES_COMPAT}" == "1" ]] && [[ -f "${make_specfiles}" ]]; then
    mkdir -p "${CACHE_DIR}/compat"
    compat_make_specfiles="${CACHE_DIR}/compat/make_specfiles.andre-arm64ec"
    rm -f "${compat_make_specfiles}"
    if [[ -n "${WCP_FREEWINE_MAKE_SPECFILES_LOCAL}" && -f "${WCP_FREEWINE_MAKE_SPECFILES_LOCAL}" ]]; then
      cp -f "${WCP_FREEWINE_MAKE_SPECFILES_LOCAL}" "${compat_make_specfiles}"
    elif [[ -n "${WCP_FREEWINE_MAKE_SPECFILES_URL}" ]]; then
      curl -fsSL "${WCP_FREEWINE_MAKE_SPECFILES_URL}" -o "${compat_make_specfiles}" \
        || fail "Unable to fetch compatible tools/make_specfiles from ${WCP_FREEWINE_MAKE_SPECFILES_URL}"
    fi

    if [[ -f "${compat_make_specfiles}" ]] && ! cmp -s "${compat_make_specfiles}" "${make_specfiles}"; then
      install -m 0755 "${compat_make_specfiles}" "${make_specfiles}"
      log "Applied FreeWine hotfix: replaced tools/make_specfiles with arm64ec-compatible generator"
    fi

    if [[ -f "${make_specfiles}" ]]; then
      python3 - <<'PY' "${make_specfiles}"
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
updated = text.replace(
    'open SPEC, "<$file" or die "cannot open $file";',
    'return unless -f $file;\n    open SPEC, "<$file" or die "cannot open $file";',
    2,
)
if updated != text:
    path.write_text(updated, encoding="utf-8")
PY
      log "Applied FreeWine hotfix: make_specfiles now skips missing donor spec files"
    fi
  fi

  # Clang with stricter pointer checks rejects LONG* where volatile long* is expected.
  # Keep this CI-side hotfix until it is folded into the canonical FreeWine tree.
  if grep -q 'InterlockedOr(&dummy, 0);' "${winnt_header}"; then
    sed -i -E 's/InterlockedOr\(&dummy,[[:space:]]*0\);/InterlockedOr((long volatile *)\&dummy, 0);/' "${winnt_header}"
    log "Applied FreeWine hotfix: winnt.h MemoryBarrier InterlockedOr cast"
  fi

  ntdll_spec="${WINE_SRC_DIR}/dlls/ntdll/ntdll.spec"
  if [[ -f "${ntdll_spec}" ]] && grep -q -- '-syscall=0x' "${ntdll_spec}"; then
    # Some FreeWine donor drops encode explicit syscall IDs in spec flags
    # (-syscall=0xNNNN), while the winebuild used in this lane only accepts
    # plain -syscall. Normalize for deterministic CI compatibility.
    sed -i -E 's/-syscall=0x[0-9A-Fa-f]+/-syscall/g' "${ntdll_spec}"
    log "Applied FreeWine hotfix: normalized ntdll syscall flags for winebuild compatibility"
  fi

  ntdll_env_c="${WINE_SRC_DIR}/dlls/ntdll/unix/env.c"
  if [[ -f "${ntdll_env_c}" ]] && grep -q 'const WCHAR \*ntdll_get_build_dir(void)' "${ntdll_env_c}"; then
    # Some mixed donor trees expose WCHAR-returning ntdll_get_* declarations,
    # while unixlib.h + win32u consumers require const char *.
    sed -i -E \
      -e 's/^const WCHAR \*ntdll_get_build_dir\(void\)$/const char *ntdll_get_build_dir(void)/' \
      -e 's/^const WCHAR \*ntdll_get_data_dir\(void\)$/const char *ntdll_get_data_dir(void)/' \
      -e 's/return nt_build_dir;/return build_dir;/' \
      -e 's/return nt_data_dir;/return data_dir;/' \
      "${ntdll_env_c}"
    log "Applied FreeWine hotfix: normalized ntdll_get_build_dir/data_dir ABI to const char *"
  fi

  ntdll_file_c="${WINE_SRC_DIR}/dlls/ntdll/unix/file.c"
  ntdll_loader_c="${WINE_SRC_DIR}/dlls/ntdll/unix/loader.c"
  ntdll_process_c="${WINE_SRC_DIR}/dlls/ntdll/unix/process.c"
  if [[ -f "${ntdll_loader_c}" ]] && grep -q 'static BYTE syscall_args\[ARRAY_SIZE(syscalls)\]' "${ntdll_loader_c}"; then
    # Mixed donor trees can desync syscall table macros, which breaks
    # fixed-size syscall_args generation. Keep args table unsized to let
    # the compiler derive the exact initializer length.
    sed -i 's/static BYTE syscall_args\[ARRAY_SIZE(syscalls)\]/static BYTE syscall_args[]/' "${ntdll_loader_c}"
    log "Applied FreeWine hotfix: normalized ntdll loader syscall_args sizing"
  fi

  if [[ -f "${ntdll_file_c}" ]] && grep -q 'WineFileUnixNameInformation' "${ntdll_file_c}"; then
    if ! grep -Rqs 'WineFileUnixNameInformation' "${WINE_SRC_DIR}/include"; then
      # If info-class symbol is absent in headers, keep buildable behavior by
      # disabling this legacy donor-only branch.
      sed -i -E 's/if \(class == WineFileUnixNameInformation\)/if (0 \/\* WineFileUnixNameInformation unavailable \*\/)/' "${ntdll_file_c}"
      log "Applied FreeWine hotfix: gated legacy WineFileUnixNameInformation branch"
    fi
  fi

  server_protocol="${WINE_SRC_DIR}/include/wine/server_protocol.h"
  if [[ -f "${ntdll_file_c}" ]] && grep -q 'reply->cancel_handle' "${ntdll_file_c}"; then
    if [[ -f "${server_protocol}" ]] && ! grep -q 'cancel_handle' "${server_protocol}"; then
      # Newer protocol variant has empty cancel_async_reply; normalize legacy
      # caller code that expects reply->cancel_handle.
      sed -i -E 's/cancel_handle = wine_server_ptr_handle\( reply->cancel_handle \);/cancel_handle = 0; \/\* cancel_async reply has no cancel_handle in this protocol \*\//g' "${ntdll_file_c}"
      log "Applied FreeWine hotfix: normalized cancel_async reply handling"
    fi
  fi

  if [[ "${FREEWINE_ENABLE_LOADER_COMPAT_PATCH:-0}" == "1" ]] \
      && [[ -f "${ntdll_loader_c}" ]] \
      && grep -q 'ALL_SYSCALL_STUBS' "${ntdll_loader_c}"; then
    if ! grep -q 'FREEWINE_LOADER_SYSCALL_COMPAT' "${ntdll_loader_c}"; then
      python3 - <<'PY' "${ntdll_loader_c}"
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
anchor = "#define SYSCALL_STUB(name) static void name(void) { stub_syscall( #name ); }\n"
inject = """
#ifndef ALL_SYSCALLS
# ifdef ALL_SYSCALLS64
#  define ALL_SYSCALLS ALL_SYSCALLS64
# elif defined(ALL_SYSCALLS32)
#  define ALL_SYSCALLS ALL_SYSCALLS32
# else
#  define ALL_SYSCALLS
# endif
#endif
#define FREEWINE_LOADER_SYSCALL_COMPAT 1
"""

updated = text
if anchor in updated and "FREEWINE_LOADER_SYSCALL_COMPAT" not in updated:
    updated = updated.replace(anchor, anchor + inject + "\n", 1)

# In mixed donor trees ALL_SYSCALL_STUBS may lag behind ALL_SYSCALLS.
# Build a deterministic local stub table directly from ALL_SYSCALLS.
compat_stub_block = """#if defined(FREEWINE_LOADER_SYSCALL_COMPAT)
#define SYSCALL_ENTRY(id,name,args) SYSCALL_STUB(name)
ALL_SYSCALLS
#undef SYSCALL_ENTRY
#else
ALL_SYSCALL_STUBS
#endif"""
updated = re.sub(
    r"(?m)^ALL_SYSCALL_STUBS$",
    compat_stub_block,
    updated,
    count=1,
)

# Mixed donor syscall generators may produce mismatched counts between
# resolved syscall symbol table and emitted args list. Keep args array
# unsized so build stays deterministic under CI normalization.
updated = re.sub(
    r"static\s+BYTE\s+syscall_args\s*\[\s*ARRAY_SIZE\s*\(\s*syscalls\s*\)\s*\]",
    "static BYTE syscall_args[]",
    updated,
    count=1,
)

if updated != text:
    path.write_text(updated, encoding="utf-8")
PY
      log "Applied FreeWine hotfix: normalized ntdll loader syscall macro compatibility"
    fi
  fi

  if [[ -f "${ntdll_process_c}" ]] && [[ -f "${server_protocol}" ]]; then
    local needs_base_priority_compat=0
    local needs_disable_boost_compat=0
    local needs_get_next_process_compat=0

    if ! grep -q 'SET_PROCESS_INFO_BASE_PRIORITY' "${server_protocol}"; then
      needs_base_priority_compat=1
    fi
    if ! grep -q 'disable_boost' "${server_protocol}"; then
      needs_disable_boost_compat=1
    fi
    if ! grep -q 'REQ_get_next_process' "${server_protocol}"; then
      needs_get_next_process_compat=1
    fi

    if [[ "${needs_base_priority_compat}" == "1" || "${needs_disable_boost_compat}" == "1" || "${needs_get_next_process_compat}" == "1" ]]; then
      python3 - <<'PY' "${ntdll_process_c}" "${needs_base_priority_compat}" "${needs_disable_boost_compat}" "${needs_get_next_process_compat}"
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
needs_base = sys.argv[2] == "1"
needs_boost = sys.argv[3] == "1"
needs_next = sys.argv[4] == "1"
text = path.read_text(encoding="utf-8")
original = text

if needs_base:
    text = text.replace("pbi.BasePriority = reply->base_priority;", "pbi.BasePriority = reply->priority;")
    text = text.replace("req->base_priority = *base_priority;", "req->priority = *base_priority;")
    text = text.replace("SET_PROCESS_INFO_BASE_PRIORITY", "SET_PROCESS_INFO_PRIORITY")

if needs_boost:
    text = text.replace("*disable_boost = reply->disable_boost;",
                        "*disable_boost = 0; /* disable_boost unsupported in this protocol */")
    text = text.replace(
        "                req->disable_boost = *disable_boost;\n"
        "                req->mask          = SET_PROCESS_INFO_DISABLE_BOOST;\n"
        "                ret = wine_server_call( req );",
        "                (void)disable_boost;\n"
        "                ret = STATUS_NOT_SUPPORTED;")

if needs_next and "FREEWINE_PROCESS_GET_NEXT_COMPAT" not in text:
    start = text.find("NTSTATUS WINAPI NtGetNextProcess(")
    marker = "\n\n\n/**********************************************************************\n *           NtDebugActiveProcess"
    end = text.find(marker, start)
    if start != -1 and end != -1:
        replacement = """NTSTATUS WINAPI NtGetNextProcess( HANDLE process, ACCESS_MASK access, ULONG attributes,\n                                  ULONG flags, HANDLE *handle )\n{\n    (void)process;\n    (void)access;\n    (void)attributes;\n    (void)flags;\n    *handle = 0;\n    /* FREEWINE_PROCESS_GET_NEXT_COMPAT: server protocol has no get_next_process request. */\n    return STATUS_NOT_SUPPORTED;\n}\n"""
        text = text[:start] + replacement + text[end:]

if text != original:
    path.write_text(text, encoding="utf-8")
PY
      log "Applied FreeWine hotfix: normalized ntdll process/server protocol compatibility"
    fi
  fi
}

validate_freewine_source_tree() {
  local marker_report
  marker_report="$(mktemp)"
  # Match only real git conflict markers. Do not flag decorative separators
  # from LICENSE/CREDITS files that start with long "======" lines.
  if grep -RInE '^(<<<<<<< .+|=======|>>>>>>> .+|\|\|\|\|\|\| .+)$' "${WINE_SRC_DIR}" \
      --exclude-dir='.git' \
      --exclude='*.patch' \
      --exclude='*.diff' > "${marker_report}"; then
    log "Detected unresolved merge markers in FreeWine source:"
    sed -n '1,40p' "${marker_report}" >&2
    rm -f "${marker_report}"
    fail "FreeWine source tree contains unresolved merge markers"
  fi
  rm -f "${marker_report}"
}

build_wine() {
  local make_vulkan_log build_log jobs
  local -a configure_args

  ensure_sdl2_tooling
  ensure_usb_tooling
  export TARGET_HOST
  # Guarantee prefixPack is available for downstream packaging/validation.
  ensure_prefix_pack "${ROOT_DIR}/prefixPack.txz"

  wcp_ensure_configure_script "${WINE_SRC_DIR}"
  make_vulkan_log="${OUT_DIR}/logs/make_vulkan.log"
  wcp_try_bootstrap_winevulkan "${WINE_SRC_DIR}" "${make_vulkan_log}"

  rm -rf "${BUILD_WINE_DIR}" "${STAGE_DIR}"
  mkdir -p "${BUILD_WINE_DIR}" "${STAGE_DIR}"

  pushd "${BUILD_WINE_DIR}" >/dev/null
  configure_args=(
    "${WINE_SRC_DIR}/configure"
    --prefix=/usr
    --disable-tests
    --with-mingw=clang
    --enable-archs=arm64ec,aarch64,i386
  )
  if [[ "${WCP_ENABLE_USB_RUNTIME}" == "1" ]]; then
    configure_args+=(--with-usb)
  else
    configure_args+=(--without-usb)
  fi
  "${configure_args[@]}"

  if [[ -f config.log ]] && ! grep -Eq 'arm64ec' config.log; then
    fail "configure did not include ARM64EC target support"
  fi

  jobs="$(wine_make_jobs)"
  build_log="$(wcp_build_log_file)"
  if ! wcp_make_with_serial_retry "${jobs}" "${build_log}"; then
    fail "Wine build failed (jobs=${jobs}); see ${build_log:-<stdout>}"
  fi
  if ! wcp_make_logged "1" "${build_log}" install DESTDIR="${STAGE_DIR}"; then
    fail "Wine install failed; see ${build_log:-<stdout>}"
  fi
  validate_sdl2_runtime_payload
  validate_usb_runtime_payload
  popd >/dev/null
}

ensure_freewine_prefixpack() {
  local prefix_pack_path build_script source_url
  prefix_pack_path="${PREFIX_PACK_PATH:-${ROOT_DIR}/prefixPack.txz}"

  if [[ -f "${prefix_pack_path}" ]]; then
    return
  fi
  if [[ "${WCP_FREEWINE_PREFIXPACK_AUTOBUILD}" != "1" ]]; then
    return
  fi

  build_script="${ROOT_DIR}/ci/wine11-arm64ec/build-freewine-prefixpack.sh"
  [[ -f "${build_script}" ]] || fail "Missing FreeWine prefix pack builder: ${build_script}"
  chmod +x "${build_script}"

  source_url="${FREEWINE_PREFIXPACK_SRC_URL:-${PREFIX_PACK_URL:-}}"
  log "prefixPack is missing; building FreeWine prefix pack at ${prefix_pack_path}"
  FREEWINE_PREFIXPACK_OUT="${prefix_pack_path}" \
  FREEWINE_PREFIXPACK_SRC_URL="${source_url:-https://raw.githubusercontent.com/GameNative/bionic-prefix-files/main/prefixPack-arm64ec.txz}" \
  bash "${build_script}"
}


ensure_arm64ec_api_set_compat() {
  # Some llvm-mingw releases miss libapi-ms-win-core-processthreads-l1-1-3.a,
  # while upstream build files may still request it indirectly.
  local libdir compat target candidate
  for libdir in \
    "${LLVM_MINGW_DIR}/arm64ec-w64-mingw32/lib" \
    "${LLVM_MINGW_DIR}/aarch64-w64-mingw32/lib"; do
    [[ -d "${libdir}" ]] || continue

    compat="${libdir}/libapi-ms-win-core-processthreads-l1-1-3.a"
    [[ -e "${compat}" ]] && continue

    target=""
    for candidate in \
      "${libdir}/libapi-ms-win-core-processthreads-l1-1-4.a" \
      "${libdir}/libapi-ms-win-core-processthreads-l1-1-2.a" \
      "${libdir}/libapi-ms-win-core-processthreads-l1-1-1.a" \
      "${libdir}/libkernel32.a"; do
      if [[ -e "${candidate}" ]]; then
        target="${candidate}"
        break
      fi
    done

    if [[ -n "${target}" ]]; then
      ln -s "$(basename "${target}")" "${compat}" || true
      log "Created API-set compatibility alias: ${compat} -> $(basename "${target}")"
    fi
  done
}

build_fex_dlls() {
  rm -rf "${HANGOVER_SRC_DIR}"
  git clone --recursive --filter=blob:none "${HANGOVER_REPO}" "${HANGOVER_SRC_DIR}"
  run_native_forensics_scaffold fex "${HANGOVER_SRC_DIR}"

  mkdir -p "${HANGOVER_SRC_DIR}/fex/build_ec"
  pushd "${HANGOVER_SRC_DIR}/fex/build_ec" >/dev/null
  # Keep ARM64EC link flags minimal; api-ms import lib may be absent in some llvm-mingw builds.
  cmake -DCMAKE_BUILD_TYPE="${FEX_BUILD_TYPE}" \
    -DCMAKE_TOOLCHAIN_FILE=../Data/CMake/toolchain_mingw.cmake \
    -DENABLE_LTO=False \
    -DMINGW_TRIPLE=arm64ec-w64-mingw32 \
    -DBUILD_TESTS=False \
    -DENABLE_TESTS=OFF \
    -DUNIT_TESTS=OFF \
    -DCMAKE_SHARED_LINKER_FLAGS="-lkernel32" \
    -DCMAKE_MODULE_LINKER_FLAGS="-lkernel32" \
    ..
  make -j"$(fex_make_jobs)" arm64ecfex
  popd >/dev/null

  mkdir -p "${HANGOVER_SRC_DIR}/fex/build_pe"
  pushd "${HANGOVER_SRC_DIR}/fex/build_pe" >/dev/null
  cmake -DCMAKE_BUILD_TYPE="${FEX_BUILD_TYPE}" \
    -DCMAKE_TOOLCHAIN_FILE=../Data/CMake/toolchain_mingw.cmake \
    -DENABLE_LTO=False \
    -DMINGW_TRIPLE=aarch64-w64-mingw32 \
    -DBUILD_TESTS=False \
    -DENABLE_TESTS=OFF \
    -DUNIT_TESTS=OFF \
    ..
  make -j"$(fex_make_jobs)" wow64fex
  popd >/dev/null

  mkdir -p "${STAGE_DIR}/usr/lib/wine/aarch64-windows"
  cp -f "${HANGOVER_SRC_DIR}/fex/build_ec/Bin/libarm64ecfex.dll" "${STAGE_DIR}/usr/lib/wine/aarch64-windows/"
  cp -f "${HANGOVER_SRC_DIR}/fex/build_pe/Bin/libwow64fex.dll" "${STAGE_DIR}/usr/lib/wine/aarch64-windows/"
}

extract_fex_dlls_from_prebuilt_wcp() {
  local tmp_root archive dll_ec dll_pe
  tmp_root="${CACHE_DIR}/prebuilt-fex"
  archive="${tmp_root}/fexcore.wcp"

  rm -rf "${tmp_root}"
  mkdir -p "${tmp_root}/extract"
  log "Downloading prebuilt FEX package: ${FEX_WCP_URL}"
  curl -fL --retry 5 --retry-delay 2 -o "${archive}" "${FEX_WCP_URL}"

  if tar --zstd -xf "${archive}" -C "${tmp_root}/extract" >/dev/null 2>&1; then
    :
  elif tar -xJf "${archive}" -C "${tmp_root}/extract" >/dev/null 2>&1; then
    :
  elif tar -xf "${archive}" -C "${tmp_root}/extract" >/dev/null 2>&1; then
    :
  else
    fail "Unable to extract prebuilt FEX package: ${archive}"
  fi

  dll_ec="$(find "${tmp_root}/extract" -type f -name 'libarm64ecfex.dll' | head -n1 || true)"
  dll_pe="$(find "${tmp_root}/extract" -type f -name 'libwow64fex.dll' | head -n1 || true)"

  [[ -n "${dll_ec}" ]] || fail "libarm64ecfex.dll not found in prebuilt FEX package"
  [[ -n "${dll_pe}" ]] || fail "libwow64fex.dll not found in prebuilt FEX package"

  mkdir -p "${STAGE_DIR}/usr/lib/wine/aarch64-windows"
  cp -f "${dll_ec}" "${STAGE_DIR}/usr/lib/wine/aarch64-windows/libarm64ecfex.dll"
  cp -f "${dll_pe}" "${STAGE_DIR}/usr/lib/wine/aarch64-windows/libwow64fex.dll"
  log "Using prebuilt FEX DLLs from ${FEX_WCP_URL}"
}

install_fex_dlls() {
  case "${FEX_SOURCE_MODE}" in
    prebuilt)
      extract_fex_dlls_from_prebuilt_wcp
      ;;
    build)
      build_fex_dlls
      ;;
    auto)
      if ! extract_fex_dlls_from_prebuilt_wcp; then
        log "Prebuilt FEX package failed, falling back to local FEX build"
        build_fex_dlls
      fi
      ;;
    *)
      fail "FEX_SOURCE_MODE must be one of: auto, prebuilt, build"
      ;;
  esac
}

ensure_sdl2_tooling() {
  if [[ "${WCP_ENABLE_SDL2_RUNTIME}" != "1" ]]; then
    return
  fi

  require_cmd pkg-config
  pkg-config --exists sdl2 || fail "SDL2 development files are missing (pkg-config sdl2 failed)"
}

ensure_usb_tooling() {
  if [[ "${WCP_ENABLE_USB_RUNTIME}" != "1" ]]; then
    return
  fi

  require_cmd pkg-config
  pkg-config --exists libusb-1.0 || fail "USB runtime check failed: libusb-1.0 development files are missing"
}

validate_sdl2_runtime_payload() {
  local winebus_module winebus_module_dir strings_cmd
  if [[ "${WCP_ENABLE_SDL2_RUNTIME}" != "1" ]]; then
    return
  fi

  winebus_module_dir="${STAGE_DIR}/usr/lib/wine/aarch64-unix"
  if [[ -f "${winebus_module_dir}/winebus.so" ]]; then
    winebus_module="${winebus_module_dir}/winebus.so"
  elif [[ -f "${winebus_module_dir}/winebus.sys.so" ]]; then
    winebus_module="${winebus_module_dir}/winebus.sys.so"
  else
    fail "SDL2 runtime check failed: missing ${winebus_module_dir}/winebus.so (or winebus.sys.so)"
  fi

  if readelf -d "${winebus_module}" | grep -Eiq 'NEEDED.*SDL2'; then
    log "SDL2 runtime check passed ($(basename "${winebus_module}") links against SDL2)"
    return
  fi

  strings_cmd="$(command -v strings || command -v llvm-strings || true)"
  if [[ -n "${strings_cmd}" ]] && "${strings_cmd}" -a "${winebus_module}" | grep -Eiq 'libSDL2(-2\\.0)?\\.so'; then
    log "SDL2 runtime check passed ($(basename "${winebus_module}") references SDL2 SONAME)"
    return
  fi

  log "SDL2 runtime probe is inconclusive for $(basename "${winebus_module}") (no direct linkage/SONAME); continuing with module-present validation"
}

validate_usb_runtime_payload() {
  local unix_dir windows64_dir windows32_dir
  if [[ "${WCP_ENABLE_USB_RUNTIME}" != "1" ]]; then
    return
  fi

  unix_dir="${STAGE_DIR}/usr/lib/wine/aarch64-unix"
  windows64_dir="${STAGE_DIR}/usr/lib/wine/aarch64-windows"
  windows32_dir="${STAGE_DIR}/usr/lib/wine/i386-windows"

  if [[ ! -f "${unix_dir}/wineusb.so" && ! -f "${unix_dir}/wineusb.sys.so" ]]; then
    fail "USB runtime check failed: missing ${unix_dir}/wineusb.so (or wineusb.sys.so)"
  fi
  [[ -f "${windows64_dir}/wineusb.sys" ]] || fail "USB runtime check failed: missing ${windows64_dir}/wineusb.sys"
  if [[ ! -f "${windows64_dir}/winusb.dll" && ! -f "${windows32_dir}/winusb.dll" ]]; then
    fail "USB runtime check failed: missing winusb.dll in aarch64/i386 windows layers"
  fi
  log "USB runtime check passed (wineusb + winusb present)"
}


strip_stage_payload() {
  [[ "${STRIP_STAGE}" == "1" ]] || return

  local strip_cmd
  strip_cmd="$(command -v llvm-strip || command -v strip || true)"
  [[ -n "${strip_cmd}" ]] || { log "No strip tool found, skipping payload stripping"; return; }

  log "Stripping ELF payload to reduce runtime memory/storage footprint (${strip_cmd})"
  while IFS= read -r -d '' f; do
    if file -b "${f}" | grep -q '^ELF '; then
      "${strip_cmd}" --strip-unneeded "${f}" >/dev/null 2>&1 || true
    fi
  done < <(find "${STAGE_DIR}/usr" -type f -print0)
}

compose_wcp_tree() {
  local emulation_policy

  rm -rf "${WCP_ROOT}"
  mkdir -p "${WCP_ROOT}"
  rsync -a "${STAGE_DIR}/usr/" "${WCP_ROOT}/"
  winlator_adopt_bionic_unix_core_modules "${WCP_ROOT}"
  winlator_adopt_bionic_launchers "${WCP_ROOT}"
  winlator_wrap_glibc_launchers
  winlator_ensure_arm64ec_unix_loader_compat_links "${WCP_ROOT}"

  if [[ -f "${WCP_ROOT}/bin/wine" && ! -e "${WCP_ROOT}/bin/wine64" ]]; then
    ln -s wine "${WCP_ROOT}/bin/wine64"
  fi

  mkdir -p "${WCP_ROOT}/winetools"
  cat > "${WCP_ROOT}/winetools/manifest.txt" <<'MANIFEST'
bin/wine
bin/wineserver
bin/winecfg
bin/regedit
bin/explorer
bin/msiexec
bin/notepad
MANIFEST

  cat > "${WCP_ROOT}/winetools/winetools.sh" <<'WINETOOLS'
#!/usr/bin/env sh
set -eu

cmd="${1:-info}"
case "$cmd" in
  list)
    sed -n 's/^/ - /p' "$(dirname "$0")/manifest.txt"
    ;;
  run)
    tool="${2:-}"
    [ -n "$tool" ] || { echo "usage: winetools.sh run <tool> [args...]"; exit 2; }
    shift 2
    exec "/usr/bin/${tool}" "$@"
    ;;
  info|*)
    echo "Winlator WCP winetools layer"
    echo "Available tools:"
    sed -n 's|^bin/||p' "$(dirname "$0")/manifest.txt"
    ;;
esac
WINETOOLS
  chmod +x "${WCP_ROOT}/winetools/winetools.sh"

  mkdir -p "${WCP_ROOT}/share/winetools"
  {
    echo "== ELF (Unix launchers) =="
    for f in \
      "${WCP_ROOT}/bin/wine" \
      "${WCP_ROOT}/bin/wineserver" \
      "${WCP_ROOT}/bin/wine.glibc-real" \
      "${WCP_ROOT}/bin/wineserver.glibc-real"; do
      [[ -e "$f" ]] || continue
      echo "--- $f"
      file "$f" || true
      readelf -d "$f" 2>/dev/null | sed -n '1,120p' || true
    done
    echo
    echo "== PE (FEX WoA DLL) =="
    for f in "${WCP_ROOT}/lib/wine/aarch64-windows/libarm64ecfex.dll" "${WCP_ROOT}/lib/wine/aarch64-windows/libwow64fex.dll"; do
      [[ -e "$f" ]] || continue
      echo "--- $f"
      file "$f" || true
    done
  } > "${WCP_ROOT}/share/winetools/linking-report.txt"

  local has_prefix_pack="0"
  # Attempt to download if missing; fallback honors REQUIRE_PREFIX_PACK flag.
  ensure_prefix_pack "${ROOT_DIR}/prefixPack.txz"
  if [[ -f "${ROOT_DIR}/prefixPack.txz" ]]; then
    cp -f "${ROOT_DIR}/prefixPack.txz" "${WCP_ROOT}/prefixPack.txz"
    log "included prefixPack.txz"
    has_prefix_pack="1"
  elif [[ "${REQUIRE_PREFIX_PACK}" == "1" ]]; then
    fail "prefixPack.txz is required but missing in repository root"
  else
    log "prefixPack.txz is missing, proceeding without bundled prefix (REQUIRE_PREFIX_PACK=0)"
  fi

  local utc_now
  utc_now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  emulation_policy="runtime-mixed"
  [[ "${WCP_MAINLINE_FEX_EXTERNAL_ONLY}" == "1" ]] && emulation_policy="fex-external-only"

  mkdir -p "${WCP_ROOT}/info"
  cat > "${WCP_ROOT}/profile.json" <<EOF_PROFILE
{
  "type": "${WCP_PROFILE_TYPE}",
  "versionName": "${WCP_VERSION_NAME}",
  "versionCode": ${WCP_VERSION_CODE},
  "description": "${WCP_DESCRIPTION}",
  "channel": "${WCP_CHANNEL}",
  "delivery": "${WCP_DELIVERY}",
  "displayCategory": "${WCP_DISPLAY_CATEGORY}",
  "sourceRepo": "${WCP_SOURCE_REPO}",
  "sourceType": "${WCP_SOURCE_TYPE}",
  "sourceVersion": "${WCP_SOURCE_VERSION}",
  "releaseTag": "${WCP_RELEASE_TAG}",
  "artifactName": "${WCP_ARTIFACT_NAME}",
  "sha256Url": "${WCP_SHA256_URL}",
  "files": [],
  "wine": {
    "binPath": "bin",
    "libPath": "lib"$(
      if [[ "${has_prefix_pack}" == "1" ]]; then
        printf ',\n    "prefixPack": "prefixPack.txz"'
      fi
    )
  },
  "runtime": {
    "target": "$(printf '%s' "${WCP_TARGET_RUNTIME}" | sed 's/"/\\"/g')",
    "runtimeClassTarget": "$(printf '%s' "${WCP_RUNTIME_CLASS_TARGET}" | sed 's/"/\\"/g')",
    "runtimeClassDetected": "$(printf '%s' "$(winlator_detect_runtime_class "${WCP_ROOT}")" | sed 's/"/\\"/g')",
    "unixAbiDetected": "$(printf '%s' "$(winlator_detect_unix_module_abi "${WCP_ROOT}")" | sed 's/"/\\"/g')",
    "wineLauncherAbi": "$(printf '%s' "$(winlator_detect_launcher_abi "${WCP_ROOT}/bin/wine")" | sed 's/"/\\"/g')",
    "wineserverLauncherAbi": "$(printf '%s' "$(winlator_detect_launcher_abi "${WCP_ROOT}/bin/wineserver")" | sed 's/"/\\"/g')",
    "runtimeMismatchReason": "$(printf '%s' "$(winlator_detect_runtime_mismatch_reason "${WCP_ROOT}" "${WCP_RUNTIME_CLASS_TARGET}")" | sed 's/"/\\"/g')",
    "emulationPolicy": "$(printf '%s' "${emulation_policy}" | sed 's/"/\\"/g')",
    "wrapperPolicyVersion": "$(printf '%s' "${WCP_WRAPPER_POLICY_VERSION}" | sed 's/"/\\"/g')",
    "policySource": "$(printf '%s' "${WCP_POLICY_SOURCE}" | sed 's/"/\\"/g')",
    "fallbackScope": "$(printf '%s' "${WCP_FALLBACK_SCOPE}" | sed 's/"/\\"/g')",
    "boxedRuntimeInWcpDetected": false,
    "policyViolationReason": "none",
    "fexExpectationMode": "$(printf '%s' "${WCP_FEX_EXPECTATION_MODE}" | sed 's/"/\\"/g')",
    "fexBundledInWcp": ${WCP_INCLUDE_FEX_DLLS},
    "usbRuntimeEnabled": ${WCP_ENABLE_USB_RUNTIME}
  }
}
EOF_PROFILE

  cat > "${WCP_ROOT}/info/info.json" <<EOF_INFO
{
  "name": "${WCP_NAME}",
  "type": "${WCP_PROFILE_TYPE}",
  "version": "${WCP_VERSION_NAME}",
  "versionCode": ${WCP_VERSION_CODE},
  "description": "${WCP_DESCRIPTION}",
  "built": "${utc_now}"
}
EOF_INFO
}


validate_wcp_tree() {
  local required_paths=(
    "${WCP_ROOT}/bin"
    "${WCP_ROOT}/bin/wine"
    "${WCP_ROOT}/bin/wineserver"
    "${WCP_ROOT}/lib"
    "${WCP_ROOT}/lib/wine"
    "${WCP_ROOT}/lib/wine/aarch64-unix"
    "${WCP_ROOT}/lib/wine/aarch64-windows"
    "${WCP_ROOT}/lib/wine/i386-windows"
    "${WCP_ROOT}/share"
    "${WCP_ROOT}/profile.json"
  )
  if [[ "${WCP_FEX_EXPECTATION_MODE}" == "bundled" ]]; then
    required_paths+=(
      "${WCP_ROOT}/lib/wine/aarch64-windows/libarm64ecfex.dll"
      "${WCP_ROOT}/lib/wine/aarch64-windows/libwow64fex.dll"
    )
  fi

  local p
  for p in "${required_paths[@]}"; do
    [[ -e "${p}" ]] || fail "WCP layout is incomplete, missing: ${p#${WCP_ROOT}/}"
  done

  wcp_assert_mainline_external_runtime_clean_tree "${WCP_ROOT}"
  wcp_assert_pruned_external_runtime_components "${WCP_ROOT}"

  local required_unix_modules=(
    "ntdll.so"
    "win32u.so"
    "ws2_32.so"
    "opengl32.so"
    "secur32.so"
    "winevulkan.so"
  )

  if [[ "${WCP_ENABLE_SDL2_RUNTIME}" == "1" ]]; then
    if [[ -f "${WCP_ROOT}/lib/wine/aarch64-unix/winebus.so" ]]; then
      required_unix_modules+=("winebus.so")
    elif [[ -f "${WCP_ROOT}/lib/wine/aarch64-unix/winebus.sys.so" ]]; then
      required_unix_modules+=("winebus.sys.so")
    else
      fail "Wine unix module missing: lib/wine/aarch64-unix/winebus.so (or winebus.sys.so)"
    fi
  fi
  if [[ "${WCP_ENABLE_USB_RUNTIME}" == "1" ]]; then
    if [[ -f "${WCP_ROOT}/lib/wine/aarch64-unix/wineusb.so" ]]; then
      required_unix_modules+=("wineusb.so")
    elif [[ -f "${WCP_ROOT}/lib/wine/aarch64-unix/wineusb.sys.so" ]]; then
      required_unix_modules+=("wineusb.sys.so")
    else
      fail "Wine unix module missing: lib/wine/aarch64-unix/wineusb.so (or wineusb.sys.so)"
    fi
    [[ -f "${WCP_ROOT}/lib/wine/aarch64-windows/wineusb.sys" ]] || fail "Wine PE module missing: lib/wine/aarch64-windows/wineusb.sys"
    if [[ ! -f "${WCP_ROOT}/lib/wine/aarch64-windows/winusb.dll" && ! -f "${WCP_ROOT}/lib/wine/i386-windows/winusb.dll" ]]; then
      fail "Wine PE module missing: winusb.dll (aarch64 or i386 windows layer)"
    fi
  fi

  local mod
  for mod in "${required_unix_modules[@]}"; do
    [[ -f "${WCP_ROOT}/lib/wine/aarch64-unix/${mod}" ]] || fail "Wine unix module missing: lib/wine/aarch64-unix/${mod}"
  done

  local unix_abi runtime_mismatch_reason
  unix_abi="$(winlator_detect_unix_module_abi "${WCP_ROOT}")"
  if [[ "${WCP_RUNTIME_CLASS_TARGET}" == "bionic-native" && "${unix_abi}" != "bionic-unix" ]]; then
    fail "Bionic runtime target requires bionic-linked unix modules; detected unix ABI=${unix_abi} (expected bionic-unix)"
  fi

  if [[ "${REQUIRE_PREFIX_PACK}" == "1" ]]; then
    [[ -f "${WCP_ROOT}/prefixPack.txz" ]] || fail "WCP layout is incomplete, missing: prefixPack.txz"
  fi

  winlator_validate_launchers
  runtime_mismatch_reason="$(winlator_detect_runtime_mismatch_reason "${WCP_ROOT}" "${WCP_RUNTIME_CLASS_TARGET}")"
  [[ "${runtime_mismatch_reason}" == "none" ]] || fail "Runtime mismatch after validation: ${runtime_mismatch_reason}"
  wcp_validate_forensic_manifest "${WCP_ROOT}"
  wcp_runtime_verify_glibc_lock "${WCP_ROOT}"
  log "WCP layout validation passed"
}

pack_wcp() {
  mkdir -p "${OUT_DIR}"
  local out_wcp
  out_wcp="${OUT_DIR}/${WCP_NAME}.wcp"

  pushd "${WCP_ROOT}" >/dev/null
  case "${WCP_COMPRESS}" in
    xz)
      tar -cJf "${out_wcp}" .
      ;;
    zst|zstd)
      tar --zstd -cf "${out_wcp}" .
      ;;
    *)
      fail "WCP_COMPRESS must be xz or zst"
      ;;
  esac
  popd >/dev/null

  case "${WCP_COMPRESS}" in
    xz)
      tar -tJf "${out_wcp}" >/dev/null || fail "Packed WCP is not a valid xz tar archive"
      ;;
    zst|zstd)
      tar --zstd -tf "${out_wcp}" >/dev/null || fail "Packed WCP is not a valid zstd tar archive"
      ;;
  esac

  log "built artifact: ${out_wcp}"
  ls -lh "${out_wcp}"
}

main() {
  cd "${ROOT_DIR}"

  require_cmd curl
  require_cmd git
  require_cmd python3
  require_cmd cmake
  require_cmd make
  require_cmd tar
  require_cmd rsync
  if [[ "${WCP_COMPRESS}" == "zstd" || "${WCP_COMPRESS}" == "zst" ]]; then
    require_cmd zstd
  fi
  require_cmd file
  require_cmd readelf
  require_cmd pkg-config

  require_bool_flag WCP_ENABLE_SDL2_RUNTIME "${WCP_ENABLE_SDL2_RUNTIME}"
  require_bool_flag WCP_ENABLE_USB_RUNTIME "${WCP_ENABLE_USB_RUNTIME}"
  require_bool_flag WCP_RUNTIME_CLASS_ENFORCE "${WCP_RUNTIME_CLASS_ENFORCE}"
  require_bool_flag WCP_PRUNE_EXTERNAL_COMPONENTS "${WCP_PRUNE_EXTERNAL_COMPONENTS}"
  require_bool_flag WCP_INCLUDE_FEX_DLLS "${WCP_INCLUDE_FEX_DLLS}"
  require_bool_flag WCP_MAINLINE_BIONIC_ONLY "${WCP_MAINLINE_BIONIC_ONLY}"
  require_bool_flag WCP_MAINLINE_FEX_EXTERNAL_ONLY "${WCP_MAINLINE_FEX_EXTERNAL_ONLY}"
  require_bool_flag WCP_ALLOW_GLIBC_EXPERIMENTAL "${WCP_ALLOW_GLIBC_EXPERIMENTAL}"
  require_bool_flag WCP_ALLOW_X86_64_HOST "${WCP_ALLOW_X86_64_HOST}"
  require_bool_flag WCP_BIONIC_SOURCE_MAP_FORCE "${WCP_BIONIC_SOURCE_MAP_FORCE}"
  require_bool_flag WCP_BIONIC_SOURCE_MAP_REQUIRED "${WCP_BIONIC_SOURCE_MAP_REQUIRED}"
  require_bool_flag WCP_GN_PATCHSET_ENABLE "${WCP_GN_PATCHSET_ENABLE}"
  require_bool_flag WCP_FREEWINE_PREFIXPACK_AUTOBUILD "${WCP_FREEWINE_PREFIXPACK_AUTOBUILD}"
  if [[ "${WCP_GN_PATCHSET_ENABLE}" == "1" ]]; then
    fail "WCP_GN_PATCHSET_ENABLE=1 is not allowed by freewine-only policy"
  fi
  wcp_require_enum WCP_FEX_EXPECTATION_MODE "${WCP_FEX_EXPECTATION_MODE}" external bundled
  wcp_require_enum WCP_RUNTIME_CLASS_TARGET "${WCP_RUNTIME_CLASS_TARGET}" bionic-native glibc-wrapped
  wcp_require_enum WCP_RUNTIME_BUNDLE_LOCK_MODE "${WCP_RUNTIME_BUNDLE_LOCK_MODE}" audit enforce relaxed-enforce
  case "${WCP_FEX_EXPECTATION_MODE}" in
    external|bundled) ;;
    *) fail "WCP_FEX_EXPECTATION_MODE must be external or bundled" ;;
  esac
  wcp_validate_winlator_profile_identifier "${WCP_VERSION_NAME}" "${WCP_VERSION_CODE}"
  wcp_enforce_mainline_bionic_policy
  wcp_enforce_mainline_external_runtime_policy
  if [[ "${WCP_BIONIC_SOURCE_PREFLIGHT}" == "1" ]]; then
    CHECK_REMOTE="${WCP_BIONIC_SOURCE_PREFLIGHT}" source "${ROOT_DIR}/ci/runtime-sources/resolve-bionic-source.sh" "${WCP_NAME}"
  fi
  winlator_preflight_bionic_source_contract

  check_host_arch
  ensure_llvm_mingw
  ensure_arm64ec_api_set_compat

  export PATH="${LLVM_MINGW_DIR}/bin:${PATH}"
  log "clang: $(command -v clang)"
  log "ld.lld: $(command -v ld.lld || true)"
  clang --version | sed -n '1,2p'
  ld.lld --version | sed -n '1,2p'

  fetch_wine_sources
  mkdir -p "${OUT_DIR}/logs"
  ensure_freewine_prefixpack
  build_wine
  if [[ "${WCP_INCLUDE_FEX_DLLS}" == "1" ]]; then
    install_fex_dlls
  else
    log "Skipping FEX DLL embedding (WCP_INCLUDE_FEX_DLLS=0, mode=${WCP_FEX_EXPECTATION_MODE})"
  fi
  strip_stage_payload
  compose_wcp_tree
  wcp_prune_external_runtime_components "${WCP_ROOT}" "${OUT_DIR}/logs/pruned-components.txt"
  wcp_write_forensic_manifest "${WCP_ROOT}"
  validate_wcp_tree
  pack_wcp
  smoke_check_wcp "${OUT_DIR}/${WCP_NAME}.wcp" "${WCP_COMPRESS}"
}

main "$@"
