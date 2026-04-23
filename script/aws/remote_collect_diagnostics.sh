#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=script/aws/lib/common.sh
source "$(dirname "$0")/lib/common.sh"
require_cmd aws

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <instance-id> [region] [output-dir]" >&2
  exit 1
fi

INSTANCE_ID="$1"
REGION="$(resolve_region "${2:-}")"
OUTPUT_DIR="${3:-}"
TEMP_OUTPUT_DIR=""

if [[ -z "${OUTPUT_DIR}" ]]; then
  TEMP_OUTPUT_DIR="$(mktemp -d)"
  OUTPUT_DIR="${TEMP_OUTPUT_DIR}"
fi

mkdir -p "${OUTPUT_DIR}"

cleanup() {
  if [[ -n "${TEMP_OUTPUT_DIR}" ]]; then
    rm -rf "${TEMP_OUTPUT_DIR}"
  fi
}
trap cleanup EXIT

capture_ssm_output() {
  local filename="$1"
  local comment="$2"
  local commands="$3"
  local stdout_path="${OUTPUT_DIR}/${filename}"
  local stderr_path="${stdout_path}.stderr.txt"
  local tmp_stderr
  local output=""

  tmp_stderr="$(mktemp)"
  if output="$(ssm_run_command "${INSTANCE_ID}" "${comment}" "${commands}" "${REGION}" 2>"${tmp_stderr}")"; then
    :
  fi

  printf '%s' "${output}" > "${stdout_path}"
  if [[ -s "${tmp_stderr}" ]]; then
    cp "${tmp_stderr}" "${stderr_path}"
  else
    rm -f "${stderr_path}"
  fi
  rm -f "${tmp_stderr}"
}

capture_local_output() {
  local filename="$1"
  shift
  local stdout_path="${OUTPUT_DIR}/${filename}"
  local stderr_path="${stdout_path}.stderr.txt"

  if "$@" >"${stdout_path}" 2>"${stderr_path}"; then
    :
  fi

  if [[ ! -s "${stderr_path}" ]]; then
    rm -f "${stderr_path}"
  fi
}

capture_ssm_output "host-system-summary.txt" "Collect Scuro host system summary" "$(cat <<'EOF'
set -euo pipefail
echo "==== uptime ===="
uptime || true
echo "==== disk ===="
df -h || true
echo "==== memory ===="
free -m || true
echo "==== service status ===="
systemctl --no-pager --full status scuro-anvil.service scuro-operator-api.service || true
systemctl --no-pager --full status nginx.service || true
echo "==== journalctl services ===="
journalctl -u scuro-anvil.service -u scuro-operator-api.service --no-pager -n 120 || true
echo "==== kernel log tail ===="
journalctl -k --no-pager -n 80 || true
echo "==== bootstrap env ===="
sed -n '1,220p' /etc/scuro-testnet/bootstrap.env || true
echo "==== runtime env keys ===="
sed -E 's/=.*/=<redacted>/' /etc/scuro-testnet/runtime.env || true
echo "==== path resolution ===="
printf 'PATH=%s\n' "${PATH}" || true
command -v aws || true
command -v cast || true
command -v forge || true
command -v anvil || true
echo "==== operator health ===="
curl -sS http://127.0.0.1:8787/health || true
EOF
)"

capture_ssm_output "host-operator-log.txt" "Collect Scuro operator log tail" "$(cat <<'EOF'
set -euo pipefail
tail -n 200 /var/log/scuro-testnet/operator-api.log || true
EOF
)"

capture_ssm_output "host-anvil-log.txt" "Collect Scuro anvil log tail" "$(cat <<'EOF'
set -euo pipefail
tail -n 200 /var/log/scuro-testnet/anvil.log || true
EOF
)"

capture_ssm_output "host-deploy-log.txt" "Collect Scuro deploy log tail" "$(cat <<'EOF'
set -euo pipefail
tail -n 200 /var/lib/scuro-testnet/deploy.log || true
EOF
)"

capture_ssm_output "host-deploy-jobs.txt" "Collect Scuro deploy job files" "$(cat <<'EOF'
set -euo pipefail
ls -l /var/lib/scuro-testnet/deploy-jobs || true
for file in /var/lib/scuro-testnet/deploy-jobs/*.json; do
  if [[ -f "${file}" ]]; then
    echo "---- ${file} ----"
    sed -n '1,220p' "${file}" || true
  fi
done
EOF
)"

capture_ssm_output "host-anvil-version.txt" "Collect Scuro Foundry tool versions" "$(cat <<'EOF'
set -euo pipefail
/opt/scuro-testnet/tools/bin/forge --version || true
/opt/scuro-testnet/tools/bin/cast --version || true
/opt/scuro-testnet/tools/bin/anvil --version || true
file /opt/scuro-testnet/tools/bin/bun /opt/scuro-testnet/tools/bin/forge /opt/scuro-testnet/tools/bin/cast /opt/scuro-testnet/tools/bin/anvil || true
EOF
)"

capture_ssm_output "host-nginx-status.txt" "Collect Scuro nginx status" "$(cat <<'EOF'
set -euo pipefail
systemctl --no-pager --full status nginx.service || true
EOF
)"

capture_ssm_output "host-nginx-config.txt" "Collect Scuro nginx config" "$(cat <<'EOF'
set -euo pipefail
sed -n '1,220p' /etc/nginx/conf.d/scuro-public-rpc.conf || true
EOF
)"

capture_ssm_output "host-nginx-error.log" "Collect Scuro nginx error log" "$(cat <<'EOF'
set -euo pipefail
tail -n 200 /var/log/nginx/error.log || true
EOF
)"

capture_local_output \
  "host-manifest.json" \
  bash "$(dirname "$0")/remote_operator.sh" "${INSTANCE_ID}" GET /manifest "" "${REGION}"

capture_local_output \
  "host-actors.json" \
  bash "$(dirname "$0")/remote_operator.sh" "${INSTANCE_ID}" GET /actors "" "${REGION}"

SUMMARY_PATH="${OUTPUT_DIR}/host-diagnostics.txt"
{
  for file in \
    host-system-summary.txt \
    host-manifest.json \
    host-actors.json \
    host-deploy-jobs.txt \
    host-deploy-log.txt \
    host-operator-log.txt \
    host-anvil-log.txt \
    host-anvil-version.txt \
    host-nginx-status.txt \
    host-nginx-config.txt \
    host-nginx-error.log
  do
    path="${OUTPUT_DIR}/${file}"
    if [[ -f "${path}" ]]; then
      echo "==== ${file} ===="
      sed -n '1,220p' "${path}" || true
      echo
    fi

    stderr_path="${path}.stderr.txt"
    if [[ -f "${stderr_path}" ]]; then
      echo "==== ${file}.stderr.txt ===="
      sed -n '1,220p' "${stderr_path}" || true
      echo
    fi
  done
} > "${SUMMARY_PATH}"

cat "${SUMMARY_PATH}"
