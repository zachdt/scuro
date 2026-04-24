#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=script/testnet/lib/common.sh
source "$(dirname "$0")/lib/common.sh"

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <ssh-target>" >&2
  exit 1
fi

"$(dirname "$0")/remote_operator.sh" "$1" POST /reset
