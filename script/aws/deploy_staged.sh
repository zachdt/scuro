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

if [[ -z "${PRIVATE_KEY}" ]]; then
  echo "PRIVATE_KEY is required" >&2
  exit 1
fi

run_stage() {
  local stage_name="$1"
  local target="$2"
  local output_file="$3"
  local env_args=()

  echo "[deploy-staged] starting ${stage_name}" >&2

  for name in \
    GameCatalog \
    ProtocolSettlement \
    VRFCoordinatorMock \
    ScuroToken \
    ScuroStakingToken \
    TimelockController \
    ScuroGovernor \
    GameDeploymentFactory \
    DeveloperExpressionRegistry \
    DeveloperRewards \
    NumberPickerEngine \
    NumberPickerAdapter \
    NumberPickerModuleId \
    TournamentController \
    TournamentPokerEngine \
    TournamentPokerVerifierBundle \
    TournamentPokerModuleId \
    PvPController \
    PvPPokerEngine \
    PvPPokerVerifierBundle \
    PvPPokerModuleId \
    BlackjackVerifierBundle \
    SingleDeckBlackjackEngine \
    BlackjackController \
    BlackjackModuleId
  do
    if [[ -n "${!name:-}" ]]; then
      env_args+=("${name}=${!name}")
    fi
  done

  if [[ ${#env_args[@]} -gt 0 ]]; then
    env \
      -u HTTP_PROXY \
      -u HTTPS_PROXY \
      -u ALL_PROXY \
      -u http_proxy \
      -u https_proxy \
      -u all_proxy \
      -u NO_PROXY \
      -u no_proxy \
      "${env_args[@]}" \
      PRIVATE_KEY="${PRIVATE_KEY}" \
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
ProtocolSettlement="$(extract_value ProtocolSettlement)"
VRFCoordinatorMock="$(extract_value VRFCoordinatorMock)"
ScuroToken="$(extract_value ScuroToken)"
ScuroStakingToken="$(extract_value ScuroStakingToken)"
TimelockController="$(extract_value TimelockController)"
ScuroGovernor="$(extract_value ScuroGovernor)"
GameDeploymentFactory="$(extract_value GameDeploymentFactory)"
DeveloperExpressionRegistry="$(extract_value DeveloperExpressionRegistry)"
DeveloperRewards="$(extract_value DeveloperRewards)"

run_stage "number-picker" "script/aws/DeployNumberPickerModule.s.sol:DeployNumberPickerModule" "${MODULE_NUMBER_PICKER_OUTPUT}"
run_stage "poker-tournament" "script/aws/DeployPokerTournamentModule.s.sol:DeployPokerTournamentModule" "${MODULE_TOURNAMENT_OUTPUT}"
run_stage "poker-pvp" "script/aws/DeployPokerPvPModule.s.sol:DeployPokerPvPModule" "${MODULE_PVP_OUTPUT}"
run_stage "blackjack" "script/aws/DeployBlackjackModule.s.sol:DeployBlackjackModule" "${MODULE_BLACKJACK_OUTPUT}"

extract_module_value() {
  local file="$1"
  local wanted="$2"
  awk -v wanted="${wanted}" '$1 == wanted {print $2}' "${file}" | tail -n 1
}

NumberPickerEngine="$(extract_module_value "${MODULE_NUMBER_PICKER_OUTPUT}" NumberPickerEngine)"
NumberPickerAdapter="$(extract_module_value "${MODULE_NUMBER_PICKER_OUTPUT}" NumberPickerAdapter)"
NumberPickerModuleId="$(extract_module_value "${MODULE_NUMBER_PICKER_OUTPUT}" NumberPickerModuleId)"
TournamentController="$(extract_module_value "${MODULE_TOURNAMENT_OUTPUT}" TournamentController)"
TournamentPokerEngine="$(extract_module_value "${MODULE_TOURNAMENT_OUTPUT}" TournamentPokerEngine)"
TournamentPokerVerifierBundle="$(extract_module_value "${MODULE_TOURNAMENT_OUTPUT}" TournamentPokerVerifierBundle)"
TournamentPokerModuleId="$(extract_module_value "${MODULE_TOURNAMENT_OUTPUT}" TournamentPokerModuleId)"
PvPController="$(extract_module_value "${MODULE_PVP_OUTPUT}" PvPController)"
PvPPokerEngine="$(extract_module_value "${MODULE_PVP_OUTPUT}" PvPPokerEngine)"
PvPPokerVerifierBundle="$(extract_module_value "${MODULE_PVP_OUTPUT}" PvPPokerVerifierBundle)"
PvPPokerModuleId="$(extract_module_value "${MODULE_PVP_OUTPUT}" PvPPokerModuleId)"
BlackjackVerifierBundle="$(extract_module_value "${MODULE_BLACKJACK_OUTPUT}" BlackjackVerifierBundle)"
SingleDeckBlackjackEngine="$(extract_module_value "${MODULE_BLACKJACK_OUTPUT}" SingleDeckBlackjackEngine)"
BlackjackController="$(extract_module_value "${MODULE_BLACKJACK_OUTPUT}" BlackjackController)"
BlackjackModuleId="$(extract_module_value "${MODULE_BLACKJACK_OUTPUT}" BlackjackModuleId)"

run_stage "finalize" "script/aws/DeployFinalize.s.sol:DeployFinalize" "${FINALIZE_OUTPUT}"
