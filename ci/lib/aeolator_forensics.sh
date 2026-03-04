#!/usr/bin/env bash

aeo_forensics_enabled() {
  case "${AEO_FORENSIC_ENABLE:-1}" in
    0|false|False|FALSE|no|No|NO)
      return 1
      ;;
  esac
  return 0
}

aeo_forensics_now_utc() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}

aeo_forensics_sanitize() {
  local value="${1:-unknown}"
  value="${value//[^A-Za-z0-9._-]/-}"
  value="${value//--/-}"
  value="${value#-}"
  value="${value%-}"
  if [[ -z "${value}" ]]; then
    value="unknown"
  fi
  printf '%s' "${value}"
}

aeo_forensics_json_escape() {
  local value="${1:-}"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/\\r}"
  value="${value//$'\t'/\\t}"
  printf '%s' "${value}"
}

aeo_forensics_emit_event() {
  local level="$1" event_id="$2" stage="$3" status="$4" message="${5:-}"
  [[ "${AEO_FORENSIC_ACTIVE:-0}" == "1" ]] || return 0

  local ts msg esc_stage esc_event esc_status esc_level esc_pipeline esc_session esc_target esc_mode esc_aliases
  ts="$(aeo_forensics_now_utc)"
  msg="$(aeo_forensics_json_escape "${message}")"
  esc_stage="$(aeo_forensics_json_escape "${stage}")"
  esc_event="$(aeo_forensics_json_escape "${event_id}")"
  esc_status="$(aeo_forensics_json_escape "${status}")"
  esc_level="$(aeo_forensics_json_escape "${level}")"
  esc_pipeline="$(aeo_forensics_json_escape "${AEO_FORENSIC_PIPELINE}")"
  esc_session="$(aeo_forensics_json_escape "${AEO_FORENSIC_SESSION_ID}")"
  esc_target="$(aeo_forensics_json_escape "${AEO_FORENSIC_SYNC_TARGET}")"
  esc_mode="$(aeo_forensics_json_escape "${AEO_FORENSIC_SYNC_MODE}")"
  esc_aliases="$(aeo_forensics_json_escape "${AEO_FORENSIC_SYNC_ALIASES}")"

  printf '{"ts":"%s","session":"%s","pipeline":"%s","level":"%s","event":"%s","stage":"%s","status":"%s","pid":%s,"syncTarget":"%s","syncMode":"%s","syncAliases":"%s","message":"%s"}\n' \
    "${ts}" "${esc_session}" "${esc_pipeline}" "${esc_level}" "${esc_event}" "${esc_stage}" "${esc_status}" "$$" \
    "${esc_target}" "${esc_mode}" "${esc_aliases}" "${msg}" \
    >> "${AEO_FORENSIC_EVENTS_FILE}"
}

aeo_forensics_write_sync() {
  [[ "${AEO_FORENSIC_ACTIVE:-0}" == "1" ]] || return 0

  local sync_json="${AEO_FORENSIC_PIPELINE_DIR}/sync.json"
  local alias_name
  local -a _aeo_alias_arr=()
  cat > "${sync_json}" <<EOF
{
  "syncTarget": "${AEO_FORENSIC_SYNC_TARGET}",
  "syncMode": "${AEO_FORENSIC_SYNC_MODE}",
  "syncAliases": "${AEO_FORENSIC_SYNC_ALIASES}",
  "sessionId": "${AEO_FORENSIC_SESSION_ID}",
  "pipeline": "${AEO_FORENSIC_PIPELINE}",
  "pipelineDir": "${AEO_FORENSIC_PIPELINE_DIR}",
  "eventsJsonl": "${AEO_FORENSIC_EVENTS_FILE}",
  "statusFile": "${AEO_FORENSIC_STATUS_FILE}",
  "ts": "$(aeo_forensics_now_utc)"
}
EOF

  ln -sfn "${AEO_FORENSIC_SESSION_DIR}" "${AEO_FORENSIC_ROOT}/latest-session"
  ln -sfn "${AEO_FORENSIC_PIPELINE_DIR}" "${AEO_FORENSIC_ROOT}/latest-${AEO_FORENSIC_PIPELINE}"
  cp -f "${sync_json}" "${AEO_FORENSIC_ROOT}/aeolator-sync.json"
  cp -f "${sync_json}" "${AEO_FORENSIC_ROOT}/aeolater-sync.json"
  cp -f "${sync_json}" "${AEO_FORENSIC_ROOT}/aesolator-sync.json"

  IFS=',' read -r -a _aeo_alias_arr <<< "${AEO_FORENSIC_SYNC_ALIASES}"
  for alias_name in "${_aeo_alias_arr[@]}"; do
    alias_name="${alias_name//[[:space:]]/}"
    alias_name="$(aeo_forensics_sanitize "${alias_name}")"
    [[ -n "${alias_name}" ]] || continue
    cp -f "${sync_json}" "${AEO_FORENSIC_ROOT}/${alias_name}-sync.json"
  done
}

aeo_forensics_init() {
  local pipeline="${1:-unknown-pipeline}"
  if ! aeo_forensics_enabled; then
    export AEO_FORENSIC_ACTIVE=0
    return 0
  fi

  : "${AEO_FORENSIC_ROOT:=/tmp/aeolator-forensics}"
  : "${AEO_FORENSIC_SYNC_TARGET:=aeolator}"
  : "${AEO_FORENSIC_SYNC_MODE:=native}"
  : "${AEO_FORENSIC_SYNC_ALIASES:=aeolator,aeolater,aesolator}"
  : "${AEO_FORENSIC_SESSION_ID:=}"

  if [[ -z "${AEO_FORENSIC_SESSION_ID}" ]]; then
    AEO_FORENSIC_SESSION_ID="$(date -u +%Y%m%dT%H%M%SZ)-$$"
  fi

  local pipeline_safe
  pipeline_safe="$(aeo_forensics_sanitize "${pipeline}")"

  local repo_root
  repo_root="${ROOT_DIR:-$(pwd)}"

  export AEO_FORENSIC_ACTIVE=1
  export AEO_FORENSIC_PIPELINE="${pipeline_safe}"
  export AEO_FORENSIC_SESSION_DIR="${AEO_FORENSIC_ROOT}/${AEO_FORENSIC_SESSION_ID}"
  export AEO_FORENSIC_PIPELINE_DIR="${AEO_FORENSIC_SESSION_DIR}/${AEO_FORENSIC_PIPELINE}"
  export AEO_FORENSIC_EVENTS_FILE="${AEO_FORENSIC_PIPELINE_DIR}/events.jsonl"
  export AEO_FORENSIC_STATUS_FILE="${AEO_FORENSIC_PIPELINE_DIR}/status.env"
  export AEO_FORENSIC_STAGE_SEQ=0

  mkdir -p "${AEO_FORENSIC_PIPELINE_DIR}/stages"
  touch "${AEO_FORENSIC_EVENTS_FILE}"

  if [[ ! -f "${AEO_FORENSIC_SESSION_DIR}/session.meta.env" ]]; then
    local git_head git_branch
    git_head="$(git -C "${repo_root}" rev-parse HEAD 2>/dev/null || true)"
    git_branch="$(git -C "${repo_root}" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
    cat > "${AEO_FORENSIC_SESSION_DIR}/session.meta.env" <<EOF
session_id=${AEO_FORENSIC_SESSION_ID}
sync_target=${AEO_FORENSIC_SYNC_TARGET}
sync_mode=${AEO_FORENSIC_SYNC_MODE}
sync_aliases=${AEO_FORENSIC_SYNC_ALIASES}
repo_root=${repo_root}
git_branch=${git_branch}
git_head=${git_head}
started_utc=$(aeo_forensics_now_utc)
EOF
  fi

  printf 'pipeline=%s\nstarted_utc=%s\npid=%s\n' \
    "${AEO_FORENSIC_PIPELINE}" "$(aeo_forensics_now_utc)" "$$" > "${AEO_FORENSIC_STATUS_FILE}"

  aeo_forensics_emit_event "info" "CI_PIPELINE_START" "pipeline" "start" "pipeline forensic initialized"
  aeo_forensics_write_sync
}

aeo_forensics_finalize() {
  local rc="${1:-0}"
  if [[ "${AEO_FORENSIC_ACTIVE:-0}" != "1" ]]; then
    return "${rc}"
  fi

  printf 'exit_code=%s\nfinished_utc=%s\n' "${rc}" "$(aeo_forensics_now_utc)" >> "${AEO_FORENSIC_STATUS_FILE}"
  if [[ "${rc}" -eq 0 ]]; then
    aeo_forensics_emit_event "info" "CI_PIPELINE_END" "pipeline" "success" "pipeline completed successfully"
  else
    aeo_forensics_emit_event "error" "CI_PIPELINE_END" "pipeline" "failed" "pipeline failed"
  fi
  aeo_forensics_write_sync
  return "${rc}"
}

aeo_forensics_run_stage() {
  local stage_name="$1"
  shift
  if [[ "${AEO_FORENSIC_ACTIVE:-0}" != "1" ]]; then
    "$@"
    return $?
  fi

  local stage_safe idx stage_dir rc
  stage_safe="$(aeo_forensics_sanitize "${stage_name}")"
  AEO_FORENSIC_STAGE_SEQ=$((AEO_FORENSIC_STAGE_SEQ + 1))
  printf -v idx '%03d' "${AEO_FORENSIC_STAGE_SEQ}"
  stage_dir="${AEO_FORENSIC_PIPELINE_DIR}/stages/${idx}-${stage_safe}"
  mkdir -p "${stage_dir}"
  printf '%q ' "$@" > "${stage_dir}/command.sh.txt"
  printf '\n' >> "${stage_dir}/command.sh.txt"

  aeo_forensics_emit_event "info" "CI_STAGE_START" "${stage_name}" "start" "$*"

  set +e
  "$@" > >(tee "${stage_dir}/stdout.log") 2> >(tee "${stage_dir}/stderr.log" >&2)
  rc=$?
  set -e

  printf '%s\n' "${rc}" > "${stage_dir}/exit_code.txt"
  if [[ "${rc}" -eq 0 ]]; then
    aeo_forensics_emit_event "info" "CI_STAGE_END" "${stage_name}" "success" "stage completed"
  else
    aeo_forensics_emit_event "error" "CI_STAGE_END" "${stage_name}" "failed" "stage failed"
  fi
  return "${rc}"
}

aeo_forensics_wrap_main() {
  local pipeline="$1"
  shift
  local entrypoint="$1"
  shift

  aeo_forensics_init "${pipeline}"

  local rc=0
  "${entrypoint}" "$@" || rc=$?

  aeo_forensics_finalize "${rc}"
  return "${rc}"
}
