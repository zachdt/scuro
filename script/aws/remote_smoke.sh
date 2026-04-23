#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=script/aws/lib/common.sh
source "$(dirname "$0")/lib/common.sh"

if [[ $# -lt 2 ]]; then
  echo "usage: $0 <instance-id> <number-picker|slot> [region]" >&2
  exit 1
fi

INSTANCE_ID="$1"
TARGET="$2"
REGION="$(resolve_region "${3:-}")"

RESPONSE="$("$(dirname "$0")/remote_operator.sh" "${INSTANCE_ID}" POST "/smoke/${TARGET}" "" "${REGION}")"
printf '%s\n' "${RESPONSE}"
