#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=script/aws/lib/common.sh
source "$(dirname "$0")/lib/common.sh"
require_cmd forge

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <rpc-url>" >&2
  exit 1
fi

RPC_URL="$1"
ROOT="$(repo_root)"
PRIVATE_KEY="${PRIVATE_KEY:-}"
PLAYER1_PRIVATE_KEY="${PLAYER1_PRIVATE_KEY:-}"
PLAYER2_PRIVATE_KEY="${PLAYER2_PRIVATE_KEY:-}"

if [[ -z "${PRIVATE_KEY}" ]]; then
  echo "PRIVATE_KEY is required" >&2
  exit 1
fi

run_stage() {
  local stage_name="$1"
  local target="$2"
  local output_file="$3"
  shift 3

  echo "[deploy-staged] starting ${stage_name}" >&2

  if [[ $# -gt 0 ]]; then
    env \
      -u HTTP_PROXY \
      -u HTTPS_PROXY \
      -u ALL_PROXY \
      -u http_proxy \
      -u https_proxy \
      -u all_proxy \
      -u NO_PROXY \
      -u no_proxy \
      "$@" \
      PRIVATE_KEY="${PRIVATE_KEY}" \
      PLAYER1_PRIVATE_KEY="${PLAYER1_PRIVATE_KEY}" \
      PLAYER2_PRIVATE_KEY="${PLAYER2_PRIVATE_KEY}" \
      forge script "${target}" \
      --rpc-url "${RPC_URL}" \
      --broadcast \
      --offline \
      --skip-simulation \
      --non-interactive \
      --disable-code-size-limit \
      -vvvv 2>&1 | tee "${output_file}"
  else
    env \
      -u HTTP_PROXY \
      -u HTTPS_PROXY \
      -u ALL_PROXY \
      -u http_proxy \
      -u https_proxy \
      -u all_proxy \
      -u NO_PROXY \
      -u no_proxy \
      PRIVATE_KEY="${PRIVATE_KEY}" \
      PLAYER1_PRIVATE_KEY="${PLAYER1_PRIVATE_KEY}" \
      PLAYER2_PRIVATE_KEY="${PLAYER2_PRIVATE_KEY}" \
      forge script "${target}" \
      --rpc-url "${RPC_URL}" \
      --broadcast \
      --offline \
      --skip-simulation \
      --non-interactive \
      --disable-code-size-limit \
      -vvvv 2>&1 | tee "${output_file}"
  fi

  echo "[deploy-staged] finished ${stage_name}" >&2
}

cd "${ROOT}"

CORE_OUTPUT="$(mktemp)"
MODULE_NUMBER_PICKER_OUTPUT="$(mktemp)"
MODULE_TOURNAMENT_OUTPUT="$(mktemp)"
MODULE_PVP_OUTPUT="$(mktemp)"
MODULE_BLACKJACK_OUTPUT="$(mktemp)"
FINALIZE_OUTPUT="$(mktemp)"
trap 'rm -f "${CORE_OUTPUT}" "${MODULE_NUMBER_PICKER_OUTPUT}" "${MODULE_TOURNAMENT_OUTPUT}" "${MODULE_PVP_OUTPUT}" "${MODULE_BLACKJACK_OUTPUT}" "${FINALIZE_OUTPUT}"' EXIT

run_stage "core" "script/aws/DeployCore.s.sol:DeployCore" "${CORE_OUTPUT}"

extract_value() {
  local label="$1"
  awk -v wanted="${label}" '$1 == wanted {print $2}' "${CORE_OUTPUT}" | tail -n 1
}

GameCatalog="$(extract_value GameCatalog)"
VRFCoordinatorMock="$(extract_value VRFCoordinatorMock)"
ScuroToken="$(extract_value ScuroToken)"
TimelockController="$(extract_value TimelockController)"
GameDeploymentFactory="$(extract_value GameDeploymentFactory)"
DeveloperExpressionRegistry="$(extract_value DeveloperExpressionRegistry)"

run_stage \
  "number-picker" \
  "script/aws/DeployNumberPickerModule.s.sol:DeployNumberPickerModule" \
  "${MODULE_NUMBER_PICKER_OUTPUT}" \
  "GameDeploymentFactory=${GameDeploymentFactory}" \
  "VRFCoordinatorMock=${VRFCoordinatorMock}"
run_stage \
  "poker-tournament" \
  "script/aws/DeployPokerTournamentModule.s.sol:DeployPokerTournamentModule" \
  "${MODULE_TOURNAMENT_OUTPUT}" \
  "GameDeploymentFactory=${GameDeploymentFactory}"
run_stage \
  "poker-pvp" \
  "script/aws/DeployPokerPvPModule.s.sol:DeployPokerPvPModule" \
  "${MODULE_PVP_OUTPUT}" \
  "GameDeploymentFactory=${GameDeploymentFactory}"
run_stage \
  "blackjack" \
  "script/aws/DeployBlackjackModule.s.sol:DeployBlackjackModule" \
  "${MODULE_BLACKJACK_OUTPUT}" \
  "GameDeploymentFactory=${GameDeploymentFactory}"

extract_module_value() {
  local file="$1"
  local wanted="$2"
  awk -v wanted="${wanted}" '$1 == wanted {print $2}' "${file}" | tail -n 1
}

NumberPickerEngine="$(extract_module_value "${MODULE_NUMBER_PICKER_OUTPUT}" NumberPickerEngine)"
TournamentPokerEngine="$(extract_module_value "${MODULE_TOURNAMENT_OUTPUT}" TournamentPokerEngine)"
BlackjackEngine="$(extract_module_value "${MODULE_BLACKJACK_OUTPUT}" BlackjackEngine)"
run_stage \
  "finalize" \
  "script/aws/DeployFinalize.s.sol:DeployFinalize" \
  "${FINALIZE_OUTPUT}" \
  "ScuroToken=${ScuroToken}" \
  "TimelockController=${TimelockController}" \
  "GameCatalog=${GameCatalog}" \
  "GameDeploymentFactory=${GameDeploymentFactory}" \
  "DeveloperExpressionRegistry=${DeveloperExpressionRegistry}" \
  "NumberPickerEngine=${NumberPickerEngine}" \
  "TournamentPokerEngine=${TournamentPokerEngine}" \
  "BlackjackEngine=${BlackjackEngine}"
