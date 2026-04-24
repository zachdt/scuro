#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=script/testnet/lib/common.sh
source "$(dirname "$0")/lib/common.sh"

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <ssh-target> [output-dir]" >&2
  exit 1
fi

TARGET="$(remote_target "$1")"
OUTPUT_DIR="${2:-}"
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

capture_remote_output() {
  local filename="$1"
  local commands="$2"
  local stdout_path="${OUTPUT_DIR}/${filename}"
  local stderr_path="${stdout_path}.stderr.txt"

  if remote_run "${TARGET}" "${commands}" >"${stdout_path}" 2>"${stderr_path}"; then
    :
  fi

  if [[ ! -s "${stderr_path}" ]]; then
    rm -f "${stderr_path}"
  fi
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

capture_remote_output "host-system-summary.txt" "$(cat <<'EOF'
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
command -v cast || true
command -v forge || true
command -v anvil || true
echo "==== operator health ===="
curl -sS http://127.0.0.1:8787/health || true
EOF
)"

capture_remote_output "host-operator-log.txt" "tail -n 200 /var/log/scuro-testnet/operator-api.log || true"
capture_remote_output "host-anvil-log.txt" "tail -n 200 /var/log/scuro-testnet/anvil.log || true"
capture_remote_output "host-deploy-log.txt" "tail -n 200 /var/lib/scuro-testnet/deploy.log || true"
capture_remote_output "host-deploy-jobs.txt" "$(cat <<'EOF'
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
capture_remote_output "host-tool-versions.txt" "$(cat <<'EOF'
set -euo pipefail
/opt/scuro-testnet/tools/bin/forge --version || true
/opt/scuro-testnet/tools/bin/cast --version || true
/opt/scuro-testnet/tools/bin/anvil --version || true
file /opt/scuro-testnet/tools/bin/bun /opt/scuro-testnet/tools/bin/forge /opt/scuro-testnet/tools/bin/cast /opt/scuro-testnet/tools/bin/anvil || true
EOF
)"
capture_remote_output "host-nginx-status.txt" "systemctl --no-pager --full status nginx.service || true"
capture_remote_output "host-nginx-config.txt" "sed -n '1,220p' /etc/nginx/conf.d/scuro-public-rpc.conf || true"
capture_remote_output "host-nginx-error.log" "tail -n 200 /var/log/nginx/error.log || true"

capture_local_output "host-manifest.json" bash "$(dirname "$0")/remote_operator.sh" "${TARGET}" GET /manifest
capture_local_output "host-actors.json" bash "$(dirname "$0")/remote_operator.sh" "${TARGET}" GET /actors

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
    host-tool-versions.txt \
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
