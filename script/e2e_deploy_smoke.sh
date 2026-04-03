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

bun run --cwd "${ROOT_DIR}/zk" check >/dev/null

anvil --port "${RPC_PORT}" --disable-code-size-limit --gas-limit 100000000 >"${ANVIL_LOG}" 2>&1 &
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

PRIVATE_KEY="${ADMIN_KEY}" bash "${ROOT_DIR}/script/aws/deploy_staged.sh" "${RPC_URL}" \
  2>&1 | tee "${DEPLOY_LOG}"

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
EXPRESSION_REGISTRY="$(extract_value DeveloperExpressionRegistry)"
DEVELOPER_REWARDS="$(extract_value DeveloperRewards)"
NUMBER_PICKER_ENGINE="$(extract_value NumberPickerEngine)"
NUMBER_PICKER_ADAPTER="$(extract_value NumberPickerAdapter)"
TOURNAMENT_POKER_ENGINE="$(extract_value TournamentPokerEngine)"
TOURNAMENT_POKER_VERIFIER_BUNDLE="$(extract_value TournamentPokerVerifierBundle)"
PVP_POKER_ENGINE="$(extract_value PvPPokerEngine)"
BLACKJACK_ENGINE="$(extract_value BlackjackEngine)"
BLACKJACK_VERIFIER_BUNDLE="$(extract_value BlackjackVerifierBundle)"
BLACKJACK_CONTROLLER="$(extract_value BlackjackController)"
TOURNAMENT_CONTROLLER="$(extract_value TournamentController)"
PVP_CONTROLLER="$(extract_value PvPController)"
NUMBER_PICKER_MODULE_ID="$(extract_value NumberPickerModuleId)"
TOURNAMENT_POKER_MODULE_ID="$(extract_value TournamentPokerModuleId)"
PVP_POKER_MODULE_ID="$(extract_value PvPPokerModuleId)"
BLACKJACK_MODULE_ID="$(extract_value BlackjackModuleId)"
PLAYER1="$(extract_value Player1)"
PLAYER2="$(extract_value Player2)"
SOLO_DEVELOPER="$(extract_value SoloDeveloper)"
POKER_DEVELOPER="$(extract_value PokerDeveloper)"
NUMBER_PICKER_EXPRESSION_TOKEN_ID="$(extract_value NumberPickerExpressionTokenId)"
POKER_EXPRESSION_TOKEN_ID="$(extract_value PokerExpressionTokenId)"
BLACKJACK_EXPRESSION_TOKEN_ID="$(extract_value BlackjackExpressionTokenId)"

for label in SCURO_TOKEN STAKING_TOKEN SETTLEMENT GAME_CATALOG GAME_DEPLOYMENT_FACTORY EXPRESSION_REGISTRY DEVELOPER_REWARDS NUMBER_PICKER_ENGINE NUMBER_PICKER_ADAPTER TOURNAMENT_POKER_ENGINE TOURNAMENT_POKER_VERIFIER_BUNDLE PVP_POKER_ENGINE PVP_POKER_VERIFIER_BUNDLE BLACKJACK_ENGINE BLACKJACK_VERIFIER_BUNDLE BLACKJACK_CONTROLLER TOURNAMENT_CONTROLLER PVP_CONTROLLER NUMBER_PICKER_MODULE_ID TOURNAMENT_POKER_MODULE_ID PVP_POKER_MODULE_ID BLACKJACK_MODULE_ID PLAYER1 PLAYER2 SOLO_DEVELOPER POKER_DEVELOPER NUMBER_PICKER_EXPRESSION_TOKEN_ID POKER_EXPRESSION_TOKEN_ID BLACKJACK_EXPRESSION_TOKEN_ID; do
  if [[ -z "${!label}" ]]; then
    echo "missing deployment output for ${label}" >&2
    exit 1
  fi
done

MINTER_ROLE="$(cast keccak "MINTER_ROLE")"

assert_equal \
  "$(cast call "${SCURO_TOKEN}" "hasRole(bytes32,address)(bool)" "${MINTER_ROLE}" "${SETTLEMENT}" --rpc-url "${RPC_URL}")" \
  "true" \
  "settlement minter role"
assert_equal \
  "$(cast call "${SCURO_TOKEN}" "hasRole(bytes32,address)(bool)" "${MINTER_ROLE}" "${DEVELOPER_REWARDS}" --rpc-url "${RPC_URL}")" \
  "true" \
  "developer rewards minter role"
assert_equal \
  "$(cast call "${GAME_CATALOG}" "isLaunchableController(address)(bool)" "${NUMBER_PICKER_ADAPTER}" --rpc-url "${RPC_URL}")" \
  "true" \
  "number picker controller launchability"
assert_equal \
  "$(cast call "${GAME_CATALOG}" "isAuthorizedControllerForEngine(address,address)(bool)" "${NUMBER_PICKER_ADAPTER}" "${NUMBER_PICKER_ENGINE}" --rpc-url "${RPC_URL}")" \
  "true" \
  "number picker controller authorization"
assert_equal \
  "$(cast call "${GAME_CATALOG}" "isLaunchableController(address)(bool)" "${TOURNAMENT_CONTROLLER}" --rpc-url "${RPC_URL}")" \
  "true" \
  "tournament controller launchability"
assert_equal \
  "$(cast call "${GAME_CATALOG}" "isAuthorizedControllerForEngine(address,address)(bool)" "${TOURNAMENT_CONTROLLER}" "${TOURNAMENT_POKER_ENGINE}" --rpc-url "${RPC_URL}")" \
  "true" \
  "tournament controller authorization"
assert_equal \
  "$(cast call "${GAME_CATALOG}" "isLaunchableController(address)(bool)" "${PVP_CONTROLLER}" --rpc-url "${RPC_URL}")" \
  "true" \
  "pvp controller launchability"
assert_equal \
  "$(cast call "${GAME_CATALOG}" "isAuthorizedControllerForEngine(address,address)(bool)" "${PVP_CONTROLLER}" "${PVP_POKER_ENGINE}" --rpc-url "${RPC_URL}")" \
  "true" \
  "pvp controller authorization"
assert_equal \
  "$(cast call "${GAME_CATALOG}" "isLaunchableController(address)(bool)" "${BLACKJACK_CONTROLLER}" --rpc-url "${RPC_URL}")" \
  "true" \
  "blackjack controller launchability"
assert_equal \
  "$(cast call "${GAME_CATALOG}" "isAuthorizedControllerForEngine(address,address)(bool)" "${BLACKJACK_CONTROLLER}" "${BLACKJACK_ENGINE}" --rpc-url "${RPC_URL}")" \
  "true" \
  "blackjack controller authorization"
assert_equal \
  "$(cast call "${GAME_CATALOG}" "controllerModuleIds(address)(uint256)" "${NUMBER_PICKER_ADAPTER}" --rpc-url "${RPC_URL}")" \
  "${NUMBER_PICKER_MODULE_ID}" \
  "number picker module id mapping"
assert_equal \
  "$(cast call "${GAME_CATALOG}" "controllerModuleIds(address)(uint256)" "${TOURNAMENT_CONTROLLER}" --rpc-url "${RPC_URL}")" \
  "${TOURNAMENT_POKER_MODULE_ID}" \
  "tournament module id mapping"
assert_equal \
  "$(cast call "${GAME_CATALOG}" "controllerModuleIds(address)(uint256)" "${PVP_CONTROLLER}" --rpc-url "${RPC_URL}")" \
  "${PVP_POKER_MODULE_ID}" \
  "pvp module id mapping"
assert_equal \
  "$(cast call "${GAME_CATALOG}" "controllerModuleIds(address)(uint256)" "${BLACKJACK_CONTROLLER}" --rpc-url "${RPC_URL}")" \
  "${BLACKJACK_MODULE_ID}" \
  "blackjack module id mapping"
assert_equal \
  "$(cast call "${EXPRESSION_REGISTRY}" "ownerOf(uint256)(address)" "${NUMBER_PICKER_EXPRESSION_TOKEN_ID}" --rpc-url "${RPC_URL}")" \
  "${SOLO_DEVELOPER}" \
  "number picker expression owner"
assert_equal \
  "$(cast call "${EXPRESSION_REGISTRY}" "ownerOf(uint256)(address)" "${POKER_EXPRESSION_TOKEN_ID}" --rpc-url "${RPC_URL}")" \
  "${POKER_DEVELOPER}" \
  "poker expression owner"
assert_equal \
  "$(cast call "${EXPRESSION_REGISTRY}" "ownerOf(uint256)(address)" "${BLACKJACK_EXPRESSION_TOKEN_ID}" --rpc-url "${RPC_URL}")" \
  "${SOLO_DEVELOPER}" \
  "blackjack expression owner"

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

PRIVATE_KEY="${ADMIN_KEY}" \
PLAYER1_PRIVATE_KEY=0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d \
PLAYER2_PRIVATE_KEY=0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a \
SCURO_TOKEN="${SCURO_TOKEN}" \
DEVELOPER_REWARDS="${DEVELOPER_REWARDS}" \
GAME_CATALOG="${GAME_CATALOG}" \
TOURNAMENT_CONTROLLER="${TOURNAMENT_CONTROLLER}" \
TOURNAMENT_POKER_ENGINE="${TOURNAMENT_POKER_ENGINE}" \
TOURNAMENT_POKER_VERIFIER_BUNDLE="${TOURNAMENT_POKER_VERIFIER_BUNDLE}" \
BLACKJACK_CONTROLLER="${BLACKJACK_CONTROLLER}" \
BLACKJACK_ENGINE="${BLACKJACK_ENGINE}" \
BLACKJACK_VERIFIER_BUNDLE="${BLACKJACK_VERIFIER_BUNDLE}" \
SOLO_DEVELOPER="${SOLO_DEVELOPER}" \
POKER_DEVELOPER="${POKER_DEVELOPER}" \
POKER_EXPRESSION_TOKEN_ID="${POKER_EXPRESSION_TOKEN_ID}" \
BLACKJACK_EXPRESSION_TOKEN_ID="${BLACKJACK_EXPRESSION_TOKEN_ID}" \
forge script script/SmokeRealProofHands.s.sol:SmokeRealProofHands --rpc-url "${RPC_URL}" --broadcast --offline --skip-simulation --non-interactive --disable-code-size-limit >/dev/null

echo "deploy smoke passed"
