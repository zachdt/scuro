#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=script/aws/lib/common.sh
source "$(dirname "$0")/lib/common.sh"
require_cmd aws

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <instance-id> [remote-port] [local-port]" >&2
  exit 1
fi

INSTANCE_ID="$1"
REMOTE_PORT="${2:-8787}"
LOCAL_PORT="${3:-8787}"

aws ssm start-session \
  --target "${INSTANCE_ID}" \
  --document-name AWS-StartPortForwardingSession \
  --parameters "portNumber=${REMOTE_PORT},localPortNumber=${LOCAL_PORT}"
