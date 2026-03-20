#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=script/aws/lib/common.sh
source "$(dirname "$0")/lib/common.sh"

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <instance-id> [region] [attempts] [sleep-seconds]" >&2
  exit 1
fi

INSTANCE_ID="$1"
REGION="$(resolve_region "${2:-}")"
ATTEMPTS="${3:-30}"
SLEEP_SECONDS="${4:-10}"

for attempt in $(seq 1 "${ATTEMPTS}"); do
  if OUTPUT="$("$(dirname "$0")/remote_operator.sh" "${INSTANCE_ID}" GET /health "" "${REGION}" 2>/dev/null)"; then
    if python3 - <<'PY' "${OUTPUT}"
import json
import sys

try:
    payload = json.loads(sys.argv[1])
except json.JSONDecodeError:
    raise SystemExit(1)

raise SystemExit(0 if payload.get("ok") is True else 1)
PY
    then
      printf '%s\n' "${OUTPUT}"
      exit 0
    fi

    echo "operator responded but health is not ready (${attempt}/${ATTEMPTS})" >&2
  fi

  echo "waiting for operator health (${attempt}/${ATTEMPTS})" >&2
  sleep "${SLEEP_SECONDS}"
done

echo "operator did not become healthy in time" >&2
exit 1
