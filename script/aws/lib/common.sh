#!/usr/bin/env bash
set -euo pipefail

repo_root() {
  cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd
}

terraform_dir() {
  printf '%s/infra/aws/testnet\n' "$(repo_root)"
}

service_dir() {
  printf '%s/ops/aws-testnet\n' "$(repo_root)"
}

resolve_region() {
  printf '%s' "${1:-${AWS_REGION:-${AWS_DEFAULT_REGION:-}}}"
}

require_cmd() {
  local cmd="$1"
  command -v "${cmd}" >/dev/null 2>&1 || {
    echo "missing required command: ${cmd}" >&2
    exit 1
  }
}

ssm_send_command() {
  local instance_id="$1"
  local comment="$2"
  local commands="$3"
  local region="${4:-}"
  local parameters_json

  parameters_json="$(python3 - <<'PY' "${commands}"
import json
import sys

commands = sys.argv[1].splitlines()
print(json.dumps({"commands": commands}))
PY
)"

  if [[ -n "${region}" ]]; then
    aws ssm send-command \
      --instance-ids "${instance_id}" \
      --document-name "AWS-RunShellScript" \
      --comment "${comment}" \
      --parameters "${parameters_json}" \
      --region "${region}" \
      --query "Command.CommandId" \
      --output text
  else
    aws ssm send-command \
      --instance-ids "${instance_id}" \
      --document-name "AWS-RunShellScript" \
      --comment "${comment}" \
      --parameters "${parameters_json}" \
      --query "Command.CommandId" \
      --output text
  fi
}

ssm_wait_command() {
  local instance_id="$1"
  local command_id="$2"
  local region="${3:-}"

  if [[ -n "${region}" ]]; then
    aws ssm wait command-executed \
      --instance-id "${instance_id}" \
      --command-id "${command_id}" \
      --region "${region}"
  else
    aws ssm wait command-executed \
      --instance-id "${instance_id}" \
      --command-id "${command_id}"
  fi
}

ssm_get_invocation_field() {
  local instance_id="$1"
  local command_id="$2"
  local query="$3"
  local region="${4:-}"

  if [[ -n "${region}" ]]; then
    aws ssm get-command-invocation \
      --instance-id "${instance_id}" \
      --command-id "${command_id}" \
      --region "${region}" \
      --query "${query}" \
      --output text
  else
    aws ssm get-command-invocation \
      --instance-id "${instance_id}" \
      --command-id "${command_id}" \
      --query "${query}" \
      --output text
  fi
}

ssm_run_command() {
  local instance_id="$1"
  local comment="$2"
  local commands="$3"
  local region="${4:-}"

  local command_id
  command_id="$(ssm_send_command "${instance_id}" "${comment}" "${commands}" "${region}")"

  if ! ssm_wait_command "${instance_id}" "${command_id}" "${region}"; then
    :
  fi

  local status
  local stdout
  local stderr
  status="$(ssm_get_invocation_field "${instance_id}" "${command_id}" "Status" "${region}")"
  stdout="$(ssm_get_invocation_field "${instance_id}" "${command_id}" "StandardOutputContent" "${region}")"
  stderr="$(ssm_get_invocation_field "${instance_id}" "${command_id}" "StandardErrorContent" "${region}")"

  if [[ -n "${stdout}" && "${stdout}" != "None" ]]; then
    printf '%s\n' "${stdout}"
  fi

  if [[ "${status}" != "Success" ]]; then
    if [[ -n "${stderr}" && "${stderr}" != "None" ]]; then
      printf '%s\n' "${stderr}" >&2
    fi
    echo "ssm command failed with status: ${status}" >&2
    return 1
  fi
}
