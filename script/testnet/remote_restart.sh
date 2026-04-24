#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=script/testnet/lib/common.sh
source "$(dirname "$0")/lib/common.sh"

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <ssh-target>" >&2
  exit 1
fi

TARGET="$(remote_target "$1")"

remote_run "${TARGET}" "set -euo pipefail
systemctl daemon-reload
systemctl restart scuro-anvil.service scuro-operator-api.service
if systemctl list-unit-files nginx.service >/dev/null 2>&1; then
  nginx -t
  systemctl restart nginx.service
fi
"
