# GameDeploymentFactory

## Purpose

`GameDeploymentFactory` standardizes controller, engine, and catalog registration for the canonical solo module families.

## Caller Model

- Direct callers: deployment or governance actors with `DEPLOYER_ROLE`
- Downstream writes: deploys contracts and registers them in `GameCatalog`

## Roles And Permissions

- `DEFAULT_ADMIN_ROLE`
- `DEPLOYER_ROLE`

## Constructor And Config

- `constructor(admin, catalogAddress, settlementAddress, soloModuleDeployerAddress)`
- Supported families:
  - `SoloFamily.NumberPicker`
  - `SoloFamily.SlotMachine`

## Public API

- `catalog()`
- `settlement()`
- `soloModuleDeployer()`
- `deploySoloModule(family, deploymentParams)`

## Events

- `ModuleDeployed`

## State And Lifecycle Notes

- Number picker and slot machine use the configured VRF coordinator
- Every deployed module starts as `LIVE` in the catalog
- `deploymentParams` are ABI-encoded family-specific structs, so SDKs should expose typed wrappers rather than raw bytes
- Number picker modules use `NumberPickerDeployment { vrfCoordinator, configHash, developerRewardBps }`
- Slot modules use `SlotDeployment { vrfCoordinator, configHash, developerRewardBps }`

## Revert Conditions

- Missing `DEPLOYER_ROLE`
- Unsupported family value for the selected deploy function
- Any revert bubbling up from constructor code or `GameCatalog.registerModule`

## Test Anchors

- `script/DeployLocal.s.sol`
- `test/e2e/BaseE2E.t.sol`
- `test/ProtocolCore.t.sol`
