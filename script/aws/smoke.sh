#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=script/aws/lib/common.sh
source "$(dirname "$0")/lib/common.sh"
require_cmd curl

HOST="${SCURO_OPERATOR_HOST:-127.0.0.1}"
PORT="${SCURO_OPERATOR_PORT:-8787}"
TARGET="${1:-number-picker}"

case "${TARGET}" in
  number-picker|poker|blackjack)
    curl -sSf -X POST "http://${HOST}:${PORT}/smoke/${TARGET}"
    ;;
  *)
    echo "usage: $0 [number-picker|poker|blackjack]" >&2
    exit 1
    ;;
esac
