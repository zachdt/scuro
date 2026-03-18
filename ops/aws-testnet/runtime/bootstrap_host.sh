#!/usr/bin/env bash
set -euo pipefail

BUNDLE_ARCHIVE="${1:-}"
INSTALL_ROOT="${SCURO_INSTALL_ROOT:-/opt/scuro-testnet}"
STATE_DIR="${SCURO_STATE_DIR:-/var/lib/scuro-testnet}"
LOG_DIR="${SCURO_LOG_DIR:-/var/log/scuro-testnet}"
ENV_DIR="/etc/scuro-testnet"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

if [[ -z "${BUNDLE_ARCHIVE}" ]]; then
  echo "usage: $0 <bundle-archive>" >&2
  exit 1
fi

mkdir -p "${INSTALL_ROOT}" "${STATE_DIR}" "${LOG_DIR}" "${ENV_DIR}"
tar -xzf "${BUNDLE_ARCHIVE}" -C "${TMP_DIR}"

rm -rf "${INSTALL_ROOT}/current" "${INSTALL_ROOT}/tools"
mkdir -p "${INSTALL_ROOT}/tools"
cp -R "${TMP_DIR}/repo" "${INSTALL_ROOT}/current"
cp -R "${TMP_DIR}/tools" "${INSTALL_ROOT}/tools"

chmod +x "${INSTALL_ROOT}/tools/bin/"*
chmod +x "${INSTALL_ROOT}/current/ops/aws-testnet/runtime/"*.sh

if [[ ! -f "${ENV_DIR}/scuro.env" ]]; then
  cp "${INSTALL_ROOT}/current/ops/aws-testnet/runtime/scuro.env.example" "${ENV_DIR}/scuro.env"
fi

if [[ -f "${ENV_DIR}/bootstrap.env" ]]; then
  cat "${ENV_DIR}/bootstrap.env" >> "${ENV_DIR}/scuro.env"
fi

cp "${INSTALL_ROOT}/current/ops/aws-testnet/runtime/systemd/scuro-anvil.service" /etc/systemd/system/scuro-anvil.service
cp "${INSTALL_ROOT}/current/ops/aws-testnet/runtime/systemd/scuro-operator-api.service" /etc/systemd/system/scuro-operator-api.service
cp "${INSTALL_ROOT}/current/ops/aws-testnet/runtime/systemd/scuro-prover-worker.service" /etc/systemd/system/scuro-prover-worker.service

systemctl daemon-reload
systemctl enable scuro-anvil.service scuro-operator-api.service scuro-prover-worker.service
systemctl restart scuro-anvil.service
systemctl restart scuro-operator-api.service
systemctl restart scuro-prover-worker.service
