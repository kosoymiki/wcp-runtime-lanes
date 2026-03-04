#!/usr/bin/env bash
set -euo pipefail

WCP_COMMON_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# Re-export llvm-mingw helpers (including ensure_llvm_mingw) through this common entrypoint.
# Keep a stable alias so callers can source only wcp_common.sh.
source "${WCP_COMMON_DIR}/llvm-mingw.sh"
if declare -F ensure_llvm_mingw >/dev/null 2>&1; then
  eval "$(declare -f ensure_llvm_mingw | sed '1s/ensure_llvm_mingw/llvm_mingw_ensure_llvm_mingw/')"
  ensure_llvm_mingw() {
    llvm_mingw_ensure_llvm_mingw "$@"
  }
fi

source "${WCP_COMMON_DIR}/winlator-runtime.sh"

wcp_log() {
  if declare -F log >/dev/null 2>&1; then
    log "$@"
  else
    printf '[wcp] %s\n' "$*"
  fi
}

wcp_fail() {
  if declare -F fail >/dev/null 2>&1; then
    fail "$@"
  else
    printf '[wcp][error] %s\n' "$*" >&2
    exit 1
  fi
}

wcp_make_jobs() {
  if [[ -n "${WCP_WINE_BUILD_JOBS:-}" ]]; then
    printf '%s' "${WCP_WINE_BUILD_JOBS}"
    return
  fi
  if [[ -n "${WCP_BUILD_JOBS:-}" ]]; then
    printf '%s' "${WCP_BUILD_JOBS}"
    return
  fi
  nproc
}

wcp_build_log_file() {
  if [[ -n "${WCP_BUILD_LOG_FILE:-}" ]]; then
    printf '%s' "${WCP_BUILD_LOG_FILE}"
    return
  fi
  if [[ -n "${WCP_OUTPUT_DIR:-}" ]]; then
    printf '%s' "${WCP_OUTPUT_DIR}/logs/wine-build.log"
    return
  fi
  printf ''
}

wcp_usb_runtime_enabled() {
  [[ "${WCP_ENABLE_USB_RUNTIME:-0}" == "1" ]]
}

wcp_make_logged() {
  local jobs="$1" log_file="$2"
  shift 2
  local stdout_mode heartbeat_sec target_desc make_pid log_size elapsed rc

  if [[ -n "${log_file}" ]]; then
    mkdir -p "$(dirname -- "${log_file}")"
    stdout_mode="${WCP_BUILD_LOG_STDOUT_MODE:-tee}"
    case "${stdout_mode}" in
      tee)
        make -j"${jobs}" "$@" 2>&1 | tee -a "${log_file}"
        return "${PIPESTATUS[0]}"
        ;;
      quiet)
        heartbeat_sec="${WCP_BUILD_HEARTBEAT_SEC:-60}"
        target_desc="${*:-all}"
        wcp_log "make -j${jobs} ${target_desc} (quiet mode, log -> ${log_file})"
        printf '\n=== make -j%s %s @ %s ===\n' "${jobs}" "${target_desc}" "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" >> "${log_file}"
        make -j"${jobs}" "$@" >> "${log_file}" 2>&1 &
        make_pid=$!
        elapsed=0
        while kill -0 "${make_pid}" >/dev/null 2>&1; do
          sleep "${heartbeat_sec}"
          elapsed=$((elapsed + heartbeat_sec))
          if ! kill -0 "${make_pid}" >/dev/null 2>&1; then
            break
          fi
          log_size="$(wc -c < "${log_file}" 2>/dev/null || echo 0)"
          wcp_log "heartbeat: make -j${jobs} ${target_desc} running (${elapsed}s, log=${log_size}B)"
        done
        if wait "${make_pid}"; then
          rc=0
        else
          rc=$?
        fi
        if [[ ${rc} -eq 0 ]]; then
          return 0
        fi
        wcp_log "make -j${jobs} ${target_desc} failed (rc=${rc}), tail ${log_file}:"
        tail -n 160 "${log_file}" >&2 || true
        return "${rc}"
        ;;
      *)
        wcp_fail "WCP_BUILD_LOG_STDOUT_MODE must be tee or quiet (got: ${stdout_mode})"
        ;;
    esac
  fi

  make -j"${jobs}" "$@"
}

wcp_make_with_serial_retry() {
  local jobs="$1" log_file="$2"
  shift 2

  if wcp_make_logged "${jobs}" "${log_file}" "$@"; then
    return 0
  fi

  if [[ "${jobs}" != "1" ]]; then
    wcp_log "Parallel make failed with -j${jobs}; retrying serial build (-j1)"
    wcp_make_logged "1" "${log_file}" "$@"
    return $?
  fi

  return 1
}

wcp_configure_profile_args() {
  local profile="$1"
  case "${profile}" in
    proton-android-minimal)
      cat <<'EOF'
--enable-win64
--disable-win16
--enable-nls
--disable-amd_ags_x64
--enable-wineandroid_drv=no
--with-alsa
--without-capi
--without-coreaudio
--without-cups
--without-dbus
--without-ffmpeg
--with-fontconfig
--with-freetype
--without-gcrypt
--without-gettext
--with-gettextpo=no
--without-gphoto
--with-gnutls
--without-gssapi
--with-gstreamer
--without-inotify
--without-krb5
--without-netapi
--without-opencl
--with-opengl
--without-osmesa
--without-oss
--without-pcap
--without-pcsclite
--without-piper
--with-pthread
--with-pulse
--without-sane
--with-sdl
--without-udev
--without-unwind
--without-v4l2
--without-vosk
--with-vulkan
--without-wayland
--without-xcomposite
--without-xcursor
--with-xfixes
--without-xinerama
--without-xinput
--without-xinput2
--without-xrandr
--without-xrender
--without-xshape
--with-xshm
--without-xxf86vm
EOF
      if wcp_usb_runtime_enabled; then
        printf '%s\n' "--with-usb"
      else
        printf '%s\n' "--without-usb"
      fi
      ;;
    "")
      return 0
      ;;
    *)
      wcp_fail "Unknown WINE_CONFIGURE_PROFILE: ${profile}"
      ;;
  esac
}

source "${WCP_COMMON_DIR}/runtime-bundle-lock.sh"

wcp_require_cmd() {
  command -v "$1" >/dev/null 2>&1 || wcp_fail "Required command not found: $1"
}

wcp_require_bool() {
  local flag_name="$1" flag_value="$2"
  case "${flag_value}" in
    0|1) ;;
    *) wcp_fail "${flag_name} must be 0 or 1 (got: ${flag_value})" ;;
  esac
}

wcp_require_enum() {
  local flag_name="$1" flag_value="$2"; shift 2
  local candidate
  for candidate in "$@"; do
    [[ "${flag_value}" == "${candidate}" ]] && return 0
  done
  wcp_fail "${flag_name} must be one of: $* (got: ${flag_value})"
}

wcp_trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "${value}"
}

wcp_json_array_from_csv() {
  local csv="$1"
  local first=1 raw item
  local -a values

  IFS=',' read -r -a values <<< "${csv}"

  printf '['
  for raw in "${values[@]}"; do
    item="$(wcp_trim "${raw}")"
    [[ -n "${item}" ]] || continue
    if [[ ${first} -eq 0 ]]; then
      printf ','
    fi
    printf '"%s"' "$(wcp_json_escape "${item}")"
    first=0
  done
  printf ']'
}

wcp_enforce_mainline_bionic_policy() {
  : "${WCP_MAINLINE_BIONIC_ONLY:=1}"
  : "${WCP_ALLOW_GLIBC_EXPERIMENTAL:=0}"
  : "${WCP_BIONIC_SOURCE_MAP_FORCE:=0}"
  : "${WCP_BIONIC_SOURCE_MAP_REQUIRED:=0}"
  wcp_require_bool WCP_MAINLINE_BIONIC_ONLY "${WCP_MAINLINE_BIONIC_ONLY}"
  wcp_require_bool WCP_ALLOW_GLIBC_EXPERIMENTAL "${WCP_ALLOW_GLIBC_EXPERIMENTAL}"
  wcp_require_bool WCP_BIONIC_SOURCE_MAP_FORCE "${WCP_BIONIC_SOURCE_MAP_FORCE}"
  wcp_require_bool WCP_BIONIC_SOURCE_MAP_REQUIRED "${WCP_BIONIC_SOURCE_MAP_REQUIRED}"

  [[ "${WCP_MAINLINE_BIONIC_ONLY}" == "1" ]] || return 0
  [[ "${WCP_RUNTIME_CLASS_TARGET:-bionic-native}" == "bionic-native" ]] || \
    wcp_fail "Mainline bionic-only policy requires WCP_RUNTIME_CLASS_TARGET=bionic-native"
  [[ "${WCP_RUNTIME_CLASS_ENFORCE:-1}" == "1" ]] || \
    wcp_fail "Mainline bionic-only policy requires WCP_RUNTIME_CLASS_ENFORCE=1"
  [[ "${WCP_ALLOW_GLIBC_EXPERIMENTAL}" == "0" ]] || \
    wcp_fail "Mainline bionic-only policy forbids WCP_ALLOW_GLIBC_EXPERIMENTAL=1"
  if [[ "${WCP_BIONIC_SOURCE_MAP_REQUIRED}" == "1" ]]; then
    [[ -n "${WCP_BIONIC_SOURCE_MAP_FILE:-}" ]] || \
      wcp_fail "WCP_BIONIC_SOURCE_MAP_REQUIRED=1 requires WCP_BIONIC_SOURCE_MAP_FILE"
    [[ -f "${WCP_BIONIC_SOURCE_MAP_FILE}" ]] || \
      wcp_fail "WCP_BIONIC_SOURCE_MAP_REQUIRED=1 requires existing source-map file: ${WCP_BIONIC_SOURCE_MAP_FILE}"
  fi
}

wcp_enforce_mainline_external_runtime_policy() {
  : "${WCP_MAINLINE_FEX_EXTERNAL_ONLY:=1}"
  : "${WCP_PRUNE_EXTERNAL_COMPONENTS:=1}"
  wcp_require_bool WCP_MAINLINE_FEX_EXTERNAL_ONLY "${WCP_MAINLINE_FEX_EXTERNAL_ONLY}"
  wcp_require_bool WCP_PRUNE_EXTERNAL_COMPONENTS "${WCP_PRUNE_EXTERNAL_COMPONENTS}"
  [[ "${WCP_MAINLINE_FEX_EXTERNAL_ONLY}" == "1" ]] || return 0

  [[ "${WCP_FEX_EXPECTATION_MODE:-external}" == "external" ]] || \
    wcp_fail "Mainline external-runtime policy requires WCP_FEX_EXPECTATION_MODE=external"
  [[ "${WCP_INCLUDE_FEX_DLLS:-0}" == "0" ]] || \
    wcp_fail "Mainline external-runtime policy requires WCP_INCLUDE_FEX_DLLS=0"
  [[ "${WCP_PRUNE_EXTERNAL_COMPONENTS}" == "1" ]] || \
    wcp_fail "Mainline external-runtime policy requires WCP_PRUNE_EXTERNAL_COMPONENTS=1"
}

wcp_external_runtime_component_paths() {
  cat <<'EOF_EXTERNAL_COMPONENTS'
fex	lib/wine/aarch64-windows/libarm64ecfex.dll
fex	lib/wine/aarch64-windows/libwow64fex.dll
fex	lib/wine/i386-windows/libwow64fex.dll
fex	lib/wine/fexcore
fex	lib/fexcore
fex	share/fexcore
fex	bin/FEXInterpreter
fex	bin/FEXBash
fex	lib/fex-emu
fex	share/fex-emu
box64	bin/box64
wowbox64	bin/wowbox64
box64	lib/box64
wowbox64	lib/wowbox64
box64	share/box64
wowbox64	share/wowbox64
box64	lib/wine/box64
wowbox64	lib/wine/wowbox64
dxvk	lib/wine/dxvk
vkd3d	lib/wine/vkd3d
vkd3d	lib/wine/vk3d
dxvk	lib/dxvk
vkd3d	lib/vkd3d
dxvk	share/dxvk
vkd3d	share/vkd3d
EOF_EXTERNAL_COMPONENTS
}

wcp_is_internal_vulkan_runtime_relpath() {
  local rel="${1#./}"

  : "${WCP_EMBED_VULKAN_RUNTIME:=1}"
  wcp_require_bool WCP_EMBED_VULKAN_RUNTIME "${WCP_EMBED_VULKAN_RUNTIME}"
  [[ "${WCP_EMBED_VULKAN_RUNTIME}" == "1" ]] || return 1

  case "${rel}" in
    share/vulkan|share/vulkan/|\
    share/vulkan/icd.d|share/vulkan/icd.d/|share/vulkan/icd.d/wrapper_icd.aarch64.json|\
    share/vulkan/explicit_layer.d|share/vulkan/explicit_layer.d/|share/vulkan/explicit_layer.d/VkLayer_khronos_validation.json|\
    share/vulkan-sdk|share/vulkan-sdk/|share/vulkan-sdk/*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

wcp_list_external_runtime_policy_hits() {
  local wcp_root="$1"
  local rel category

  [[ -d "${wcp_root}" ]] || return 0

  while IFS=$'\t' read -r category rel; do
    [[ -n "${rel}" ]] || continue
    [[ -e "${wcp_root}/${rel}" ]] && printf '%s\n' "${rel}"
  done < <(wcp_external_runtime_component_paths)

  find "${wcp_root}" -mindepth 1 \
    \( -iname '*box64*' -o -iname '*wowbox64*' -o -iname '*fexcore*' \) \
    -printf '%P\n' 2>/dev/null | LC_ALL=C sort -u
}

wcp_prune_external_vulkan_runtime_components() {
  local wcp_root="$1"
  local report_file="${2:-}"
  local rel removed_count=0

  : "${WCP_PRUNE_EXTERNAL_COMPONENTS:=1}"
  : "${WCP_EMBED_VULKAN_RUNTIME:=1}"
  wcp_require_bool WCP_PRUNE_EXTERNAL_COMPONENTS "${WCP_PRUNE_EXTERNAL_COMPONENTS}"
  wcp_require_bool WCP_EMBED_VULKAN_RUNTIME "${WCP_EMBED_VULKAN_RUNTIME}"
  [[ "${WCP_PRUNE_EXTERNAL_COMPONENTS}" == "1" ]] || return 0
  [[ -d "${wcp_root}/share/vulkan" ]] || return 0

  while IFS= read -r rel; do
    [[ -n "${rel}" ]] || continue
    if wcp_is_internal_vulkan_runtime_relpath "${rel}"; then
      continue
    fi
    rm -rf "${wcp_root:?}/${rel}"
    removed_count=$((removed_count + 1))
    if [[ -n "${report_file}" ]]; then
      printf 'driver\t%s\n' "${rel}" >> "${report_file}"
    fi
  done < <(find "${wcp_root}/share/vulkan" -mindepth 1 -printf 'share/vulkan/%P\n' | LC_ALL=C sort -r)

  find "${wcp_root}/share/vulkan" -depth -type d -empty -delete 2>/dev/null || true
  if [[ ! -d "${wcp_root}/share/vulkan" ]]; then
    rmdir "${wcp_root}/share" 2>/dev/null || true
  fi
  if [[ ${removed_count} -gt 0 ]]; then
    wcp_log "Pruned non-whitelisted Vulkan runtime entries from WCP tree (removed=${removed_count})"
  fi
  export WCP_VULKAN_PRUNE_REMOVED_COUNT="${removed_count}"
}

wcp_assert_mainline_external_runtime_clean_tree() {
  local wcp_root="$1"
  local violations

  : "${WCP_MAINLINE_FEX_EXTERNAL_ONLY:=1}"
  wcp_require_bool WCP_MAINLINE_FEX_EXTERNAL_ONLY "${WCP_MAINLINE_FEX_EXTERNAL_ONLY}"
  [[ "${WCP_MAINLINE_FEX_EXTERNAL_ONLY}" == "1" ]] || return 0

  violations="$(wcp_list_external_runtime_policy_hits "${wcp_root}" | LC_ALL=C sort -u || true)"
  [[ -z "${violations}" ]] && return 0

  wcp_fail "Mainline external-runtime policy forbids bundled external runtime payload in WCP:\n${violations}"
}

wcp_prune_external_runtime_components() {
  local wcp_root="$1"
  local report_file="${2:-}"
  local category rel removed_count

  : "${WCP_PRUNE_EXTERNAL_COMPONENTS:=1}"
  wcp_require_bool WCP_PRUNE_EXTERNAL_COMPONENTS "${WCP_PRUNE_EXTERNAL_COMPONENTS}"
  [[ "${WCP_PRUNE_EXTERNAL_COMPONENTS}" == "1" ]] || return 0
  [[ -d "${wcp_root}" ]] || wcp_fail "WCP root not found for prune step: ${wcp_root}"

  removed_count=0
  if [[ -n "${report_file}" ]]; then
    mkdir -p "$(dirname "${report_file}")"
    : > "${report_file}"
  fi

  while IFS=$'\t' read -r category rel; do
    [[ -n "${rel}" ]] || continue
    if [[ -e "${wcp_root}/${rel}" ]]; then
      rm -rf "${wcp_root:?}/${rel}"
      removed_count=$((removed_count + 1))
      if [[ -n "${report_file}" ]]; then
        printf '%s\t%s\n' "${category}" "${rel}" >> "${report_file}"
      fi
    fi
  done < <(wcp_external_runtime_component_paths)

  wcp_prune_external_vulkan_runtime_components "${wcp_root}" "${report_file}"
  removed_count=$((removed_count + ${WCP_VULKAN_PRUNE_REMOVED_COUNT:-0}))

  if [[ -n "${report_file}" && ! -s "${report_file}" ]]; then
    echo "none" > "${report_file}"
  fi
  wcp_log "Pruned external runtime components from WCP tree (removed=${removed_count})"
}

wcp_assert_pruned_external_runtime_components() {
  local wcp_root="$1"
  local category rel
  local hits=""

  : "${WCP_PRUNE_EXTERNAL_COMPONENTS:=1}"
  wcp_require_bool WCP_PRUNE_EXTERNAL_COMPONENTS "${WCP_PRUNE_EXTERNAL_COMPONENTS}"
  [[ "${WCP_PRUNE_EXTERNAL_COMPONENTS}" == "1" ]] || return 0
  [[ -d "${wcp_root}" ]] || wcp_fail "WCP root not found for prune validation: ${wcp_root}"

  while IFS=$'\t' read -r category rel; do
    [[ -n "${rel}" ]] || continue
    if [[ -e "${wcp_root}/${rel}" ]]; then
      hits+="${category}:${rel}"$'\n'
    fi
  done < <(wcp_external_runtime_component_paths)

  if [[ -d "${wcp_root}/share/vulkan" ]]; then
    while IFS= read -r rel; do
      [[ -n "${rel}" ]] || continue
      if ! wcp_is_internal_vulkan_runtime_relpath "${rel}"; then
        hits+="driver:${rel}"$'\n'
      fi
    done < <(find "${wcp_root}/share/vulkan" -mindepth 1 -printf 'share/vulkan/%P\n' | LC_ALL=C sort -u)
  fi

  [[ -z "${hits}" ]] || wcp_fail "External component prune policy violation in WCP tree:\n${hits%$'\n'}"
}

wcp_write_external_runtime_component_audit() {
  local wcp_root="$1"
  local out_file="$2"
  local category rel present

  [[ -d "${wcp_root}" ]] || wcp_fail "WCP root not found for external component audit: ${wcp_root}"
  mkdir -p "$(dirname "${out_file}")"
  {
    printf 'category\tpath\tpresent\n'
    while IFS=$'\t' read -r category rel; do
      [[ -n "${rel}" ]] || continue
      present=0
      [[ -e "${wcp_root}/${rel}" ]] && present=1
      printf '%s\t%s\t%s\n' "${category}" "${rel}" "${present}"
    done < <(wcp_external_runtime_component_paths)
  } > "${out_file}"
}

wcp_json_escape() {
  local s="${1-}"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "${s}"
}

wcp_sha256_file() {
  local file="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "${file}" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "${file}" | awk '{print $1}'
  else
    wcp_fail "Neither sha256sum nor shasum is available"
  fi
}

wcp_validate_winlator_profile_identifier() {
  local version_name="$1" version_code="$2"

  # Winlator Ludashi currently parses installed Wine entries through
  # Wine-<versionName>-<versionCode> and strips exactly two trailing chars
  # from identifier, so versionCode must remain one digit.
  [[ "${version_code}" =~ ^[0-9]$ ]] || wcp_fail "WCP_VERSION_CODE must be a single digit for Winlator compatibility (got: ${version_code})"

  # Must map to regex: ^(wine|proton)-([0-9\\.]+)-?([0-9\\.]+)?-(x86|x86_64|arm64ec)$
  [[ "${version_name}" =~ ^[0-9]+([.][0-9]+)*(-[0-9]+([.][0-9]+)*)?-(x86|x86_64|arm64ec)$ ]] || \
    wcp_fail "WCP_VERSION_NAME must be Winlator-parseable (example: 10.32-arm64ec), got: ${version_name}"
}

ensure_prefix_pack() {
  local dst="${1:-${PREFIX_PACK_PATH:-${ROOT_DIR:-$(pwd)}/prefixPack.txz}}"
  local url="${PREFIX_PACK_URL:-}"
  local tmp

  if [[ -f "${dst}" ]]; then
    return
  fi

  [[ -n "${url}" ]] || wcp_fail "prefixPack is missing (${dst}) and PREFIX_PACK_URL is not set (freewine-only policy)"
  wcp_require_cmd curl
  tmp="$(mktemp)"
  wcp_log "Downloading prefixPack.txz from ${url}"
  if ! curl -fL --retry 5 --retry-delay 2 -o "${tmp}" "${url}"; then
    rm -f "${tmp}"
    wcp_fail "Failed to download prefixPack from ${url}"
  fi
  mkdir -p "$(dirname "${dst}")"
  mv "${tmp}" "${dst}"
}

wcp_check_host_arch() {
  local arch
  arch="$(uname -m)"
  if [[ "${arch}" != "aarch64" && "${arch}" != "arm64" ]]; then
    wcp_fail "ARM64 host is required (aarch64/arm64). Current arch: ${arch}"
  fi
}

wcp_try_bootstrap_winevulkan() {
  local wine_src_dir="$1"
  local log_file="${2:-}"
  if [[ "$#" -ge 2 ]]; then
    shift 2
  else
    shift "$#"
  fi

  local make_vulkan_py vk_xml video_xml search_dir
  local -a search_roots cmd

  [[ -d "${wine_src_dir}" ]] || wcp_fail "wine source directory not found: ${wine_src_dir}"
  [[ -f "${wine_src_dir}/include/wine/vulkan.h" ]] && return 0

  make_vulkan_py="${wine_src_dir}/dlls/winevulkan/make_vulkan"
  if [[ ! -f "${make_vulkan_py}" ]]; then
    wcp_log "Skipping make_vulkan bootstrap: missing ${make_vulkan_py}"
    return 0
  fi

  search_roots=(
    "${wine_src_dir}/dlls/winevulkan"
    "${wine_src_dir}/Vulkan-Headers/registry"
  )
  for search_dir in "$@"; do
    [[ -n "${search_dir}" ]] || continue
    search_roots+=(
      "${search_dir}/dlls/winevulkan"
      "${search_dir}/Vulkan-Headers/registry"
      "${search_dir}"
    )
  done

  vk_xml=""
  video_xml=""
  for search_dir in "${search_roots[@]}"; do
    if [[ -f "${search_dir}/vk.xml" ]]; then
      vk_xml="${search_dir}/vk.xml"
      [[ -f "${search_dir}/video.xml" ]] && video_xml="${search_dir}/video.xml"
      break
    fi
  done

  if [[ -z "${vk_xml}" ]]; then
    wcp_log "Skipping make_vulkan bootstrap: vk.xml not found in known registry paths"
    return 0
  fi

  wcp_require_cmd python3
  cmd=(python3 "${make_vulkan_py}" -x "${vk_xml}")
  [[ -n "${video_xml}" ]] && cmd+=(-X "${video_xml}")

  if [[ -n "${log_file}" ]]; then
    mkdir -p "$(dirname -- "${log_file}")"
    "${cmd[@]}" >"${log_file}" 2>&1 || wcp_fail "make_vulkan failed; see ${log_file}"
  else
    "${cmd[@]}"
  fi
}

wcp_ensure_configure_script() {
  local wine_src_dir="$1"
  local need_autoreconf=0

  # Some FreeWine trees miss vendored SPIR-V headers after selective rebases.
  # Seed from known source/system locations before configure to avoid vkd3d probe failures.
  wcp_seed_spirv_headers_for_vkd3d "${wine_src_dir}"
  wcp_seed_spirv_tools_headers_for_vkd3d "${wine_src_dir}"
  wcp_seed_tools_gdbinit_template "${wine_src_dir}"

  if [[ ! -x "${wine_src_dir}/configure" ]]; then
    need_autoreconf=1
    wcp_log "configure is missing in ${wine_src_dir}; will regenerate autotools files"
  fi

  if [[ -f "${wine_src_dir}/configure" ]] && grep -Fq '"$wine_makedep"$makedep_flags -i' "${wine_src_dir}/configure"; then
    need_autoreconf=1
    wcp_log "configure contains legacy makedep -i invocation; will regenerate autotools files"
  fi

  if [[ ! -f "${wine_src_dir}/include/config.h.in" ]]; then
    need_autoreconf=1
    wcp_log "include/config.h.in is missing in ${wine_src_dir}; will regenerate autotools files"
  fi

  if [[ "${need_autoreconf}" -eq 0 ]]; then
    return
  fi

  [[ -f "${wine_src_dir}/configure.ac" ]] || wcp_fail "Missing configure script and configure.ac in ${wine_src_dir}"
  wcp_require_cmd autoreconf

  wcp_log "Running autoreconf -ifv in ${wine_src_dir}"
  pushd "${wine_src_dir}" >/dev/null
  if [[ -x tools/make_requests ]]; then
    tools/make_requests
  fi
  if [[ -x tools/make_specfiles ]]; then
    tools/make_specfiles
  fi
  wcp_try_bootstrap_winevulkan "${wine_src_dir}"
  autoreconf -ifv
  popd >/dev/null

  [[ -f "${wine_src_dir}/configure" ]] || wcp_fail "autoreconf did not produce configure in ${wine_src_dir}"
  [[ -f "${wine_src_dir}/include/config.h.in" ]] || wcp_fail "autoreconf did not produce include/config.h.in in ${wine_src_dir}"
  chmod +x "${wine_src_dir}/configure" || true
}

wcp_seed_spirv_headers_for_vkd3d() {
  local wine_src_dir="$1"
  local target_dir target_header source_dir
  local -a source_dirs=()

  target_dir="${wine_src_dir}/libs/vkd3d/libs/vkd3d-shader/spirv/unified1"
  target_header="${target_dir}/spirv.h"
  [[ -f "${target_header}" ]] && return 0

  source_dirs+=(
    "${WCP_LOCAL_WINE11_ACTIVE_DIR:-}/libs/vkd3d/libs/vkd3d-shader/spirv/unified1"
    "${WCP_LOCAL_WINE11_FALLBACK_DIR:-}/libs/vkd3d/libs/vkd3d-shader/spirv/unified1"
    "/usr/include/spirv/unified1"
  )

  for source_dir in "${source_dirs[@]}"; do
    [[ -n "${source_dir}" ]] || continue
    [[ -f "${source_dir}/spirv.h" ]] || continue
    mkdir -p "${target_dir}"
    cp -a "${source_dir}/." "${target_dir}/"
    wcp_log "Seeded SPIR-V headers for vkd3d from ${source_dir}"
    return 0
  done

  wcp_log "SPIR-V headers were not seeded (no source found for ${target_header})"
}

wcp_seed_spirv_tools_headers_for_vkd3d() {
  local wine_src_dir="$1"
  local target_dir target_header source_dir
  local -a source_dirs=()

  target_dir="${wine_src_dir}/libs/vkd3d/libs/vkd3d-shader/spirv-tools"
  target_header="${target_dir}/libspirv.h"
  [[ -f "${target_header}" ]] && return 0

  source_dirs+=(
    "${WCP_LOCAL_WINE11_ACTIVE_DIR:-}/libs/vkd3d/libs/vkd3d-shader/spirv-tools"
    "${WCP_LOCAL_WINE11_FALLBACK_DIR:-}/libs/vkd3d/libs/vkd3d-shader/spirv-tools"
    "/usr/include/spirv-tools"
  )

  for source_dir in "${source_dirs[@]}"; do
    [[ -n "${source_dir}" ]] || continue
    [[ -f "${source_dir}/libspirv.h" ]] || continue
    mkdir -p "${target_dir}"
    cp -a "${source_dir}/." "${target_dir}/"
    wcp_log "Seeded SPIRV-Tools headers for vkd3d from ${source_dir}"
    return 0
  done

  wcp_log "SPIRV-Tools headers were not seeded (no source found for ${target_header})"
}

wcp_seed_tools_gdbinit_template() {
  local wine_src_dir="$1"
  local template_path

  template_path="${wine_src_dir}/tools/gdbinit.py.in"
  [[ -f "${template_path}" ]] && return 0

  mkdir -p "$(dirname -- "${template_path}")"
  cat > "${template_path}" <<'EOF'
# Auto-generated placeholder for FreeWine runtime CI.
# Full gdb integration templates are optional for WCP packaging.
EOF
  wcp_log "Generated placeholder tools/gdbinit.py.in for makedep compatibility"
}

build_wine_tools_host() {
  local wine_src_dir="$1" build_dir="$2"
  local -a configure_args
  local jobs build_log

  wcp_ensure_configure_script "${wine_src_dir}"
  mkdir -p "${build_dir}"

  pushd "${build_dir}" >/dev/null
  if [[ ! -f Makefile ]]; then
    configure_args=(
      "${wine_src_dir}/configure"
      --prefix=/usr
      --disable-tests
      --with-mingw=clang
      --enable-archs=arm64ec,aarch64,i386
    )
    if [[ -n "${WINE_TOOLS_CONFIGURE_EXTRA_ARGS:-}" ]]; then
      # shellcheck disable=SC2206
      local tools_extra_args=( ${WINE_TOOLS_CONFIGURE_EXTRA_ARGS} )
      configure_args+=("${tools_extra_args[@]}")
    fi
    "${configure_args[@]}"
  fi

  jobs="$(wcp_make_jobs)"
  build_log="$(wcp_build_log_file)"
  if ! wcp_make_with_serial_retry "${jobs}" "${build_log}" tools; then
    wcp_log "make tools target is unavailable; continuing with full build path"
  fi
  popd >/dev/null
}

build_wine_multiarc_arm64ec() {
  local wine_src_dir="$1" build_dir="$2" stage_dir="$3"
  local -a configure_args
  local jobs build_log

  wcp_ensure_configure_script "${wine_src_dir}"

  mkdir -p "${build_dir}" "${stage_dir}"
  pushd "${build_dir}" >/dev/null

  configure_args=(
    "${wine_src_dir}/configure"
    --prefix=/usr
    --disable-tests
    --with-mingw=clang
    --enable-archs=arm64ec,aarch64,i386
  )

  if [[ -n "${WINE_CONFIGURE_PROFILE:-}" ]]; then
    local profile_arg
    while IFS= read -r profile_arg; do
      [[ -n "${profile_arg}" ]] || continue
      configure_args+=("${profile_arg}")
    done < <(wcp_configure_profile_args "${WINE_CONFIGURE_PROFILE}")
    wcp_log "Applied configure profile: ${WINE_CONFIGURE_PROFILE}"
  fi

  # Space-delimited optional extras from caller.
  if [[ -n "${WINE_CONFIGURE_EXTRA_ARGS:-}" ]]; then
    # shellcheck disable=SC2206
    local extra_args=( ${WINE_CONFIGURE_EXTRA_ARGS} )
    configure_args+=("${extra_args[@]}")
  fi

  "${configure_args[@]}"

  if [[ -f config.log ]] && ! grep -Eq 'arm64ec' config.log; then
    wcp_fail "configure did not include ARM64EC target support"
  fi

  jobs="$(wcp_make_jobs)"
  build_log="$(wcp_build_log_file)"

  if ! wcp_make_with_serial_retry "${jobs}" "${build_log}"; then
    wcp_fail "Wine build failed (jobs=${jobs}); see ${build_log:-<stdout>}"
  fi
  if ! wcp_make_logged "1" "${build_log}" install DESTDIR="${stage_dir}"; then
    wcp_fail "Wine install failed; see ${build_log:-<stdout>}"
  fi
  popd >/dev/null
}

generate_winetools_layer() {
  local wcp_root="$1"

  mkdir -p "${wcp_root}/winetools" "${wcp_root}/share/winetools"

  cat > "${wcp_root}/winetools/manifest.txt" <<'MANIFEST'
bin/wine
bin/wineserver
bin/winecfg
bin/regedit
bin/explorer
bin/msiexec
bin/notepad
MANIFEST

  cat > "${wcp_root}/winetools/winetools.sh" <<'WINETOOLS'
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
  chmod +x "${wcp_root}/winetools/winetools.sh"

  {
    echo "== ELF (Unix launchers) =="
    for f in \
      "${wcp_root}/bin/wine" \
      "${wcp_root}/bin/wineserver" \
      "${wcp_root}/bin/wine.glibc-real" \
      "${wcp_root}/bin/wineserver.glibc-real"; do
      [[ -e "${f}" ]] || continue
      echo "--- ${f}"
      file "${f}" || true
      readelf -d "${f}" 2>/dev/null | sed -n '1,120p' || true
    done
  } > "${wcp_root}/share/winetools/linking-report.txt"
}

wcp_materialize_embedded_vulkan_runtime() {
  local wcp_root="$1"
  local wrapper_asset layer_asset runtime_flavor wrapper_mode sdk_version lanes source_url
  local runtime_dir metadata_file validation_manifest validation_present api_dump_present
  local tmp_dir wrapper_stage layer_stage

  : "${ROOT_DIR:=$(cd -- "${WCP_COMMON_DIR}/../.." && pwd)}"
  : "${WCP_EMBED_VULKAN_RUNTIME:=1}"
  : "${WCP_VULKAN_SDK_VERSION:=1.4.341.1}"
  : "${WCP_VULKAN_SDK_LANES:=1.1,1.2,1.3,1.4}"
  : "${WCP_VULKAN_RUNTIME_FLAVOR:=bionic-assets}"
  : "${WCP_VULKAN_WRAPPER_MODE:=embedded-preferred}"
  : "${WCP_VULKAN_SDK_SOURCE_URL:=https://vulkan.lunarg.com/sdk/latest/linux.json}"
  : "${WCP_VULKAN_WRAPPER_ASSET:=${ROOT_DIR}/work/winlator-ludashi/src/app/src/main/assets/graphics_driver/wrapper.tzst}"
  : "${WCP_VULKAN_LAYER_ASSET:=${ROOT_DIR}/work/winlator-ludashi/src/app/src/main/assets/layers.tzst}"

  wcp_require_bool WCP_EMBED_VULKAN_RUNTIME "${WCP_EMBED_VULKAN_RUNTIME}"
  [[ "${WCP_EMBED_VULKAN_RUNTIME}" == "1" ]] || {
    export WCP_VULKAN_RUNTIME_EMBEDDED=0
    export WCP_VULKAN_WRAPPER_ICD_EMBEDDED=0
    export WCP_VULKAN_VALIDATION_LAYER_EMBEDDED=0
    export WCP_VULKAN_API_DUMP_LAYER_EMBEDDED=0
    return 0
  }

  [[ -d "${wcp_root}" ]] || wcp_fail "WCP root not found for Vulkan runtime materialization: ${wcp_root}"
  [[ -f "${WCP_VULKAN_WRAPPER_ASSET}" ]] || wcp_fail "Missing embedded Vulkan wrapper asset: ${WCP_VULKAN_WRAPPER_ASSET}"
  [[ -f "${WCP_VULKAN_LAYER_ASSET}" ]] || wcp_fail "Missing embedded Vulkan layer asset: ${WCP_VULKAN_LAYER_ASSET}"

  sdk_version="${WCP_VULKAN_SDK_VERSION}"
  lanes="${WCP_VULKAN_SDK_LANES}"
  runtime_flavor="${WCP_VULKAN_RUNTIME_FLAVOR}"
  wrapper_mode="${WCP_VULKAN_WRAPPER_MODE}"
  source_url="${WCP_VULKAN_SDK_SOURCE_URL}"
  runtime_dir="${wcp_root}/share/vulkan-sdk/${sdk_version}"
  metadata_file="${runtime_dir}/manifest.json"
  validation_manifest="${wcp_root}/share/vulkan/explicit_layer.d/VkLayer_khronos_validation.json"
  validation_present=0
  api_dump_present=0

  tmp_dir="$(mktemp -d)"
  wrapper_stage="${tmp_dir}/wrapper"
  layer_stage="${tmp_dir}/layers"
  mkdir -p "${wrapper_stage}" "${layer_stage}" "${runtime_dir}"
  tar --zstd -xf "${WCP_VULKAN_WRAPPER_ASSET}" -C "${wrapper_stage}"
  tar --zstd -xf "${WCP_VULKAN_LAYER_ASSET}" -C "${layer_stage}"

  mkdir -p "${wcp_root}/lib" "${wcp_root}/share/vulkan/icd.d" "${wcp_root}/share/vulkan/explicit_layer.d"
  if [[ -d "${wrapper_stage}/usr/lib" ]]; then
    rsync -a "${wrapper_stage}/usr/lib/" "${wcp_root}/lib/"
  fi
  if [[ -d "${wrapper_stage}/usr/share/vulkan/icd.d" ]]; then
    rsync -a "${wrapper_stage}/usr/share/vulkan/icd.d/" "${wcp_root}/share/vulkan/icd.d/"
  fi
  if [[ -f "${layer_stage}/usr/lib/libVkLayer_khronos_validation.so" ]]; then
    cp -f "${layer_stage}/usr/lib/libVkLayer_khronos_validation.so" "${wcp_root}/lib/"
    validation_present=1
    cat > "${validation_manifest}" <<EOF_VALIDATION
{
  "file_format_version": "1.2.0",
  "layer": {
    "name": "VK_LAYER_KHRONOS_validation",
    "type": "GLOBAL",
    "library_path": "../../../lib/libVkLayer_khronos_validation.so",
    "api_version": "1.4.0",
    "implementation_version": 1,
    "description": "Ae.solator embedded bionic validation layer"
  }
}
EOF_VALIDATION
  fi

  cat > "${metadata_file}" <<EOF_VULKAN_RUNTIME
{
  "sdkVersion": "$(wcp_json_escape "${sdk_version}")",
  "sdkSourceUrl": "$(wcp_json_escape "${source_url}")",
  "runtimeFlavor": "$(wcp_json_escape "${runtime_flavor}")",
  "wrapperMode": "$(wcp_json_escape "${wrapper_mode}")",
  "supportedApiLanes": $(wcp_json_array_from_csv "${lanes}"),
  "components": {
    "wrapperIcd": "embedded",
    "validationLayer": "$( [[ ${validation_present} -eq 1 ]] && printf embedded || printf unavailable )",
    "apiDumpLayer": "$( [[ ${api_dump_present} -eq 1 ]] && printf embedded || printf unavailable )"
  },
  "assets": {
    "wrapper": "$(wcp_json_escape "${WCP_VULKAN_WRAPPER_ASSET}")",
    "layers": "$(wcp_json_escape "${WCP_VULKAN_LAYER_ASSET}")"
  }
}
EOF_VULKAN_RUNTIME

  cat > "${runtime_dir}/runtime.env" <<EOF_VULKAN_ENV
WCP_VULKAN_SDK_VERSION=${sdk_version}
WCP_VULKAN_SDK_LANES=${lanes}
WCP_VULKAN_RUNTIME_FLAVOR=${runtime_flavor}
WCP_VULKAN_WRAPPER_MODE=${wrapper_mode}
WCP_VULKAN_WRAPPER_ICD=share/vulkan/icd.d/wrapper_icd.aarch64.json
WCP_VULKAN_VALIDATION_LAYER_JSON=$( [[ ${validation_present} -eq 1 ]] && printf 'share/vulkan/explicit_layer.d/VkLayer_khronos_validation.json' || printf '' )
EOF_VULKAN_ENV

  rm -rf "${tmp_dir}"

  export WCP_VULKAN_RUNTIME_EMBEDDED=1
  export WCP_VULKAN_RUNTIME_FLAVOR="${runtime_flavor}"
  export WCP_VULKAN_WRAPPER_MODE="${wrapper_mode}"
  export WCP_VULKAN_WRAPPER_ICD_EMBEDDED=1
  export WCP_VULKAN_VALIDATION_LAYER_EMBEDDED="${validation_present}"
  export WCP_VULKAN_API_DUMP_LAYER_EMBEDDED="${api_dump_present}"
  export WCP_VULKAN_WRAPPER_ASSET_PATH_EFFECTIVE="${WCP_VULKAN_WRAPPER_ASSET}"
  export WCP_VULKAN_LAYER_ASSET_PATH_EFFECTIVE="${WCP_VULKAN_LAYER_ASSET}"
}

compose_wcp_tree_from_stage() {
  local stage_dir="$1" wcp_root="$2"
  local prefix_pack_path profile_name profile_type utc_now runtime_class_detected unix_abi_detected
  local wine_launcher_abi wineserver_launcher_abi runtime_mismatch_reason emulation_policy

  : "${ROOT_DIR:=$(cd -- "${WCP_COMMON_DIR}/../.." && pwd)}"
  : "${WCP_TARGET_RUNTIME:=winlator-bionic}"
  : "${WCP_RUNTIME_CLASS_TARGET:=bionic-native}"
  : "${WCP_RUNTIME_CLASS_ENFORCE:=1}"
  : "${WCP_VERSION_NAME:=arm64ec}"
  : "${WCP_VERSION_CODE:=0}"
  : "${WCP_DESCRIPTION:=ARM64EC WCP package}"
  : "${WCP_NAME:=arm64ec-wcp}"
  : "${WCP_PROFILE_NAME:=${WCP_NAME}}"
  : "${WCP_PROFILE_TYPE:=Wine}"
  : "${WCP_CHANNEL:=stable}"
  : "${WCP_DELIVERY:=remote}"
  : "${WCP_DISPLAY_CATEGORY:=${WCP_PROFILE_TYPE}}"
  : "${WCP_SOURCE_REPO:=${GITHUB_REPOSITORY:-kosoymiki/wcp-runtime-lanes}}"
  : "${WCP_RELEASE_TAG:=wcp-latest}"
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
  : "${WCP_WRAPPER_POLICY_VERSION:=runtime-v1}"
  : "${WCP_POLICY_SOURCE:=aesolator-mainline}"
  : "${WCP_FALLBACK_SCOPE:=bionic-internal-only}"
  : "${WCP_ARM64_ANDROID_AUTOTUNE_DEFAULT:=1}"
  : "${WCP_ARM64_ANDROID_AUTOTUNE_PROFILE:=auto}"
  if [[ -z "${WCP_GLIBC_SOURCE_MODE+x}" ]]; then
    if [[ "${WCP_RUNTIME_CLASS_TARGET}" == "glibc-wrapped" ]]; then
      WCP_GLIBC_SOURCE_MODE="pinned-source"
    else
      WCP_GLIBC_SOURCE_MODE="host"
    fi
  fi
  : "${WCP_GLIBC_VERSION:=2.43}"
  : "${WCP_GLIBC_TARGET_VERSION:=2.43}"
  : "${WCP_GLIBC_SOURCE_URL:=https://ftp.gnu.org/gnu/glibc/glibc-2.43.tar.xz}"
  : "${WCP_GLIBC_SOURCE_SHA256:=d9c86c6b5dbddb43a3e08270c5844fc5177d19442cf5b8df4be7c07cd5fa3831}"
  : "${WCP_GLIBC_SOURCE_REF:=glibc-2.43}"
  : "${WCP_GLIBC_SOURCE_PATCH_ID:=android-seccomp-rseq-robust-v1}"
  : "${WCP_GLIBC_SOURCE_PATCH_SCRIPT:=}"
  : "${WCP_GLIBC_PATCHSET_ID:=}"
  : "${WCP_GLIBC_RUNTIME_PATCH_OVERLAY_DIR:=}"
  : "${WCP_GLIBC_RUNTIME_PATCH_SCRIPT:=}"
  : "${WCP_RUNTIME_BUNDLE_LOCK_ID:=glibc-2.43-bundle-v1}"
  : "${WCP_RUNTIME_BUNDLE_LOCK_FILE:=}"
  : "${WCP_RUNTIME_BUNDLE_ENFORCE_LOCK:=0}"
  : "${WCP_RUNTIME_BUNDLE_LOCK_MODE:=relaxed-enforce}"
  : "${WCP_INCLUDE_FEX_DLLS:=0}"
  : "${WCP_FEX_EXPECTATION_MODE:=external}"
  : "${WCP_MAINLINE_FEX_EXTERNAL_ONLY:=1}"

  wcp_validate_winlator_profile_identifier "${WCP_VERSION_NAME}" "${WCP_VERSION_CODE}"
  wcp_require_bool WCP_EMBED_VULKAN_RUNTIME "${WCP_EMBED_VULKAN_RUNTIME}"
  wcp_require_enum WCP_RUNTIME_CLASS_TARGET "${WCP_RUNTIME_CLASS_TARGET}" bionic-native glibc-wrapped
  wcp_require_bool WCP_RUNTIME_CLASS_ENFORCE "${WCP_RUNTIME_CLASS_ENFORCE}"
  wcp_require_bool WCP_INCLUDE_FEX_DLLS "${WCP_INCLUDE_FEX_DLLS}"
  wcp_require_bool WCP_MAINLINE_FEX_EXTERNAL_ONLY "${WCP_MAINLINE_FEX_EXTERNAL_ONLY}"
  wcp_require_bool WCP_ARM64_ANDROID_AUTOTUNE_DEFAULT "${WCP_ARM64_ANDROID_AUTOTUNE_DEFAULT}"
  wcp_require_enum WCP_ARM64_ANDROID_AUTOTUNE_PROFILE "${WCP_ARM64_ANDROID_AUTOTUNE_PROFILE}" auto conservative balanced aggressive
  wcp_require_enum WCP_FEX_EXPECTATION_MODE "${WCP_FEX_EXPECTATION_MODE}" external bundled
  if [[ -z "${WCP_GLIBC_SOURCE_PATCH_SCRIPT}" && "${WCP_GLIBC_SOURCE_MODE}" != "host" ]]; then
    local source_patch_default="${ROOT_DIR}/ci/runtime-bundle/source-patches/apply-android-seccomp-compat.sh"
    if [[ -x "${source_patch_default}" ]]; then
      WCP_GLIBC_SOURCE_PATCH_SCRIPT="${source_patch_default}"
    fi
  fi
  [[ -n "${WCP_WRAPPER_POLICY_VERSION}" ]] || wcp_fail "WCP_WRAPPER_POLICY_VERSION must not be empty"
  [[ -n "${WCP_POLICY_SOURCE}" ]] || wcp_fail "WCP_POLICY_SOURCE must not be empty"
  [[ -n "${WCP_FALLBACK_SCOPE}" ]] || wcp_fail "WCP_FALLBACK_SCOPE must not be empty"
  wcp_enforce_mainline_bionic_policy
  wcp_enforce_mainline_external_runtime_policy

  prefix_pack_path="${PREFIX_PACK_PATH:-${ROOT_DIR}/prefixPack.txz}"
  ensure_prefix_pack "${prefix_pack_path}"
  profile_name="${WCP_PROFILE_NAME}"
  profile_type="${WCP_PROFILE_TYPE}"

  [[ -d "${stage_dir}/usr" ]] || wcp_fail "Stage is missing usr/ payload: ${stage_dir}/usr"

  rm -rf "${wcp_root}"
  mkdir -p "${wcp_root}"
  rsync -a "${stage_dir}/usr/" "${wcp_root}/"

  mkdir -p "${wcp_root}/share"
  cp -f "${prefix_pack_path}" "${wcp_root}/prefixPack.txz"

  winlator_preflight_bionic_source_contract
  winlator_adopt_bionic_unix_core_modules "${wcp_root}"
  winlator_adopt_bionic_launchers "${wcp_root}"
  winlator_wrap_glibc_launchers
  winlator_ensure_arm64ec_unix_loader_compat_links "${wcp_root}"
  generate_winetools_layer "${wcp_root}"
  wcp_materialize_embedded_vulkan_runtime "${wcp_root}"
  runtime_class_detected="$(winlator_detect_runtime_class "${wcp_root}")"
  unix_abi_detected="$(winlator_detect_unix_module_abi "${wcp_root}")"
  wine_launcher_abi="$(winlator_detect_launcher_abi "${wcp_root}/bin/wine")"
  wineserver_launcher_abi="$(winlator_detect_launcher_abi "${wcp_root}/bin/wineserver")"
  runtime_mismatch_reason="$(winlator_detect_runtime_mismatch_reason "${wcp_root}" "${WCP_RUNTIME_CLASS_TARGET}")"
  emulation_policy="runtime-mixed"
  [[ "${WCP_MAINLINE_FEX_EXTERNAL_ONLY}" == "1" ]] && emulation_policy="fex-external-only"

  utc_now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  cat > "${wcp_root}/profile.json" <<EOF_PROFILE
{
  "type": "${profile_type}",
  "name": "${profile_name}",
  "versionName": "${WCP_VERSION_NAME}",
  "versionCode": ${WCP_VERSION_CODE},
  "description": "${WCP_DESCRIPTION}",
  "channel": "$(wcp_json_escape "${WCP_CHANNEL}")",
  "delivery": "$(wcp_json_escape "${WCP_DELIVERY}")",
  "displayCategory": "$(wcp_json_escape "${WCP_DISPLAY_CATEGORY}")",
  "sourceRepo": "$(wcp_json_escape "${WCP_SOURCE_REPO}")",
  "sourceType": "$(wcp_json_escape "${WCP_SOURCE_TYPE}")",
  "sourceVersion": "$(wcp_json_escape "${WCP_SOURCE_VERSION}")",
  "releaseTag": "$(wcp_json_escape "${WCP_RELEASE_TAG}")",
  "artifactName": "$(wcp_json_escape "${WCP_ARTIFACT_NAME}")",
  "sha256Url": "$(wcp_json_escape "${WCP_SHA256_URL}")",
  "files": [],
  "wine": {
    "binPath": "bin",
    "libPath": "lib",
    "prefixPack": "prefixPack.txz"
  },
  "vulkan": {
    "embeddedRuntime": ${WCP_EMBED_VULKAN_RUNTIME},
    "sdkVersion": "$(wcp_json_escape "${WCP_VULKAN_SDK_VERSION}")",
    "apiLane": "$(wcp_json_escape "${WCP_VULKAN_API_LANE}")",
    "supportedApiLanes": $(wcp_json_array_from_csv "${WCP_VULKAN_SDK_LANES}"),
    "sdkSourceUrl": "$(wcp_json_escape "${WCP_VULKAN_SDK_SOURCE_URL}")",
    "toolsConfigureMode": "$(wcp_json_escape "${WCP_VULKAN_TOOLS_CONFIGURE_MODE}")",
    "runtimeFlavor": "$(wcp_json_escape "${WCP_VULKAN_RUNTIME_FLAVOR}")",
    "wrapperMode": "$(wcp_json_escape "${WCP_VULKAN_WRAPPER_MODE}")",
    "wrapperIcdEmbedded": "$(wcp_json_escape "${WCP_VULKAN_WRAPPER_ICD_EMBEDDED:-0}")",
    "validationLayerEmbedded": "$(wcp_json_escape "${WCP_VULKAN_VALIDATION_LAYER_EMBEDDED:-0}")",
    "apiDumpLayerEmbedded": "$(wcp_json_escape "${WCP_VULKAN_API_DUMP_LAYER_EMBEDDED:-0}")"
  },
  "runtime": {
    "target": "${WCP_TARGET_RUNTIME}",
    "runtimeClassTarget": "$(wcp_json_escape "${WCP_RUNTIME_CLASS_TARGET}")",
    "runtimeClassDetected": "$(wcp_json_escape "${runtime_class_detected}")",
    "unixAbiDetected": "$(wcp_json_escape "${unix_abi_detected}")",
    "wineLauncherAbi": "$(wcp_json_escape "${wine_launcher_abi}")",
    "wineserverLauncherAbi": "$(wcp_json_escape "${wineserver_launcher_abi}")",
    "runtimeMismatchReason": "$(wcp_json_escape "${runtime_mismatch_reason}")",
    "runtimeClassAutoPromoted": "$(wcp_json_escape "${WCP_RUNTIME_CLASS_AUTO_PROMOTED:-0}")",
    "emulationPolicy": "$(wcp_json_escape "${emulation_policy}")",
    "wrapperPolicyVersion": "$(wcp_json_escape "${WCP_WRAPPER_POLICY_VERSION}")",
    "policySource": "$(wcp_json_escape "${WCP_POLICY_SOURCE}")",
    "fallbackScope": "$(wcp_json_escape "${WCP_FALLBACK_SCOPE}")",
    "arm64AndroidAutotune": {
      "enabledByDefault": "$(wcp_json_escape "${WCP_ARM64_ANDROID_AUTOTUNE_DEFAULT}")",
      "defaultProfile": "$(wcp_json_escape "${WCP_ARM64_ANDROID_AUTOTUNE_PROFILE}")",
      "profileMode": "soc-auto-matrix",
      "matrixVersion": "android-arm64-v1",
      "socMap": {
        "entry": "conservative",
        "mid-range": "balanced",
        "high-end": "aggressive"
      },
      "entrypoint": "ntdll-unix-loader-jni"
    },
    "bionicSourceMapApplied": "$(wcp_json_escape "${WCP_BIONIC_SOURCE_MAP_APPLIED:-0}")",
    "bionicSourceMapPath": "$(wcp_json_escape "${WCP_BIONIC_SOURCE_MAP_PATH_EFFECTIVE:-${WCP_BIONIC_SOURCE_MAP_FILE:-}}")",
    "bionicSourceMapSha256": "$(wcp_json_escape "${WCP_BIONIC_SOURCE_MAP_SHA256:-}")",
    "bionicLauncherSourceWcpUrl": "$(wcp_json_escape "${WCP_BIONIC_LAUNCHER_SOURCE_WCP_URL:-}")",
    "bionicLauncherSourceSha256": "$(wcp_json_escape "${WCP_BIONIC_LAUNCHER_SOURCE_WCP_SHA256:-}")",
    "bionicLauncherSourceSha256Alternates": "$(wcp_json_escape "${WCP_BIONIC_LAUNCHER_SOURCE_WCP_SHA256_ALTERNATES:-}")",
    "bionicUnixSourceWcpUrl": "$(wcp_json_escape "${WCP_BIONIC_UNIX_SOURCE_WCP_URL:-}")",
    "bionicUnixSourceSha256": "$(wcp_json_escape "${WCP_BIONIC_UNIX_SOURCE_WCP_SHA256:-}")",
    "bionicUnixSourceSha256Alternates": "$(wcp_json_escape "${WCP_BIONIC_UNIX_SOURCE_WCP_SHA256_ALTERNATES:-}")",
    "bionicLauncherSourceResolvedPath": "$(wcp_json_escape "${WCP_BIONIC_LAUNCHER_SOURCE_WCP_RESOLVED_PATH:-}")",
    "bionicLauncherSourceResolvedSha256": "$(wcp_json_escape "${WCP_BIONIC_LAUNCHER_SOURCE_WCP_RESOLVED_SHA256:-}")",
    "bionicUnixSourceResolvedPath": "$(wcp_json_escape "${WCP_BIONIC_UNIX_SOURCE_WCP_RESOLVED_PATH:-}")",
    "bionicUnixSourceResolvedSha256": "$(wcp_json_escape "${WCP_BIONIC_UNIX_SOURCE_WCP_RESOLVED_SHA256:-}")",
    "bionicUnixCoreAdopt": "$(wcp_json_escape "${WCP_BIONIC_UNIX_CORE_ADOPT:-0}")",
    "bionicUnixCoreModules": "$(wcp_json_escape "${WCP_BIONIC_UNIX_CORE_MODULES:-}")",
    "bionicDonorPreflightDone": "$(wcp_json_escape "${WCP_BIONIC_DONOR_PREFLIGHT_DONE:-0}")",
    "boxedRuntimeInWcpDetected": false,
    "policyViolationReason": "none",
    "fexExpectationMode": "$(wcp_json_escape "${WCP_FEX_EXPECTATION_MODE}")",
    "fexBundledInWcp": ${WCP_INCLUDE_FEX_DLLS}
  },
  "built": "${utc_now}"
}
EOF_PROFILE
}

wcp_write_forensic_manifest() {
  local wcp_root="$1"
  local forensic_root manifest_file source_refs_file env_file index_file hashes_file utc_now repo_commit repo_remote
  local external_runtime_audit_file unix_module_abi_file bionic_source_entry_file
  local glibc_runtime_index glibc_runtime_markers glibc_runtime_present
  local glibc_stage_reports_index glibc_stage_reports_dir
  local fex_bundled_present=0 boxed_runtime_detected=0
  local -a critical_paths
  local rel hash runtime_class_detected unix_abi_detected wine_launcher_abi wineserver_launcher_abi runtime_mismatch_reason module_abi
  local emulation_policy policy_violation_reason policy_violations_file policy_hits

  : "${WCP_FORENSICS_ALWAYS_ON:=1}"
  [[ "${WCP_FORENSICS_ALWAYS_ON}" == "1" ]] || return 0
  [[ -d "${wcp_root}" ]] || wcp_fail "WCP root not found for forensic manifest: ${wcp_root}"

  forensic_root="${wcp_root}/share/wcp-forensics"
  mkdir -p "${forensic_root}"
  manifest_file="${forensic_root}/manifest.json"
  source_refs_file="${forensic_root}/source-refs.json"
  env_file="${forensic_root}/build-env.txt"
  index_file="${forensic_root}/file-index.txt"
  hashes_file="${forensic_root}/critical-sha256.tsv"
  external_runtime_audit_file="${forensic_root}/external-runtime-components.tsv"
  unix_module_abi_file="${forensic_root}/unix-module-abi.tsv"
  bionic_source_entry_file="${forensic_root}/bionic-source-entry.json"
  policy_violations_file="${forensic_root}/policy-violations.txt"
  glibc_runtime_index="${forensic_root}/glibc-runtime-libs.tsv"
  glibc_runtime_markers="${forensic_root}/glibc-runtime-version-markers.tsv"
  glibc_stage_reports_index="${forensic_root}/glibc-stage-reports-index.tsv"
  glibc_stage_reports_dir="${forensic_root}/glibc-stage-reports"
  utc_now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  repo_commit=""
  repo_remote=""
  if [[ -n "${ROOT_DIR:-}" && -d "${ROOT_DIR}/.git" ]]; then
    repo_commit="$(git -C "${ROOT_DIR}" rev-parse HEAD 2>/dev/null || true)"
    repo_remote="$(git -C "${ROOT_DIR}" remote get-url origin 2>/dev/null || true)"
  fi

  find "${wcp_root}" -type f -printf '%P\t%s\n' | LC_ALL=C sort > "${index_file}"

  critical_paths=(
    "profile.json"
    "bin/wine"
    "bin/wineserver"
    "bin/wine.glibc-real"
    "bin/wineserver.glibc-real"
    "lib/wine/aarch64-unix/ntdll.so"
    "lib/wine/aarch64-unix/win32u.so"
    "lib/wine/aarch64-unix/ws2_32.so"
    "lib/wine/aarch64-unix/winevulkan.so"
    "lib/wine/aarch64-unix/winebus.so"
    "lib/wine/aarch64-unix/winebus.sys.so"
    "lib/wine/aarch64-unix/wineusb.so"
    "lib/wine/aarch64-unix/wineusb.sys.so"
    "lib/wine/aarch64-windows/wineusb.sys"
    "lib/wine/aarch64-windows/winusb.dll"
    "lib/wine/i386-windows/winusb.dll"
    "lib/wine/wcp-glibc-runtime/ld-linux-aarch64.so.1"
    "lib/wine/wcp-glibc-runtime/libc.so.6"
    "lib/wine/wcp-glibc-runtime/libstdc++.so.6"
    "lib/wine/wcp-glibc-runtime/libgcc_s.so.1"
    "lib/wine/wcp-glibc-runtime/libSDL2-2.0.so.0"
    "prefixPack.txz"
  )

  : > "${hashes_file}"
  for rel in "${critical_paths[@]}"; do
    if [[ -f "${wcp_root}/${rel}" ]]; then
      hash="$(wcp_sha256_file "${wcp_root}/${rel}")"
      printf '%s\t%s\n' "${rel}" "${hash}" >> "${hashes_file}"
    else
      printf '%s\t%s\n' "${rel}" "MISSING" >> "${hashes_file}"
    fi
  done

  {
    echo "generatedAt=${utc_now}"
    echo "WCP_NAME=${WCP_NAME:-}"
    echo "WCP_VERSION_NAME=${WCP_VERSION_NAME:-}"
    echo "WCP_VERSION_CODE=${WCP_VERSION_CODE:-}"
    echo "WCP_PROFILE_NAME=${WCP_PROFILE_NAME:-}"
    echo "WCP_PROFILE_TYPE=${WCP_PROFILE_TYPE:-Wine}"
    echo "WCP_CHANNEL=${WCP_CHANNEL:-stable}"
    echo "WCP_DELIVERY=${WCP_DELIVERY:-remote}"
    echo "WCP_DISPLAY_CATEGORY=${WCP_DISPLAY_CATEGORY:-}"
    echo "WCP_SOURCE_REPO=${WCP_SOURCE_REPO:-}"
    echo "WCP_SOURCE_TYPE=${WCP_SOURCE_TYPE:-}"
    echo "WCP_SOURCE_VERSION=${WCP_SOURCE_VERSION:-}"
    echo "WCP_RELEASE_TAG=${WCP_RELEASE_TAG:-}"
    echo "WCP_ARTIFACT_NAME=${WCP_ARTIFACT_NAME:-}"
    echo "WCP_SHA256_URL=${WCP_SHA256_URL:-}"
    echo "WCP_WRAPPER_POLICY_VERSION=${WCP_WRAPPER_POLICY_VERSION:-runtime-v1}"
    echo "WCP_POLICY_SOURCE=${WCP_POLICY_SOURCE:-aesolator-mainline}"
    echo "WCP_FALLBACK_SCOPE=${WCP_FALLBACK_SCOPE:-bionic-internal-only}"
    echo "WCP_ARM64_ANDROID_AUTOTUNE_DEFAULT=${WCP_ARM64_ANDROID_AUTOTUNE_DEFAULT:-1}"
    echo "WCP_ARM64_ANDROID_AUTOTUNE_PROFILE=${WCP_ARM64_ANDROID_AUTOTUNE_PROFILE:-auto}"
    echo "WCP_TARGET_RUNTIME=${WCP_TARGET_RUNTIME:-}"
    echo "WCP_RUNTIME_CLASS_TARGET=${WCP_RUNTIME_CLASS_TARGET:-}"
    echo "WCP_RUNTIME_CLASS_ENFORCE=${WCP_RUNTIME_CLASS_ENFORCE:-}"
    echo "WCP_RUNTIME_CLASS_AUTO_PROMOTED=${WCP_RUNTIME_CLASS_AUTO_PROMOTED:-0}"
    echo "WCP_RUNTIME_UNIX_ABI_DETECTED=$(winlator_detect_unix_module_abi "${wcp_root}")"
    echo "WCP_RUNTIME_WINE_LAUNCHER_ABI=$(winlator_detect_launcher_abi "${wcp_root}/bin/wine")"
    echo "WCP_RUNTIME_WINESERVER_LAUNCHER_ABI=$(winlator_detect_launcher_abi "${wcp_root}/bin/wineserver")"
    echo "WCP_RUNTIME_MISMATCH_REASON=$(winlator_detect_runtime_mismatch_reason "${wcp_root}" "${WCP_RUNTIME_CLASS_TARGET:-bionic-native}")"
    echo "WCP_ALLOW_GLIBC_EXPERIMENTAL=${WCP_ALLOW_GLIBC_EXPERIMENTAL:-0}"
    echo "WCP_MAINLINE_BIONIC_ONLY=${WCP_MAINLINE_BIONIC_ONLY:-1}"
    echo "WCP_GLIBC_SOURCE_MODE=${WCP_GLIBC_SOURCE_MODE:-}"
    echo "WCP_GLIBC_VERSION=${WCP_GLIBC_VERSION:-}"
    echo "WCP_GLIBC_TARGET_VERSION=${WCP_GLIBC_TARGET_VERSION:-}"
    echo "WCP_GLIBC_SOURCE_URL=${WCP_GLIBC_SOURCE_URL:-}"
    echo "WCP_GLIBC_SOURCE_SHA256=${WCP_GLIBC_SOURCE_SHA256:-}"
    echo "WCP_GLIBC_SOURCE_REF=${WCP_GLIBC_SOURCE_REF:-}"
    echo "WCP_GLIBC_SOURCE_PATCH_ID=${WCP_GLIBC_SOURCE_PATCH_ID:-}"
    echo "WCP_GLIBC_SOURCE_PATCH_SCRIPT=${WCP_GLIBC_SOURCE_PATCH_SCRIPT:-}"
    echo "WCP_GLIBC_PATCHSET_ID=${WCP_GLIBC_PATCHSET_ID:-}"
    echo "WCP_GLIBC_RUNTIME_PATCH_OVERLAY_DIR=${WCP_GLIBC_RUNTIME_PATCH_OVERLAY_DIR:-}"
    echo "WCP_GLIBC_RUNTIME_PATCH_SCRIPT=${WCP_GLIBC_RUNTIME_PATCH_SCRIPT:-}"
    echo "WCP_RUNTIME_BUNDLE_LOCK_ID=${WCP_RUNTIME_BUNDLE_LOCK_ID:-}"
    echo "WCP_RUNTIME_BUNDLE_LOCK_FILE=${WCP_RUNTIME_BUNDLE_LOCK_FILE:-}"
    echo "WCP_RUNTIME_BUNDLE_ENFORCE_LOCK=${WCP_RUNTIME_BUNDLE_ENFORCE_LOCK:-}"
    echo "WCP_RUNTIME_BUNDLE_LOCK_MODE=${WCP_RUNTIME_BUNDLE_LOCK_MODE:-}"
    echo "WCP_PRUNE_EXTERNAL_COMPONENTS=${WCP_PRUNE_EXTERNAL_COMPONENTS:-1}"
    echo "WCP_INCLUDE_FEX_DLLS=${WCP_INCLUDE_FEX_DLLS:-}"
    echo "WCP_FEX_EXPECTATION_MODE=${WCP_FEX_EXPECTATION_MODE:-}"
    echo "WCP_MAINLINE_FEX_EXTERNAL_ONLY=${WCP_MAINLINE_FEX_EXTERNAL_ONLY:-1}"
    echo "WCP_BIONIC_LAUNCHER_SOURCE_WCP_PATH=${WCP_BIONIC_LAUNCHER_SOURCE_WCP_PATH:-}"
    echo "WCP_BIONIC_LAUNCHER_SOURCE_WCP_URL=${WCP_BIONIC_LAUNCHER_SOURCE_WCP_URL:-}"
    echo "WCP_BIONIC_LAUNCHER_SOURCE_WCP_SHA256=${WCP_BIONIC_LAUNCHER_SOURCE_WCP_SHA256:-}"
    echo "WCP_BIONIC_LAUNCHER_SOURCE_WCP_SHA256_ALTERNATES=${WCP_BIONIC_LAUNCHER_SOURCE_WCP_SHA256_ALTERNATES:-}"
    echo "WCP_BIONIC_SOURCE_MAP_FILE=${WCP_BIONIC_SOURCE_MAP_FILE:-}"
    echo "WCP_BIONIC_SOURCE_MAP_PATH_EFFECTIVE=${WCP_BIONIC_SOURCE_MAP_PATH_EFFECTIVE:-${WCP_BIONIC_SOURCE_MAP_FILE:-}}"
    echo "WCP_BIONIC_SOURCE_MAP_SHA256=${WCP_BIONIC_SOURCE_MAP_SHA256:-}"
    echo "WCP_BIONIC_SOURCE_MAP_FORCE=${WCP_BIONIC_SOURCE_MAP_FORCE:-1}"
    echo "WCP_BIONIC_SOURCE_MAP_REQUIRED=${WCP_BIONIC_SOURCE_MAP_REQUIRED:-0}"
    echo "WCP_BIONIC_SOURCE_MAP_APPLIED=${WCP_BIONIC_SOURCE_MAP_APPLIED:-0}"
    echo "WCP_BIONIC_SOURCE_MAP_RESOLVED=${WCP_BIONIC_SOURCE_MAP_RESOLVED:-0}"
    echo "WCP_BIONIC_UNIX_SOURCE_WCP_PATH=${WCP_BIONIC_UNIX_SOURCE_WCP_PATH:-}"
    echo "WCP_BIONIC_UNIX_SOURCE_WCP_URL=${WCP_BIONIC_UNIX_SOURCE_WCP_URL:-}"
    echo "WCP_BIONIC_UNIX_SOURCE_WCP_SHA256=${WCP_BIONIC_UNIX_SOURCE_WCP_SHA256:-}"
    echo "WCP_BIONIC_UNIX_SOURCE_WCP_SHA256_ALTERNATES=${WCP_BIONIC_UNIX_SOURCE_WCP_SHA256_ALTERNATES:-}"
    echo "WCP_BIONIC_UNIX_CORE_ADOPT=${WCP_BIONIC_UNIX_CORE_ADOPT:-0}"
    echo "WCP_BIONIC_UNIX_CORE_MODULES=${WCP_BIONIC_UNIX_CORE_MODULES:-}"
    echo "WCP_BIONIC_LAUNCHER_SOURCE_WCP_RESOLVED_PATH=${WCP_BIONIC_LAUNCHER_SOURCE_WCP_RESOLVED_PATH:-}"
    echo "WCP_BIONIC_LAUNCHER_SOURCE_WCP_RESOLVED_SHA256=${WCP_BIONIC_LAUNCHER_SOURCE_WCP_RESOLVED_SHA256:-}"
    echo "WCP_BIONIC_UNIX_SOURCE_WCP_RESOLVED_PATH=${WCP_BIONIC_UNIX_SOURCE_WCP_RESOLVED_PATH:-}"
    echo "WCP_BIONIC_UNIX_SOURCE_WCP_RESOLVED_SHA256=${WCP_BIONIC_UNIX_SOURCE_WCP_RESOLVED_SHA256:-}"
    echo "WCP_BIONIC_DONOR_PREFLIGHT_DONE=${WCP_BIONIC_DONOR_PREFLIGHT_DONE:-0}"
    echo "WCP_COMPRESS=${WCP_COMPRESS:-}"
    echo "TARGET_HOST=${TARGET_HOST:-}"
    echo "LLVM_MINGW_TAG=${LLVM_MINGW_TAG:-}"
    echo "STRIP_STAGE=${STRIP_STAGE:-}"
  } > "${env_file}"

  cat > "${source_refs_file}" <<EOF_SOURCE_REFS
{
  "repo": {
    "origin": "$(wcp_json_escape "${repo_remote}")",
    "commit": "$(wcp_json_escape "${repo_commit}")"
  },
  "inputs": {
    "WINE_REPO": "$(wcp_json_escape "${WINE_REPO:-}")",
    "WINE_BRANCH": "$(wcp_json_escape "${WINE_BRANCH:-}")",
    "WINE_REF": "$(wcp_json_escape "${WINE_REF:-}")",
    "VALVE_WINE_REPO": "$(wcp_json_escape "${VALVE_WINE_REPO:-}")",
    "VALVE_WINE_REF": "$(wcp_json_escape "${VALVE_WINE_REF:-}")",
    "ANDRE_WINE_REPO": "$(wcp_json_escape "${ANDRE_WINE_REPO:-}")",
    "ANDRE_ARM64EC_REF": "$(wcp_json_escape "${ANDRE_ARM64EC_REF:-}")",
    "PROTON_GE_REPO": "$(wcp_json_escape "${PROTON_GE_REPO:-}")",
    "PROTON_GE_REF": "$(wcp_json_escape "${PROTON_GE_REF:-}")",
    "PROTONWINE_REPO": "$(wcp_json_escape "${PROTONWINE_REPO:-}")",
    "PROTONWINE_REF": "$(wcp_json_escape "${PROTONWINE_REF:-}")",
    "HANGOVER_REPO": "$(wcp_json_escape "${HANGOVER_REPO:-}")",
    "FEX_SOURCE_MODE": "$(wcp_json_escape "${FEX_SOURCE_MODE:-}")",
    "WCP_GLIBC_SOURCE_MODE": "$(wcp_json_escape "${WCP_GLIBC_SOURCE_MODE:-}")",
    "WCP_GLIBC_VERSION": "$(wcp_json_escape "${WCP_GLIBC_VERSION:-}")",
    "WCP_GLIBC_TARGET_VERSION": "$(wcp_json_escape "${WCP_GLIBC_TARGET_VERSION:-}")",
    "WCP_GLIBC_SOURCE_URL": "$(wcp_json_escape "${WCP_GLIBC_SOURCE_URL:-}")",
    "WCP_GLIBC_SOURCE_SHA256": "$(wcp_json_escape "${WCP_GLIBC_SOURCE_SHA256:-}")",
    "WCP_GLIBC_SOURCE_REF": "$(wcp_json_escape "${WCP_GLIBC_SOURCE_REF:-}")",
    "WCP_GLIBC_SOURCE_PATCH_ID": "$(wcp_json_escape "${WCP_GLIBC_SOURCE_PATCH_ID:-}")",
    "WCP_GLIBC_SOURCE_PATCH_SCRIPT": "$(wcp_json_escape "${WCP_GLIBC_SOURCE_PATCH_SCRIPT:-}")",
    "WCP_GLIBC_PATCHSET_ID": "$(wcp_json_escape "${WCP_GLIBC_PATCHSET_ID:-}")",
    "WCP_GLIBC_RUNTIME_PATCH_OVERLAY_DIR": "$(wcp_json_escape "${WCP_GLIBC_RUNTIME_PATCH_OVERLAY_DIR:-}")",
    "WCP_GLIBC_RUNTIME_PATCH_SCRIPT": "$(wcp_json_escape "${WCP_GLIBC_RUNTIME_PATCH_SCRIPT:-}")",
    "WCP_CHANNEL": "$(wcp_json_escape "${WCP_CHANNEL:-stable}")",
    "WCP_DELIVERY": "$(wcp_json_escape "${WCP_DELIVERY:-remote}")",
    "WCP_DISPLAY_CATEGORY": "$(wcp_json_escape "${WCP_DISPLAY_CATEGORY:-}")",
    "WCP_SOURCE_REPO": "$(wcp_json_escape "${WCP_SOURCE_REPO:-}")",
    "WCP_SOURCE_TYPE": "$(wcp_json_escape "${WCP_SOURCE_TYPE:-}")",
    "WCP_SOURCE_VERSION": "$(wcp_json_escape "${WCP_SOURCE_VERSION:-}")",
    "WCP_RELEASE_TAG": "$(wcp_json_escape "${WCP_RELEASE_TAG:-}")",
    "WCP_ARTIFACT_NAME": "$(wcp_json_escape "${WCP_ARTIFACT_NAME:-}")",
    "WCP_SHA256_URL": "$(wcp_json_escape "${WCP_SHA256_URL:-}")",
    "WCP_EMBED_VULKAN_RUNTIME": "$(wcp_json_escape "${WCP_EMBED_VULKAN_RUNTIME:-1}")",
    "WCP_VULKAN_SDK_VERSION": "$(wcp_json_escape "${WCP_VULKAN_SDK_VERSION:-}")",
    "WCP_VULKAN_API_LANE": "$(wcp_json_escape "${WCP_VULKAN_API_LANE:-}")",
    "WCP_VULKAN_SDK_LANES": "$(wcp_json_escape "${WCP_VULKAN_SDK_LANES:-}")",
    "WCP_VULKAN_SDK_SOURCE_URL": "$(wcp_json_escape "${WCP_VULKAN_SDK_SOURCE_URL:-}")",
    "WCP_VULKAN_TOOLS_CONFIGURE_MODE": "$(wcp_json_escape "${WCP_VULKAN_TOOLS_CONFIGURE_MODE:-}")",
    "WCP_VULKAN_RUNTIME_FLAVOR": "$(wcp_json_escape "${WCP_VULKAN_RUNTIME_FLAVOR:-}")",
    "WCP_VULKAN_WRAPPER_MODE": "$(wcp_json_escape "${WCP_VULKAN_WRAPPER_MODE:-}")",
    "WCP_VULKAN_WRAPPER_ICD_EMBEDDED": "$(wcp_json_escape "${WCP_VULKAN_WRAPPER_ICD_EMBEDDED:-0}")",
    "WCP_VULKAN_VALIDATION_LAYER_EMBEDDED": "$(wcp_json_escape "${WCP_VULKAN_VALIDATION_LAYER_EMBEDDED:-0}")",
    "WCP_VULKAN_API_DUMP_LAYER_EMBEDDED": "$(wcp_json_escape "${WCP_VULKAN_API_DUMP_LAYER_EMBEDDED:-0}")",
    "WCP_VULKAN_WRAPPER_ASSET_PATH_EFFECTIVE": "$(wcp_json_escape "${WCP_VULKAN_WRAPPER_ASSET_PATH_EFFECTIVE:-}")",
    "WCP_VULKAN_LAYER_ASSET_PATH_EFFECTIVE": "$(wcp_json_escape "${WCP_VULKAN_LAYER_ASSET_PATH_EFFECTIVE:-}")",
    "WCP_WRAPPER_POLICY_VERSION": "$(wcp_json_escape "${WCP_WRAPPER_POLICY_VERSION:-runtime-v1}")",
    "WCP_POLICY_SOURCE": "$(wcp_json_escape "${WCP_POLICY_SOURCE:-aesolator-mainline}")",
    "WCP_FALLBACK_SCOPE": "$(wcp_json_escape "${WCP_FALLBACK_SCOPE:-bionic-internal-only}")",
    "WCP_RUNTIME_CLASS_TARGET": "$(wcp_json_escape "${WCP_RUNTIME_CLASS_TARGET:-}")",
    "WCP_RUNTIME_CLASS_ENFORCE": "$(wcp_json_escape "${WCP_RUNTIME_CLASS_ENFORCE:-}")",
    "WCP_RUNTIME_CLASS_AUTO_PROMOTED": "$(wcp_json_escape "${WCP_RUNTIME_CLASS_AUTO_PROMOTED:-0}")",
    "WCP_RUNTIME_UNIX_ABI_DETECTED": "$(wcp_json_escape "$(winlator_detect_unix_module_abi "${wcp_root}")")",
    "WCP_RUNTIME_WINE_LAUNCHER_ABI": "$(wcp_json_escape "$(winlator_detect_launcher_abi "${wcp_root}/bin/wine")")",
    "WCP_RUNTIME_WINESERVER_LAUNCHER_ABI": "$(wcp_json_escape "$(winlator_detect_launcher_abi "${wcp_root}/bin/wineserver")")",
    "WCP_RUNTIME_MISMATCH_REASON": "$(wcp_json_escape "$(winlator_detect_runtime_mismatch_reason "${wcp_root}" "${WCP_RUNTIME_CLASS_TARGET:-bionic-native}")")",
    "WCP_ALLOW_GLIBC_EXPERIMENTAL": "$(wcp_json_escape "${WCP_ALLOW_GLIBC_EXPERIMENTAL:-0}")",
    "WCP_MAINLINE_BIONIC_ONLY": "$(wcp_json_escape "${WCP_MAINLINE_BIONIC_ONLY:-1}")",
    "WCP_RUNTIME_BUNDLE_LOCK_ID": "$(wcp_json_escape "${WCP_RUNTIME_BUNDLE_LOCK_ID:-}")",
    "WCP_RUNTIME_BUNDLE_LOCK_FILE": "$(wcp_json_escape "${WCP_RUNTIME_BUNDLE_LOCK_FILE:-}")",
    "WCP_RUNTIME_BUNDLE_ENFORCE_LOCK": "$(wcp_json_escape "${WCP_RUNTIME_BUNDLE_ENFORCE_LOCK:-}")",
    "WCP_RUNTIME_BUNDLE_LOCK_MODE": "$(wcp_json_escape "${WCP_RUNTIME_BUNDLE_LOCK_MODE:-}")",
    "WCP_PRUNE_EXTERNAL_COMPONENTS": "$(wcp_json_escape "${WCP_PRUNE_EXTERNAL_COMPONENTS:-1}")",
    "WCP_INCLUDE_FEX_DLLS": "$(wcp_json_escape "${WCP_INCLUDE_FEX_DLLS:-}")",
    "WCP_FEX_EXPECTATION_MODE": "$(wcp_json_escape "${WCP_FEX_EXPECTATION_MODE:-}")",
    "WCP_MAINLINE_FEX_EXTERNAL_ONLY": "$(wcp_json_escape "${WCP_MAINLINE_FEX_EXTERNAL_ONLY:-1}")",
    "WCP_BIONIC_LAUNCHER_SOURCE_WCP_PATH": "$(wcp_json_escape "${WCP_BIONIC_LAUNCHER_SOURCE_WCP_PATH:-}")",
    "WCP_BIONIC_LAUNCHER_SOURCE_WCP_URL": "$(wcp_json_escape "${WCP_BIONIC_LAUNCHER_SOURCE_WCP_URL:-}")",
    "WCP_BIONIC_LAUNCHER_SOURCE_WCP_SHA256": "$(wcp_json_escape "${WCP_BIONIC_LAUNCHER_SOURCE_WCP_SHA256:-}")",
    "WCP_BIONIC_LAUNCHER_SOURCE_WCP_SHA256_ALTERNATES": "$(wcp_json_escape "${WCP_BIONIC_LAUNCHER_SOURCE_WCP_SHA256_ALTERNATES:-}")",
    "WCP_BIONIC_SOURCE_MAP_FILE": "$(wcp_json_escape "${WCP_BIONIC_SOURCE_MAP_FILE:-}")",
    "WCP_BIONIC_SOURCE_MAP_PATH_EFFECTIVE": "$(wcp_json_escape "${WCP_BIONIC_SOURCE_MAP_PATH_EFFECTIVE:-${WCP_BIONIC_SOURCE_MAP_FILE:-}}")",
    "WCP_BIONIC_SOURCE_MAP_SHA256": "$(wcp_json_escape "${WCP_BIONIC_SOURCE_MAP_SHA256:-}")",
    "WCP_BIONIC_SOURCE_MAP_FORCE": "$(wcp_json_escape "${WCP_BIONIC_SOURCE_MAP_FORCE:-1}")",
    "WCP_BIONIC_SOURCE_MAP_REQUIRED": "$(wcp_json_escape "${WCP_BIONIC_SOURCE_MAP_REQUIRED:-0}")",
    "WCP_BIONIC_SOURCE_MAP_APPLIED": "$(wcp_json_escape "${WCP_BIONIC_SOURCE_MAP_APPLIED:-0}")",
    "WCP_BIONIC_SOURCE_MAP_RESOLVED": "$(wcp_json_escape "${WCP_BIONIC_SOURCE_MAP_RESOLVED:-0}")",
    "WCP_BIONIC_UNIX_SOURCE_WCP_PATH": "$(wcp_json_escape "${WCP_BIONIC_UNIX_SOURCE_WCP_PATH:-}")",
    "WCP_BIONIC_UNIX_SOURCE_WCP_URL": "$(wcp_json_escape "${WCP_BIONIC_UNIX_SOURCE_WCP_URL:-}")",
    "WCP_BIONIC_UNIX_SOURCE_WCP_SHA256": "$(wcp_json_escape "${WCP_BIONIC_UNIX_SOURCE_WCP_SHA256:-}")",
    "WCP_BIONIC_UNIX_SOURCE_WCP_SHA256_ALTERNATES": "$(wcp_json_escape "${WCP_BIONIC_UNIX_SOURCE_WCP_SHA256_ALTERNATES:-}")",
    "WCP_BIONIC_UNIX_CORE_ADOPT": "$(wcp_json_escape "${WCP_BIONIC_UNIX_CORE_ADOPT:-0}")",
    "WCP_BIONIC_UNIX_CORE_MODULES": "$(wcp_json_escape "${WCP_BIONIC_UNIX_CORE_MODULES:-}")",
    "WCP_BIONIC_LAUNCHER_SOURCE_WCP_RESOLVED_PATH": "$(wcp_json_escape "${WCP_BIONIC_LAUNCHER_SOURCE_WCP_RESOLVED_PATH:-}")",
    "WCP_BIONIC_LAUNCHER_SOURCE_WCP_RESOLVED_SHA256": "$(wcp_json_escape "${WCP_BIONIC_LAUNCHER_SOURCE_WCP_RESOLVED_SHA256:-}")",
    "WCP_BIONIC_UNIX_SOURCE_WCP_RESOLVED_PATH": "$(wcp_json_escape "${WCP_BIONIC_UNIX_SOURCE_WCP_RESOLVED_PATH:-}")",
    "WCP_BIONIC_UNIX_SOURCE_WCP_RESOLVED_SHA256": "$(wcp_json_escape "${WCP_BIONIC_UNIX_SOURCE_WCP_RESOLVED_SHA256:-}")",
    "WCP_BIONIC_DONOR_PREFLIGHT_DONE": "$(wcp_json_escape "${WCP_BIONIC_DONOR_PREFLIGHT_DONE:-0}")"
  }
}
EOF_SOURCE_REFS
  wcp_write_external_runtime_component_audit "${wcp_root}" "${external_runtime_audit_file}"
  cat > "${bionic_source_entry_file}" <<EOF_BIONIC_SOURCE
{
  "packageName": "$(wcp_json_escape "${WCP_NAME:-}")",
  "sourceMap": {
    "path": "$(wcp_json_escape "${WCP_BIONIC_SOURCE_MAP_PATH_EFFECTIVE:-${WCP_BIONIC_SOURCE_MAP_FILE:-}}")",
    "sha256": "$(wcp_json_escape "${WCP_BIONIC_SOURCE_MAP_SHA256:-}")",
    "applied": "$(wcp_json_escape "${WCP_BIONIC_SOURCE_MAP_APPLIED:-0}")",
    "resolved": "$(wcp_json_escape "${WCP_BIONIC_SOURCE_MAP_RESOLVED:-0}")"
  },
  "launcherSource": {
    "url": "$(wcp_json_escape "${WCP_BIONIC_LAUNCHER_SOURCE_WCP_URL:-}")",
    "sha256": "$(wcp_json_escape "${WCP_BIONIC_LAUNCHER_SOURCE_WCP_SHA256:-}")",
    "resolvedPath": "$(wcp_json_escape "${WCP_BIONIC_LAUNCHER_SOURCE_WCP_RESOLVED_PATH:-}")",
    "resolvedSha256": "$(wcp_json_escape "${WCP_BIONIC_LAUNCHER_SOURCE_WCP_RESOLVED_SHA256:-}")"
  },
  "unixSource": {
    "url": "$(wcp_json_escape "${WCP_BIONIC_UNIX_SOURCE_WCP_URL:-}")",
    "sha256": "$(wcp_json_escape "${WCP_BIONIC_UNIX_SOURCE_WCP_SHA256:-}")",
    "resolvedPath": "$(wcp_json_escape "${WCP_BIONIC_UNIX_SOURCE_WCP_RESOLVED_PATH:-}")",
    "resolvedSha256": "$(wcp_json_escape "${WCP_BIONIC_UNIX_SOURCE_WCP_RESOLVED_SHA256:-}")"
  },
  "unixCore": {
    "adopt": "$(wcp_json_escape "${WCP_BIONIC_UNIX_CORE_ADOPT:-0}")",
    "modules": "$(wcp_json_escape "${WCP_BIONIC_UNIX_CORE_MODULES:-}")"
  },
  "donorPreflightDone": "$(wcp_json_escape "${WCP_BIONIC_DONOR_PREFLIGHT_DONE:-0}")"
}
EOF_BIONIC_SOURCE
  : > "${unix_module_abi_file}"
  if [[ -d "${wcp_root}/lib/wine/aarch64-unix" ]]; then
    while IFS= read -r rel; do
      module_abi="$(winlator_detect_unix_module_abi_from_path "${wcp_root}/${rel}")"
      printf '%s\t%s\n' "${rel}" "${module_abi}" >> "${unix_module_abi_file}"
    done < <(
      find "${wcp_root}/lib/wine/aarch64-unix" -maxdepth 1 -type f -name '*.so' \
        -printf '%P\n' | LC_ALL=C sort | sed 's#^#lib/wine/aarch64-unix/#'
    )
  fi

  glibc_runtime_present=0
  : > "${glibc_runtime_index}"
  if [[ -d "${wcp_root}/lib/wine/wcp-glibc-runtime" ]]; then
    glibc_runtime_present=1
    while IFS= read -r rel; do
      [[ -f "${wcp_root}/${rel}" ]] || continue
      printf '%s\t%s\t%s\n' "${rel}" "$(stat -c '%s' "${wcp_root}/${rel}" 2>/dev/null || echo 0)" "$(wcp_sha256_file "${wcp_root}/${rel}")" >> "${glibc_runtime_index}"
    done < <(find "${wcp_root}/lib/wine/wcp-glibc-runtime" -type f -printf '%P\n' | LC_ALL=C sort | sed 's#^#lib/wine/wcp-glibc-runtime/#')
  else
    echo "ABSENT" > "${glibc_runtime_index}"
  fi
  wcp_runtime_write_glibc_markers "${wcp_root}" "${glibc_runtime_markers}"

  rm -rf "${glibc_stage_reports_dir}"
  : > "${glibc_stage_reports_index}"
  if [[ -d "${wcp_root}/lib/wine/wcp-glibc-runtime/.build-reports" ]]; then
    mkdir -p "${glibc_stage_reports_dir}"
    while IFS= read -r rel; do
      [[ -f "${wcp_root}/${rel}" ]] || continue
      mkdir -p "${glibc_stage_reports_dir}/$(dirname -- "${rel#lib/wine/wcp-glibc-runtime/.build-reports/}")"
      cp -f "${wcp_root}/${rel}" "${glibc_stage_reports_dir}/${rel#lib/wine/wcp-glibc-runtime/.build-reports/}"
      printf '%s\t%s\n' "${rel#lib/wine/wcp-glibc-runtime/.build-reports/}" "$(stat -c '%s' "${wcp_root}/${rel}" 2>/dev/null || echo 0)" >> "${glibc_stage_reports_index}"
    done < <(find "${wcp_root}/lib/wine/wcp-glibc-runtime/.build-reports" -type f -printf '%P\n' | LC_ALL=C sort | sed 's#^#lib/wine/wcp-glibc-runtime/.build-reports/#')
  else
    echo "ABSENT" > "${glibc_stage_reports_index}"
  fi

  if [[ -f "${wcp_root}/lib/wine/aarch64-windows/libarm64ecfex.dll" || -f "${wcp_root}/lib/wine/aarch64-windows/libwow64fex.dll" ]]; then
    fex_bundled_present=1
  fi
  emulation_policy="runtime-mixed"
  policy_violation_reason="none"
  if [[ "${WCP_MAINLINE_FEX_EXTERNAL_ONLY:-1}" == "1" ]]; then
    emulation_policy="fex-external-only"
    policy_hits="$(wcp_list_external_runtime_policy_hits "${wcp_root}" | LC_ALL=C sort -u || true)"
    if [[ -n "${policy_hits}" ]]; then
      boxed_runtime_detected=1
      policy_violation_reason="embedded-runtime-artifacts-detected"
      printf '%s\n' "${policy_hits}" > "${policy_violations_file}"
    else
      echo "none" > "${policy_violations_file}"
    fi
  else
    echo "policy-disabled" > "${policy_violations_file}"
  fi
  runtime_class_detected="$(winlator_detect_runtime_class "${wcp_root}")"
  unix_abi_detected="$(winlator_detect_unix_module_abi "${wcp_root}")"
  wine_launcher_abi="$(winlator_detect_launcher_abi "${wcp_root}/bin/wine")"
  wineserver_launcher_abi="$(winlator_detect_launcher_abi "${wcp_root}/bin/wineserver")"
  runtime_mismatch_reason="$(winlator_detect_runtime_mismatch_reason "${wcp_root}" "${WCP_RUNTIME_CLASS_TARGET:-bionic-native}")"

  cat > "${manifest_file}" <<EOF_MANIFEST
{
  "schema": "wcp-forensics/v1",
  "generatedAt": "${utc_now}",
  "package": {
    "name": "$(wcp_json_escape "${WCP_NAME:-}")",
    "profileName": "$(wcp_json_escape "${WCP_PROFILE_NAME:-${WCP_NAME:-}}")",
    "profileType": "$(wcp_json_escape "${WCP_PROFILE_TYPE:-Wine}")",
    "versionName": "$(wcp_json_escape "${WCP_VERSION_NAME:-}")",
    "versionCode": ${WCP_VERSION_CODE:-0},
    "channel": "$(wcp_json_escape "${WCP_CHANNEL:-stable}")",
    "delivery": "$(wcp_json_escape "${WCP_DELIVERY:-remote}")",
    "displayCategory": "$(wcp_json_escape "${WCP_DISPLAY_CATEGORY:-}")",
    "sourceRepo": "$(wcp_json_escape "${WCP_SOURCE_REPO:-}")",
    "sourceType": "$(wcp_json_escape "${WCP_SOURCE_TYPE:-}")",
    "sourceVersion": "$(wcp_json_escape "${WCP_SOURCE_VERSION:-}")",
    "releaseTag": "$(wcp_json_escape "${WCP_RELEASE_TAG:-}")",
    "artifactName": "$(wcp_json_escape "${WCP_ARTIFACT_NAME:-}")",
    "sha256Url": "$(wcp_json_escape "${WCP_SHA256_URL:-}")",
    "vulkanSdkVersion": "$(wcp_json_escape "${WCP_VULKAN_SDK_VERSION:-}")",
    "vulkanApiLane": "$(wcp_json_escape "${WCP_VULKAN_API_LANE:-}")",
    "vulkanSupportedApiLanes": $(wcp_json_array_from_csv "${WCP_VULKAN_SDK_LANES:-}"),
    "vulkanSdkSourceUrl": "$(wcp_json_escape "${WCP_VULKAN_SDK_SOURCE_URL:-}")",
    "vulkanToolsConfigureMode": "$(wcp_json_escape "${WCP_VULKAN_TOOLS_CONFIGURE_MODE:-}")",
    "vulkanRuntimeEmbedded": "$(wcp_json_escape "${WCP_EMBED_VULKAN_RUNTIME:-1}")",
    "vulkanRuntimeFlavor": "$(wcp_json_escape "${WCP_VULKAN_RUNTIME_FLAVOR:-}")",
    "vulkanWrapperMode": "$(wcp_json_escape "${WCP_VULKAN_WRAPPER_MODE:-}")",
    "vulkanWrapperIcdEmbedded": "$(wcp_json_escape "${WCP_VULKAN_WRAPPER_ICD_EMBEDDED:-0}")",
    "vulkanValidationLayerEmbedded": "$(wcp_json_escape "${WCP_VULKAN_VALIDATION_LAYER_EMBEDDED:-0}")",
    "vulkanApiDumpLayerEmbedded": "$(wcp_json_escape "${WCP_VULKAN_API_DUMP_LAYER_EMBEDDED:-0}")",
    "runtimeTarget": "$(wcp_json_escape "${WCP_TARGET_RUNTIME:-}")",
    "runtimeClassTarget": "$(wcp_json_escape "${WCP_RUNTIME_CLASS_TARGET:-}")",
    "runtimeClassDetected": "$(wcp_json_escape "${runtime_class_detected}")",
    "unixModuleAbi": "$(wcp_json_escape "${unix_abi_detected}")",
    "wineLauncherAbi": "$(wcp_json_escape "${wine_launcher_abi}")",
    "wineserverLauncherAbi": "$(wcp_json_escape "${wineserver_launcher_abi}")",
    "runtimeMismatchReason": "$(wcp_json_escape "${runtime_mismatch_reason}")",
    "allowGlibcExperimental": "$(wcp_json_escape "${WCP_ALLOW_GLIBC_EXPERIMENTAL:-0}")",
    "mainlineBionicOnly": "$(wcp_json_escape "${WCP_MAINLINE_BIONIC_ONLY:-1}")",
    "emulationPolicy": "$(wcp_json_escape "${emulation_policy}")",
    "wrapperPolicyVersion": "$(wcp_json_escape "${WCP_WRAPPER_POLICY_VERSION:-runtime-v1}")",
    "policySource": "$(wcp_json_escape "${WCP_POLICY_SOURCE:-aesolator-mainline}")",
    "fallbackScope": "$(wcp_json_escape "${WCP_FALLBACK_SCOPE:-bionic-internal-only}")",
    "arm64AndroidAutotuneDefault": "$(wcp_json_escape "${WCP_ARM64_ANDROID_AUTOTUNE_DEFAULT:-1}")",
    "arm64AndroidAutotuneProfile": "$(wcp_json_escape "${WCP_ARM64_ANDROID_AUTOTUNE_PROFILE:-auto}")",
    "bionicSourceMapApplied": "$(wcp_json_escape "${WCP_BIONIC_SOURCE_MAP_APPLIED:-0}")",
    "bionicSourceMapResolved": "$(wcp_json_escape "${WCP_BIONIC_SOURCE_MAP_RESOLVED:-0}")",
    "bionicSourceMapPath": "$(wcp_json_escape "${WCP_BIONIC_SOURCE_MAP_PATH_EFFECTIVE:-${WCP_BIONIC_SOURCE_MAP_FILE:-}}")",
    "bionicSourceMapSha256": "$(wcp_json_escape "${WCP_BIONIC_SOURCE_MAP_SHA256:-}")",
    "bionicLauncherSourceWcpUrl": "$(wcp_json_escape "${WCP_BIONIC_LAUNCHER_SOURCE_WCP_URL:-}")",
    "bionicLauncherSourceSha256": "$(wcp_json_escape "${WCP_BIONIC_LAUNCHER_SOURCE_WCP_SHA256:-}")",
    "bionicLauncherSourceSha256Alternates": "$(wcp_json_escape "${WCP_BIONIC_LAUNCHER_SOURCE_WCP_SHA256_ALTERNATES:-}")",
    "bionicUnixSourceWcpUrl": "$(wcp_json_escape "${WCP_BIONIC_UNIX_SOURCE_WCP_URL:-}")",
    "bionicUnixSourceSha256": "$(wcp_json_escape "${WCP_BIONIC_UNIX_SOURCE_WCP_SHA256:-}")",
    "bionicUnixSourceSha256Alternates": "$(wcp_json_escape "${WCP_BIONIC_UNIX_SOURCE_WCP_SHA256_ALTERNATES:-}")",
    "bionicLauncherSourceResolvedPath": "$(wcp_json_escape "${WCP_BIONIC_LAUNCHER_SOURCE_WCP_RESOLVED_PATH:-}")",
    "bionicLauncherSourceResolvedSha256": "$(wcp_json_escape "${WCP_BIONIC_LAUNCHER_SOURCE_WCP_RESOLVED_SHA256:-}")",
    "bionicUnixSourceResolvedPath": "$(wcp_json_escape "${WCP_BIONIC_UNIX_SOURCE_WCP_RESOLVED_PATH:-}")",
    "bionicUnixSourceResolvedSha256": "$(wcp_json_escape "${WCP_BIONIC_UNIX_SOURCE_WCP_RESOLVED_SHA256:-}")",
    "bionicUnixCoreAdopt": "$(wcp_json_escape "${WCP_BIONIC_UNIX_CORE_ADOPT:-0}")",
    "bionicUnixCoreModules": "$(wcp_json_escape "${WCP_BIONIC_UNIX_CORE_MODULES:-}")",
    "bionicDonorPreflightDone": "$(wcp_json_escape "${WCP_BIONIC_DONOR_PREFLIGHT_DONE:-0}")",
    "boxedRuntimeInWcpDetected": ${boxed_runtime_detected},
    "policyViolationReason": "$(wcp_json_escape "${policy_violation_reason}")",
    "pruneExternalComponents": "$(wcp_json_escape "${WCP_PRUNE_EXTERNAL_COMPONENTS:-1}")",
    "fexBundledInWcp": ${fex_bundled_present},
    "fexExpectationMode": "$(wcp_json_escape "${WCP_FEX_EXPECTATION_MODE:-}")"
  },
  "glibcRuntime": {
    "present": ${glibc_runtime_present},
    "sourceMode": "$(wcp_json_escape "${WCP_GLIBC_SOURCE_MODE:-}")",
    "version": "$(wcp_json_escape "${WCP_GLIBC_VERSION:-}")",
    "targetVersion": "$(wcp_json_escape "${WCP_GLIBC_TARGET_VERSION:-}")",
    "sourceUrl": "$(wcp_json_escape "${WCP_GLIBC_SOURCE_URL:-}")",
    "sourceRef": "$(wcp_json_escape "${WCP_GLIBC_SOURCE_REF:-}")",
    "sourcePatchId": "$(wcp_json_escape "${WCP_GLIBC_SOURCE_PATCH_ID:-}")",
    "sourcePatchScript": "$(wcp_json_escape "${WCP_GLIBC_SOURCE_PATCH_SCRIPT:-}")",
    "patchsetId": "$(wcp_json_escape "${WCP_GLIBC_PATCHSET_ID:-}")",
    "runtimeLockId": "$(wcp_json_escape "${WCP_RUNTIME_BUNDLE_LOCK_ID:-}")",
    "runtimeLockFile": "$(wcp_json_escape "${WCP_RUNTIME_BUNDLE_LOCK_FILE:-}")",
    "runtimeLockEnforce": "$(wcp_json_escape "${WCP_RUNTIME_BUNDLE_ENFORCE_LOCK:-}")",
    "runtimeLockMode": "$(wcp_json_escape "${WCP_RUNTIME_BUNDLE_LOCK_MODE:-}")",
    "runtimePatchOverlayDir": "$(wcp_json_escape "${WCP_GLIBC_RUNTIME_PATCH_OVERLAY_DIR:-}")",
    "runtimePatchScript": "$(wcp_json_escape "${WCP_GLIBC_RUNTIME_PATCH_SCRIPT:-}")",
    "libsIndex": "share/wcp-forensics/glibc-runtime-libs.tsv",
    "versionMarkers": "share/wcp-forensics/glibc-runtime-version-markers.tsv",
    "stageReportsIndex": "share/wcp-forensics/glibc-stage-reports-index.tsv"
  },
  "files": {
    "index": "share/wcp-forensics/file-index.txt",
    "criticalSha256": "share/wcp-forensics/critical-sha256.tsv",
    "externalRuntimeAudit": "share/wcp-forensics/external-runtime-components.tsv",
    "bionicSourceEntry": "share/wcp-forensics/bionic-source-entry.json",
    "unixModuleAbiIndex": "share/wcp-forensics/unix-module-abi.tsv",
    "glibcRuntimeIndex": "share/wcp-forensics/glibc-runtime-libs.tsv",
    "glibcRuntimeVersionMarkers": "share/wcp-forensics/glibc-runtime-version-markers.tsv",
    "glibcStageReportsIndex": "share/wcp-forensics/glibc-stage-reports-index.tsv",
    "policyViolations": "share/wcp-forensics/policy-violations.txt",
    "buildEnv": "share/wcp-forensics/build-env.txt",
    "sourceRefs": "share/wcp-forensics/source-refs.json"
  }
}
EOF_MANIFEST

  wcp_log "WCP forensic manifest written: ${forensic_root}"
}

wcp_validate_forensic_manifest() {
  local wcp_root="$1"
  : "${WCP_FORENSICS_ALWAYS_ON:=1}"
  [[ "${WCP_FORENSICS_ALWAYS_ON}" == "1" ]] || return 0

  local required=(
    "${wcp_root}/share/wcp-forensics/manifest.json"
    "${wcp_root}/share/wcp-forensics/critical-sha256.tsv"
    "${wcp_root}/share/wcp-forensics/external-runtime-components.tsv"
    "${wcp_root}/share/wcp-forensics/bionic-source-entry.json"
    "${wcp_root}/share/wcp-forensics/unix-module-abi.tsv"
    "${wcp_root}/share/wcp-forensics/glibc-runtime-libs.tsv"
    "${wcp_root}/share/wcp-forensics/glibc-runtime-version-markers.tsv"
    "${wcp_root}/share/wcp-forensics/glibc-stage-reports-index.tsv"
    "${wcp_root}/share/wcp-forensics/policy-violations.txt"
    "${wcp_root}/share/wcp-forensics/file-index.txt"
    "${wcp_root}/share/wcp-forensics/build-env.txt"
    "${wcp_root}/share/wcp-forensics/source-refs.json"
  )
  local p
  for p in "${required[@]}"; do
    [[ -f "${p}" ]] || wcp_fail "WCP forensic manifest is incomplete, missing: ${p#${wcp_root}/}"
  done

  wcp_validate_bionic_source_entry() {
    local entry_file="$1" strict_mode="${2:-0}"
    python3 - "${entry_file}" "${strict_mode}" <<'PY'
import json
import re
import sys
from pathlib import Path

entry_path = Path(sys.argv[1])
strict = sys.argv[2] == "1"
errors = []

if not entry_path.exists():
    print(f"[wcp][error] missing bionic source entry: {entry_path}")
    sys.exit(1)

try:
    data = json.loads(entry_path.read_text(encoding="utf-8"))
except Exception as exc:
    print(f"[wcp][error] invalid bionic source entry json: {exc}")
    sys.exit(1)

sha_re = re.compile(r"^[0-9a-f]{64}$")

def strv(obj, key):
    v = (obj or {}).get(key)
    return (v or "").strip() if isinstance(v, str) else ""

def check_source(name, obj, strict_donor):
    src_sha = strv(obj, "sha256").lower()
    resolved_sha = strv(obj, "resolvedSha256").lower()
    resolved_path = strv(obj, "resolvedPath")
    if strict_donor:
        if not sha_re.fullmatch(src_sha):
            errors.append(f"{name}.sha256 must be 64 lowercase hex")
        if not sha_re.fullmatch(resolved_sha):
            errors.append(f"{name}.resolvedSha256 must be 64 lowercase hex")
        if src_sha and resolved_sha and src_sha != resolved_sha:
            errors.append(f"{name}.sha256 and {name}.resolvedSha256 mismatch")
        if not resolved_path:
            errors.append(f"{name}.resolvedPath must be set in strict mode")

if strict:
    if not strv(data, "packageName"):
        errors.append("packageName must be set")
    source_map = data.get("sourceMap") or {}
    source_map_applied = strv(source_map, "applied")
    source_map_resolved = strv(source_map, "resolved")
    source_map_sha = strv(source_map, "sha256").lower()
    if source_map_applied in ("1", "true") and not sha_re.fullmatch(source_map_sha):
        errors.append("sourceMap.sha256 must be 64 lowercase hex when sourceMap.applied=1")
    if source_map_applied and source_map_applied not in ("0", "1", "true", "false"):
        errors.append("sourceMap.applied must be 0/1/true/false when set")
    if source_map_resolved and source_map_resolved not in ("0", "1", "true", "false"):
        errors.append("sourceMap.resolved must be 0/1/true/false when set")

launcher = data.get("launcherSource") or {}
unix = data.get("unixSource") or {}
donor_fields = (
    strv(launcher, "url"), strv(launcher, "sha256"), strv(launcher, "resolvedPath"), strv(launcher, "resolvedSha256"),
    strv(unix, "url"), strv(unix, "sha256"), strv(unix, "resolvedPath"), strv(unix, "resolvedSha256"),
)
donor_configured = any(v for v in donor_fields)
if strict and donor_configured:
    donor_preflight = strv(data, "donorPreflightDone")
    if donor_preflight not in ("1", "true"):
        errors.append("donorPreflightDone must be 1 when donor source is configured")

check_source("launcherSource", launcher, strict and donor_configured)
check_source("unixSource", unix, strict and donor_configured)

if errors:
    for err in errors:
        print(f"[wcp][error] {err}")
    sys.exit(1)
PY
  }

  local unix_abi_file="${wcp_root}/share/wcp-forensics/unix-module-abi.tsv"
  local ntdll_abi fallback_ntdll_abi
  local glibc_row glibc_name allowed opt
  local -a strict_allowed_glibc_modules forensic_glibc_rows blocking_glibc_rows
  local bionic_source_entry_file="${wcp_root}/share/wcp-forensics/bionic-source-entry.json"
  if [[ "${WCP_RUNTIME_CLASS_TARGET:-bionic-native}" == "bionic-native" && "${WCP_RUNTIME_CLASS_ENFORCE:-0}" == "1" ]]; then
    ntdll_abi="$(awk -F'\t' '$1=="lib/wine/aarch64-unix/ntdll.so"{print $2; exit}' "${unix_abi_file}" 2>/dev/null || true)"
    case "${ntdll_abi}" in
      bionic-unix)
        ;;
      unknown)
        fallback_ntdll_abi="$(winlator_detect_unix_module_abi "${wcp_root}")"
        case "${fallback_ntdll_abi}" in
          bionic-unix|unknown)
            wcp_log "Strict bionic mode: ntdll ABI marker is unknown in forensic index, fallback detector reports ${fallback_ntdll_abi}"
            ;;
          *)
            wcp_fail "Forensic unix ABI index is missing bionic ntdll marker"
            ;;
        esac
        ;;
      *)
        wcp_fail "Forensic unix ABI index is missing bionic ntdll marker"
        ;;
    esac
    mapfile -t forensic_glibc_rows < <(awk -F'\t' '$2=="glibc-unix"{print $1}' "${unix_abi_file}" 2>/dev/null || true)
    if [[ "${#forensic_glibc_rows[@]}" -gt 0 ]]; then
      : "${WCP_BIONIC_STRICT_ALLOWED_GLIBC_UNIX_MODULES:=winebth.so opencl.so winedmo.so}"
      # shellcheck disable=SC2206
      strict_allowed_glibc_modules=( ${WCP_BIONIC_STRICT_ALLOWED_GLIBC_UNIX_MODULES} )
      blocking_glibc_rows=()
      for glibc_row in "${forensic_glibc_rows[@]}"; do
        glibc_name="$(basename "${glibc_row}")"
        allowed=0
        for opt in "${strict_allowed_glibc_modules[@]}"; do
          [[ "${glibc_name}" == "${opt}" ]] || continue
          allowed=1
          break
        done
        if [[ "${allowed}" != "1" ]]; then
          blocking_glibc_rows+=("${glibc_row}")
        fi
      done
      if [[ "${#blocking_glibc_rows[@]}" -gt 0 ]]; then
        wcp_fail "Forensic unix ABI index contains glibc-unix modules in strict bionic mode: ${blocking_glibc_rows[*]}"
      fi
      wcp_log "Strict bionic forensic check tolerated optional glibc unix modules: ${forensic_glibc_rows[*]}"
    fi
    wcp_validate_bionic_source_entry "${bionic_source_entry_file}" "1" || \
      wcp_fail "Forensic bionic source entry contract validation failed in strict bionic mode"
  else
    wcp_validate_bionic_source_entry "${bionic_source_entry_file}" "0" || \
      wcp_fail "Forensic bionic source entry contract validation failed"
  fi
}

validate_wcp_tree_arm64ec() {
  local wcp_root="$1"
  local -a required_paths required_modules
  local p mod unix_abi

  : "${WCP_MAINLINE_FEX_EXTERNAL_ONLY:=1}"
  wcp_require_bool WCP_MAINLINE_FEX_EXTERNAL_ONLY "${WCP_MAINLINE_FEX_EXTERNAL_ONLY}"
  wcp_enforce_mainline_external_runtime_policy

  required_paths=(
    "${wcp_root}/bin"
    "${wcp_root}/bin/wine"
    "${wcp_root}/bin/wineserver"
    "${wcp_root}/lib"
    "${wcp_root}/lib/wine"
    "${wcp_root}/lib/wine/aarch64-unix"
    "${wcp_root}/lib/wine/aarch64-windows"
    "${wcp_root}/lib/wine/i386-windows"
    "${wcp_root}/share"
    "${wcp_root}/prefixPack.txz"
    "${wcp_root}/profile.json"
  )

  for p in "${required_paths[@]}"; do
    [[ -e "${p}" ]] || wcp_fail "WCP layout is incomplete, missing: ${p#${wcp_root}/}"
  done

  if [[ "${WCP_FEX_EXPECTATION_MODE:-external}" == "bundled" ]]; then
    [[ -f "${wcp_root}/lib/wine/aarch64-windows/libarm64ecfex.dll" ]] || wcp_fail "Bundled FEX mode requires lib/wine/aarch64-windows/libarm64ecfex.dll"
    [[ -f "${wcp_root}/lib/wine/aarch64-windows/libwow64fex.dll" ]] || wcp_fail "Bundled FEX mode requires lib/wine/aarch64-windows/libwow64fex.dll"
  fi

  wcp_assert_mainline_external_runtime_clean_tree "${wcp_root}"
  wcp_assert_pruned_external_runtime_components "${wcp_root}"

  if [[ -d "${wcp_root}/lib/wine/arm64ec-windows" ]]; then
    wcp_log "Detected explicit arm64ec-windows layer"
  fi

  required_modules=(
    "ntdll.so"
    "win32u.so"
    "ws2_32.so"
    "winevulkan.so"
  )

  for mod in "${required_modules[@]}"; do
    [[ -f "${wcp_root}/lib/wine/aarch64-unix/${mod}" ]] || wcp_fail "Wine unix module missing: lib/wine/aarch64-unix/${mod}"
  done

  if [[ "${WCP_ENABLE_SDL2_RUNTIME:-1}" == "1" ]]; then
    if [[ ! -f "${wcp_root}/lib/wine/aarch64-unix/winebus.so" && ! -f "${wcp_root}/lib/wine/aarch64-unix/winebus.sys.so" ]]; then
      wcp_fail "Wine unix module missing: lib/wine/aarch64-unix/winebus.so (or winebus.sys.so)"
    fi
  fi
  if wcp_usb_runtime_enabled; then
    if [[ ! -f "${wcp_root}/lib/wine/aarch64-unix/wineusb.so" && ! -f "${wcp_root}/lib/wine/aarch64-unix/wineusb.sys.so" ]]; then
      wcp_fail "Wine unix module missing: lib/wine/aarch64-unix/wineusb.so (or wineusb.sys.so)"
    fi
    [[ -f "${wcp_root}/lib/wine/aarch64-windows/wineusb.sys" ]] || wcp_fail "Wine PE module missing: lib/wine/aarch64-windows/wineusb.sys"
    if [[ ! -f "${wcp_root}/lib/wine/aarch64-windows/winusb.dll" && ! -f "${wcp_root}/lib/wine/i386-windows/winusb.dll" ]]; then
      wcp_fail "Wine PE module missing: winusb.dll (aarch64 or i386 windows layer)"
    fi
  fi

  unix_abi="$(winlator_detect_unix_module_abi "${wcp_root}")"
  if [[ "${WCP_RUNTIME_CLASS_TARGET:-bionic-native}" == "bionic-native" && "${unix_abi}" != "bionic-unix" ]]; then
    if [[ "${WCP_RUNTIME_CLASS_ENFORCE:-0}" == "1" ]]; then
      wcp_fail "Bionic runtime target requires bionic-linked unix modules; detected unix ABI=${unix_abi} (expected bionic-unix)"
    fi
    wcp_log "runtime-class warning: unix ABI is ${unix_abi} while target is bionic-native (continuing because WCP_RUNTIME_CLASS_ENFORCE=0)"
  fi

  if [[ "${WCP_RUNTIME_CLASS_TARGET:-bionic-native}" == "bionic-native" && -d "${wcp_root}/lib/wine/wcp-glibc-runtime" ]]; then
    wcp_fail "Bionic runtime target forbids bundled glibc runtime payload: lib/wine/wcp-glibc-runtime"
  fi

  winlator_validate_launchers
  wcp_validate_forensic_manifest "${wcp_root}"
  wcp_runtime_verify_glibc_lock "${wcp_root}"
  wcp_log "ARM64EC WCP tree validation passed"
}

pack_wcp() {
  local wcp_root="$1" out_dir="$2" wcp_name="$3"
  local out_wcp
  : "${WCP_COMPRESS:=xz}"

  mkdir -p "${out_dir}"
  out_wcp="${out_dir}/${wcp_name}.wcp"

  case "${WCP_COMPRESS}" in
    xz)
      tar -cJf "${out_wcp}" -C "${wcp_root}" .
      ;;
    zst|zstd)
      tar --zstd -cf "${out_wcp}" -C "${wcp_root}" .
      ;;
    *)
      wcp_fail "WCP_COMPRESS must be xz or zst"
      ;;
  esac

  printf '%s\n' "${out_wcp}"
}

smoke_check_wcp() {
  local wcp_path="$1"
  local wcp_compress="${2:-${WCP_COMPRESS:-xz}}"
  local list_file normalized_file shebang profile_json
  local forbidden

  [[ -f "${wcp_path}" ]] || wcp_fail "WCP artifact not found: ${wcp_path}"

  list_file="$(mktemp)"
  normalized_file="$(mktemp)"
  trap 'rm -f "${list_file:-}" "${normalized_file:-}"' RETURN

  case "${wcp_compress}" in
    xz)
      tar -tJf "${wcp_path}" > "${list_file}"
      ;;
    zst|zstd)
      tar --zstd -tf "${wcp_path}" > "${list_file}"
      ;;
    *)
      wcp_fail "WCP_COMPRESS must be xz or zst"
      ;;
  esac

  sed 's#^\./##' "${list_file}" > "${normalized_file}"

  grep -qx 'bin/wine' "${normalized_file}" || wcp_fail "Missing bin/wine"
  grep -qx 'bin/wineserver' "${normalized_file}" || wcp_fail "Missing bin/wineserver"
  grep -qx 'prefixPack.txz' "${normalized_file}" || wcp_fail "Missing prefixPack.txz"
  grep -qx 'profile.json' "${normalized_file}" || wcp_fail "Missing profile.json"
  grep -qx 'share/wcp-forensics/manifest.json' "${normalized_file}" || wcp_fail "Missing share/wcp-forensics/manifest.json"
  grep -qx 'share/wcp-forensics/critical-sha256.tsv' "${normalized_file}" || wcp_fail "Missing share/wcp-forensics/critical-sha256.tsv"
  grep -qx 'share/wcp-forensics/external-runtime-components.tsv' "${normalized_file}" || wcp_fail "Missing share/wcp-forensics/external-runtime-components.tsv"
  grep -qx 'share/wcp-forensics/bionic-source-entry.json' "${normalized_file}" || wcp_fail "Missing share/wcp-forensics/bionic-source-entry.json"
  grep -qx 'share/wcp-forensics/unix-module-abi.tsv' "${normalized_file}" || wcp_fail "Missing share/wcp-forensics/unix-module-abi.tsv"
  grep -qx 'share/wcp-forensics/file-index.txt' "${normalized_file}" || wcp_fail "Missing share/wcp-forensics/file-index.txt"
  grep -qx 'share/wcp-forensics/build-env.txt' "${normalized_file}" || wcp_fail "Missing share/wcp-forensics/build-env.txt"
  grep -qx 'share/wcp-forensics/source-refs.json' "${normalized_file}" || wcp_fail "Missing share/wcp-forensics/source-refs.json"
  grep -q '^lib/wine/aarch64-unix/' "${normalized_file}" || wcp_fail "Missing lib/wine/aarch64-unix"
  grep -q '^lib/wine/aarch64-windows/' "${normalized_file}" || wcp_fail "Missing lib/wine/aarch64-windows"
  grep -q '^lib/wine/i386-windows/' "${normalized_file}" || wcp_fail "Missing lib/wine/i386-windows"
  : "${WCP_EMBED_VULKAN_RUNTIME:=1}"
  if [[ "${WCP_EMBED_VULKAN_RUNTIME}" == "1" ]]; then
    grep -qx 'share/vulkan/icd.d/wrapper_icd.aarch64.json' "${normalized_file}" || wcp_fail "Missing embedded Vulkan wrapper ICD"
    grep -qx "share/vulkan-sdk/${WCP_VULKAN_SDK_VERSION}/manifest.json" "${normalized_file}" || wcp_fail "Missing embedded Vulkan SDK manifest"
  fi

  profile_json=""
  case "${wcp_compress}" in
    xz)
      profile_json="$(tar -xJOf "${wcp_path}" ./profile.json 2>/dev/null || tar -xJOf "${wcp_path}" profile.json 2>/dev/null || true)"
      ;;
    zst|zstd)
      profile_json="$(tar --zstd -xOf "${wcp_path}" ./profile.json 2>/dev/null || tar --zstd -xOf "${wcp_path}" profile.json 2>/dev/null || true)"
      ;;
  esac
  [[ -n "${profile_json}" ]] || wcp_fail "Unable to read profile.json from archive"
  grep -q '"wrapperPolicyVersion"' <<< "${profile_json}" || wcp_fail "profile.json is missing runtime.wrapperPolicyVersion"
  grep -q '"policySource"' <<< "${profile_json}" || wcp_fail "profile.json is missing runtime.policySource"
  grep -q '"fallbackScope"' <<< "${profile_json}" || wcp_fail "profile.json is missing runtime.fallbackScope"
  if [[ "${WCP_EMBED_VULKAN_RUNTIME}" == "1" ]]; then
    grep -q '"supportedApiLanes"' <<< "${profile_json}" || wcp_fail "profile.json is missing vulkan.supportedApiLanes"
    grep -q '"embeddedRuntime"' <<< "${profile_json}" || wcp_fail "profile.json is missing vulkan.embeddedRuntime"
  fi

  : "${WCP_MAINLINE_FEX_EXTERNAL_ONLY:=1}"
  : "${WCP_PRUNE_EXTERNAL_COMPONENTS:=1}"
  wcp_require_bool WCP_MAINLINE_FEX_EXTERNAL_ONLY "${WCP_MAINLINE_FEX_EXTERNAL_ONLY}"
  wcp_require_bool WCP_PRUNE_EXTERNAL_COMPONENTS "${WCP_PRUNE_EXTERNAL_COMPONENTS}"
  if [[ "${WCP_MAINLINE_FEX_EXTERNAL_ONLY}" == "1" ]]; then
    forbidden="$(grep -Ei '(^|/)(libarm64ecfex\.dll|libwow64fex\.dll|fexcore|box64|wowbox64)($|/)' "${normalized_file}" || true)"
    [[ -z "${forbidden}" ]] || wcp_fail "Mainline external-runtime policy violation inside archive:\n${forbidden}"
  fi

  if [[ "${WCP_PRUNE_EXTERNAL_COMPONENTS}" == "1" ]]; then
    forbidden="$(grep -Ei '^(lib/wine/(dxvk|vkd3d|vk3d)(/|$)|lib/(dxvk|vkd3d)(/|$)|share/(dxvk|vkd3d)(/|$))' "${normalized_file}" || true)"
    if grep -q '^share/vulkan' "${normalized_file}"; then
      while IFS= read -r rel; do
        [[ -n "${rel}" ]] || continue
        if ! wcp_is_internal_vulkan_runtime_relpath "${rel}"; then
          forbidden+="${forbidden:+$'\n'}${rel}"
        fi
      done < <(grep '^share/vulkan' "${normalized_file}" || true)
    fi
    [[ -z "${forbidden}" ]] || wcp_fail "External component prune policy violation inside archive:\n${forbidden}"
  fi

  if grep -qx 'bin/wine.glibc-real' "${normalized_file}"; then
    grep -qx 'lib/wine/wcp-glibc-runtime/ld-linux-aarch64.so.1' "${normalized_file}" || wcp_fail "Missing bundled glibc runtime loader"
    case "${wcp_compress}" in
      xz) shebang="$(tar -xJOf "${wcp_path}" ./bin/wine 2>/dev/null | head -n1)" ;;
      zst|zstd) shebang="$(tar --zstd -xOf "${wcp_path}" ./bin/wine 2>/dev/null | head -n1)" ;;
    esac
    [[ "${shebang}" == "#!/system/bin/sh" ]] || wcp_fail "bin/wine wrapper must use #!/system/bin/sh"
  fi

  (
    cd "$(dirname "${wcp_path}")"
    sha256sum "$(basename "${wcp_path}")" > SHA256SUMS
  )

  wcp_log "WCP smoke checks passed for ${wcp_path}"
}
