#!/usr/bin/env bash
set -euo pipefail

wcp_resolve_gamenative_patchset_mode() {
  local mode="${WCP_GN_PATCHSET_MODE:-auto}"
  wcp_require_enum WCP_GN_PATCHSET_MODE "${mode}" auto full normalize-only off
  if [[ "${mode}" == "auto" ]]; then
    if [[ "${WCP_GN_PATCHSET_ENABLE:-1}" == "1" ]]; then
      printf '%s' "full"
    else
      printf '%s' "normalize-only"
    fi
    return 0
  fi
  printf '%s' "${mode}"
}

wcp_clone_clean_source_tree() {
  local source_dir="$1" clone_dir="$2"
  [[ -d "${source_dir}" ]] || wcp_fail "source_dir not found: ${source_dir}"
  git clone -q --no-hardlinks -- "${source_dir}" "${clone_dir}"
  git -C "${clone_dir}" reset --hard -q HEAD
  git -C "${clone_dir}" clean -fdqx
}

wcp_gamenative_report_path() {
  local target="$1"
  if [[ -n "${WCP_GN_PATCHSET_REPORT:-}" ]]; then
    printf '%s' "${WCP_GN_PATCHSET_REPORT}"
    return 0
  fi
  if [[ -n "${WCP_OUTPUT_DIR:-}" ]]; then
    printf '%s' "${WCP_OUTPUT_DIR}/logs/gamenative-patchset-${target}.tsv"
    return 0
  fi
  printf '%s' "/tmp/gamenative-patchset-${target}.tsv"
}

wcp_preflight_unified_gamenative_patch_base() {
  local target="$1" patch_target="$2" source_dir="$3" patchset_mode="$4" strict_value="$5"
  local tmp_dir clone_dir base_report preflight_report rc=0

  : "${WCP_GN_PATCHSET_VERIFY_AUTOFIX:=1}"
  : "${WCP_GN_PATCHSET_REF:=28c3a06ba773f6d29b9f3ed23b9297f94af4771c}"

  tmp_dir="$(mktemp -d /tmp/wcp_gn_preflight_XXXXXX)"
  clone_dir="${tmp_dir}/src"
  base_report="$(wcp_gamenative_report_path "${target}")"
  preflight_report="${base_report%.tsv}.preflight.tsv"
  [[ "${preflight_report}" == "${base_report}" ]] && preflight_report="${base_report}.preflight"

  wcp_log "Unified GameNative patch preflight: target=${target}, source=${source_dir}"
  wcp_clone_clean_source_tree "${source_dir}" "${clone_dir}"

  if ! WCP_GN_PATCHSET_MODE="${patchset_mode}" \
    WCP_GN_PATCHSET_STRICT="${strict_value}" \
    WCP_GN_PATCHSET_VERIFY_AUTOFIX="${WCP_GN_PATCHSET_VERIFY_AUTOFIX}" \
    WCP_GN_PATCHSET_REF="${WCP_GN_PATCHSET_REF}" \
    WCP_GN_PATCHSET_REPORT="${preflight_report}" \
    bash "${ROOT_DIR}/ci/gamenative/apply-android-patchset.sh" --target "${patch_target}" --source-dir "${clone_dir}"; then
    rc=$?
    rm -rf "${tmp_dir}"
    return "${rc}"
  fi

  if ! WCP_GN_PATCHSET_STRICT="${strict_value}" \
    bash "${ROOT_DIR}/ci/validation/check-gamenative-patch-contract.sh" --target "${patch_target}" --source-dir "${clone_dir}"; then
    rc=$?
    rm -rf "${tmp_dir}"
    return "${rc}"
  fi

  rm -rf "${tmp_dir}"
}

wcp_apply_unified_gamenative_patch_base() {
  local target="$1" source_dir="$2" strict_override="${3:-default}"
  local patch_target patchset_mode gn_contract_strict

  [[ -n "${ROOT_DIR:-}" ]] || wcp_fail "ROOT_DIR must be set before applying GameNative patch base"
  [[ -n "${source_dir}" ]] || wcp_fail "source_dir must not be empty"
  [[ -d "${source_dir}" ]] || wcp_fail "source_dir not found: ${source_dir}"

  case "${target}" in
    wine|protonge)
      patch_target="${target}"
      ;;
    protonwine)
      # ProtonWine10 reuses the Wine contract markers.
      patch_target="wine"
      ;;
    *)
      wcp_fail "Unsupported patch base target: ${target} (expected wine|protonge|protonwine)"
      ;;
  esac

  case "${strict_override}" in
    default|0|1) ;;
    *)
      wcp_fail "strict_override must be default, 0 or 1 (got: ${strict_override})"
      ;;
  esac

  : "${WCP_GN_PATCHSET_ENABLE:=1}"
  : "${WCP_GN_PATCHSET_STRICT:=1}"
  : "${WCP_GN_PATCHSET_VERIFY_AUTOFIX:=1}"
  : "${WCP_GN_PATCHSET_REF:=28c3a06ba773f6d29b9f3ed23b9297f94af4771c}"
  : "${WCP_GN_PATCHSET_MODE:=auto}"
  : "${WCP_GN_PATCHSET_PREFLIGHT:=1}"

  wcp_require_bool WCP_GN_PATCHSET_ENABLE "${WCP_GN_PATCHSET_ENABLE}"
  wcp_require_bool WCP_GN_PATCHSET_STRICT "${WCP_GN_PATCHSET_STRICT}"
  wcp_require_bool WCP_GN_PATCHSET_VERIFY_AUTOFIX "${WCP_GN_PATCHSET_VERIFY_AUTOFIX}"
  wcp_require_bool WCP_GN_PATCHSET_PREFLIGHT "${WCP_GN_PATCHSET_PREFLIGHT}"

  patchset_mode="$(wcp_resolve_gamenative_patchset_mode)"
  gn_contract_strict="${WCP_GN_PATCHSET_STRICT}"

  if [[ "${patchset_mode}" == "normalize-only" ]]; then
    gn_contract_strict="0"
  fi

  if [[ "${strict_override}" != "default" ]]; then
    gn_contract_strict="${strict_override}"
  fi

  if [[ "${patchset_mode}" == "off" ]]; then
    wcp_log "Unified GameNative patch base is disabled (target=${target}, source=${source_dir})"
    return 0
  fi

  wcp_log "Unified GameNative patch base: target=${target}, patch-target=${patch_target}, mode=${patchset_mode}, strict=${gn_contract_strict}"

  if [[ "${WCP_GN_PATCHSET_PREFLIGHT}" == "1" ]]; then
    wcp_preflight_unified_gamenative_patch_base \
      "${target}" \
      "${patch_target}" \
      "${source_dir}" \
      "${patchset_mode}" \
      "${gn_contract_strict}"
  fi

  WCP_GN_PATCHSET_MODE="${patchset_mode}" \
    WCP_GN_PATCHSET_STRICT="${gn_contract_strict}" \
    WCP_GN_PATCHSET_VERIFY_AUTOFIX="${WCP_GN_PATCHSET_VERIFY_AUTOFIX}" \
    WCP_GN_PATCHSET_REF="${WCP_GN_PATCHSET_REF}" \
    WCP_GN_PATCHSET_REPORT="$(wcp_gamenative_report_path "${target}")" \
    bash "${ROOT_DIR}/ci/gamenative/apply-android-patchset.sh" --target "${patch_target}" --source-dir "${source_dir}"

  WCP_GN_PATCHSET_STRICT="${gn_contract_strict}" \
    bash "${ROOT_DIR}/ci/validation/check-gamenative-patch-contract.sh" --target "${patch_target}" --source-dir "${source_dir}"
}
