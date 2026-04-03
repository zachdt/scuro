#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=script/aws/lib/common.sh
source "$(dirname "$0")/lib/common.sh"
require_cmd forge
require_cmd python3

ROOT="$(repo_root)"
THRESHOLDS_PATH="${ROOT}/script/aws/deploy-size-thresholds.json"

cd "${ROOT}"

forge build \
  script/aws/BetaDeployCommon.s.sol \
  script/aws/DeployCore.s.sol \
  script/aws/DeployNumberPickerModule.s.sol \
  script/aws/DeployPokerTournamentModule.s.sol \
  script/aws/DeployPokerPvPModule.s.sol \
  script/aws/DeployBlackjackModule.s.sol \
  script/aws/DeployFinalize.s.sol >/dev/null

python3 - <<'PY' "${ROOT}" "${THRESHOLDS_PATH}"
from __future__ import annotations

import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
thresholds_path = pathlib.Path(sys.argv[2])

artifact_paths = {
    "GameDeploymentFactory": "out/GameDeploymentFactory.sol/GameDeploymentFactory.json",
    "SoloModuleDeployer": "out/SoloModuleDeployer.sol/SoloModuleDeployer.json",
    "BlackjackModuleDeployer": "out/BlackjackModuleDeployer.sol/BlackjackModuleDeployer.json",
    "PokerModuleDeployer": "out/PokerModuleDeployer.sol/PokerModuleDeployer.json",
    "CheminDeFerModuleDeployer": "out/CheminDeFerModuleDeployer.sol/CheminDeFerModuleDeployer.json",
    "PokerVerifierBundle": "out/PokerVerifierBundle.sol/PokerVerifierBundle.json",
    "BlackjackVerifierBundle": "out/BlackjackVerifierBundle.sol/BlackjackVerifierBundle.json",
    "PokerInitialDealVerifier": "out/PokerInitialDealVerifier.sol/PokerInitialDealVerifier.json",
    "PokerDrawResolveVerifier": "out/PokerDrawResolveVerifier.sol/PokerDrawResolveVerifier.json",
    "PokerShowdownVerifier": "out/PokerShowdownVerifier.sol/PokerShowdownVerifier.json",
    "BlackjackInitialDealVerifier": "out/BlackjackInitialDealVerifier.sol/BlackjackInitialDealVerifier.json",
    "BlackjackPeekVerifier": "out/BlackjackPeekVerifier.sol/BlackjackPeekVerifier.json",
    "BlackjackActionResolveVerifier": "out/BlackjackActionResolveVerifier.sol/BlackjackActionResolveVerifier.json",
    "BlackjackShowdownVerifier": "out/BlackjackShowdownVerifier.sol/BlackjackShowdownVerifier.json",
    "SingleDraw2To7Engine": "out/SingleDraw2To7Engine.sol/SingleDraw2To7Engine.json",
    "BlackjackEngine": "out/BlackjackEngine.sol/BlackjackEngine.json",
}

thresholds = json.loads(thresholds_path.read_text())
failures: list[str] = []

for contract, limits in thresholds.items():
    artifact = root / artifact_paths[contract]
    data = json.loads(artifact.read_text())
    constructor_bytes = len(data["bytecode"]["object"]) // 2
    runtime_bytes = len(data["deployedBytecode"]["object"]) // 2

    max_constructor = limits["constructor_bytes_max"]
    max_runtime = limits["runtime_bytes_max"]

    if constructor_bytes > max_constructor:
        failures.append(
            f"{contract} constructor bytecode grew to {constructor_bytes} bytes (max {max_constructor})"
        )
    if runtime_bytes > max_runtime:
        failures.append(
            f"{contract} runtime bytecode grew to {runtime_bytes} bytes (max {max_runtime})"
        )

if failures:
    print("Deploy size regression detected:", file=sys.stderr)
    for failure in failures:
        print(f" - {failure}", file=sys.stderr)
    sys.exit(1)

print("deploy size thresholds satisfied")
PY
