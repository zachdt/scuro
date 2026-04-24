#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=script/aws/lib/common.sh
source "$(dirname "$0")/lib/common.sh"

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <tools-dir> [output-log]" >&2
  exit 1
fi

TOOLS_DIR="$1"
OUTPUT_LOG="${2:-}"
ROOT="$(repo_root)"
RPC_PORT="${RPC_PORT:-9555}"
RPC_URL="http://127.0.0.1:${RPC_PORT}"
PRIVATE_KEY="${PRIVATE_KEY:-0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80}"
FUNDED_BALANCE_HEX="${FUNDED_BALANCE_HEX:-0x21e19e0c9bab2400000}"

FORGE_BIN="${TOOLS_DIR}/forge"
ANVIL_BIN="${TOOLS_DIR}/anvil"
CAST_BIN="${TOOLS_DIR}/cast"

require_cmd curl

if [[ ! -x "${FORGE_BIN}" || ! -x "${ANVIL_BIN}" || ! -x "${CAST_BIN}" ]]; then
  echo "expected bundled forge, cast, and anvil binaries in ${TOOLS_DIR}" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
ANVIL_LOG="$(mktemp)"
cleanup() {
  if [[ -n "${ANVIL_PID:-}" ]]; then
    kill "${ANVIL_PID}" >/dev/null 2>&1 || true
  fi
  rm -rf "${TMP_DIR}"
  rm -f "${ANVIL_LOG}"
}
trap cleanup EXIT

export HOME="${TMP_DIR}"
export PATH="${TOOLS_DIR}:${PATH}"

if [[ -d "${TOOLS_DIR}/svm" ]]; then
  cp -R "${TOOLS_DIR}/svm" "${HOME}/.svm"
fi

"${ANVIL_BIN}" \
  --host 127.0.0.1 \
  --port "${RPC_PORT}" \
  --chain-id 31337 >"${ANVIL_LOG}" 2>&1 &
ANVIL_PID=$!

rpc_ready() {
  curl -sSf \
    -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
    "${RPC_URL}" >/dev/null
}

for _ in $(seq 1 20); do
  if rpc_ready; then
    break
  fi
  sleep 1
done

if ! rpc_ready; then
  echo "bundled anvil did not become ready" >&2
  sed -n '1,200p' "${ANVIL_LOG}" >&2 || true
  exit 1
fi

ADMIN_ADDRESS="$("${CAST_BIN}" wallet address --private-key "${PRIVATE_KEY}")"
"${CAST_BIN}" rpc \
  --rpc-url "${RPC_URL}" \
  anvil_setBalance \
  "[\"${ADMIN_ADDRESS}\",\"${FUNDED_BALANCE_HEX}\"]" \
  --raw >/dev/null

cd "${ROOT}"

if [[ -n "${OUTPUT_LOG}" ]]; then
  mkdir -p "$(dirname "${OUTPUT_LOG}")"
  PRIVATE_KEY="${PRIVATE_KEY}" "${FORGE_BIN}" script script/aws/DeployCore.s.sol:DeployCore \
    --rpc-url "${RPC_URL}" \
    --broadcast \
    --offline \
    --skip-simulation \
    --non-interactive \
    2>&1 | tee "${OUTPUT_LOG}"
else
  PRIVATE_KEY="${PRIVATE_KEY}" "${FORGE_BIN}" script script/aws/DeployCore.s.sol:DeployCore \
    --rpc-url "${RPC_URL}" \
    --broadcast \
    --offline \
    --skip-simulation \
    --non-interactive
fi
