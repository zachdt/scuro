#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=script/aws/lib/common.sh
source "$(dirname "$0")/lib/common.sh"
require_cmd forge
require_cmd anvil
require_cmd curl
require_cmd python3

ROOT="$(repo_root)"
REPORT_PATH="${ROOT}/docs/deploy-gas-baseline.md"
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

forge build \
  script/aws/BetaDeployCommon.s.sol \
  script/aws/DeployCore.s.sol \
  script/aws/DeployNumberPickerModule.s.sol \
  script/aws/DeployPokerTournamentModule.s.sol \
  script/aws/DeployPokerPvPModule.s.sol \
  script/aws/DeployBlackjackModule.s.sol \
  script/aws/DeployFinalize.s.sol >/dev/null

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

DEPLOY_STATUS=0
if ! PRIVATE_KEY="${ADMIN_KEY}" bash "${ROOT}/script/aws/deploy_staged.sh" "${RPC_URL}" >/dev/null; then
  DEPLOY_STATUS=$?
fi

python3 - <<'PY' "${ROOT}" "${REPORT_PATH}" "${DEPLOY_STATUS}"
from __future__ import annotations

import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
report_path = pathlib.Path(sys.argv[2])
deploy_status = int(sys.argv[3])

contracts = [
    ("GameDeploymentFactory", "out/GameDeploymentFactory.sol/GameDeploymentFactory.json"),
    ("SoloModuleDeployer", "out/SoloModuleDeployer.sol/SoloModuleDeployer.json"),
    ("BlackjackModuleDeployer", "out/BlackjackModuleDeployer.sol/BlackjackModuleDeployer.json"),
    ("PokerModuleDeployer", "out/PokerModuleDeployer.sol/PokerModuleDeployer.json"),
    ("CheminDeFerModuleDeployer", "out/CheminDeFerModuleDeployer.sol/CheminDeFerModuleDeployer.json"),
    ("PokerVerifierBundle", "out/PokerVerifierBundle.sol/PokerVerifierBundle.json"),
    ("BlackjackVerifierBundle", "out/BlackjackVerifierBundle.sol/BlackjackVerifierBundle.json"),
    ("PokerInitialDealVerifier", "out/PokerInitialDealVerifier.sol/PokerInitialDealVerifier.json"),
    ("PokerDrawResolveVerifier", "out/PokerDrawResolveVerifier.sol/PokerDrawResolveVerifier.json"),
    ("PokerShowdownVerifier", "out/PokerShowdownVerifier.sol/PokerShowdownVerifier.json"),
    ("BlackjackInitialDealVerifier", "out/BlackjackInitialDealVerifier.sol/BlackjackInitialDealVerifier.json"),
    ("BlackjackActionResolveVerifier", "out/BlackjackActionResolveVerifier.sol/BlackjackActionResolveVerifier.json"),
    ("BlackjackShowdownVerifier", "out/BlackjackShowdownVerifier.sol/BlackjackShowdownVerifier.json"),
    ("SingleDraw2To7Engine", "out/SingleDraw2To7Engine.sol/SingleDraw2To7Engine.json"),
    ("SingleDeckBlackjackEngine", "out/SingleDeckBlackjackEngine.sol/SingleDeckBlackjackEngine.json"),
]

size_rows: list[tuple[str, int, int]] = []
for label, rel_path in contracts:
    artifact = root / rel_path
    data = json.loads(artifact.read_text())
    bytecode = len(data["bytecode"]["object"]) // 2
    deployed = len(data["deployedBytecode"]["object"]) // 2
    size_rows.append((label, bytecode, deployed))

gas_rows: list[tuple[str, int]] = []
deploy_failure_note: str | None = None
total_gas = 0
stage_receipts = [
    (
        root / "broadcast/DeployCore.s.sol/31337/run-latest.json",
        {
            "SoloModuleDeployer": "Core:SoloModuleDeployer",
            "BlackjackModuleDeployer": "Core:BlackjackModuleDeployer",
            "PokerModuleDeployer": "Core:PokerModuleDeployer",
            "CheminDeFerModuleDeployer": "Core:CheminDeFerModuleDeployer",
            "GameDeploymentFactory": "Core:GameDeploymentFactory",
        },
    ),
    (
        root / "broadcast/DeployNumberPickerModule.s.sol/31337/run-latest.json",
        {"deploySoloModule(uint8,bytes)": "NumberPicker:DeployModule"},
    ),
    (
        root / "broadcast/DeployPokerTournamentModule.s.sol/31337/run-latest.json",
        {"deployTournamentModule(uint8,bytes)": "TournamentPoker:DeployModule"},
    ),
    (
        root / "broadcast/DeployPokerPvPModule.s.sol/31337/run-latest.json",
        {"deployPvPModule(uint8,bytes)": "PvPPoker:DeployModule"},
    ),
    (
        root / "broadcast/DeployBlackjackModule.s.sol/31337/run-latest.json",
        {"deploySoloModule(uint8,bytes)": "Blackjack:DeployModule"},
    ),
    (
        root / "broadcast/DeployFinalize.s.sol/31337/run-latest.json",
        {},
    ),
]

if deploy_status == 0:
    for path, labels in stage_receipts:
        if not path.exists():
            deploy_failure_note = f"missing broadcast receipt file: {path}"
            gas_rows = []
            break
        run = json.loads(path.read_text())
        for tx, receipt in zip(run["transactions"], run["receipts"]):
            gas_used = int(receipt["gasUsed"], 16)
            total_gas += gas_used
            label = labels.get(tx.get("contractName") or tx.get("function"))
            if label:
                gas_rows.append((label, gas_used))
else:
    deploy_failure_note = f"staged deploy failed with exit code {deploy_status}"

report_lines = [
    "# Deploy Gas Baseline",
    "",
    "- Anvil reference gas limit: `100000000`",
    "- This baseline uses the staged beta deploy path, not `DeployLocal`.",
    "- The previously failing tx was approximately `32194656` gas, which is below the Anvil ceiling and points to deployment architecture size rather than a simple chain gas-cap mismatch.",
    "",
    "## Bytecode Size Baseline",
    "",
    "| Contract | Constructor Bytecode (bytes) | Runtime Bytecode (bytes) |",
    "| --- | ---: | ---: |",
]

for label, bytecode, deployed in size_rows:
    report_lines.append(f"| {label} | {bytecode} | {deployed} |")

report_lines.extend(
    [
        "",
        "## Staged Deploy Gas Baseline",
        "",
    ]
)

if gas_rows:
    report_lines.extend(
        [
            "| Stage Action | Gas Used |",
            "| --- | ---: |",
        ]
    )
    for label, gas in gas_rows:
        report_lines.append(f"| {label} | {gas} |")
    report_lines.extend(
        [
            "",
            f"- Full staged beta deploy total gas: `{total_gas}`",
        ]
    )
else:
    report_lines.append(
        f"Staged deploy gas rows were not captured in this environment. {deploy_failure_note or 'Run this generator on Linux or in CI to populate them.'}"
    )

report_path.write_text("\n".join(report_lines) + "\n")
PY

echo "wrote ${REPORT_PATH}"
