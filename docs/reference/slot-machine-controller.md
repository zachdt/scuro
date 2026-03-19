# SlotMachineController

## Purpose

`SlotMachineController` is the user-facing controller for the governed slot module. It burns the player stake, launches a preset-driven spin on the engine, and settles the resolved payout through `ProtocolSettlement`.

## Caller Model

- Players call `spin`
- Any caller may call `settle` once the engine has resolved the spin

## Roles And Permissions

- No local roles
- Launch and settlement gating are delegated to `GameCatalog`

## Constructor And Config

- `constructor(settlementAddress, catalogAddress, engineAddress)`
- Exposes `settlement()`, `catalog()`, and `engine()`

## Public API

- `engine()`
- `spinSettled(spinId)`
- `spinExpressionTokenId(spinId)`
- `spin(stake, presetId, playRef, expressionTokenId)`
- `settle(spinId)`

## Events

- `SpinFinalized`

## State And Lifecycle Notes

- `spin()` eagerly calls `_finalize()`, so the full flow completes in one transaction when the VRF callback happens immediately
- The controller records `expressionTokenId` locally and uses it during settlement
- Developer accrual uses the original burned stake, not the resolved payout

## Revert Conditions

- Module inactive for launch or settlement
- Pending engine outcome on `settle`
- Duplicate settlement

## Test Anchors

- `test/SlotMachineController.t.sol`
- `test/e2e/SmokeE2E.t.sol`
- `test/e2e/UserFlowsE2E.t.sol`
- `test/e2e/AbusePathsE2E.t.sol`
