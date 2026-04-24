#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=script/testnet/lib/common.sh
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
      -vvvv 2>&1 | tee "${output_file}"
  fi

  echo "[deploy-staged] finished ${stage_name}" >&2
}

cd "${ROOT}"

CORE_OUTPUT="$(mktemp)"
MODULE_NUMBER_PICKER_OUTPUT="$(mktemp)"
MODULE_SLOT_OUTPUT="$(mktemp)"
FINALIZE_OUTPUT="$(mktemp)"
trap 'rm -f "${CORE_OUTPUT}" "${MODULE_NUMBER_PICKER_OUTPUT}" "${MODULE_SLOT_OUTPUT}" "${FINALIZE_OUTPUT}"' EXIT

run_stage "core" "script/testnet/DeployCore.s.sol:DeployCore" "${CORE_OUTPUT}"

extract_value() {
  local label="$1"
  awk -v wanted="${label}" '$1 == wanted {print $2}' "${CORE_OUTPUT}" | tail -n 1
}

GameCatalog="$(extract_value GameCatalog)"
ProtocolSettlement="$(extract_value ProtocolSettlement)"
VRFCoordinatorMock="$(extract_value VRFCoordinatorMock)"
ScuroToken="$(extract_value ScuroToken)"
TimelockController="$(extract_value TimelockController)"
DeveloperExpressionRegistry="$(extract_value DeveloperExpressionRegistry)"

run_stage \
  "number-picker" \
  "script/testnet/DeployNumberPickerModule.s.sol:DeployNumberPickerModule" \
  "${MODULE_NUMBER_PICKER_OUTPUT}" \
  "GameCatalog=${GameCatalog}" \
  "ProtocolSettlement=${ProtocolSettlement}" \
  "VRFCoordinatorMock=${VRFCoordinatorMock}"
run_stage \
  "slot" \
  "script/testnet/DeploySlotModule.s.sol:DeploySlotModule" \
  "${MODULE_SLOT_OUTPUT}" \
  "GameCatalog=${GameCatalog}" \
  "ProtocolSettlement=${ProtocolSettlement}" \
  "VRFCoordinatorMock=${VRFCoordinatorMock}"

extract_module_value() {
  local file="$1"
  local wanted="$2"
  awk -v wanted="${wanted}" '$1 == wanted {print $2}' "${file}" | tail -n 1
}

NumberPickerEngine="$(extract_module_value "${MODULE_NUMBER_PICKER_OUTPUT}" NumberPickerEngine)"
SlotMachineEngine="$(extract_module_value "${MODULE_SLOT_OUTPUT}" SlotMachineEngine)"
run_stage \
  "finalize" \
  "script/testnet/DeployFinalize.s.sol:DeployFinalize" \
  "${FINALIZE_OUTPUT}" \
  "ScuroToken=${ScuroToken}" \
  "TimelockController=${TimelockController}" \
  "GameCatalog=${GameCatalog}" \
  "DeveloperExpressionRegistry=${DeveloperExpressionRegistry}" \
  "NumberPickerEngine=${NumberPickerEngine}" \
  "SlotMachineEngine=${SlotMachineEngine}"
