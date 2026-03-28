#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=script/aws/lib/common.sh
source "$(dirname "$0")/lib/common.sh"
require_cmd forge
require_cmd anvil
require_cmd curl
require_cmd python3

ROOT="$(repo_root)"
THRESHOLDS_PATH="${ROOT}/script/aws/deploy-gas-thresholds.json"
RPC_PORT="${RPC_PORT:-9555}"
RPC_URL="http://127.0.0.1:${RPC_PORT}"
ADMIN_KEY="${PRIVATE_KEY:-0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80}"
ANVIL_LOG="$(mktemp)"

cleanup() {
  if [[ -n "${ANVIL_PID:-}" ]]; then
    kill "${ANVIL_PID}" >/dev/null 2>&1 || true
  fi
  rm -f "${ANVIL_LOG}"
}
trap cleanup EXIT

cd "${ROOT}"

echo "[gas-check] building staged deploy scripts"
forge build \
  script/aws/BetaDeployCommon.s.sol \
  script/aws/DeployCore.s.sol \
  script/aws/DeployNumberPickerModule.s.sol \
  script/aws/DeployPokerTournamentModule.s.sol \
  script/aws/DeployPokerPvPModule.s.sol \
  script/aws/DeployBlackjackModule.s.sol \
  script/aws/DeployFinalize.s.sol >/dev/null

echo "[gas-check] starting anvil on ${RPC_URL}"
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

echo "[gas-check] running staged beta deploy"
PRIVATE_KEY="${ADMIN_KEY}" bash "${ROOT}/script/aws/deploy_staged.sh" "${RPC_URL}" >/dev/null

echo "[gas-check] parsing broadcast receipts"
python3 - <<'PY' "${ROOT}" "${THRESHOLDS_PATH}"
from __future__ import annotations

import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
thresholds = json.loads(pathlib.Path(sys.argv[2]).read_text())

stage_files = {
    "core": root / "broadcast/DeployCore.s.sol/31337/run-latest.json",
    "number_picker": root / "broadcast/DeployNumberPickerModule.s.sol/31337/run-latest.json",
    "poker_tournament": root / "broadcast/DeployPokerTournamentModule.s.sol/31337/run-latest.json",
    "poker_pvp": root / "broadcast/DeployPokerPvPModule.s.sol/31337/run-latest.json",
    "blackjack": root / "broadcast/DeployBlackjackModule.s.sol/31337/run-latest.json",
    "finalize": root / "broadcast/DeployFinalize.s.sol/31337/run-latest.json",
}

failures: list[str] = []

for name, path in stage_files.items():
    if not path.exists():
        failures.append(f"missing broadcast receipts for {name}")

if failures:
    print("Deploy gas regression detected:", file=sys.stderr)
    for failure in failures:
        print(f" - {failure}", file=sys.stderr)
    sys.exit(1)

core_run = json.loads(stage_files["core"].read_text())
core_seen: dict[str, int] = {}
core_map = {
    "SoloModuleDeployer": "solo_module_deployer",
    "BlackjackModuleDeployer": "blackjack_module_deployer",
    "PokerModuleDeployer": "poker_module_deployer",
    "CheminDeFerModuleDeployer": "chemin_de_fer_module_deployer",
    "GameDeploymentFactory": "game_deployment_factory",
}

total_gas = 0
for tx, receipt in zip(core_run["transactions"], core_run["receipts"]):
    gas_used = int(receipt["gasUsed"], 16)
    total_gas += gas_used
    contract_name = tx.get("contractName")
    if contract_name in core_map and contract_name not in core_seen:
        core_seen[contract_name] = gas_used

for contract_name, threshold_key in core_map.items():
    actual = core_seen.get(contract_name)
    expected = thresholds["staged_deploy"][threshold_key]
    if actual is None:
        failures.append(f"missing gas sample for core {contract_name}")
        continue
    if actual > expected:
        failures.append(f"core {contract_name} used {actual} gas (max {expected})")

stage_map = {
    "number_picker": "number_picker_module",
    "poker_tournament": "poker_tournament_module",
    "poker_pvp": "poker_pvp_module",
    "blackjack": "blackjack_module",
}

for name, threshold_key in stage_map.items():
    run = json.loads(stage_files[name].read_text())
    if not run["receipts"]:
        failures.append(f"missing receipts for {name}")
        continue
    actual = int(run["receipts"][0]["gasUsed"], 16)
    total_gas += sum(int(receipt["gasUsed"], 16) for receipt in run["receipts"])
    expected = thresholds["staged_deploy"][threshold_key]
    if actual > expected:
        failures.append(f"{name} used {actual} gas (max {expected})")

finalize_run = json.loads(stage_files["finalize"].read_text())
total_gas += sum(int(receipt["gasUsed"], 16) for receipt in finalize_run["receipts"])

if total_gas > thresholds["staged_deploy"]["full_beta_deploy_total"]:
    failures.append(
        f"full beta deploy used {total_gas} gas (max {thresholds['staged_deploy']['full_beta_deploy_total']})"
    )

if failures:
    print("Deploy gas regression detected:", file=sys.stderr)
    for failure in failures:
        print(f" - {failure}", file=sys.stderr)
    sys.exit(1)

print("deploy gas thresholds satisfied")
PY
