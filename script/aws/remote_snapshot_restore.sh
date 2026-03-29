#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=script/aws/lib/common.sh
source "$(dirname "$0")/lib/common.sh"

if [[ $# -lt 2 ]]; then
  echo "usage: $0 <instance-id> <snapshot-name> [region]" >&2
  exit 1
fi

INSTANCE_ID="$1"
SNAPSHOT_NAME="$2"
REGION="$(resolve_region "${3:-}")"
BODY=$(printf '{"name":"%s"}' "${SNAPSHOT_NAME}")

"$(dirname "$0")/remote_operator.sh" "${INSTANCE_ID}" POST /snapshots/restore "${BODY}" "${REGION}"
