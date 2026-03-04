#!/usr/bin/env bash

# Stable local source roots used as shared git object caches and long-lived
# editable working trees next to the main repository.

: "${WCP_LOCAL_SOURCE_ROOT:=/home/mikhail/wcp-sources}"
: "${WCP_LOCAL_ANDRE_WINE11_DIR:=${WCP_LOCAL_SOURCE_ROOT}/andre-wine11-arm64ec}"
: "${WCP_LOCAL_VALVE_WINE_EXP10_DIR:=${WCP_LOCAL_SOURCE_ROOT}/valve-wine-experimental10}"
: "${WCP_LOCAL_PROTON_GE_UPSTREAM_DIR:=${WCP_LOCAL_SOURCE_ROOT}/proton-ge-upstream}"
: "${WCP_LOCAL_PROTON_GE_LINKED_DIR:=${WCP_LOCAL_SOURCE_ROOT}/proton-ge-linked-wine11}"
: "${WCP_LOCAL_GAMENATIVE_PROTON_DIR:=${WCP_LOCAL_SOURCE_ROOT}/gamenative-proton}"
: "${WCP_LOCAL_PROTON11_STACK_DIR:=${WCP_LOCAL_SOURCE_ROOT}/proton11-ae-stack}"
: "${WCP_LOCAL_PROTON11_GE_ARM64EC_DIR:=${WCP_LOCAL_SOURCE_ROOT}/proton11-ge-arm64ec}"
: "${WCP_LOCAL_FREEWINE11_DIR:=${WCP_LOCAL_SOURCE_ROOT}/freewine11}"
: "${WCP_LOCAL_WINE11_DONOR_DIR:=${WCP_LOCAL_ANDRE_WINE11_DIR}}"
: "${WCP_LOCAL_WINE11_ACTIVE_DIR:=${WCP_LOCAL_FREEWINE11_DIR}}"
: "${WCP_LOCAL_WINE11_FALLBACK_DIR:=${WCP_LOCAL_WINE11_DONOR_DIR}}"

wcp_local_repo_exists() {
  local repo_dir="$1"
  [[ -d "${repo_dir}/.git" || -f "${repo_dir}/.git" ]]
}

wcp_resolve_wine11_active_dir() {
  if wcp_local_repo_exists "${WCP_LOCAL_WINE11_ACTIVE_DIR}"; then
    printf '%s\n' "${WCP_LOCAL_WINE11_ACTIVE_DIR}"
  else
    printf '%s\n' "${WCP_LOCAL_WINE11_FALLBACK_DIR}"
  fi
}

wcp_clone_from_seed_or_remote() {
  local repo_url="$1" ref="$2" local_seed="$3" dest_dir="$4"
  local -a clone_opts=(--filter=blob:none --no-checkout)
  local clone_ok=0

  rm -rf "${dest_dir}"

  if [[ -n "${local_seed}" ]] && wcp_local_repo_exists "${local_seed}"; then
    if git clone --reference-if-able "${local_seed}" --dissociate "${clone_opts[@]}" "${repo_url}" "${dest_dir}"; then
      clone_ok=1
    fi
    if [[ ${clone_ok} -eq 0 ]]; then
      rm -rf "${dest_dir}"
      if git clone --reference-if-able "${local_seed}" --dissociate --no-checkout "${repo_url}" "${dest_dir}"; then
        clone_ok=1
      fi
    fi
  else
    if git clone "${clone_opts[@]}" "${repo_url}" "${dest_dir}"; then
      clone_ok=1
    fi
    if [[ ${clone_ok} -eq 0 ]]; then
      rm -rf "${dest_dir}"
      if git clone --no-checkout "${repo_url}" "${dest_dir}"; then
        clone_ok=1
      fi
    fi
  fi

  if [[ ${clone_ok} -eq 0 ]]; then
    return 1
  fi

  if git -C "${dest_dir}" fetch --no-tags origin "${ref}"; then
    :
  elif git -C "${dest_dir}" fetch origin "refs/tags/${ref}:refs/tags/${ref}"; then
    :
  else
    return 1
  fi

  if git -C "${dest_dir}" checkout --detach "${ref}"; then
    :
  else
    git -C "${dest_dir}" checkout --detach FETCH_HEAD
  fi
}

wcp_print_local_source_layout() {
  cat <<EOF
WCP_LOCAL_SOURCE_ROOT=${WCP_LOCAL_SOURCE_ROOT}
WCP_LOCAL_ANDRE_WINE11_DIR=${WCP_LOCAL_ANDRE_WINE11_DIR}
WCP_LOCAL_VALVE_WINE_EXP10_DIR=${WCP_LOCAL_VALVE_WINE_EXP10_DIR}
WCP_LOCAL_PROTON_GE_UPSTREAM_DIR=${WCP_LOCAL_PROTON_GE_UPSTREAM_DIR}
WCP_LOCAL_PROTON_GE_LINKED_DIR=${WCP_LOCAL_PROTON_GE_LINKED_DIR}
WCP_LOCAL_GAMENATIVE_PROTON_DIR=${WCP_LOCAL_GAMENATIVE_PROTON_DIR}
WCP_LOCAL_PROTON11_STACK_DIR=${WCP_LOCAL_PROTON11_STACK_DIR}
WCP_LOCAL_PROTON11_GE_ARM64EC_DIR=${WCP_LOCAL_PROTON11_GE_ARM64EC_DIR}
WCP_LOCAL_FREEWINE11_DIR=${WCP_LOCAL_FREEWINE11_DIR}
WCP_LOCAL_WINE11_DONOR_DIR=${WCP_LOCAL_WINE11_DONOR_DIR}
WCP_LOCAL_WINE11_ACTIVE_DIR=${WCP_LOCAL_WINE11_ACTIVE_DIR}
WCP_LOCAL_WINE11_FALLBACK_DIR=${WCP_LOCAL_WINE11_FALLBACK_DIR}
WCP_LOCAL_WINE11_EFFECTIVE_ACTIVE_DIR=$(wcp_resolve_wine11_active_dir)
EOF
}
