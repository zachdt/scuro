# CI/CD And Testing Overview

This page captures the current verification and release surface so the next CI/CD rebuild has a shared baseline. It is intentionally descriptive, not a promise that the current GitHub Actions shape is final.

## Goals For The Rebuild

- Keep the canonical protocol surface easy to verify locally before a pull request.
- Split fast pull-request feedback from slower release and infrastructure checks.
- Make every CI lane map back to a local command or script.
- Preserve staged beta deploy confidence without making every PR wait on AWS.
- Keep generated docs and SDK metadata reproducible from the checked-in source.

## Current Verification Lanes

| Lane | Local command | Current CI coverage | Purpose |
| --- | --- | --- | --- |
| Foundry build | `forge build --offline` | `verify.yml` targeted AWS deploy script build | Compile contracts and deploy scripts without changing generated metadata. |
| Foundry unit and integration tests | `forge test --offline` | `verify.yml` focused core/controller tests | Exercise protocol core, module controllers, and E2E flows. |
| Foundry invariants | `forge test --match-path 'test/invariants/*.t.sol' --offline` | `verify.yml` invariant lane | Stress slot lifecycle, preset, and spin invariants. |
| Local all-up verification | `bash script/verify_local.sh` | Not currently run as one CI job | Runs full Forge tests, invariants, gas tests, optional EV analysis, and Slither advisory checks. |
| AWS-style local verification | `bash script/aws/verify_local.sh` | Partially mirrored in `verify.yml` and release workflows | Builds staged deploy scripts, runs focused tests, deploys to local Anvil, then snapshot-isolates number-picker and slot smokes. |
| Operator type/runtime checks | `bun run --cwd ops/aws-testnet check` | `verify.yml` | Checks the Bun operator and runtime assumptions. |
| Operator tests | `bun test --cwd ops/aws-testnet` | `verify.yml` | Tests AWS testnet operator behavior. |
| Terraform formatting | `terraform -chdir=infra/aws/testnet fmt -check -diff` | `verify.yml` | Keeps beta infrastructure files formatted. |
| Terraform validation | `terraform -chdir=infra/aws/testnet init -backend=false` then `terraform -chdir=infra/aws/testnet validate` | `verify.yml` | Validates beta infrastructure without touching remote state. |
| Shell scripts | `shellcheck -x script/aws/*.sh ops/aws-testnet/runtime/*.sh` | `verify.yml` | Catches shell portability and safety issues. |
| Bundle assembly | `SCURO_BUNDLE_INCLUDE_HOST_TOOLS=0 bash script/aws/build_bundle.sh /tmp/scuro-beta-bundle.tar.gz` | `verify.yml` | Verifies the source-only beta bundle can be assembled on CI. |
| SDK docs metadata | `bash script/docs/check_sdk_docs.sh` | Not currently in `verify.yml` | Regenerates and smokes protocol manifest, ABIs, event signatures, enum labels, and docs coverage. |
| Deploy gas and size | `bash script/aws/check_deploy_gas_regressions.sh` and `bash script/aws/check_deploy_size_regressions.sh` | `deploy-gas-report.yml` | Enforces staged deploy gas and bytecode thresholds. |

## Current GitHub Workflows

| Workflow | Trigger | Role |
| --- | --- | --- |
| `.github/workflows/verify.yml` | Pull requests and pushes to `main` | Main pull-request verification lane for operator checks, focused Forge tests, Terraform validation, Shellcheck, and bundle assembly. |
| `.github/workflows/deploy-gas-report.yml` | Pull requests touching protocol/deploy paths and manual dispatch | Generates the deploy gas baseline artifact and enforces deploy gas and size thresholds. |
| `.github/workflows/release-beta.yml` | Manual dispatch | Builds a Linux beta bundle, applies Terraform, uploads the bundle, deploys protocol contracts through the remote operator, runs smokes, and publishes release records. |
| `.github/workflows/iterate-beta-runtime.yml` | Manual dispatch | Iterates on the existing beta host runtime and can optionally redeploy the protocol. |
| `.github/workflows/destroy-beta.yml` | Manual dispatch | Destroys the beta AWS stack. |

## Suggested Rebuild Shape

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
- `script/aws/verify_local.sh` for staged deploy and snapshot-isolated smokes.
- Deploy gas and bytecode threshold checks.
- Optional Slither advisory lane.
- Optional slot EV analysis when Python dependencies are installed.

### Tier 3: Manual Release Path

Run only through manual dispatch or protected release automation:

- Linux bundle with host tools.
- Terraform plan/apply against the beta backend.
- Remote bootstrap or runtime iteration.
- Async protocol deploy through the operator.
- Manifest validation and snapshot-isolated remote smokes.
- Release record upload and artifact retention.
- Explicit destroy workflow for teardown.

## Local Pre-PR Checklist

For routine contract changes:

```bash
forge build --offline
forge test --offline
forge test --match-path 'test/invariants/*.t.sol' --offline
```

For deploy, operator, or beta runtime changes:

```bash
bun run --cwd ops/aws-testnet check
bun test --cwd ops/aws-testnet
bash script/aws/verify_local.sh
SCURO_BUNDLE_INCLUDE_HOST_TOOLS=0 bash script/aws/build_bundle.sh /tmp/scuro-beta-bundle.tar.gz
```

For docs, ABI, manifest, or SDK-facing changes:

```bash
bash script/docs/check_sdk_docs.sh
```

For release threshold changes:

```bash
bash script/aws/check_deploy_gas_regressions.sh
bash script/aws/check_deploy_size_regressions.sh
```

## Rebuild Notes

- Prefer keeping CI commands identical to checked-in scripts. If a command needs CI-only setup, put the setup in the workflow and keep the behavioral check in a script.
- Keep AWS credentials out of pull-request jobs. PRs should validate Terraform without a backend and use local Anvil for deploy confidence.
- Treat `script/aws/deploy_staged.sh` as the canonical beta deployment path.
- Treat `test/e2e/MATRIX.md` as the E2E coverage index.
- Treat `docs/generated/protocol-manifest.json` and companion generated files as the SDK-facing contract.
- Keep gas and bytecode thresholds explicit in `script/aws/deploy-gas-thresholds.json` and `script/aws/deploy-size-thresholds.json`.
