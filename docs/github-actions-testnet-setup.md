# GitHub Actions Testnet Setup

This page describes the first-time GitHub setup for the canonical Hetzner + Cloudflare testnet. Local Terraform state remains canonical for v1 unless a remote backend is deliberately introduced later.

## Environment

Create a GitHub environment named `testnet`. Use required reviewers for manual deploy jobs if the repository needs a protected release gate.

## Repository Variables

Set these repository or `testnet` environment variables:

| Name | Required | Purpose |
| --- | --- | --- |
| `SCURO_TESTNET_RPC_HOSTNAME` | yes | Cloudflare proxied RPC hostname, for example `rpc-testnet.example.com`. |
| `SCURO_TESTNET_SSH_HOST` | yes | Hetzner origin IPv4 address or host output from Terraform. |
| `SCURO_TESTNET_SSH_USER` | yes | SSH user used by release scripts, usually `root` unless the host bootstrap creates a deploy user. |
| `SCURO_TESTNET_SERVER_NAME` | no | Human-readable Hetzner server name for summaries. |
| `FOUNDRY_GIT_REF` | no | Foundry version or tag used when building bundled host tools. |

## Repository Secrets

Set these repository or `testnet` environment secrets:

| Name | Required | Purpose |
| --- | --- | --- |
| `HCLOUD_TOKEN` | yes | Hetzner Cloud API token for server, firewall, and SSH key management. |
| `CLOUDFLARE_API_TOKEN` | yes | Cloudflare API token for DNS, zone settings, and Origin CA management. |
| `SCURO_TESTNET_SSH_PRIVATE_KEY` | yes | Private half of the SSH key authorized on the Hetzner host. |
| `SCURO_TESTNET_PRIVATE_KEY` | no | Runtime admin/deployer key if the default local Anvil key should not be used. |
| `SCURO_TESTNET_PLAYER1_PRIVATE_KEY` | no | Player 1 runtime key override. |
| `SCURO_TESTNET_PLAYER2_PRIVATE_KEY` | no | Player 2 runtime key override. |

## SSH Key Setup

Generate a deploy key locally:

```bash
ssh-keygen -t ed25519 -C scuro-testnet-github -f ~/.ssh/scuro_testnet_github
```

Add `~/.ssh/scuro_testnet_github.pub` to the Terraform variable that populates the Hetzner SSH key. Add the private key contents to the GitHub secret `SCURO_TESTNET_SSH_PRIVATE_KEY`:

```bash
cat ~/.ssh/scuro_testnet_github
```

Keep the key dedicated to this testnet. Rotate it by updating the Terraform SSH key input, applying Terraform, and then replacing the GitHub secret.

## Token Permissions

Hetzner token:

- Read/write access for servers.
- Read/write access for firewalls.
- Read/write access for SSH keys.

Cloudflare token:

- Zone DNS edit for the target zone.
- Zone settings edit when Terraform manages SSL/TLS settings.
- Origin CA certificate permissions when Terraform creates or rotates the origin certificate.

## Workflow Expectations

The manual testnet workflow should:

- Build the Linux bundle with host tools.
- Install the SSH private key from `SCURO_TESTNET_SSH_PRIVATE_KEY`.
- Upload the bundle to `SCURO_TESTNET_SSH_USER@SCURO_TESTNET_SSH_HOST`.
- Bootstrap or restart the host over SSH.
- Deploy through the localhost operator.
- Run snapshot-isolated number-picker and slot smokes.
- Verify `https://${SCURO_TESTNET_RPC_HOSTNAME}` with JSON-RPC.
- Upload manifest, deploy job, smoke outputs, and diagnostics as workflow artifacts.

Do not run Terraform apply from GitHub until the repository has an intentional remote state backend and locking strategy. The v1 source of truth is local Terraform state in `infra/hetzner-cloudflare/testnet`.
