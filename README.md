# Scuro

Scuro is an on-chain gaming protocol centered on a shared economic core and two canonical solo RNG modules: `NumberPicker` and `SlotMachine`.

The current branch intentionally removes the former non-canonical game and off-chain validation surfaces. Git history is the archive for those modules; the canonical source tree now focuses on deployable slot and number-picker gameplay.

## Core Primitives

- **`ScuroToken` (`SCU`)**: The protocol asset used for wagers, rewards, staking, and payouts.
- **`ScuroStakingToken` (`sSCU`)**: A staked SCU representation used for governance voting power.
- **`ProtocolSettlement`**: The shared value-movement layer for burns, payouts, and developer accruals.
- **`GameCatalog`**: The registry of authorized controllers and engines, with `LIVE`, `RETIRED`, and `DISABLED` lifecycle controls.
- **`GameDeploymentFactory`**: The canonical deployment helper for `NumberPicker` and `SlotMachine` solo modules.
- **`DeveloperExpressionRegistry`**: ERC721 expression identities used for developer reward attribution.
- **`DeveloperRewards`**: Epoch-based developer reward accounting.
- **`ScuroGovernor` and `TimelockController`**: Governance and delayed execution for protocol administration.

## Canonical Modules

- **NumberPicker**: A compact VRF-backed solo game for picking a number and settling immediately through the shared core.
- **SlotMachine**: A governed preset-based slot runtime with canonical `base`, `free`, `pick`, and `hold` presets.

Both modules use the same expression/reward path and are deployed by the local and AWS beta scripts.

## Developer Quickstart

- Build: `forge build --offline`
- Test: `forge test --offline`
- Slot invariants: `forge test --match-path 'test/invariants/*.t.sol' --offline`
- Local deploy smoke: `./script/e2e_deploy_smoke.sh`
- AWS local check: `bash script/aws/verify_local.sh`

For setup details, see [Local Deployment and Testing](./docs/local-deployment-testing.md).

## Documentation Map

- [Docs Index](./docs/README.md)
- [Protocol Architecture](./docs/protocol-architecture.md)
- [Reference Lane](./docs/reference/README.md)
- [Integration Lane](./docs/integration/README.md)
- [Generated Metadata](./docs/generated/README.md)
- [Private AWS Testnet](./docs/private-aws-testnet.md)
- [E2E Scenario Matrix](./test/e2e/MATRIX.md)

## License

Unless otherwise specified in a file header or [THIRD_PARTY_NOTICES.md](./THIRD_PARTY_NOTICES.md), this repository is proprietary and provided for inspection only. See [LICENSE](./LICENSE) for details.
