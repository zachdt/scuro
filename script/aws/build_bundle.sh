#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib/common.sh"
require_cmd tar

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <output-archive>" >&2
  exit 1
fi

OUTPUT_ARCHIVE="$1"
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

if [[ "${SCURO_BUNDLE_INCLUDE_HOST_TOOLS:-1}" == "1" ]]; then
  if [[ "$(uname -s)" != "Linux" || "$(uname -m)" != "x86_64" ]]; then
    echo "Linux x86_64 is required for deployable bundles with host tools." >&2
    echo "Build release bundles on GitHub ubuntu runners, or set SCURO_BUNDLE_INCLUDE_HOST_TOOLS=0 for a source-only archive." >&2
    exit 1
  fi

  require_cmd bun
  require_cmd forge
  require_cmd anvil
  require_cmd cast

  cp "$(command -v bun)" "${TMP_DIR}/tools/bin/bun"
  cp "$(command -v forge)" "${TMP_DIR}/tools/bin/forge"
  cp "$(command -v anvil)" "${TMP_DIR}/tools/bin/anvil"
  cp "$(command -v cast)" "${TMP_DIR}/tools/bin/cast"
fi

mkdir -p "$(dirname "${OUTPUT_ARCHIVE}")"
tar -czf "${OUTPUT_ARCHIVE}" -C "${TMP_DIR}" repo tools
