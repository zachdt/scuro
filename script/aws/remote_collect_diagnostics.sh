#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=script/aws/lib/common.sh
source "$(dirname "$0")/lib/common.sh"
require_cmd aws

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <instance-id> [region]" >&2
  exit 1
fi

INSTANCE_ID="$1"
REGION="$(resolve_region "${2:-}")"

COMMANDS=$(cat <<'EOF'
set -euo pipefail
echo "==== uptime ===="
uptime || true
echo "==== disk ===="
df -h || true
echo "==== memory ===="
free -m || true
echo "==== service status ===="
systemctl --no-pager --full status scuro-anvil.service scuro-operator-api.service scuro-prover-worker.service || true
systemctl --no-pager --full status nginx.service || true
echo "==== journalctl services ===="
journalctl -u scuro-anvil.service -u scuro-operator-api.service -u scuro-prover-worker.service --no-pager -n 200 || true
echo "==== kernel log tail ===="
journalctl -k --no-pager -n 100 || true
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
echo "==== operator log ===="
tail -n 200 /var/log/scuro-testnet/operator-api.log || true
echo "==== anvil log ===="
tail -n 200 /var/log/scuro-testnet/anvil.log || true
echo "==== worker log ===="
tail -n 200 /var/log/scuro-testnet/prover-worker.log || true
echo "==== deploy log ===="
tail -n 200 /var/lib/scuro-testnet/deploy.log || true
echo "==== deploy jobs ===="
ls -l /var/lib/scuro-testnet/deploy-jobs || true
for file in /var/lib/scuro-testnet/deploy-jobs/*.json; do
  if [[ -f "${file}" ]]; then
    echo "---- ${file} ----"
    sed -n '1,220p' "${file}" || true
  fi
done
echo "==== nginx status ===="
systemctl --no-pager --full status nginx.service || true
echo "==== nginx config ===="
sed -n '1,220p' /etc/nginx/conf.d/scuro-public-rpc.conf || true
echo "==== nginx log ===="
tail -n 200 /var/log/nginx/error.log || true
echo "==== binary details ===="
file /opt/scuro-testnet/tools/bin/bun /opt/scuro-testnet/tools/bin/forge /opt/scuro-testnet/tools/bin/cast /opt/scuro-testnet/tools/bin/anvil || true
ldd /opt/scuro-testnet/tools/bin/anvil || true
EOF
)

ssm_run_command "${INSTANCE_ID}" "Collect Scuro host diagnostics" "${COMMANDS}" "${REGION}"
