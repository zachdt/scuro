#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib/common.sh"
require_cmd aws

if [[ $# -lt 3 ]]; then
  echo "usage: $0 <instance-id> <method> <path> [json-body] [region]" >&2
  exit 1
fi

INSTANCE_ID="$1"
METHOD="$2"
PATHNAME="$3"
BODY="${4:-}"
REGION="$(resolve_region "${5:-}")"
PORT="${SCURO_OPERATOR_PORT:-8787}"
BODY_B64=""

if [[ -n "${BODY}" ]]; then
  BODY_B64="$(printf '%s' "${BODY}" | base64 | tr -d '\n')"
fi

COMMANDS=$(cat <<EOF
set -euo pipefail
URL="http://127.0.0.1:${PORT}${PATHNAME}"
if [[ -n "${BODY_B64}" ]]; then
  printf '%s' '${BODY_B64}' | base64 -d >/tmp/scuro-operator-body.json
  curl -sS -X "${METHOD}" -H 'Content-Type: application/json' --data-binary @/tmp/scuro-operator-body.json "\${URL}"
else
  curl -sS -X "${METHOD}" "\${URL}"
fi
EOF
)

ssm_run_command "${INSTANCE_ID}" "Invoke Scuro operator ${METHOD} ${PATHNAME}" "${COMMANDS}" "${REGION}"
