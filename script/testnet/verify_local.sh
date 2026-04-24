#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=script/testnet/lib/common.sh
source "$(dirname "$0")/lib/common.sh"
require_cmd forge
require_cmd anvil
require_cmd cast
require_cmd curl
require_cmd bash

ROOT="$(repo_root)"
RPC_PORT="${RPC_PORT:-8545}"
RPC_URL="http://127.0.0.1:${RPC_PORT}"
ADMIN_KEY="${PRIVATE_KEY:-0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80}"
PLAYER1_KEY="${PLAYER1_PRIVATE_KEY:-0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d}"
PLAYER2_KEY="${PLAYER2_PRIVATE_KEY:-0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a}"
ANVIL_LOG="$(mktemp)"
DEPLOY_LOG="$(mktemp)"
SNAPSHOT_FILE="$(mktemp)"

cleanup() {
  if [[ -n "${ANVIL_PID:-}" ]]; then
    kill "${ANVIL_PID}" >/dev/null 2>&1 || true
  fi
  rm -f "${ANVIL_LOG}" "${DEPLOY_LOG}" "${SNAPSHOT_FILE}"
}
trap cleanup EXIT

echo "[1/5] Targeted forge build for testnet scripts"
cd "${ROOT}"
forge build \
  script/testnet/TestnetDeployCommon.s.sol \
  script/testnet/DeployCore.s.sol \
  script/testnet/DeployNumberPickerModule.s.sol \
  script/testnet/DeploySlotModule.s.sol \
  script/testnet/DeployFinalize.s.sol \
  script/testnet/SmokeNumberPicker.s.sol \
  script/testnet/SmokeSlot.s.sol

echo "[2/5] Focused forge tests"
forge test --match-path 'test/{ProtocolCore,NumberPickerAdapter,SlotMachineController}.t.sol' --offline
forge test --match-path 'test/invariants/*.t.sol' --offline

echo "[3/5] Start Anvil"
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

extract_value() {
  local label="$1"
  awk -v wanted="${label}" '$1 == wanted {print $2}' "${DEPLOY_LOG}" | tail -n 1
}

deploy_stack() {
  : >"${DEPLOY_LOG}"
  PRIVATE_KEY="${ADMIN_KEY}" \
    PLAYER1_PRIVATE_KEY="${PLAYER1_KEY}" \
    PLAYER2_PRIVATE_KEY="${PLAYER2_KEY}" \
    bash "${ROOT}/script/testnet/deploy_staged.sh" "${RPC_URL}" \
    2>&1 | tee "${DEPLOY_LOG}" >/dev/null

  SCURO_TOKEN="$(extract_value ScuroToken)"
  PROTOCOL_SETTLEMENT="$(extract_value ProtocolSettlement)"
  NUMBER_PICKER_ADAPTER="$(extract_value NumberPickerAdapter)"
  NUMBER_PICKER_ENGINE="$(extract_value NumberPickerEngine)"
  SLOT_MACHINE_CONTROLLER="$(extract_value SlotMachineController)"
  SLOT_MACHINE_ENGINE="$(extract_value SlotMachineEngine)"
  SOLO_DEVELOPER="$(extract_value SoloDeveloper)"
  NUMBER_PICKER_EXPRESSION_TOKEN_ID="$(extract_value NumberPickerExpressionTokenId)"
  SLOT_MACHINE_EXPRESSION_TOKEN_ID="$(extract_value SlotMachineExpressionTokenId)"
  SLOT_BASE_PRESET_ID="$(extract_value SlotBasePresetId)"

  export \
    SCURO_TOKEN \
    PROTOCOL_SETTLEMENT \
    NUMBER_PICKER_ADAPTER \
    NUMBER_PICKER_ENGINE \
    SLOT_MACHINE_CONTROLLER \
    SLOT_MACHINE_ENGINE \
    SOLO_DEVELOPER \
    NUMBER_PICKER_EXPRESSION_TOKEN_ID \
    SLOT_MACHINE_EXPRESSION_TOKEN_ID \
    SLOT_BASE_PRESET_ID
}

restore_baseline_snapshot() {
  local state
  state="$(tr -d '\r\n' <"${SNAPSHOT_FILE}")"
  state="${state#\"}"
  state="${state%\"}"
  if [[ "${state}" != 0x* ]]; then
    state="0x${state}"
  fi
  cast rpc --rpc-url "${RPC_URL}" anvil_reset >/dev/null
  cast rpc --rpc-url "${RPC_URL}" anvil_loadState "[\"${state}\"]" --raw >/dev/null
}

run_smoke() {
  local target="$1"
  PRIVATE_KEY="${ADMIN_KEY}" PLAYER1_PRIVATE_KEY="${PLAYER1_KEY}" PLAYER2_PRIVATE_KEY="${PLAYER2_KEY}" \
    forge script "${target}" \
      --rpc-url "${RPC_URL}" \
      --broadcast \
      --offline \
      --skip-simulation \
      --non-interactive >/dev/null
}

echo "[4/5] Deploy stack and capture clean baseline"
deploy_stack
cast rpc --rpc-url "${RPC_URL}" anvil_dumpState >"${SNAPSHOT_FILE}"

echo "[5/5] Snapshot-isolated smoke passes"
restore_baseline_snapshot
run_smoke "script/testnet/SmokeNumberPicker.s.sol:SmokeNumberPicker"

restore_baseline_snapshot
run_smoke "script/testnet/SmokeSlot.s.sol:SmokeSlot"

echo "local verification passed"
