#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib/common.sh"
require_cmd aws
require_cmd tar
require_cmd bun
require_cmd forge
require_cmd anvil
require_cmd cast

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <s3-bucket> [bundle-name]" >&2
  exit 1
fi

BUCKET="$1"
BUNDLE_NAME="${2:-$(date +%Y%m%d-%H%M%S)}"
ROOT="$(repo_root)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

mkdir -p "${TMP_DIR}/repo" "${TMP_DIR}/tools/bin"

tar \
  --exclude=.git \
  --exclude=out \
  --exclude=cache \
  --exclude=.scuro-testnet \
  --exclude='infra/aws/testnet/.terraform' \
  --exclude='infra/aws/testnet/*.tfstate*' \
  -cf "${TMP_DIR}/repo.tar" \
  -C "${ROOT}" .
tar -xf "${TMP_DIR}/repo.tar" -C "${TMP_DIR}/repo"

cp "$(which bun)" "${TMP_DIR}/tools/bin/bun"
cp "$(which forge)" "${TMP_DIR}/tools/bin/forge"
cp "$(which anvil)" "${TMP_DIR}/tools/bin/anvil"
cp "$(which cast)" "${TMP_DIR}/tools/bin/cast"

tar -czf "${TMP_DIR}/${BUNDLE_NAME}.tar.gz" -C "${TMP_DIR}" repo tools
aws s3 cp "${TMP_DIR}/${BUNDLE_NAME}.tar.gz" "s3://${BUCKET}/bundles/${BUNDLE_NAME}.tar.gz"

printf 's3://%s/bundles/%s.tar.gz\n' "${BUCKET}" "${BUNDLE_NAME}"
