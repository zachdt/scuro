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

rpc_ready() {
  curl -sSf \
    -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
    "${RPC_URL}" | grep -q '"result"'
}

for _ in $(seq 1 20); do
  if rpc_ready; then
    break
  fi
  sleep 1
done

if ! rpc_ready; then
  echo "anvil did not start" >&2
  exit 1
fi

PRIVATE_KEY="${ADMIN_KEY}" bash "${ROOT_DIR}/script/aws/deploy_staged.sh" "${RPC_URL}" 2>&1 | tee "${DEPLOY_LOG}"

extract_value() {
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

SCURO_TOKEN="$(extract_value ScuroToken)"
STAKING_TOKEN="$(extract_value ScuroStakingToken)"
SETTLEMENT="$(extract_value ProtocolSettlement)"
GAME_CATALOG="$(extract_value GameCatalog)"
DEVELOPER_REWARDS="$(extract_value DeveloperRewards)"
NUMBER_PICKER_ENGINE="$(extract_value NumberPickerEngine)"
NUMBER_PICKER_ADAPTER="$(extract_value NumberPickerAdapter)"
SLOT_MACHINE_ENGINE="$(extract_value SlotMachineEngine)"
SLOT_MACHINE_CONTROLLER="$(extract_value SlotMachineController)"
NUMBER_PICKER_MODULE_ID="$(extract_value NumberPickerModuleId)"
SLOT_MACHINE_MODULE_ID="$(extract_value SlotMachineModuleId)"
PLAYER1="$(extract_value Player1)"
PLAYER2="$(extract_value Player2)"
SOLO_DEVELOPER="$(extract_value SoloDeveloper)"
NUMBER_PICKER_EXPRESSION_TOKEN_ID="$(extract_value NumberPickerExpressionTokenId)"
SLOT_MACHINE_EXPRESSION_TOKEN_ID="$(extract_value SlotMachineExpressionTokenId)"

for label in SCURO_TOKEN STAKING_TOKEN SETTLEMENT GAME_CATALOG DEVELOPER_REWARDS NUMBER_PICKER_ENGINE NUMBER_PICKER_ADAPTER SLOT_MACHINE_ENGINE SLOT_MACHINE_CONTROLLER NUMBER_PICKER_MODULE_ID SLOT_MACHINE_MODULE_ID PLAYER1 PLAYER2 SOLO_DEVELOPER NUMBER_PICKER_EXPRESSION_TOKEN_ID SLOT_MACHINE_EXPRESSION_TOKEN_ID; do
  if [[ -z "${!label}" ]]; then
    echo "missing deployment output for ${label}" >&2
    exit 1
  fi
done

MINTER_ROLE="$(cast keccak "MINTER_ROLE")"

assert_equal "$(cast call "${SCURO_TOKEN}" "hasRole(bytes32,address)(bool)" "${MINTER_ROLE}" "${SETTLEMENT}" --rpc-url "${RPC_URL}")" "true" "settlement minter role"
assert_equal "$(cast call "${SCURO_TOKEN}" "hasRole(bytes32,address)(bool)" "${MINTER_ROLE}" "${DEVELOPER_REWARDS}" --rpc-url "${RPC_URL}")" "true" "developer rewards minter role"
assert_equal "$(cast call "${GAME_CATALOG}" "isLaunchableController(address)(bool)" "${NUMBER_PICKER_ADAPTER}" --rpc-url "${RPC_URL}")" "true" "number picker launchability"
assert_equal "$(cast call "${GAME_CATALOG}" "isLaunchableController(address)(bool)" "${SLOT_MACHINE_CONTROLLER}" --rpc-url "${RPC_URL}")" "true" "slot launchability"
assert_equal "$(cast call "${GAME_CATALOG}" "isAuthorizedControllerForEngine(address,address)(bool)" "${NUMBER_PICKER_ADAPTER}" "${NUMBER_PICKER_ENGINE}" --rpc-url "${RPC_URL}")" "true" "number picker authorization"
assert_equal "$(cast call "${GAME_CATALOG}" "isAuthorizedControllerForEngine(address,address)(bool)" "${SLOT_MACHINE_CONTROLLER}" "${SLOT_MACHINE_ENGINE}" --rpc-url "${RPC_URL}")" "true" "slot authorization"
assert_equal "$(cast call "${GAME_CATALOG}" "controllerModuleIds(address)(uint256)" "${NUMBER_PICKER_ADAPTER}" --rpc-url "${RPC_URL}")" "${NUMBER_PICKER_MODULE_ID}" "number picker module id"
assert_equal "$(cast call "${GAME_CATALOG}" "controllerModuleIds(address)(uint256)" "${SLOT_MACHINE_CONTROLLER}" --rpc-url "${RPC_URL}")" "${SLOT_MACHINE_MODULE_ID}" "slot module id"
assert_equal "$(cast call "${SCURO_TOKEN}" "balanceOf(address)(uint256)" "${PLAYER1}" --rpc-url "${RPC_URL}")" "10000000000000000000000" "player1 seed balance"
assert_equal "$(cast call "${SCURO_TOKEN}" "balanceOf(address)(uint256)" "${PLAYER2}" --rpc-url "${RPC_URL}")" "10000000000000000000000" "player2 seed balance"
assert_equal "$(cast call "${SCURO_TOKEN}" "balanceOf(address)(uint256)" "${ADMIN_ADDR}" --rpc-url "${RPC_URL}")" "10000000000000000000000" "admin seed balance"

cast send "${SCURO_TOKEN}" "approve(address,uint256)" "${STAKING_TOKEN}" "5000000000000000000" \
  --private-key "${ADMIN_KEY}" --rpc-url "${RPC_URL}" >/dev/null
cast send "${STAKING_TOKEN}" "stake(uint256)" "5000000000000000000" \
  --private-key "${ADMIN_KEY}" --rpc-url "${RPC_URL}" >/dev/null
assert_equal "$(cast call "${STAKING_TOKEN}" "balanceOf(address)(uint256)" "${ADMIN_ADDR}" --rpc-url "${RPC_URL}")" "5000000000000000000" "admin staked balance"

PRIVATE_KEY="${ADMIN_KEY}" \
PLAYER1_PRIVATE_KEY=0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d \
PLAYER2_PRIVATE_KEY=0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a \
SCURO_TOKEN="${SCURO_TOKEN}" \
PROTOCOL_SETTLEMENT="${SETTLEMENT}" \
NUMBER_PICKER_ADAPTER="${NUMBER_PICKER_ADAPTER}" \
NUMBER_PICKER_ENGINE="${NUMBER_PICKER_ENGINE}" \
SLOT_MACHINE_CONTROLLER="${SLOT_MACHINE_CONTROLLER}" \
SLOT_MACHINE_ENGINE="${SLOT_MACHINE_ENGINE}" \
NUMBER_PICKER_EXPRESSION_TOKEN_ID="${NUMBER_PICKER_EXPRESSION_TOKEN_ID}" \
SLOT_MACHINE_EXPRESSION_TOKEN_ID="${SLOT_MACHINE_EXPRESSION_TOKEN_ID}" \
forge script script/aws/SmokeNumberPicker.s.sol:SmokeNumberPicker --rpc-url "${RPC_URL}" --broadcast --offline --skip-simulation --non-interactive >/dev/null

PRIVATE_KEY="${ADMIN_KEY}" \
PLAYER1_PRIVATE_KEY=0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d \
PLAYER2_PRIVATE_KEY=0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a \
SCURO_TOKEN="${SCURO_TOKEN}" \
PROTOCOL_SETTLEMENT="${SETTLEMENT}" \
SLOT_MACHINE_CONTROLLER="${SLOT_MACHINE_CONTROLLER}" \
SLOT_MACHINE_ENGINE="${SLOT_MACHINE_ENGINE}" \
SLOT_MACHINE_EXPRESSION_TOKEN_ID="${SLOT_MACHINE_EXPRESSION_TOKEN_ID}" \
forge script script/aws/SmokeSlot.s.sol:SmokeSlot --rpc-url "${RPC_URL}" --broadcast --offline --skip-simulation --non-interactive >/dev/null

echo "deploy smoke passed"
