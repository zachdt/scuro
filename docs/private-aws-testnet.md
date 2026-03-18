# Private AWS Testnet

This guide covers the new private AWS-hosted Scuro testnet runtime added under:

- `infra/aws/testnet`
- `ops/aws-testnet`
- `script/aws`

## Architecture

- Single private EC2 host in one AZ
- Private VPC subnet with no NAT gateway and no public ALB
- AWS Systems Manager for operator access and port forwarding
- S3 bucket for runtime bundles, manifests, and snapshots
- SQS proof queue plus DLQ for async coordinator work
- Local Anvil chain with the existing `DeployLocal` protocol stack
- Internal Bun operator API and internal Bun prover worker

## Workflow

1. Create or update the AWS stack:
   - `script/aws/terraform_apply.sh -var-file=terraform.tfvars`
2. Upload the runtime bundle:
   - `script/aws/publish_bundle.sh <artifacts-bucket> [bundle-name]`
3. Bootstrap the host through SSM:
   - `script/aws/remote_bootstrap.sh <instance-id> <bundle-s3-uri> [region]`
4. Forward the private operator API locally:
   - `script/aws/ssm_port_forward.sh <instance-id> [remote-port] [local-port]`
5. Deploy or reset the protocol through the operator API:
   - `script/aws/protocol_deploy.sh`
   - `script/aws/protocol_reset.sh`
6. Queue smoke jobs:
   - `script/aws/smoke.sh number-picker`
   - `script/aws/smoke.sh poker`
   - `script/aws/smoke.sh blackjack`

## Operator API

- `GET /health`
- `GET /manifest`
- `GET /actors`
- `POST /deploy`
- `POST /reset`
- `POST /seed`
- `POST /smoke/number-picker`
- `POST /smoke/poker`
- `POST /smoke/blackjack`
- `POST /proof-jobs`
- `GET /proof-jobs/:id`
- `POST /snapshots/export`
- `POST /snapshots/restore`

## Hybrid Coordinator Notes

- Fixture-backed proof execution is the default gameplay path in v1.
- Live proving is wired through the worker abstraction, but gameplay jobs intentionally reject `mode = live`.
- The only supported live-mode job in this first cut is `benchmark-live-proof`, which is intended for operator benchmarking when the full proving toolchain is bundled.
