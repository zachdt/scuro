#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=script/testnet/lib/common.sh
source "$(dirname "$0")/lib/common.sh"

if [[ $# -lt 2 ]]; then
  echo "usage: $0 <ssh-target> <number-picker|slot>" >&2
  exit 1
fi

TARGET_SSH="$(remote_target "$1")"
TARGET="$2"

RESPONSE="$("$(dirname "$0")/remote_operator.sh" "${TARGET_SSH}" POST "/smoke/${TARGET}")"
printf '%s\n' "${RESPONSE}"
