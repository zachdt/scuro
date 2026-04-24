#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=script/testnet/lib/common.sh
source "$(dirname "$0")/lib/common.sh"

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <ssh-target> [remote-bundle-path]" >&2
  exit 1
fi

TARGET="$(remote_target "$1")"
REMOTE_BUNDLE_PATH="${2:-/tmp/scuro-bootstrap/bundle.tar.gz}"
LOCAL_CERT_PATH="${SCURO_TESTNET_ORIGIN_CERT_PATH:-$(terraform_dir)/.origin/scuro-origin.pem}"
LOCAL_KEY_PATH="${SCURO_TESTNET_ORIGIN_KEY_PATH:-$(terraform_dir)/.origin/scuro-origin.key}"

remote_run "${TARGET}" "set -euo pipefail
mkdir -p /tmp/scuro-bootstrap /etc/scuro-testnet/tls
tar -xzf '${REMOTE_BUNDLE_PATH}' -C /tmp/scuro-bootstrap repo/ops/testnet/runtime/bootstrap_host.sh
"

if [[ -f "${LOCAL_CERT_PATH}" && -f "${LOCAL_KEY_PATH}" ]]; then
  remote_copy_to "${LOCAL_CERT_PATH}" "${TARGET}" "/etc/scuro-testnet/tls/origin.pem"
  remote_copy_to "${LOCAL_KEY_PATH}" "${TARGET}" "/etc/scuro-testnet/tls/origin.key"
fi

remote_run "${TARGET}" "set -euo pipefail
bash /tmp/scuro-bootstrap/repo/ops/testnet/runtime/bootstrap_host.sh '${REMOTE_BUNDLE_PATH}'
"
