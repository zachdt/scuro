# GameDeploymentFactory

## Purpose

`GameDeploymentFactory` standardizes controller, engine, verifier-bundle, and catalog registration for shipped module families.

## Caller Model

- Direct callers: deployment or governance actors with `DEPLOYER_ROLE`
- Downstream writes: deploys contracts and registers them in `GameCatalog`

## Roles And Permissions

- `DEFAULT_ADMIN_ROLE`
- `DEPLOYER_ROLE`

## Constructor And Config

- `constructor(admin, catalogAddress, settlementAddress)`
- Supported families:
  - `SoloFamily.NumberPicker`
  - `SoloFamily.Blackjack`
  - `SoloFamily.SuperBaccarat`
  - `MatchFamily.PokerSingleDraw2To7`
  - `MatchFamily.CheminDeFerBaccarat`

## Public API

- `catalog()`
- `settlement()`
- `deploySoloModule(family, deploymentParams)`
- `deployPvPModule(family, deploymentParams)`
- `deployTournamentModule(family, deploymentParams)`

## Events

- `ModuleDeployed`

## State And Lifecycle Notes

- The factory deploys verifier bundles for poker and blackjack automatically
- Solo baccarat and chemin de fer deploy without verifier bundles and instead use VRF coordinators
- Every deployed module starts as `LIVE` in the catalog
- `deploymentParams` are ABI-encoded family-specific structs, so SDKs should expose typed wrappers rather than raw bytes

## Revert Conditions

- Missing `DEPLOYER_ROLE`
- Unsupported family value for the selected deploy function
- Any revert bubbling up from constructor code or `GameCatalog.registerModule`

## Test Anchors

- `script/DeployLocal.s.sol`
- `test/e2e/BaseE2E.t.sol`
- `test/ProtocolCore.t.sol`
