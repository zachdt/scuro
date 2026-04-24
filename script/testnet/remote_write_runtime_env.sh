#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=script/testnet/lib/common.sh
source "$(dirname "$0")/lib/common.sh"

if [[ $# -lt 2 ]]; then
  echo "usage: $0 <ssh-target> <runtime-env-path>" >&2
  exit 1
fi

TARGET="$(remote_target "$1")"
RUNTIME_ENV_PATH="$2"

if [[ ! -f "${RUNTIME_ENV_PATH}" ]]; then
  echo "runtime env file not found: ${RUNTIME_ENV_PATH}" >&2
  exit 1
fi

remote_run "${TARGET}" "set -euo pipefail
mkdir -p /etc/scuro-testnet
"
remote_copy_to "${RUNTIME_ENV_PATH}" "${TARGET}" "/etc/scuro-testnet/runtime.env"
