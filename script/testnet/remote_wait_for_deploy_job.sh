#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=script/testnet/lib/common.sh
source "$(dirname "$0")/lib/common.sh"
require_cmd python3

if [[ $# -lt 2 ]]; then
  echo "usage: $0 <ssh-target> <job-id> [attempts] [sleep-seconds]" >&2
  exit 1
fi

TARGET="$(remote_target "$1")"
JOB_ID="$2"
ATTEMPTS="${3:-120}"
SLEEP_SECONDS="${4:-10}"
LAST_OUTPUT=""

for attempt in $(seq 1 "${ATTEMPTS}"); do
  OUTPUT="$("$(dirname "$0")/remote_operator.sh" "${TARGET}" GET "/deploy-jobs/${JOB_ID}")"
  LAST_OUTPUT="${OUTPUT}"
  STATUS="$(printf '%s' "${OUTPUT}" | python3 -c 'import json, sys; print(json.load(sys.stdin).get("status", ""))')"

  if [[ "${STATUS}" == "completed" ]]; then
    printf '%s\n' "${OUTPUT}"
    exit 0
  fi

  if [[ "${STATUS}" == "failed" ]]; then
    printf '%s\n' "${OUTPUT}"
    echo "deploy job ${JOB_ID} failed" >&2
    exit 1
  fi

  echo "waiting for deploy job ${JOB_ID} (${attempt}/${ATTEMPTS})" >&2
  sleep "${SLEEP_SECONDS}"
done

if [[ -n "${LAST_OUTPUT}" ]]; then
  printf '%s\n' "${LAST_OUTPUT}"
fi
echo "deploy job ${JOB_ID} did not complete in time" >&2
exit 1
