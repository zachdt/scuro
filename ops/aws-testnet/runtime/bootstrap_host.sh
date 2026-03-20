#!/usr/bin/env bash
set -euo pipefail

BUNDLE_ARCHIVE="${1:-}"
INSTALL_ROOT="${SCURO_INSTALL_ROOT:-/opt/scuro-testnet}"
STATE_DIR="${SCURO_STATE_DIR:-/var/lib/scuro-testnet}"
LOG_DIR="${SCURO_LOG_DIR:-/var/log/scuro-testnet}"
ENV_DIR="/etc/scuro-testnet"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

ensure_swap() {
  local swapfile="/swapfile"
  if swapon --show | grep -q "${swapfile}"; then
    return
  fi

  if [[ ! -f "${swapfile}" ]]; then
    fallocate -l 2G "${swapfile}" || dd if=/dev/zero of="${swapfile}" bs=1M count=2048
    chmod 600 "${swapfile}"
    mkswap "${swapfile}"
  fi

  swapon "${swapfile}" || true
  grep -q "^${swapfile} " /etc/fstab || echo "${swapfile} none swap sw 0 0" >> /etc/fstab
}

ensure_runtime_env() {
  local runtime_env_path="${ENV_DIR}/runtime.env"
  local aws_args=()

  if [[ -n "${AWS_REGION:-}" ]]; then
    aws_args=(--region "${AWS_REGION}")
  fi

  if [[ -n "${SCURO_ENV_SSM_PARAMETER:-}" ]]; then
    aws ssm get-parameter \
      --name "${SCURO_ENV_SSM_PARAMETER}" \
      --with-decryption \
      --query 'Parameter.Value' \
      --output text \
      "${aws_args[@]}" >"${runtime_env_path}"
  else
    : >"${runtime_env_path}"
  fi
}

install_cloudwatch_agent() {
  if [[ "${SCURO_ENABLE_CLOUDWATCH_LOGS:-0}" != "1" ]]; then
    return
  fi

  if command -v /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl >/dev/null 2>&1; then
    return
  fi

  local rpm_path="${TMP_DIR}/amazon-cloudwatch-agent.rpm"
  local aws_args=()
  if [[ -n "${AWS_REGION:-}" ]]; then
    aws_args=(--region "${AWS_REGION}")
  fi

  aws s3 cp \
    s3://amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm \
    "${rpm_path}" \
    "${aws_args[@]}"
  dnf install -y "${rpm_path}"
}

configure_cloudwatch_agent() {
  if [[ "${SCURO_ENABLE_CLOUDWATCH_LOGS:-0}" != "1" || -z "${SCURO_CLOUDWATCH_LOG_GROUP:-}" ]]; then
    return
  fi

  local config_path="${TMP_DIR}/amazon-cloudwatch-agent.json"
  cat >"${config_path}" <<EOF
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "${LOG_DIR}/anvil.log",
            "log_group_name": "${SCURO_CLOUDWATCH_LOG_GROUP}",
            "log_stream_name": "{instance_id}/anvil",
            "timezone": "UTC"
          },
          {
            "file_path": "${LOG_DIR}/operator-api.log",
            "log_group_name": "${SCURO_CLOUDWATCH_LOG_GROUP}",
            "log_stream_name": "{instance_id}/operator-api",
            "timezone": "UTC"
          },
          {
            "file_path": "${LOG_DIR}/prover-worker.log",
            "log_group_name": "${SCURO_CLOUDWATCH_LOG_GROUP}",
            "log_stream_name": "{instance_id}/prover-worker",
            "timezone": "UTC"
          }
        ]
      }
    }
  }
}
EOF

  /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -c "file:${config_path}" \
    -s
}

if [[ -z "${BUNDLE_ARCHIVE}" ]]; then
  echo "usage: $0 <bundle-archive>" >&2
  exit 1
fi

mkdir -p "${INSTALL_ROOT}" "${STATE_DIR}" "${LOG_DIR}" "${ENV_DIR}"
tar -xzf "${BUNDLE_ARCHIVE}" -C "${TMP_DIR}"

rm -rf "${INSTALL_ROOT}/current" "${INSTALL_ROOT}/tools"
mkdir -p "${INSTALL_ROOT}/tools"
cp -R "${TMP_DIR}/repo" "${INSTALL_ROOT}/current"
if [[ -d "${TMP_DIR}/tools" ]]; then
  cp -R "${TMP_DIR}/tools/." "${INSTALL_ROOT}/tools"
fi

if compgen -G "${INSTALL_ROOT}/tools/bin/*" >/dev/null; then
  chmod +x "${INSTALL_ROOT}/tools/bin/"*
fi
chmod +x "${INSTALL_ROOT}/current/ops/aws-testnet/runtime/"*.sh

if [[ ! -f "${ENV_DIR}/scuro.env" ]]; then
  cp "${INSTALL_ROOT}/current/ops/aws-testnet/runtime/scuro.env.example" "${ENV_DIR}/scuro.env"
fi

ensure_swap
ensure_runtime_env
install_cloudwatch_agent

cp "${INSTALL_ROOT}/current/ops/aws-testnet/runtime/systemd/scuro-anvil.service" /etc/systemd/system/scuro-anvil.service
cp "${INSTALL_ROOT}/current/ops/aws-testnet/runtime/systemd/scuro-operator-api.service" /etc/systemd/system/scuro-operator-api.service
cp "${INSTALL_ROOT}/current/ops/aws-testnet/runtime/systemd/scuro-prover-worker.service" /etc/systemd/system/scuro-prover-worker.service

systemctl daemon-reload
systemctl enable scuro-anvil.service scuro-operator-api.service scuro-prover-worker.service
systemctl restart scuro-anvil.service
systemctl restart scuro-operator-api.service
systemctl restart scuro-prover-worker.service
configure_cloudwatch_agent
