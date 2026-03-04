#!/usr/bin/env bash
set -euo pipefail

# Backward-compat shim: keep legacy entrypoint name while mainline uses source naming.
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/resolve-bionic-source.sh" "$@"
