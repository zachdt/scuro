# Canonical Testnet

The canonical Scuro testnet runs on a single Hetzner Cloud host behind a Cloudflare proxied hostname. The host runs Anvil and the Bun operator API on localhost only. Public JSON-RPC traffic enters through Cloudflare, terminates at nginx on the origin, and is proxied to local Anvil.

## Architecture

- Hetzner Cloud provides the origin VM, SSH access, and host firewall.
- Cloudflare owns the public RPC hostname, proxied DNS record, and edge TLS.
- nginx listens on the origin for Cloudflare traffic and forwards JSON-RPC requests to `127.0.0.1:8545`.
- Anvil listens on `127.0.0.1:8545`.
- The operator API listens on `127.0.0.1:8787` and is reached only over SSH.
- Terraform in `infra/hetzner-cloudflare/testnet` is the source of truth for infrastructure.
- Runtime scripts in `script/testnet` build, upload, bootstrap, deploy, smoke, snapshot, and diagnose the host.

## Prerequisites

- A Hetzner Cloud project with a read/write API token.
- A Cloudflare-managed domain and zone id.
- A Cloudflare API token that can edit DNS records, zone settings, and Origin CA certificates for the zone.
- Terraform.
- Bun.
- Foundry tools: `forge`, `cast`, and `anvil`.
- An SSH key pair for testnet administration.
- A local shell with `ssh`, `scp`, `curl`, and `jq` or Python 3 for JSON parsing.

## First-Time Local Setup

Create an SSH key dedicated to the testnet host:

```bash
ssh-keygen -t ed25519 -C scuro-testnet -f ~/.ssh/scuro_testnet
```

Export provider credentials and the deploy key path:

```bash
export HCLOUD_TOKEN="<hetzner-cloud-token>"
export CLOUDFLARE_API_TOKEN="<cloudflare-api-token>"
export SCURO_TESTNET_SSH_KEY_PATH="$HOME/.ssh/scuro_testnet"
```

If the chosen Cloudflare Origin CA Terraform flow requires the user service key, also export:

```bash
export CLOUDFLARE_API_USER_SERVICE_KEY="<cloudflare-origin-ca-service-key>"
```

Create local Terraform variables from the example:

```bash
cp infra/hetzner-cloudflare/testnet/terraform.tfvars.example \
  infra/hetzner-cloudflare/testnet/terraform.auto.tfvars
```

Edit `infra/hetzner-cloudflare/testnet/terraform.auto.tfvars` with the Cloudflare zone id, RPC hostname, SSH public key path, and allowed SSH admin CIDRs. Do not commit this file.

Provision the host and Cloudflare endpoint:

```bash
terraform -chdir=infra/hetzner-cloudflare/testnet init
terraform -chdir=infra/hetzner-cloudflare/testnet plan
terraform -chdir=infra/hetzner-cloudflare/testnet apply
```

Capture outputs for the local shell:

```bash
export SCURO_TESTNET_SSH_HOST="$(terraform -chdir=infra/hetzner-cloudflare/testnet output -raw ssh_host)"
export SCURO_TESTNET_SSH_USER="$(terraform -chdir=infra/hetzner-cloudflare/testnet output -raw ssh_user)"
export SCURO_TESTNET_RPC_HOSTNAME="$(terraform -chdir=infra/hetzner-cloudflare/testnet output -raw rpc_hostname)"
```

Build and bootstrap the runtime:

```bash
bash script/testnet/build_bundle.sh /tmp/scuro-testnet-bundle.tar.gz
bash script/testnet/upload_bundle.sh \
  "$SCURO_TESTNET_SSH_USER@$SCURO_TESTNET_SSH_HOST" \
  /tmp/scuro-testnet-bundle.tar.gz
bash script/testnet/remote_bootstrap.sh \
  "$SCURO_TESTNET_SSH_USER@$SCURO_TESTNET_SSH_HOST"
```

Deploy and verify the protocol:

```bash
bash script/testnet/remote_wait_for_health.sh "$SCURO_TESTNET_SSH_USER@$SCURO_TESTNET_SSH_HOST"
bash script/testnet/remote_wait_for_chain.sh "$SCURO_TESTNET_SSH_USER@$SCURO_TESTNET_SSH_HOST"
bash script/testnet/protocol_deploy.sh "$SCURO_TESTNET_SSH_USER@$SCURO_TESTNET_SSH_HOST"
bash script/testnet/remote_wait_for_deploy_job.sh "$SCURO_TESTNET_SSH_USER@$SCURO_TESTNET_SSH_HOST" "$DEPLOY_JOB_ID"
bash script/testnet/remote_manifest.sh "$SCURO_TESTNET_SSH_USER@$SCURO_TESTNET_SSH_HOST"
```

Run snapshot-isolated smokes:

```bash
SMOKE_BASELINE_NAME="first-testnet-smoke"
bash script/testnet/remote_snapshot_export.sh "$SCURO_TESTNET_SSH_USER@$SCURO_TESTNET_SSH_HOST" "$SMOKE_BASELINE_NAME"
bash script/testnet/remote_snapshot_restore.sh "$SCURO_TESTNET_SSH_USER@$SCURO_TESTNET_SSH_HOST" "$SMOKE_BASELINE_NAME"
bash script/testnet/remote_smoke.sh "$SCURO_TESTNET_SSH_USER@$SCURO_TESTNET_SSH_HOST" number-picker
bash script/testnet/remote_snapshot_restore.sh "$SCURO_TESTNET_SSH_USER@$SCURO_TESTNET_SSH_HOST" "$SMOKE_BASELINE_NAME"
bash script/testnet/remote_smoke.sh "$SCURO_TESTNET_SSH_USER@$SCURO_TESTNET_SSH_HOST" slot
```

Verify public RPC through Cloudflare:

```bash
curl -fsS \
  -H 'content-type: application/json' \
  --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
  "https://${SCURO_TESTNET_RPC_HOSTNAME}"
```

Verify direct public access to private services is blocked:

```bash
! curl -fsS --connect-timeout 3 "http://${SCURO_TESTNET_SSH_HOST}:8545"
! curl -fsS --connect-timeout 3 "http://${SCURO_TESTNET_SSH_HOST}:8787"
```

## Day-2 Operations

Redeploy the runtime bundle after code changes:

```bash
bash script/testnet/build_bundle.sh /tmp/scuro-testnet-bundle.tar.gz
bash script/testnet/upload_bundle.sh \
  "$SCURO_TESTNET_SSH_USER@$SCURO_TESTNET_SSH_HOST" \
  /tmp/scuro-testnet-bundle.tar.gz
bash script/testnet/remote_bootstrap.sh "$SCURO_TESTNET_SSH_USER@$SCURO_TESTNET_SSH_HOST"
```

Restart services without replacing the bundle:

```bash
bash script/testnet/remote_restart.sh "$SCURO_TESTNET_SSH_USER@$SCURO_TESTNET_SSH_HOST"
```

Export or restore snapshots:

```bash
bash script/testnet/remote_snapshot_export.sh "$SCURO_TESTNET_SSH_USER@$SCURO_TESTNET_SSH_HOST" "snapshot-name"
bash script/testnet/remote_snapshot_restore.sh "$SCURO_TESTNET_SSH_USER@$SCURO_TESTNET_SSH_HOST" "snapshot-name"
```

Collect diagnostics:

```bash
bash script/testnet/remote_collect_diagnostics.sh \
  "$SCURO_TESTNET_SSH_USER@$SCURO_TESTNET_SSH_HOST" \
  /tmp/scuro-testnet-diagnostics
```

Rotate runtime env values by updating the host runtime env file through the documented SSH script, then restart the runtime:

```bash
bash script/testnet/remote_write_runtime_env.sh "$SCURO_TESTNET_SSH_USER@$SCURO_TESTNET_SSH_HOST" ./runtime.env
bash script/testnet/remote_restart.sh "$SCURO_TESTNET_SSH_USER@$SCURO_TESTNET_SSH_HOST"
```

Destroy and recreate the testnet only after exporting any snapshot you need:

```bash
terraform -chdir=infra/hetzner-cloudflare/testnet destroy
```

## Safety Rules

- Never commit `.auto.tfvars`, `.auto.tfvars.json`, private keys, Terraform state, rendered origin certificates, or runtime env files with secrets.
- Keep Anvil and the operator API bound to `127.0.0.1`.
- Keep SSH limited to explicit admin CIDRs.
- Keep public RPC behind the Cloudflare proxied hostname.
- After every first-time provision or firewall change, verify direct public access to `:8545` and `:8787` fails.

## GitHub Actions Setup

For GitHub repository setup, see [GitHub Actions Testnet Setup](./github-actions-testnet-setup.md).
