#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib/common.sh"
require_cmd aws

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <s3-bucket> [bundle-name]" >&2
  exit 1
fi

BUCKET="$1"
BUNDLE_NAME="${2:-$(date +%Y%m%d-%H%M%S)}"
ROOT="$(repo_root)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

"${ROOT}/script/aws/build_bundle.sh" "${TMP_DIR}/${BUNDLE_NAME}.tar.gz"
aws s3 cp "${TMP_DIR}/${BUNDLE_NAME}.tar.gz" "s3://${BUCKET}/bundles/${BUNDLE_NAME}.tar.gz"

printf 's3://%s/bundles/%s.tar.gz\n' "${BUCKET}" "${BUNDLE_NAME}"
