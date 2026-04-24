#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=script/testnet/lib/common.sh
source "$(dirname "$0")/lib/common.sh"

if [[ $# -lt 2 ]]; then
  echo "usage: $0 <ssh-target> <bundle-archive> [remote-bundle-path]" >&2
  exit 1
fi

TARGET="$(remote_target "$1")"
BUNDLE_ARCHIVE="$2"
REMOTE_BUNDLE_PATH="${3:-/tmp/scuro-bootstrap/bundle.tar.gz}"

if [[ ! -f "${BUNDLE_ARCHIVE}" ]]; then
  echo "bundle archive not found: ${BUNDLE_ARCHIVE}" >&2
  exit 1
fi

remote_run "${TARGET}" "set -euo pipefail
mkdir -p '$(dirname "${REMOTE_BUNDLE_PATH}")'
"
remote_copy_to "${BUNDLE_ARCHIVE}" "${TARGET}" "${REMOTE_BUNDLE_PATH}"
printf '%s\n' "${REMOTE_BUNDLE_PATH}"
