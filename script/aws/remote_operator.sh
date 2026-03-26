#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=script/aws/lib/common.sh
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
run_curl() {
  if [[ -n "${BODY_B64}" ]]; then
    printf '%s' '${BODY_B64}' | base64 -d >/tmp/scuro-operator-body.json
    curl -sS -X "${METHOD}" -H 'Content-Type: application/json' --data-binary @/tmp/scuro-operator-body.json "\${URL}"
  else
    curl -sS -X "${METHOD}" "\${URL}"
  fi
}

set +e
run_curl
curl_status=\$?
set -e

if [[ "\${curl_status}" -ne 0 ]]; then
  echo "==== operator request failed ====" >&2
  echo "curl exit status: \${curl_status}" >&2
  echo "url: \${URL}" >&2
  echo "==== operator health after failure ====" >&2
  curl -sS http://127.0.0.1:${PORT}/health >&2 || true
  echo >&2
  echo "==== operator and anvil service status ====" >&2
  systemctl --no-pager --full status scuro-operator-api.service scuro-anvil.service >&2 || true
  echo "==== operator log tail ====" >&2
  tail -n 160 /var/log/scuro-testnet/operator-api.log >&2 || true
  echo "==== anvil log tail ====" >&2
  tail -n 160 /var/log/scuro-testnet/anvil.log >&2 || true
  echo "==== deploy log tail ====" >&2
  tail -n 160 /var/lib/scuro-testnet/deploy.log >&2 || true
  echo "==== kernel log tail ====" >&2
  journalctl -k --no-pager -n 120 >&2 || true
  exit "\${curl_status}"
fi
EOF
)

ssm_run_command "${INSTANCE_ID}" "Invoke Scuro operator ${METHOD} ${PATHNAME}" "${COMMANDS}" "${REGION}"
