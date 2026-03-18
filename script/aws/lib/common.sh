#!/usr/bin/env bash
set -euo pipefail

repo_root() {
  cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd
}

terraform_dir() {
  printf '%s/infra/aws/testnet\n' "$(repo_root)"
}

service_dir() {
  printf '%s/ops/aws-testnet\n' "$(repo_root)"
}

require_cmd() {
  local cmd="$1"
  command -v "${cmd}" >/dev/null 2>&1 || {
    echo "missing required command: ${cmd}" >&2
    exit 1
  }
}
