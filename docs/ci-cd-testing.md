# CI/CD And Testing Overview

This page captures the canonical verification and release surface for Scuro. Pull requests should stay fast and local-first. Hosted testnet work should map back to scripts that can also be run from a maintainer machine.

## Goals

- Keep the canonical protocol surface easy to verify locally before a pull request.
- Split fast pull-request feedback from slower release and infrastructure checks.
- Make every CI lane map back to a checked-in command or script.
- Preserve staged hosted-testnet deploy confidence without requiring cloud credentials in pull-request jobs.
- Keep generated docs and SDK metadata reproducible from the checked-in source.

## Verification Lanes

| Lane | Local command | CI coverage | Purpose |
| --- | --- | --- | --- |
| Foundry build | `forge build --offline` | `verify.yml` targeted testnet deploy script build | Compile contracts and deploy scripts without changing generated metadata. |
| Foundry unit and integration tests | `forge test --offline` | `verify.yml` focused core/controller tests | Exercise protocol core, module controllers, and E2E flows. |
| Foundry invariants | `forge test --match-path 'test/invariants/*.t.sol' --offline` | `verify.yml` invariant lane | Stress slot lifecycle, preset, and spin invariants. |
| Local all-up verification | `bash script/verify_local.sh` | Optional heavy lane | Runs full Forge tests, invariants, gas tests, optional EV analysis, and Slither advisory checks. |
| Canonical staged verification | `bash script/testnet/verify_local.sh` | Mirrored by release workflows where practical | Deploys to local Anvil using the hosted testnet deploy path, snapshots clean state, and runs isolated smokes. |
| Operator type/runtime checks | `bun run --cwd ops/testnet check` | `verify.yml` | Checks the Bun operator and runtime assumptions. |
| Operator tests | `bun test --cwd ops/testnet` | `verify.yml` | Tests canonical testnet operator behavior. |
| Terraform formatting | `terraform -chdir=infra/hetzner-cloudflare/testnet fmt -check -diff` | `verify.yml` | Keeps canonical infrastructure files formatted. |
| Terraform validation | `terraform -chdir=infra/hetzner-cloudflare/testnet init -backend=false` then `terraform -chdir=infra/hetzner-cloudflare/testnet validate` | `verify.yml` | Validates infrastructure without touching local state or provider APIs. |
| Shell scripts | `shellcheck -x script/testnet/*.sh ops/testnet/runtime/*.sh` | `verify.yml` | Catches shell portability and safety issues. |
| Bundle assembly | `SCURO_BUNDLE_INCLUDE_HOST_TOOLS=0 bash script/testnet/build_bundle.sh /tmp/scuro-testnet-bundle.tar.gz` | `verify.yml` | Verifies the source-only testnet bundle can be assembled on CI. |
| SDK docs metadata | `bash script/docs/check_sdk_docs.sh` | Conditional docs lane | Regenerates and smokes protocol manifest, ABIs, event signatures, enum labels, and docs coverage. |
| Deploy gas and size | `bash script/testnet/check_deploy_gas_regressions.sh` and `bash script/testnet/check_deploy_size_regressions.sh` | `deploy-gas-report.yml` | Enforces staged deploy gas and bytecode thresholds. |

## GitHub Workflows

| Workflow | Trigger | Role |
| --- | --- | --- |
| `.github/workflows/verify.yml` | Pull requests and pushes to `main` | Main pull-request verification lane for operator checks, focused Forge tests, Terraform validation, Shellcheck, and bundle assembly. |
| `.github/workflows/deploy-gas-report.yml` | Pull requests touching protocol/deploy paths and manual dispatch | Generates the deploy gas baseline artifact and enforces deploy gas and size thresholds. |
| `.github/workflows/release-testnet.yml` | Manual dispatch with `testnet` environment protection | Builds a Linux bundle, uploads it to the Hetzner host over SSH, bootstraps the runtime, deploys contracts through the operator, runs smokes, and uploads release records. |
| `.github/workflows/iterate-testnet-runtime.yml` | Manual dispatch with `testnet` environment protection | Iterates on the existing testnet host runtime and can optionally redeploy the protocol. |

First-time GitHub variable and secret setup is documented in [GitHub Actions Testnet Setup](./github-actions-testnet-setup.md).

## Suggested CI Shape

Use three tiers so each job has a clear reason to exist.

### Tier 1: Pull Request Fast Path

Run on every pull request:

- Bun operator check and tests.
- Targeted Forge build for deploy scripts.
- Focused Forge tests for `ProtocolCore`, `NumberPickerAdapter`, and `SlotMachineController`.
- Slot invariant tests with bounded fuzz runs.
- Terraform format and backend-free validation.
- Shellcheck.
- Source-only bundle build.
- SDK docs metadata check if generated docs or ABI surfaces are touched.

### Tier 2: Pull Request Heavy Path

Run on protocol, deploy, or release-path changes:

- Full `forge test --offline`.
- `script/testnet/verify_local.sh` for staged deploy and snapshot-isolated smokes.
- Deploy gas and bytecode threshold checks.
- Optional Slither advisory lane.
- Optional slot EV analysis when Python dependencies are installed.

### Tier 3: Manual Release Path

Run only through manual dispatch or protected release automation:

- Linux bundle with host tools.
- SSH upload to the canonical Hetzner host.
- Remote bootstrap or runtime iteration.
- Async protocol deploy through the operator.
- Manifest validation and snapshot-isolated remote smokes.
- Public RPC verification through the Cloudflare hostname.
- Release record upload and artifact retention.

## Local Pre-PR Checklist

For routine contract changes:

```bash
forge build --offline
forge test --offline
forge test --match-path 'test/invariants/*.t.sol' --offline
```

For deploy, operator, or testnet runtime changes:

```bash
bun run --cwd ops/testnet check
bun test --cwd ops/testnet
bash script/testnet/verify_local.sh
SCURO_BUNDLE_INCLUDE_HOST_TOOLS=0 bash script/testnet/build_bundle.sh /tmp/scuro-testnet-bundle.tar.gz
```

For docs, ABI, manifest, or SDK-facing changes:

```bash
bash script/docs/check_sdk_docs.sh
```

For release threshold changes:

```bash
bash script/testnet/check_deploy_gas_regressions.sh
bash script/testnet/check_deploy_size_regressions.sh
```

## Hosted Testnet Release Checklist

Before the first manual hosted release, complete [Canonical Testnet](./canonical-testnet.md) and [GitHub Actions Testnet Setup](./github-actions-testnet-setup.md).

For every hosted release:

- Confirm the GitHub `testnet` environment has the current SSH host, SSH user, RPC hostname, and required secrets.
- Build and upload the bundle.
- Bootstrap or restart the runtime.
- Wait for operator health and chain readiness.
- Deploy through the operator and wait for the job to complete.
- Save manifest and actors outputs.
- Run snapshot-isolated number-picker and slot smokes.
- Verify `https://${SCURO_TESTNET_RPC_HOSTNAME}` responds to JSON-RPC.
- Verify direct public access to `:8545` and `:8787` fails.
- Upload deploy job, manifest, smoke outputs, public RPC checks, and diagnostics as artifacts.

## Notes

- Keep cloud provider tokens out of pull-request jobs. PRs should validate Terraform without a backend and use local Anvil for deploy confidence.
- Treat `script/testnet/deploy_staged.sh` as the canonical hosted testnet deployment path.
- Treat `test/e2e/MATRIX.md` as the E2E coverage index.
- Treat `docs/generated/protocol-manifest.json` and companion generated files as the SDK-facing contract.
- Keep gas and bytecode thresholds explicit in `script/testnet/deploy-gas-thresholds.json` and `script/testnet/deploy-size-thresholds.json`.
- Local Terraform state in `infra/hetzner-cloudflare/testnet` is canonical for v1 unless a remote backend is intentionally added later.
