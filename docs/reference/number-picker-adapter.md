# NumberPickerAdapter

## Purpose

`NumberPickerAdapter` is the user-facing controller for the NumberPicker module. It burns the wager, asks the engine for randomness, and settles the result.

## Caller Model

- Players call `play`
- Any caller may call `finalize` once the engine is complete

## Roles And Permissions

- No local roles
- Launch and settlement gating are delegated to `GameCatalog`

## Constructor And Config

- `constructor(settlementAddress, catalogAddress, engineAddress)`
- Exposes `settlement()`, `catalog()`, and `engine()`

## Public API

- `engine()`
- `requestSettled(requestId)`
- `requestExpressionTokenId(requestId)`
- `play(wager, selection, playRef, expressionTokenId)`
- `finalize(requestId)`

## Events

- `PlayFinalized`

## State And Lifecycle Notes

- `play()` eagerly calls `_finalize()`, so the full flow completes in one transaction when the VRF callback happens immediately
- The adapter records `expressionTokenId` locally and uses it during settlement

## Revert Conditions

- Module inactive for launch or settlement
- Pending engine outcome on `finalize`
- Duplicate settlement
- Engine payout mismatch against the solo settlement tuple

## Test Anchors

- `test/NumberPickerAdapter.t.sol`
- `test/e2e/UserFlowsE2E.t.sol`
- `test/e2e/AbusePathsE2E.t.sol`
