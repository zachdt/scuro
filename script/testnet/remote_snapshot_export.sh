#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=script/testnet/lib/common.sh
source "$(dirname "$0")/lib/common.sh"

if [[ $# -lt 2 ]]; then
  echo "usage: $0 <ssh-target> <snapshot-name>" >&2
  exit 1
fi

TARGET="$(remote_target "$1")"
SNAPSHOT_NAME="$2"
BODY=$(printf '{"name":"%s"}' "${SNAPSHOT_NAME}")

"$(dirname "$0")/remote_operator.sh" "${TARGET}" POST /snapshots/export "${BODY}"
