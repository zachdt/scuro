# SuperBaccaratController

## Purpose

`SuperBaccaratController` is the user-facing settlement wrapper around `SuperBaccaratEngine`.

For the canonical product rules and economics, see the [Super Baccarat session spec](../session-specs/super-baccarat.md).

## Caller Model

- Players start rounds through `play`
- Any caller may settle once the engine reports completion

## Roles And Permissions

- No local roles
- Launch and settlement gating are delegated to `GameCatalog`

## Constructor And Config

- `constructor(settlementAddress, catalogAddress, engineAddress)`

## Public API

- `engine()`
- `sessionSettled(sessionId)`
- `sessionExpressionTokenId(sessionId)`
- `play(wager, side, playRef, expressionTokenId)`
- `settle(sessionId)`

## Events

- `PlayStarted`
- `SessionSettled`

## State And Lifecycle Notes

- The controller burns the wager before requesting a round from the engine
- Settlement uses the engine’s solo lifecycle tuple and accrues developer rewards from `totalBurned`

## Revert Conditions

- Module inactive
- Duplicate settlement
- Engine not yet completed
- Any bubbled engine revert

## Test Anchors

- `test/SuperBaccaratController.t.sol`
- `test/e2e/UserFlowsE2E.t.sol`
- `test/e2e/AbusePathsE2E.t.sol`
