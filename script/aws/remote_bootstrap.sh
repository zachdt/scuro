#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=script/aws/lib/common.sh
source "$(dirname "$0")/lib/common.sh"
require_cmd aws

if [[ $# -lt 2 ]]; then
  echo "usage: $0 <instance-id> <bundle-s3-uri> [region]" >&2
  exit 1
fi

INSTANCE_ID="$1"
BUNDLE_URI="$2"
REGION="$(resolve_region "${3:-}")"

COMMANDS=$(cat <<EOF
set -euo pipefail
mkdir -p /tmp/scuro-bootstrap
aws s3 cp "${BUNDLE_URI}" /tmp/scuro-bootstrap/bundle.tar.gz ${REGION:+--region ${REGION}}
tar -xzf /tmp/scuro-bootstrap/bundle.tar.gz -C /tmp/scuro-bootstrap
bash /tmp/scuro-bootstrap/repo/ops/aws-testnet/runtime/bootstrap_host.sh /tmp/scuro-bootstrap/bundle.tar.gz
EOF
)

ssm_run_command "${INSTANCE_ID}" "Bootstrap Scuro private testnet host" "${COMMANDS}" "${REGION}"
echo "bootstrap completed on ${INSTANCE_ID}"
