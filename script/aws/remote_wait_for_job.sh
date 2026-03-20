#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=script/aws/lib/common.sh
source "$(dirname "$0")/lib/common.sh"
require_cmd python3

if [[ $# -lt 2 ]]; then
  echo "usage: $0 <instance-id> <job-id> [region] [attempts] [sleep-seconds]" >&2
  exit 1
fi

INSTANCE_ID="$1"
JOB_ID="$2"
REGION="$(resolve_region "${3:-}")"
ATTEMPTS="${4:-60}"
SLEEP_SECONDS="${5:-5}"

for attempt in $(seq 1 "${ATTEMPTS}"); do
  OUTPUT="$("$(dirname "$0")/remote_operator.sh" "${INSTANCE_ID}" GET "/proof-jobs/${JOB_ID}" "" "${REGION}")"
  STATUS="$(printf '%s' "${OUTPUT}" | python3 -c 'import json, sys; print(json.load(sys.stdin).get("status", ""))')"

  if [[ "${STATUS}" == "completed" ]]; then
    printf '%s\n' "${OUTPUT}"
    exit 0
  fi

  if [[ "${STATUS}" == "failed" ]]; then
    printf '%s\n' "${OUTPUT}" >&2
    exit 1
  fi

  echo "waiting for proof job ${JOB_ID} (${attempt}/${ATTEMPTS})" >&2
  sleep "${SLEEP_SECONDS}"
done

echo "proof job ${JOB_ID} did not complete in time" >&2
exit 1
