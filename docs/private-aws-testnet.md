# Private AWS Testnet

This guide covers the new private AWS-hosted Scuro testnet runtime added under:

- `infra/aws/testnet`
- `ops/aws-testnet`
- `script/aws`
- `.github/workflows`

## Architecture

- Single EC2 host in one AZ
- Public-subnet host for beta RPC ingress through CloudFront
- No NAT gateway and no public ALB/NLB
- AWS Systems Manager for operator access and port forwarding
- S3 bucket for runtime bundles, manifests, and snapshots
- SQS proof queue plus DLQ for async coordinator work
- Local Anvil chain with the existing `DeployLocal` protocol stack
- Internal Bun operator API and internal Bun prover worker
- CloudFront default domain pointing at a same-host reverse proxy for public JSON-RPC

## Workflow

1. Create or update the AWS stack:
   - `script/aws/terraform_apply.sh -var-file=terraform.tfvars`
2. Build and upload the runtime bundle:
   - `script/aws/build_bundle.sh /tmp/scuro-beta-bundle.tar.gz`
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

## Beta Release Model

- Private beta only: there is no public endpoint or application login flow in v1.
- The current beta redeploy path exposes only public JSON-RPC via CloudFront; operator/admin remains private over SSM.
- Poker and blackjack remain fixture-backed for gameplay flows.
- Live blackjack gameplay proving is available through `POST /proof-jobs` when `mode = live` and the payload includes either `witnessPath` or inline `witness` JSON for the requested blackjack phase.
- The budget beta currently defaults to `t3.micro` with a `40 GiB` root volume, file-queue mode, and local-only logs.
- CloudWatch log shipping, the SQS proof queue, NAT, ALB, NLB, and interface VPC endpoints are disabled by default for the first low-budget public beta.
- Release bundles are Linux `x86_64` artifacts.
  - `script/aws/build_bundle.sh` will fail on non-Linux hosts unless `SCURO_BUNDLE_INCLUDE_HOST_TOOLS=0`.
  - The supported release path is the GitHub `release-beta` workflow on `ubuntu-latest`.

## GitHub Delivery

- `verify.yml`
  - Runs on pull requests and pushes to `main`.
  - Covers Bun checks/tests, targeted Forge build/tests, Terraform fmt/validate, `shellcheck`, and Linux bundle creation.
- `release-beta.yml`
  - Manual `workflow_dispatch` only.
  - Must be dispatched from `main`.
  - Uses GitHub OIDC to assume the AWS beta deploy role.
  - Runs Terraform plan first, then applies only after the `beta` GitHub Environment approval.
  - Reuses the same Terraform backend key on every run, so reruns update the same beta stack instead of creating a duplicate one.
  - Bootstraps the host through SSM, invokes `/deploy`, validates `/manifest` and `/actors`, runs remote smoke jobs, exports a named snapshot, verifies the public CloudFront RPC, and writes canonical release records to S3.
- `destroy-beta.yml`
  - Manual `workflow_dispatch` only.
  - Uses the same backend key and tfvars as the release workflow to tear down the existing beta stack.
  - Sets `bucket_force_destroy` in the beta workflow config so the artifacts bucket can be removed cleanly during teardown.

## Safe Beta Ops Playbook

- Safe retry:
  - Use `release-beta.yml` again when the previous run failed before Terraform apply, failed during bootstrap, or failed during protocol deploy/smoke steps.
  - Because the workflow reuses the same Terraform backend key and stack name, rerunning it updates the same beta stack instead of creating a second one.
  - This is the default recovery path.
- Destroy and redeploy:
  - Use `destroy-beta.yml`, then `release-beta.yml`, when the host is stuck in a bad runtime state, the Terraform graph needs to remove drifted resources, or you want a known-clean beta environment.
  - This is also the safest path after major infra changes such as subnet, endpoint, queue, or instance-shape changes.
- Avoid destroy:
  - Do not destroy the beta stack just to roll out a new bundle, rotate runtime env values, or rerun smoke checks.
  - Prefer a straight `release-beta.yml` rerun when you want to preserve the same bucket, instance identity, snapshots, or current deployment evidence.
- Operator rule of thumb:
  - `Release Beta` for normal retries and updates.
  - `Destroy Beta` only for a deliberate reset.
  - Keep `SCURO_TF_STATE_BUCKET`, `SCURO_TF_STATE_KEY`, and `SCURO_BETA_STACK_NAME` stable unless you intentionally want a different environment.

## Post-Release Capture

- Before switching focus, record the release state from the successful `release-beta.yml` run:
  - workflow run URL
  - git SHA
  - AWS region
  - instance id
  - bundle S3 URI
  - snapshot name and snapshot S3 path
  - public RPC URL
  - manifest artifact path
  - actors artifact path
- Prefer the S3 release record as the canonical manifest source for SDK/frontend work:
  - `s3://<artifacts-bucket>/releases/latest.json`
  - `s3://<artifacts-bucket>/releases/<git-sha>/manifest.json`
- Keep the workflow artifacts from the successful run:
  - `deploy-manifest.json`
  - `manifest.json`
  - `actors.json`
  - `smoke-number-picker.json`
  - `smoke-poker.json`
  - `smoke-blackjack.json`
  - `snapshot.json`
  - `host-diagnostics.txt` if present
- Do one human verification pass over SSM port forwarding before moving on:
  - `script/aws/ssm_port_forward.sh <instance-id>`
  - `curl http://127.0.0.1:8787/health`
  - `curl http://127.0.0.1:8787/manifest`
  - `curl http://127.0.0.1:8787/actors`
- Treat the successful release record as the canonical handoff point for SDK work.

### Release Record Template

```md
# Private Beta Release Record

- Date:
- Workflow run URL:
- Git SHA:
- AWS region:
- Stack name:
- Instance ID:
- Bundle URI:
- Public RPC URL:
- Snapshot name:
- Snapshot S3 path:

## Validation

- `/health` checked manually over SSM port forwarding: yes/no
- `/manifest` captured: yes/no
- `/actors` captured: yes/no
- NumberPicker smoke passed: yes/no
- Poker smoke passed: yes/no
- Blackjack smoke passed: yes/no

## Artifacts

- deploy-manifest.json:
- manifest.json:
- actors.json:
- smoke-number-picker.json:
- smoke-poker.json:
- smoke-blackjack.json:
- snapshot.json:
- release-record.json:
- host-diagnostics.txt:

## Notes

- Runtime limitations:
- Follow-up cleanup:
- SDK assumptions based on this beta:
```

## Beta Release Handoff (2026-03-30)

This is the first successful `release-beta.yml` run with the full beta workflow enabled. Treat it as the handoff point between the `scuro-sdk` team and the platform teams (`frontend`, `indexer`, `auth`) ahead of the first tagged beta release.

- Workflow run: [Release Beta #23722592085](https://github.com/zachdt/scuro/actions/runs/23722592085)
- Git SHA: `3aa323990fbb7c16341393655e162c46401825fd`
- AWS region: `us-east-1`
- Stack name: `scuro-testnet-beta`
- Instance ID: `i-0effcfe43055983e7`
- Public RPC URL: `https://d1eu0nzcw8l9ul.cloudfront.net`
- Public RPC chain ID: `31337` (`0x7a69`)
- Bundle URI: `s3://scuro-testnet-beta-artifacts-20260328225139708000000001/bundles/3aa323990fbb7c16341393655e162c46401825fd.tar.gz`
- Snapshot: `beta-3aa323990fbb`
- Snapshot S3 path: `s3://scuro-testnet-beta-artifacts-20260328225139708000000001/snapshots/beta-3aa323990fbb.json`

### Validation Summary

- Protocol deploy completed all stages: `core`, `number-picker`, `poker-tournament`, `poker-pvp`, `blackjack`, `finalize`
- `smoke-number-picker`, `smoke-poker`, and `smoke-blackjack` all completed successfully
- Release snapshot export succeeded
- Public RPC chain ID and block-number checks succeeded
- Release records were published to S3 for downstream consumers

### Canonical Release Artifacts

Use the S3 release record for all downstream integration and release-tag prep:

- `s3://scuro-testnet-beta-artifacts-20260328225139708000000001/releases/latest.json`
- `s3://scuro-testnet-beta-artifacts-20260328225139708000000001/releases/3aa323990fbb7c16341393655e162c46401825fd/manifest.json`
- `s3://scuro-testnet-beta-artifacts-20260328225139708000000001/releases/3aa323990fbb7c16341393655e162c46401825fd/actors.json`
- `s3://scuro-testnet-beta-artifacts-20260328225139708000000001/releases/3aa323990fbb7c16341393655e162c46401825fd/release-record.json`

The release manifest is the source of truth for deployed contract addresses, actor roles, expression token IDs, and AWS/runtime metadata for this beta.

### Team Handoff

- `scuro-sdk`: use the release `manifest.json` and `actors.json` as the canonical config for chain ID, contract addresses, actor identities, and expression token IDs. This is the release candidate baseline to prepare for tagging.
- `frontend`: integrate against the public RPC URL only. Operator/admin routes remain private. Use manifest addresses for Number Picker, Poker, Blackjack, token balances, settlement, rewards, and catalog-driven discovery.
- `indexer`: index from chain ID `31337` using the public RPC endpoint and current manifest addresses. Prioritize protocol events emitted by token contracts, `GameCatalog`, controllers, engines, settlement, developer rewards, and expression registry flows.
- `auth`: no public end-user auth system ships as part of this beta release. Runtime actor keys are still operator-managed environment credentials and should not be treated as a user-facing auth model.

### Current Beta Scope

- Public JSON-RPC is available through CloudFront
- Operator APIs stay private behind the host
- Queue mode is currently `file`
- Poker and Blackjack are validated through fixture-backed smoke coverage in this release workflow

If we tag from this line, platform work should anchor on the published release record rather than ad hoc workflow artifacts or local manifests.

## AWS Prerequisites

- Create the Terraform backend before enabling GitHub applies.
  - Use `infra/aws/testnet/backend.beta.hcl.example` as the shape for the shared state backend.
- Store beta runtime secrets in a SecureString SSM parameter.
  - The parameter value is expected to be newline-delimited env vars, for example:

```dotenv
PRIVATE_KEY=0x...
PLAYER1_PRIVATE_KEY=0x...
PLAYER2_PRIVATE_KEY=0x...
```

- Set the beta repo/environment variables used by the workflows:
  - `SCURO_BETA_AWS_ROLE_ARN`
  - `SCURO_BETA_AWS_REGION`
  - `SCURO_BETA_AVAILABILITY_ZONE`
  - `SCURO_BETA_STACK_NAME`
  - `SCURO_BETA_INSTANCE_TYPE`
  - `SCURO_BETA_ROOT_VOLUME_SIZE`
  - `SCURO_BETA_RUNTIME_ENV_PARAMETER`
  - `SCURO_TF_STATE_BUCKET`
  - `SCURO_TF_STATE_LOCK_TABLE`
  - `SCURO_TF_STATE_REGION`
  - `SCURO_TF_STATE_KEY`
- Budget-friendly defaults for the first beta:
  - `SCURO_BETA_INSTANCE_TYPE=t3.micro`
  - `SCURO_BETA_ROOT_VOLUME_SIZE=40`
- The beta workflows also force `bucket_force_destroy = true` so teardown can clean the artifacts bucket without leaving duplicate stack remnants behind.
- The `40 GiB` root volume is a temporary safety margin while the lean bootstrap path is being proven; the long-term target remains reducing bootstrap peak disk usage enough to return to `20 GiB`.

## Local Verification

- Run the local verification matrix without AWS:
  - `script/aws/verify_local.sh`
- This covers:
  - Bun checks and Bun tests for the operator/worker logic
  - targeted `forge build` for `script/aws`
  - focused `forge test` coverage for fixture loading
  - Anvil-backed deploy and smoke passes for NumberPicker, poker, and blackjack when local listeners are available
  - automatic in-process Forge smoke fallback when the environment blocks Anvil startup

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
- Live blackjack gameplay proving is wired through the worker abstraction and shells to `bun run --cwd zk prove:blackjack`.
- Supported live blackjack job payloads must include either `payload.witnessPath` or `payload.witness` matching the witness JSON shape for `blackjack-initial-deal`, `blackjack-action`, or `blackjack-showdown`.
- `benchmark-live-proof` remains available for operator benchmarking when the full proving toolchain is bundled.

## Remote Operator Commands

- CI-safe remote invocation uses SSM instead of port forwarding:
  - `script/aws/remote_operator.sh <instance-id> GET /health`
  - `script/aws/remote_operator.sh <instance-id> POST /deploy`
  - `script/aws/remote_smoke.sh <instance-id> poker`
  - `script/aws/remote_snapshot_export.sh <instance-id> beta-<sha>`
- Human operators can keep using `script/aws/ssm_port_forward.sh` and the local `protocol_*.sh` / `smoke.sh` scripts.
- With the budget profile, observability is local-only through SSM plus `/var/log/scuro-testnet/*.log` and `journalctl`.
- Bootstrap now extracts only the installer script on the first pass and then stages the payload in-place under the install root to avoid redundant copies during host install.
