#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=script/testnet/lib/common.sh
source "$(dirname "$0")/lib/common.sh"

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <ssh-target> [attempts] [sleep-seconds]" >&2
  exit 1
fi

TARGET="$(remote_target "$1")"
ATTEMPTS="${2:-30}"
SLEEP_SECONDS="${3:-10}"

for attempt in $(seq 1 "${ATTEMPTS}"); do
  if OUTPUT="$("$(dirname "$0")/remote_operator.sh" "${TARGET}" GET /health 2>/dev/null)"; then
    if python3 - <<'PY' "${OUTPUT}"
import json
import sys

try:
    payload = json.loads(sys.argv[1])
except json.JSONDecodeError:
    raise SystemExit(1)

chain = payload.get("chain")
raise SystemExit(0 if isinstance(chain, dict) and chain.get("ok") is True else 1)
PY
    then
      printf '%s\n' "${OUTPUT}"
      exit 0
    fi

    echo "operator is live but chain is not ready (${attempt}/${ATTEMPTS})" >&2
  fi

  echo "waiting for chain readiness (${attempt}/${ATTEMPTS})" >&2
  sleep "${SLEEP_SECONDS}"
done

echo "chain did not become ready in time" >&2
exit 1
