#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib/common.sh"
require_cmd bun
require_cmd forge
require_cmd anvil
require_cmd curl

ROOT="$(repo_root)"
STATE_DIR="${ROOT}/.scuro-testnet"
RPC_PORT="${RPC_PORT:-8545}"
RPC_URL="http://127.0.0.1:${RPC_PORT}"
ADMIN_KEY="${PRIVATE_KEY:-0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80}"
PLAYER1_KEY="${PLAYER1_PRIVATE_KEY:-0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d}"
PLAYER2_KEY="${PLAYER2_PRIVATE_KEY:-0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a}"
ANVIL_LOG="$(mktemp)"
DEPLOY_LOG="$(mktemp)"

cleanup() {
  if [[ -n "${ANVIL_PID:-}" ]]; then
    kill "${ANVIL_PID}" >/dev/null 2>&1 || true
  fi
  rm -f "${ANVIL_LOG}" "${DEPLOY_LOG}"
}
trap cleanup EXIT

mkdir -p "${STATE_DIR}"

echo "[1/5] Bun check + tests"
bun run --cwd "${ROOT}/ops/aws-testnet" check
bun test --cwd "${ROOT}/ops/aws-testnet"

echo "[2/5] Targeted forge build for AWS scripts"
cd "${ROOT}"
forge build \
  script/aws/FixtureLoaders.sol \
  script/aws/SmokeNumberPicker.s.sol \
  script/aws/SmokePokerFixture.s.sol \
  script/aws/SmokeBlackjackFixture.s.sol \
  script/aws/SubmitPokerInitialDeal.s.sol \
  script/aws/SubmitPokerDraw.s.sol \
  script/aws/SubmitPokerShowdown.s.sol \
  script/aws/SubmitBlackjackInitialDeal.s.sol \
  script/aws/SubmitBlackjackAction.s.sol \
  script/aws/SubmitBlackjackShowdown.s.sol

echo "[3/5] Focused forge tests"
forge test --match-path 'test/aws/*.t.sol' --offline

echo "[4/5] Start Anvil"
anvil --port "${RPC_PORT}" --disable-code-size-limit >"${ANVIL_LOG}" 2>&1 &
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
  echo "anvil did not start; falling back to in-process forge smoke verification"
  forge test --match-path 'test/aws/LocalSmokeFallback.t.sol' --offline
  echo "local verification passed (forge smoke fallback)"
  exit 0
fi

extract_value() {
  local label="$1"
  awk -v wanted="${label}" '$1 == wanted {print $2}' "${DEPLOY_LOG}" | tail -n 1
}

deploy_stack() {
  : >"${DEPLOY_LOG}"
  PRIVATE_KEY="${ADMIN_KEY}" forge script script/DeployLocal.s.sol:DeployLocal \
    --rpc-url "${RPC_URL}" \
    --broadcast \
    --offline \
    --skip-simulation \
    --non-interactive \
    --disable-code-size-limit \
    2>&1 | tee "${DEPLOY_LOG}" >/dev/null

  SCURO_TOKEN="$(extract_value ScuroToken)"
  SCURO_STAKING_TOKEN="$(extract_value ScuroStakingToken)"
  PROTOCOL_SETTLEMENT="$(extract_value ProtocolSettlement)"
  GAME_CATALOG="$(extract_value GameCatalog)"
  DEVELOPER_REWARDS="$(extract_value DeveloperRewards)"
  NUMBER_PICKER_ADAPTER="$(extract_value NumberPickerAdapter)"
  NUMBER_PICKER_ENGINE="$(extract_value NumberPickerEngine)"
  TOURNAMENT_CONTROLLER="$(extract_value TournamentController)"
  TOURNAMENT_POKER_ENGINE="$(extract_value TournamentPokerEngine)"
  TOURNAMENT_POKER_VERIFIER_BUNDLE="$(extract_value TournamentPokerVerifierBundle)"
  BLACKJACK_CONTROLLER="$(extract_value BlackjackController)"
  BLACKJACK_ENGINE="$(extract_value SingleDeckBlackjackEngine)"
  BLACKJACK_VERIFIER_BUNDLE="$(extract_value BlackjackVerifierBundle)"
  SOLO_DEVELOPER="$(extract_value SoloDeveloper)"
  POKER_DEVELOPER="$(extract_value PokerDeveloper)"
  NUMBER_PICKER_EXPRESSION_TOKEN_ID="$(extract_value NumberPickerExpressionTokenId)"
  POKER_EXPRESSION_TOKEN_ID="$(extract_value PokerExpressionTokenId)"
  BLACKJACK_EXPRESSION_TOKEN_ID="$(extract_value BlackjackExpressionTokenId)"

  export \
    SCURO_TOKEN \
    SCURO_STAKING_TOKEN \
    PROTOCOL_SETTLEMENT \
    GAME_CATALOG \
    DEVELOPER_REWARDS \
    NUMBER_PICKER_ADAPTER \
    NUMBER_PICKER_ENGINE \
    TOURNAMENT_CONTROLLER \
    TOURNAMENT_POKER_ENGINE \
    TOURNAMENT_POKER_VERIFIER_BUNDLE \
    BLACKJACK_CONTROLLER \
    BLACKJACK_ENGINE \
    BLACKJACK_VERIFIER_BUNDLE \
    SOLO_DEVELOPER \
    POKER_DEVELOPER \
    NUMBER_PICKER_EXPRESSION_TOKEN_ID \
    POKER_EXPRESSION_TOKEN_ID \
    BLACKJACK_EXPRESSION_TOKEN_ID
}

reset_chain() {
  curl -sSf \
    -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","method":"anvil_reset","params":[],"id":1}' \
    "${RPC_URL}" >/dev/null
}

echo "[5/5] Local Anvil smoke passes"
reset_chain
deploy_stack
PRIVATE_KEY="${ADMIN_KEY}" PLAYER1_PRIVATE_KEY="${PLAYER1_KEY}" PLAYER2_PRIVATE_KEY="${PLAYER2_KEY}" \
  forge script script/aws/SmokeNumberPicker.s.sol:SmokeNumberPicker \
  --rpc-url "${RPC_URL}" --broadcast --offline --skip-simulation --non-interactive --disable-code-size-limit >/dev/null

reset_chain
deploy_stack
PRIVATE_KEY="${ADMIN_KEY}" PLAYER1_PRIVATE_KEY="${PLAYER1_KEY}" PLAYER2_PRIVATE_KEY="${PLAYER2_KEY}" \
  forge script script/aws/SmokePokerFixture.s.sol:SmokePokerFixture \
  --rpc-url "${RPC_URL}" --broadcast --offline --skip-simulation --non-interactive --disable-code-size-limit >/dev/null

reset_chain
deploy_stack
PRIVATE_KEY="${ADMIN_KEY}" PLAYER1_PRIVATE_KEY="${PLAYER1_KEY}" PLAYER2_PRIVATE_KEY="${PLAYER2_KEY}" \
  forge script script/aws/SmokeBlackjackFixture.s.sol:SmokeBlackjackFixture \
  --rpc-url "${RPC_URL}" --broadcast --offline --skip-simulation --non-interactive --disable-code-size-limit >/dev/null

echo "local verification passed"
