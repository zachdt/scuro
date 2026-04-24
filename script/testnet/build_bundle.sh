#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=script/testnet/lib/common.sh
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

BUN_BIN="${SCURO_BUNDLE_BUN_BIN:-}"
FORGE_BIN="${SCURO_BUNDLE_FORGE_BIN:-}"
CAST_BIN="${SCURO_BUNDLE_CAST_BIN:-}"
ANVIL_BIN="${SCURO_BUNDLE_ANVIL_BIN:-}"
SVM_DIR="${SCURO_BUNDLE_SVM_DIR:-}"

mkdir -p "${TMP_DIR}/repo" "${TMP_DIR}/tools/bin"

tar \
  --exclude=.git \
  --exclude=out \
  --exclude=cache \
  --exclude=.scuro-testnet \
  --exclude='infra/hetzner-cloudflare/testnet/.terraform' \
  --exclude='infra/hetzner-cloudflare/testnet/*.tfstate*' \
  --exclude='infra/hetzner-cloudflare/testnet/*.auto.tfvars*' \
  --exclude='infra/hetzner-cloudflare/testnet/.origin' \
  -cf "${TMP_DIR}/repo.tar" \
  -C "${ROOT}" .
tar -xf "${TMP_DIR}/repo.tar" -C "${TMP_DIR}/repo"

if [[ "${SCURO_BUNDLE_INCLUDE_HOST_TOOLS:-1}" == "1" ]]; then
  if [[ "$(uname -s)" != "Linux" || "$(uname -m)" != "x86_64" ]]; then
    echo "Linux x86_64 is required for deployable bundles with host tools." >&2
    echo "Build release bundles on GitHub ubuntu runners, or set SCURO_BUNDLE_INCLUDE_HOST_TOOLS=0 for a source-only archive." >&2
    exit 1
  fi

  if [[ -z "${BUN_BIN}" ]]; then
    require_cmd bun
    BUN_BIN="$(command -v bun)"
  fi
  if [[ -z "${FORGE_BIN}" ]]; then
    require_cmd forge
    FORGE_BIN="$(command -v forge)"
  fi
  if [[ -z "${CAST_BIN}" ]]; then
    require_cmd cast
    CAST_BIN="$(command -v cast)"
  fi
  if [[ -z "${ANVIL_BIN}" ]]; then
    require_cmd anvil
    ANVIL_BIN="$(command -v anvil)"
  fi

  cp "${BUN_BIN}" "${TMP_DIR}/tools/bin/bun"
  cp "${FORGE_BIN}" "${TMP_DIR}/tools/bin/forge"
  cp "${ANVIL_BIN}" "${TMP_DIR}/tools/bin/anvil"
  cp "${CAST_BIN}" "${TMP_DIR}/tools/bin/cast"

  if [[ -n "${SVM_DIR}" && -d "${SVM_DIR}" ]]; then
    cp -R "${SVM_DIR}" "${TMP_DIR}/tools/svm"
  fi
fi

mkdir -p "$(dirname "${OUTPUT_ARCHIVE}")"
tar -czf "${OUTPUT_ARCHIVE}" -C "${TMP_DIR}" repo tools
