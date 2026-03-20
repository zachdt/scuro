#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=script/aws/lib/common.sh
source "$(dirname "$0")/lib/common.sh"
require_cmd curl

HOST="${SCURO_OPERATOR_HOST:-127.0.0.1}"
PORT="${SCURO_OPERATOR_PORT:-8787}"

curl -sSf -X POST "http://${HOST}:${PORT}/deploy"
