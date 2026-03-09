#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RPC_PORT="${RPC_PORT:-8545}"
RPC_URL="http://127.0.0.1:${RPC_PORT}"
ADMIN_KEY="${PRIVATE_KEY:-0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80}"
ADMIN_ADDR="$(cast wallet address --private-key "${ADMIN_KEY}")"

ANVIL_LOG="$(mktemp)"
DEPLOY_LOG="$(mktemp)"

cleanup() {
  if [[ -n "${ANVIL_PID:-}" ]]; then
    kill "${ANVIL_PID}" >/dev/null 2>&1 || true
  fi
  rm -f "${ANVIL_LOG}" "${DEPLOY_LOG}"
}
trap cleanup EXIT

cd "${ROOT_DIR}"

anvil --port "${RPC_PORT}" >"${ANVIL_LOG}" 2>&1 &
ANVIL_PID=$!

for _ in $(seq 1 20); do
  if cast block-number --rpc-url "${RPC_URL}" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

if ! cast block-number --rpc-url "${RPC_URL}" >/dev/null 2>&1; then
  echo "anvil did not start" >&2
  exit 1
fi

PRIVATE_KEY="${ADMIN_KEY}" forge script script/DeployLocal.s.sol:DeployLocal --rpc-url "${RPC_URL}" --broadcast \
  2>&1 | tee "${DEPLOY_LOG}"

extract_address() {
  local label="$1"
  awk -v wanted="${label}" '$1 == wanted {print $2}' "${DEPLOY_LOG}" | tail -n 1
}

assert_equal() {
  local actual="$1"
  local expected="$2"
  local label="$3"
  actual="$(printf '%s\n' "${actual}" | awk '{print $1}')"
  if [[ "${actual}" != "${expected}" ]]; then
    echo "assertion failed for ${label}: expected ${expected}, got ${actual}" >&2
    exit 1
  fi
}

SCURO_TOKEN="$(extract_address ScuroToken)"
STAKING_TOKEN="$(extract_address ScuroStakingToken)"
SETTLEMENT="$(extract_address ProtocolSettlement)"
REGISTRY="$(extract_address GameEngineRegistry)"
CREATOR_REWARDS="$(extract_address CreatorRewards)"
NUMBER_PICKER_ENGINE="$(extract_address NumberPickerEngine)"
NUMBER_PICKER_ADAPTER="$(extract_address NumberPickerAdapter)"
POKER_ENGINE="$(extract_address SingleDraw2To7Engine)"
PLAYER1="$(extract_address Player1)"
PLAYER2="$(extract_address Player2)"
SOLO_CREATOR="$(extract_address SoloCreator)"

for label in SCURO_TOKEN STAKING_TOKEN SETTLEMENT REGISTRY CREATOR_REWARDS NUMBER_PICKER_ENGINE NUMBER_PICKER_ADAPTER POKER_ENGINE PLAYER1 PLAYER2 SOLO_CREATOR; do
  if [[ -z "${!label}" ]]; then
    echo "missing deployment output for ${label}" >&2
    exit 1
  fi
done

MINTER_ROLE="$(cast keccak "MINTER_ROLE")"
CONTROLLER_ROLE="$(cast keccak "CONTROLLER_ROLE")"
ADAPTER_ROLE="$(cast keccak "ADAPTER_ROLE")"

assert_equal \
  "$(cast call "${SCURO_TOKEN}" "hasRole(bytes32,address)(bool)" "${MINTER_ROLE}" "${SETTLEMENT}" --rpc-url "${RPC_URL}")" \
  "true" \
  "settlement minter role"
assert_equal \
  "$(cast call "${SCURO_TOKEN}" "hasRole(bytes32,address)(bool)" "${MINTER_ROLE}" "${CREATOR_REWARDS}" --rpc-url "${RPC_URL}")" \
  "true" \
  "creator rewards minter role"
assert_equal \
  "$(cast call "${SETTLEMENT}" "hasRole(bytes32,address)(bool)" "${CONTROLLER_ROLE}" "${NUMBER_PICKER_ADAPTER}" --rpc-url "${RPC_URL}")" \
  "true" \
  "adapter controller role"
assert_equal \
  "$(cast call "${NUMBER_PICKER_ENGINE}" "hasRole(bytes32,address)(bool)" "${ADAPTER_ROLE}" "${NUMBER_PICKER_ADAPTER}" --rpc-url "${RPC_URL}")" \
  "true" \
  "adapter engine role"
assert_equal \
  "$(cast call "${REGISTRY}" "isRegisteredForSolo(address)(bool)" "${NUMBER_PICKER_ENGINE}" --rpc-url "${RPC_URL}")" \
  "true" \
  "number picker registration"
assert_equal \
  "$(cast call "${REGISTRY}" "isRegisteredForTournament(address)(bool)" "${POKER_ENGINE}" --rpc-url "${RPC_URL}")" \
  "true" \
  "poker tournament registration"

assert_equal \
  "$(cast call "${SCURO_TOKEN}" "balanceOf(address)(uint256)" "${PLAYER1}" --rpc-url "${RPC_URL}")" \
  "10000000000000000000000" \
  "player1 seed balance"
assert_equal \
  "$(cast call "${SCURO_TOKEN}" "balanceOf(address)(uint256)" "${PLAYER2}" --rpc-url "${RPC_URL}")" \
  "10000000000000000000000" \
  "player2 seed balance"
assert_equal \
  "$(cast call "${SCURO_TOKEN}" "balanceOf(address)(uint256)" "${ADMIN_ADDR}" --rpc-url "${RPC_URL}")" \
  "10000000000000000000000" \
  "admin seed balance"

cast send "${SCURO_TOKEN}" "approve(address,uint256)" "${STAKING_TOKEN}" "5000000000000000000" \
  --private-key "${ADMIN_KEY}" --rpc-url "${RPC_URL}" >/dev/null
cast send "${STAKING_TOKEN}" "stake(uint256)" "5000000000000000000" \
  --private-key "${ADMIN_KEY}" --rpc-url "${RPC_URL}" >/dev/null
assert_equal \
  "$(cast call "${STAKING_TOKEN}" "balanceOf(address)(uint256)" "${ADMIN_ADDR}" --rpc-url "${RPC_URL}")" \
  "5000000000000000000" \
  "admin staked balance"

echo "deploy smoke passed"
