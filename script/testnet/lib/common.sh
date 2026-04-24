#!/usr/bin/env bash
set -euo pipefail

repo_root() {
  cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd
}

terraform_dir() {
  printf '%s/infra/hetzner-cloudflare/testnet\n' "$(repo_root)"
}

service_dir() {
  printf '%s/ops/testnet\n' "$(repo_root)"
}

require_cmd() {
  local cmd="$1"
  command -v "${cmd}" >/dev/null 2>&1 || {
    echo "missing required command: ${cmd}" >&2
    exit 1
  }
}

ssh_options() {
  local key_path="${SCURO_TESTNET_SSH_KEY_PATH:-}"
  local opts=(-o BatchMode=yes -o StrictHostKeyChecking=accept-new)

  if [[ -n "${key_path}" ]]; then
    opts+=(-i "${key_path}")
  fi

  printf '%q ' "${opts[@]}"
}

remote_target() {
  local target="${1:-}"

  if [[ -n "${target}" ]]; then
    printf '%s' "${target}"
    return
  fi

  if [[ -n "${SCURO_TESTNET_SSH_TARGET:-}" ]]; then
    printf '%s' "${SCURO_TESTNET_SSH_TARGET}"
    return
  fi

  if [[ -n "${SCURO_TESTNET_SSH_USER:-}" && -n "${SCURO_TESTNET_SSH_HOST:-}" ]]; then
    printf '%s@%s' "${SCURO_TESTNET_SSH_USER}" "${SCURO_TESTNET_SSH_HOST}"
    return
  fi

  echo "missing SSH target; pass user@host or set SCURO_TESTNET_SSH_TARGET/SCURO_TESTNET_SSH_USER and SCURO_TESTNET_SSH_HOST" >&2
  exit 1
}

remote_run() {
  local target="$1"
  local commands="$2"
  require_cmd ssh

  # shellcheck disable=SC2046
  ssh $(ssh_options) "${target}" "bash -s" <<<"${commands}"
}

remote_copy_to() {
  local source="$1"
  local target="$2"
  local destination="$3"
  require_cmd scp

  # shellcheck disable=SC2046
  scp $(ssh_options) "${source}" "${target}:${destination}"
}
