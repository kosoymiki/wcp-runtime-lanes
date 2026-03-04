#!/usr/bin/env bash
set -euo pipefail

component=""
source_dir=""
report_file=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --component) component="$2"; shift 2 ;;
    --source) source_dir="$2"; shift 2 ;;
    --report) report_file="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 --component NAME --source DIR --report FILE"
      exit 0
      ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -n "${component}" ]] || { echo "component is required" >&2; exit 1; }
[[ -n "${source_dir}" ]] || { echo "source dir is required" >&2; exit 1; }
[[ -n "${report_file}" ]] || { echo "report file is required" >&2; exit 1; }
[[ -d "${source_dir}" ]] || { echo "source dir not found: ${source_dir}" >&2; exit 1; }

mkdir -p "$(dirname -- "${report_file}")"
contract_dir="${source_dir}/.aesolator-native-forensics"
mkdir -p "${contract_dir}"

cat > "${contract_dir}/contract.env" <<'EOF_ENV'
export CPPFLAGS="${CPPFLAGS:-} -DAESOLATOR_NATIVE_FORENSICS=1"
export CFLAGS="${CFLAGS:-} -DAESOLATOR_NATIVE_FORENSICS=1"
export CXXFLAGS="${CXXFLAGS:-} -DAESOLATOR_NATIVE_FORENSICS=1"
EOF_ENV

cat > "${contract_dir}/manifest.json" <<EOF_JSON
{
  "component": "${component}",
  "sourceDir": "${source_dir}",
  "status": "scaffolded",
  "macro": "AESOLATOR_NATIVE_FORENSICS",
  "targets": [
    "wine/proton loader",
    "fex translator",
    "box64 dynarec",
    "turnip/mesa vulkan",
    "dxvk",
    "vkd3d",
    "alsa",
    "pulse"
  ],
  "notes": [
    "This scaffold injects compile flags and a manifest into the source tree.",
    "Actual runtime emitters still require source-specific patch hunks to compile in CI."
  ]
}
EOF_JSON

{
  printf '{\n'
  printf '  "component": "%s",\n' "${component}"
  printf '  "sourceDir": "%s",\n' "${source_dir}"
  printf '  "status": "scaffolded",\n'
  printf '  "contractEnv": ".aesolator-native-forensics/contract.env",\n'
  printf '  "manifest": ".aesolator-native-forensics/manifest.json",\n'
  printf '  "detectedFiles": ['
  find "${source_dir}" -maxdepth 3 -type f \( -name 'loader.c' -o -name 'dxvk.conf' -o -name '*vkd3d*' -o -name '*box64*' -o -name '*FEX*' -o -name '*pulse*' -o -name '*alsa*' \) \
    -printf '"%P",' 2>/dev/null | sed 's/,$//'
  printf ']\n}\n'
} > "${report_file}"
